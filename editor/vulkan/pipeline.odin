package renderer

import "core:fmt"
import "core:mem"
import "core:os"
import "core:slice"
import vk "vendor:vulkan"
import "vendor:zlib"

Vertex :: struct {
	position: [2]f32,
	uv:       [2]f32,
}

quad_indices :: [6]u32{0, 1, 2, 0, 2, 3}

append_quad :: proc(verts: ^[dynamic]Vertex, indices: ^[dynamic]u32, min: [2]f32, max: [2]f32) {
	base := u32(len(verts^))
	append(verts, Vertex{{min.x, min.y}, {0, 1}})
	append(verts, Vertex{{max.x, min.y}, {1, 1}})
	append(verts, Vertex{{max.x, max.y}, {1, 0}})
	append(verts, Vertex{{min.x, max.y}, {0, 0}})

	for index in quad_indices {
		append(indices, base + index)
	}
}

// Convenience wrapper for current hardcoded quad test geometry.
// Uses generic upload path to create vertex/index buffers and upload quad data.
create_quad_geo :: proc(
	l_device: vk.Device,
	p_device: vk.PhysicalDevice,
	geo_mem: ^GeoMemory,
) -> bool {
	verts := make([dynamic]Vertex)
	defer delete(verts)
	indices := make([dynamic]u32)
	defer delete(indices)

	append_quad(&verts, &indices, {-0.95, -0.75}, {-0.10, 0.75})
	append_quad(&verts, &indices, {0.10, -0.45}, {0.95, 0.45})

	return create_geo(l_device, p_device, verts[:], indices[:], geo_mem)
}

// Create GPU buffers for CPU-side vertex/index arrays and upload bytes into them.
// This version uses HOST_VISIBLE | HOST_COHERENT memory so CPU can map once,
// copy data directly, then unmap. Resulting buffer handles live in `geo_mem`.
create_geo :: proc(
	l_device: vk.Device,
	p_device: vk.PhysicalDevice,
	verts: []Vertex,
	indices: []u32,
	geo_mem: ^GeoMemory,
) -> bool {
	// Compute total byte sizes for vertex and index arrays.
	vert_size := vk.DeviceSize(len(verts) * size_of(Vertex))
	indices_size := vk.DeviceSize(len(indices) * size_of(u32))
	// Store index count now; later indexed draw call will use this value.
	geo_mem.index_count = u32(len(indices))
	// Create vertex buffer + backing memory.
	vert_buff_ok := create_buffer(
		p_device,
		l_device,
		vert_size,
		{.VERTEX_BUFFER},
		{.HOST_VISIBLE, .HOST_COHERENT},
		&geo_mem.vertex_buffer,
		&geo_mem.vertex_buffer_memory,
	)
	if !vert_buff_ok {
		return false
	}

	// Create index buffer + backing memory.
	indices_buffer_ok := create_buffer(
		p_device,
		l_device,
		indices_size,
		{.INDEX_BUFFER},
		{.HOST_VISIBLE, .HOST_COHERENT},
		&geo_mem.index_buffer,
		&geo_mem.index_buffer_memory,
	)
	if !indices_buffer_ok {
		vk.DestroyBuffer(l_device, geo_mem.vertex_buffer, nil)
		vk.FreeMemory(l_device, geo_mem.vertex_buffer_memory, nil)
		return false
	}
	// Map vertex allocation so CPU can write vertex bytes into Vulkan-owned memory.
	vert_mapped_data: rawptr
	v_map_ok := vk.MapMemory(
		l_device,
		geo_mem.vertex_buffer_memory,
		0,
		vert_size,
		{},
		&vert_mapped_data,
	)
	if v_map_ok != vk.Result.SUCCESS {
		vk.DestroyBuffer(l_device, geo_mem.index_buffer, nil)
		vk.FreeMemory(l_device, geo_mem.index_buffer_memory, nil)
		vk.DestroyBuffer(l_device, geo_mem.vertex_buffer, nil)
		vk.FreeMemory(l_device, geo_mem.vertex_buffer_memory, nil)
		return false
	}
	// Copy CPU vertex array into mapped memory.
	mem.copy(vert_mapped_data, raw_data(verts), int(vert_size))
	vk.UnmapMemory(l_device, geo_mem.vertex_buffer_memory)

	// Same upload path for index data.
	index_mapped_data: rawptr
	i_map_ok := vk.MapMemory(
		l_device,
		geo_mem.index_buffer_memory,
		0,
		indices_size,
		{},
		&index_mapped_data,
	)
	if i_map_ok != vk.Result.SUCCESS {
		vk.DestroyBuffer(l_device, geo_mem.index_buffer, nil)
		vk.FreeMemory(l_device, geo_mem.index_buffer_memory, nil)

		vk.DestroyBuffer(l_device, geo_mem.vertex_buffer, nil)
		vk.FreeMemory(l_device, geo_mem.vertex_buffer_memory, nil)
		return false
	}
	// Copy CPU index array into mapped memory.
	mem.copy(index_mapped_data, raw_data(indices), int(indices_size))
	vk.UnmapMemory(l_device, geo_mem.index_buffer_memory)
	return true
}

get_vertex_binding_description :: proc() -> vk.VertexInputBindingDescription {
	return {binding = 0, stride = u32(size_of(Vertex)), inputRate = .VERTEX}
}

get_vertex_attribute_descriptions :: proc() -> [2]vk.VertexInputAttributeDescription {
	return {
		vk.VertexInputAttributeDescription {
			binding = 0,
			location = 0,
			format = .R32G32_SFLOAT,
			offset = 0,
		},
		vk.VertexInputAttributeDescription {
			binding = 0,
			location = 1,
			format = .R32G32_SFLOAT,
			offset = size_of(Vertex{}.position),
		},
	}
}

// Vulkan memory comes in multiple types. `type_filter` says which indices are legal
// for this buffer. `properties` says what we want from that memory type, like
// HOST_VISIBLE or HOST_COHERENT. We scan legal types and return first match.
find_memory_type :: proc(
	physical_device: vk.PhysicalDevice,
	type_filter: u32,
	properties: vk.MemoryPropertyFlags,
) -> (
	u32,
	bool,
) {
	memory_props: vk.PhysicalDeviceMemoryProperties
	vk.GetPhysicalDeviceMemoryProperties(physical_device, &memory_props)

	for i in 0 ..< int(memory_props.memoryTypeCount) {
		mem_type := memory_props.memoryTypes[i]
		// `type_filter` is a bitmask: if bit i is set, memory type i is allowed.
		type_allowed := (type_filter & (1 << uint(i))) != 0
		// Memory properties are also a bitmask. This checks all requested flags exist.
		properties_match := (mem_type.propertyFlags & properties) == properties

		if type_allowed && properties_match {
			return u32(i), true
		}
	}
	return 0, false
}

// Create buffer handle, ask Vulkan what memory it needs, allocate that memory,
// then bind buffer to memory. `vk.CreateBuffer` alone does not allocate storage.
create_buffer :: proc(
	p_device: vk.PhysicalDevice,
	l_device: vk.Device,
	size: vk.DeviceSize,
	usage: vk.BufferUsageFlags,
	properties: vk.MemoryPropertyFlags,
	out_buffer: ^vk.Buffer,
	out_memory: ^vk.DeviceMemory,
) -> bool {

	// Step 1: create buffer object that describes size + intended usage.
	buffer_info := vk.BufferCreateInfo {
		sType       = .BUFFER_CREATE_INFO,
		size        = size,
		usage       = usage,
		sharingMode = .EXCLUSIVE,
	}
	if vk.CreateBuffer(l_device, &buffer_info, nil, out_buffer) != vk.Result.SUCCESS {
		fmt.eprintln("Could Not Create Buffer")
		return false
	}

	// Step 2: query memory requirements for this specific buffer.
	mem_reqs: vk.MemoryRequirements
	vk.GetBufferMemoryRequirements(l_device, out_buffer^, &mem_reqs)
	found_index, me_ok := find_memory_type(p_device, mem_reqs.memoryTypeBits, properties)
	if !me_ok {
		fmt.eprintln("Could not find memory type")
		vk.DestroyBuffer(l_device, out_buffer^, nil)
		return false
	}

	// Step 3: allocate backing memory from chosen memory type.
	mem_alloc_info := vk.MemoryAllocateInfo {
		sType           = .MEMORY_ALLOCATE_INFO,
		allocationSize  = mem_reqs.size,
		memoryTypeIndex = found_index,
	}
	if vk.AllocateMemory(l_device, &mem_alloc_info, nil, out_memory) != vk.Result.SUCCESS {
		fmt.eprintln("Could not Alloc Mem")
		vk.DestroyBuffer(l_device, out_buffer^, nil)
		return false
	}

	// Step 4: attach buffer object to allocation so GPU knows where bytes live.
	if vk.BindBufferMemory(l_device, out_buffer^, out_memory^, 0) != vk.Result.SUCCESS {
		vk.FreeMemory(l_device, out_memory^, nil)
		vk.DestroyBuffer(l_device, out_buffer^, nil)
		return false
	}

	return true
}

read_file :: proc(filepath: string) -> ([]byte, bool) {
	data, ok := os.read_entire_file(filepath)
	if !ok {
		fmt.eprintfln("Failed to read file: %s", filepath)
		return nil, false
	}
	return data, true
}

create_shader_module :: proc(device: vk.Device, code: []byte) -> (vk.ShaderModule, bool) {
	words := slice.reinterpret([]u32, code)

	create_info := vk.ShaderModuleCreateInfo {
		sType    = .SHADER_MODULE_CREATE_INFO,
		codeSize = len(code),
		pCode    = cast(^u32)raw_data(words), // code needs to be in 32bit words
	}
	shader_module: vk.ShaderModule
	result := vk.CreateShaderModule(device, &create_info, nil, &shader_module)
	if result != vk.Result.SUCCESS {
		fmt.eprintfln("Failed to create Shader Module: %d", result)
		return 0, false
	}

	return shader_module, true
}

// create_graphics_pipeline :: proc(
// 	device: vk.Device,
// 	extent: vk.Extent2D,
// 	renderpass: vk.RenderPass,
// 	layout: ^vk.PipelineLayout,
// 	gp: ^vk.Pipeline,
// ) -> bool {
// 	vert_code, vert_ok := read_file("./assets/shaders/triangle.vert.spv")
// 	if !vert_ok do return false
// 	defer delete(vert_code)

// 	frag_code, frag_ok := read_file("./assets/shaders/triangle.frag.spv")
// 	if !frag_ok do return false
// 	defer delete(frag_code)

// 	return _create_graphics_pipeline(frag_code, vert_code, device, extent, renderpass, layout, gp)
// }

_create_graphics_pipeline :: proc(
	code: []byte,
	device: vk.Device,
	extent: vk.Extent2D,
	renderpass: vk.RenderPass,
	layout: ^vk.PipelineLayout,
	gp: ^vk.Pipeline,
) -> bool {
	code_module, code_mod_ok := create_shader_module(device, code)
	if !code_mod_ok do return false
	defer vk.DestroyShaderModule(device, code_module, nil)


	vert_stage := vk.PipelineShaderStageCreateInfo {
		sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage  = {.VERTEX},
		module = code_module,
		pName  = "vertexMain",
	}

	frag_stage := vk.PipelineShaderStageCreateInfo {
		sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage  = {.FRAGMENT},
		module = code_module,
		pName  = "fragmentMain",
	}

	shader_stages := [2]vk.PipelineShaderStageCreateInfo{vert_stage, frag_stage}


	binding_desc := get_vertex_binding_description()
	attr_desc := get_vertex_attribute_descriptions()

	vertex_input_info := vk.PipelineVertexInputStateCreateInfo {
		sType                           = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
		vertexBindingDescriptionCount   = 1,
		pVertexBindingDescriptions      = &binding_desc,
		vertexAttributeDescriptionCount = 2,
		pVertexAttributeDescriptions    = &attr_desc[0],
	}
	input_assembly := vk.PipelineInputAssemblyStateCreateInfo {
		sType                  = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
		topology               = .TRIANGLE_LIST,
		primitiveRestartEnable = false,
	}

	viewport := vk.Viewport {
		x        = 0.0,
		y        = 0.0,
		width    = f32(extent.width),
		height   = f32(extent.height),
		minDepth = 0.0,
		maxDepth = 1.0,
	}

	scissor := vk.Rect2D {
		offset = {0, 0},
		extent = extent,
	}

	viewport_state := vk.PipelineViewportStateCreateInfo {
		sType         = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
		viewportCount = 1,
		pViewports    = &viewport,
		scissorCount  = 1,
		pScissors     = &scissor,
	}

	rasterizer := vk.PipelineRasterizationStateCreateInfo {
		sType                   = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
		depthClampEnable        = false,
		rasterizerDiscardEnable = false,
		polygonMode             = .FILL,
		lineWidth               = 1.0,
		cullMode                = {},
		frontFace               = .CLOCKWISE,
		depthBiasEnable         = false,
	}

	multsampling := vk.PipelineMultisampleStateCreateInfo {
		sType                = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
		sampleShadingEnable  = false,
		rasterizationSamples = {._1},
	}

	color_blend_attachment := vk.PipelineColorBlendAttachmentState {
		colorWriteMask = {.R, .G, .B, .A},
		blendEnable    = false,
	}

	color_blending := vk.PipelineColorBlendStateCreateInfo {
		sType           = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
		logicOpEnable   = false,
		logicOp         = .COPY,
		attachmentCount = 1,
		pAttachments    = &color_blend_attachment,
	}

	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
	}

	if vk.CreatePipelineLayout(device, &layout_info, nil, layout) != vk.Result.SUCCESS {
		fmt.println("Unabel to create Pipeline layout")
		return false
	}

	pipeline_info := vk.GraphicsPipelineCreateInfo {
		sType               = .GRAPHICS_PIPELINE_CREATE_INFO,
		stageCount          = 2,
		pStages             = &shader_stages[0],
		pVertexInputState   = &vertex_input_info,
		pInputAssemblyState = &input_assembly,
		pViewportState      = &viewport_state,
		pRasterizationState = &rasterizer,
		pMultisampleState   = &multsampling,
		pColorBlendState    = &color_blending,
		layout              = layout^,
		renderPass          = renderpass,
		subpass             = 0,
	}

	result := vk.CreateGraphicsPipelines(device, 0, 1, &pipeline_info, nil, gp)
	if result != vk.Result.SUCCESS {
		fmt.eprintfln("Failed to create graphics pipeline: %d", result)
		return false
	}
	fmt.println("Created Graphics Pipeline")
	return true
}

create_render_pass :: proc(
	device: vk.Device,
	format: vk.Format,
	render_pass: ^vk.RenderPass,
) -> bool {
	color_attachment := vk.AttachmentDescription {
		format         = format,
		loadOp         = .CLEAR,
		samples        = {._1},
		storeOp        = .STORE,
		stencilLoadOp  = .DONT_CARE,
		stencilStoreOp = .DONT_CARE,
		initialLayout  = .UNDEFINED,
		finalLayout    = .PRESENT_SRC_KHR,
	}

	color_attchement_ref := vk.AttachmentReference {
		attachment = 0,
		layout     = .COLOR_ATTACHMENT_OPTIMAL,
	}

	subpass := vk.SubpassDescription {
		pipelineBindPoint    = .GRAPHICS,
		colorAttachmentCount = 1,
		pColorAttachments    = &color_attchement_ref,
	}

	dependecy := vk.SubpassDependency {
		srcSubpass    = vk.SUBPASS_EXTERNAL,
		dstSubpass    = 0,
		srcStageMask  = {.COLOR_ATTACHMENT_OUTPUT},
		srcAccessMask = {},
		dstStageMask  = {.COLOR_ATTACHMENT_OUTPUT},
		dstAccessMask = {.COLOR_ATTACHMENT_WRITE},
	}

	render_pass_info := vk.RenderPassCreateInfo {
		sType           = .RENDER_PASS_CREATE_INFO,
		attachmentCount = 1,
		pAttachments    = &color_attachment,
		subpassCount    = 1,
		pSubpasses      = &subpass,
		dependencyCount = 1,
		pDependencies   = &dependecy,
	}

	result := vk.CreateRenderPass(device, &render_pass_info, nil, render_pass)
	if result != vk.Result.SUCCESS {
		fmt.eprintfln("Failed to create render pass: %v", result)
		return false
	}

	fmt.println("Render Pass Created")
	return true
}


create_offscreen_render_pass :: proc(
	device: vk.Device,
	format: vk.Format,
	render_pass: ^vk.RenderPass,
) -> bool {
	color_attachment := vk.AttachmentDescription {
		format         = format,
		loadOp         = .CLEAR,
		samples        = {._1},
		storeOp        = .STORE,
		stencilLoadOp  = .DONT_CARE,
		stencilStoreOp = .DONT_CARE,
		initialLayout  = .UNDEFINED,
		finalLayout    = .SHADER_READ_ONLY_OPTIMAL,
	}

	color_attchement_ref := vk.AttachmentReference {
		attachment = 0,
		layout     = .COLOR_ATTACHMENT_OPTIMAL,
	}

	subpass := vk.SubpassDescription {
		pipelineBindPoint    = .GRAPHICS,
		colorAttachmentCount = 1,
		pColorAttachments    = &color_attchement_ref,
	}

	dependecy := vk.SubpassDependency {
		srcSubpass    = vk.SUBPASS_EXTERNAL,
		dstSubpass    = 0,
		srcStageMask  = {.COLOR_ATTACHMENT_OUTPUT},
		srcAccessMask = {},
		dstStageMask  = {.COLOR_ATTACHMENT_OUTPUT},
		dstAccessMask = {.COLOR_ATTACHMENT_WRITE},
	}

	render_pass_info := vk.RenderPassCreateInfo {
		sType           = .RENDER_PASS_CREATE_INFO,
		attachmentCount = 1,
		pAttachments    = &color_attachment,
		subpassCount    = 1,
		pSubpasses      = &subpass,
		dependencyCount = 1,
		pDependencies   = &dependecy,
	}

	result := vk.CreateRenderPass(device, &render_pass_info, nil, render_pass)
	if result != vk.Result.SUCCESS {
		fmt.eprintfln("Failed to create render pass: %v", result)
		return false
	}

	fmt.println("Render Pass Created")
	return true
}
create_framebuffers :: proc(
	device: vk.Device,
	renderpass: vk.RenderPass,
	image_views: []vk.ImageView,
	extent: vk.Extent2D,
	framebuffers: ^[]vk.Framebuffer,
) -> bool {
	framebuffers^ = make([]vk.Framebuffer, len(image_views))

	for view, i in image_views {
		attachments := [1]vk.ImageView{view}

		frameBuffer_info := vk.FramebufferCreateInfo {
			sType           = .FRAMEBUFFER_CREATE_INFO,
			renderPass      = renderpass,
			attachmentCount = 1,
			pAttachments    = &attachments[0],
			height          = extent.height,
			width           = extent.width,
			layers          = 1,
		}
		result := vk.CreateFramebuffer(device, &frameBuffer_info, nil, &framebuffers[i])
		if result != vk.Result.SUCCESS {
			fmt.eprintfln("Failed to create buffer: %d", result)
			return false
		}
	}
	fmt.println("Created Frame Buffers")
	return true
}

