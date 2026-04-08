package renderer

import "core:fmt"
import "core:os"
import vk "vendor:vulkan"

read_file :: proc(filepath: string) -> ([]byte, bool) {
	data, ok := os.read_entire_file(filepath)
	if !ok {
		fmt.eprintfln("Failed to read file: %s", filepath)
		return nil, false
	}
	return data, true
}

create_shader_module :: proc(device: vk.Device, code: []byte) -> (vk.ShaderModule, bool) {
	create_info := vk.ShaderModuleCreateInfo {
		sType    = .SHADER_MODULE_CREATE_INFO,
		codeSize = len(code),
		pCode    = cast(^u32)raw_data(code),
	}
	shader_module: vk.ShaderModule
	result := vk.CreateShaderModule(device, &create_info, nil, &shader_module)
	if result != vk.Result.SUCCESS {
		fmt.eprintfln("Failed to create Shader Module: %d", result)
		return 0, false
	}

	return shader_module, true
}

create_graphics_pipeline :: proc(
	device: vk.Device,
	extent: vk.Extent2D,
	renderpass: vk.RenderPass,
	layout: ^vk.PipelineLayout,
	gp: ^vk.Pipeline,
) -> bool {
	vert_code, vert_ok := read_file("./assets/shaders/triangle.vert.spv")
	if !vert_ok do return false
	defer delete(vert_code)

	frag_code, frag_ok := read_file("./assets/shaders/triangle.frag.spv")
	if !frag_ok do return false
	defer delete(frag_code)

	return _create_graphics_pipeline(frag_code, vert_code, device, extent, renderpass, layout, gp)
}

_create_graphics_pipeline :: proc(
	frag_code: []byte,
	vert_code: []byte,
	device: vk.Device,
	extent: vk.Extent2D,
	renderpass: vk.RenderPass,
	layout: ^vk.PipelineLayout,
	gp: ^vk.Pipeline,
) -> bool {
	vert_module, vert_mod_ok := create_shader_module(device, vert_code)
	if !vert_mod_ok do return false
	defer vk.DestroyShaderModule(device, vert_module, nil)

	frag_module, frag_mod_ok := create_shader_module(device, frag_code)
	if !frag_mod_ok do return false
	defer vk.DestroyShaderModule(device, frag_module, nil)

	vert_stage := vk.PipelineShaderStageCreateInfo {
		sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage  = {.VERTEX},
		module = vert_module,
		pName  = "main",
	}

	frag_stage := vk.PipelineShaderStageCreateInfo {
		sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage  = {.FRAGMENT},
		module = frag_module,
		pName  = "main",
	}

	shader_stages := [2]vk.PipelineShaderStageCreateInfo{vert_stage, frag_stage}

	vertex_input_info := vk.PipelineVertexInputStateCreateInfo {
		sType                           = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
		vertexBindingDescriptionCount   = 0,
		vertexAttributeDescriptionCount = 0,
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
		cullMode                = {.BACK},
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
