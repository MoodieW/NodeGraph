package main

import "base:runtime"
import "core:fmt"
import la "core:math/linalg"
import "core:os"
import "vendor:glfw"
import vk "vendor:vulkan"

// Global state (Vulkan apps needs some globals)
//
MAX_FRAMES_IN_FLIGHT :: 2

App_State :: struct {
	window:          glfw.WindowHandle,
	vk_core:         Vulkan_Core,
	swapchain:       Swap_Chain,
	renderpipeline:  RenderPipeline,
	debug_messenger: vk.DebugUtilsMessengerEXT,
	surface:         vk.SurfaceKHR,
}

Vulkan_Core :: struct {
	instance:        vk.Instance,
	phyiscal_device: vk.PhysicalDevice,
	logical_device:  vk.Device,
	graphics_queue:  vk.Queue,
	present_queue:   vk.Queue,
}

Swap_Chain :: struct {
	swapchain: vk.SwapchainKHR,
	images:    []vk.Image,
	views:     []vk.ImageView,
	extent:    vk.Extent2D,
	format:    vk.Format,
}

RenderPipeline :: struct {
	render_pass:          vk.RenderPass,
	framebuffers:         []vk.Framebuffer,
	commandbuffers:       []vk.CommandBuffer,
	command_pool:         vk.CommandPool,
	available_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
	finished_semaphores:  []vk.Semaphore,
	in_flight_fences:     [MAX_FRAMES_IN_FLIGHT]vk.Fence,
	current_frame:        int,
	layout:               vk.PipelineLayout,
	grahpics_pipeline:    vk.Pipeline,
}

//debuf callback
debug_callback :: proc "system" (
	serverity: vk.DebugUtilsMessageSeverityFlagEXT,
	type: vk.DebugUtilsMessageTypeFlagsEXT,
	callback_data: ^vk.DebugUtilsMessengerCallbackDataEXT,
	user_data: rawptr,
) -> b32 {

	context = runtime.default_context()
	fmt.eprintfln("[VULKKAN] %s", callback_data.pMessage)
	return false
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
	// read Shader code
	vert_code, vert_ok := read_file("./shaders/triangle.vert.spv")
	if !vert_ok do return false
	defer delete(vert_code)

	frag_code, frag_ok := read_file("./shaders/triangle.frag.spv")
	if !frag_ok do return false
	defer delete(frag_code)

	// create shader modules
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

	// hardcoded in the acompiled shader
	vertex_input_info := vk.PipelineVertexInputStateCreateInfo {
		sType                           = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
		vertexBindingDescriptionCount   = 0,
		vertexAttributeDescriptionCount = 0,
	}

	// input assembly
	input_assembly := vk.PipelineInputAssemblyStateCreateInfo {
		sType                  = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
		topology               = .TRIANGLE_LIST,
		primitiveRestartEnable = false,
	}

	// viewport
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

create_instance :: proc(vk_instance: ^vk.Instance) -> bool {
	//Application info
	fmt.println("Creating application info")
	app_info := vk.ApplicationInfo {
		sType              = vk.StructureType.APPLICATION_INFO,
		pApplicationName   = "3D Editor",
		applicationVersion = vk.MAKE_VERSION(1, 0, 0),
		pEngineName        = "No Engine",
		engineVersion      = vk.MAKE_VERSION(1, 0, 0),
		apiVersion         = vk.API_VERSION_1_3,
	}
	// Get GLFW reequired extensions
	fmt.println("Getting extesions")
	glfw_extension := glfw.GetRequiredInstanceExtensions()

	extensions := make([dynamic]cstring)
	defer delete(extensions)

	for ext in glfw_extension {
		append(&extensions, ext)
	}
	append(&extensions, vk.EXT_DEBUG_UTILS_EXTENSION_NAME)

	layers := []cstring{"VK_LAYER_KHRONOS_validation"}

	//create instance
	fmt.println("Creating instance info")
	create_info := vk.InstanceCreateInfo {
		sType                   = vk.StructureType.INSTANCE_CREATE_INFO,
		pApplicationInfo        = &app_info,
		enabledExtensionCount   = u32(len(extensions)),
		ppEnabledExtensionNames = raw_data(extensions),
		enabledLayerCount       = u32(len(layers)),
		ppEnabledLayerNames     = raw_data(layers),
	}

	fmt.println("Creating Instances")

	fmt.printfln("%v", create_info)
	vk.load_proc_addresses_global(rawptr(glfw.GetInstanceProcAddress))
	result := vk.CreateInstance(&create_info, nil, vk_instance)
	if result != vk.Result.SUCCESS {
		fmt.eprintfln("Failed to create Vulkan instances: %v", result)
		return false
	}
	fmt.println("Created Instances")

	//load instance level functions
	fmt.println("Loadig instance addresses")

	vk.load_proc_addresses(vk_instance^)
	fmt.printfln("Vulkan Instances created")
	return true
}

create_debug_messenger :: proc(
	vk_instance: vk.Instance,
	debug_messenger: ^vk.DebugUtilsMessengerEXT,
) -> bool {
	create_info := vk.DebugUtilsMessengerCreateInfoEXT {
		sType           = vk.StructureType.DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
		messageSeverity = {
			vk.DebugUtilsMessageSeverityFlagEXT.VERBOSE,
			vk.DebugUtilsMessageSeverityFlagEXT.WARNING,
			vk.DebugUtilsMessageSeverityFlagEXT.ERROR,
		},
		messageType     = {
			vk.DebugUtilsMessageTypeFlagEXT.GENERAL,
			vk.DebugUtilsMessageTypeFlagEXT.VALIDATION,
			vk.DebugUtilsMessageTypeFlagEXT.PERFORMANCE,
		},
		pfnUserCallback = vk.ProcDebugUtilsMessengerCallbackEXT(debug_callback),
	}

	result := vk.CreateDebugUtilsMessengerEXT(vk_instance, &create_info, nil, debug_messenger)
	if result != vk.Result.SUCCESS {
		fmt.eprintfln("Failed to create Debug messenger: %v", result)
		return false
	}

	fmt.println("Devug Messenger Created")
	return true
}

create_surface :: proc(
	window: glfw.WindowHandle,
	vk_instance: vk.Instance,
	vk_surface: ^vk.SurfaceKHR,
) -> bool {
	fmt.printfln("filling out surface %d", vk_surface^)
	result := glfw.CreateWindowSurface(vk_instance, window, nil, vk_surface)
	if result != vk.Result.SUCCESS {
		fmt.eprintfln("Failed to create window surface: %v", result)
		return false
	}
	fmt.printfln("window surface created: %d", vk_surface^)
	return true
}


Queue_Family_Indices :: struct {
	graphics_family: Maybe(u32),
	present_family:  Maybe(u32),
}
is_complete :: proc(indices: Queue_Family_Indices) -> bool {
	return indices.graphics_family != nil && indices.present_family != nil
}

find_family_queues :: proc(
	device: vk.PhysicalDevice,
	surface: vk.SurfaceKHR,
) -> Queue_Family_Indices {
	indices: Queue_Family_Indices
	queue_family_count: u32
	vk.GetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, nil)
	queue_familes := make([]vk.QueueFamilyProperties, queue_family_count)
	defer delete(queue_familes)

	vk.GetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, raw_data(queue_familes))

	// Find graphics and queues
	for family, i in queue_familes {
		if vk.QueueFlag.GRAPHICS in family.queueFlags {
			indices.graphics_family = u32(i)
		}
		present_support: b32
		vk.GetPhysicalDeviceSurfaceSupportKHR(device, u32(i), surface, &present_support)

		if present_support {
			indices.present_family = u32(i)
		}

		if is_complete(indices) {
			break
		}

	}
	return indices
}


is_device_suitable :: proc(device: vk.PhysicalDevice, surface: vk.SurfaceKHR) -> bool {
	fmt.printfln("Checking if device is suitable: %d", device)
	indices := find_family_queues(device, surface)
	if !is_complete(indices) {
		return false
	}
	fmt.println("Found device Families")
	extensions_count: u32
	fmt.println("Getting Props count")
	vk.EnumerateDeviceExtensionProperties(device, nil, &extensions_count, nil)

	available_extensions := make([]vk.ExtensionProperties, extensions_count)
	defer delete(available_extensions)

	fmt.println("Filling out props")
	vk.EnumerateDeviceExtensionProperties(
		device,
		nil,
		&extensions_count,
		raw_data(available_extensions),
	)

	has_swapchain := false
	for ext in available_extensions {
		name := ext.extensionName
		ext_name := cstring(raw_data(name[:]))
		if ext_name == vk.KHR_SWAPCHAIN_EXTENSION_NAME {
			has_swapchain = true
			break
		}
	}
	return has_swapchain
}

pick_physical_device :: proc(
	instance: vk.Instance,
	surface: vk.SurfaceKHR,
	store_device: ^vk.PhysicalDevice,
) -> bool {
	// CHECK IF FUNCTION POINTER IS LOADED:
	fmt.printfln("func %d", vk.EnumeratePhysicalDevices)
	if vk.EnumeratePhysicalDevices == nil {
		fmt.eprintln("vk.EnumeratePhysicalDevices is NULL! Proc addresses not loaded!")
		return false
	}

	device_count: u32
	fmt.println(type_info_of(type_of(surface)))
	fmt.println("Getting Device Count")
	vk.EnumeratePhysicalDevices(instance, &device_count, nil)

	if device_count == 0 {
		fmt.eprintln("No Vulkan Gpus found")
		return false
	}
	devices := make([]vk.PhysicalDevice, device_count)
	defer delete(devices)

	vk.EnumeratePhysicalDevices(instance, &device_count, raw_data(devices))

	for device, i in devices {
		if !is_device_suitable(device, surface) {
			continue
		}

		props: vk.PhysicalDeviceProperties
		vk.GetPhysicalDeviceProperties(device, &props)
		device_name := cstring(&props.deviceName[0])
		fmt.printfln("Selected GPU: %d", device_name)
		store_device^ = device
		return true
	}
	fmt.eprintln("No Suitable GPU")
	return false
}

create_logical_device :: proc(
	p_device: vk.PhysicalDevice,
	l_device: ^vk.Device,
	g_queue: ^vk.Queue,
	p_queue: ^vk.Queue,
	surface: vk.SurfaceKHR,
) -> bool {
	fmt.println("Find Family Queues")
	indices := find_family_queues(p_device, surface)
	unique_queue_families := make(map[u32]bool)
	defer delete(unique_queue_families)
	graphics_family := indices.graphics_family.?
	present_family := indices.present_family.?

	unique_queue_families[graphics_family] = true
	unique_queue_families[present_family] = true
	queue_create_infos := make([dynamic]vk.DeviceQueueCreateInfo)
	defer delete(queue_create_infos)

	queue_priority: f32 = 1.0
	for family in unique_queue_families {
		queue_info := vk.DeviceQueueCreateInfo {
			sType            = .DEVICE_QUEUE_CREATE_INFO,
			queueFamilyIndex = family,
			queueCount       = 1,
			pQueuePriorities = &queue_priority,
		}
		append(&queue_create_infos, queue_info)
	}

	device_feature := vk.PhysicalDeviceFeatures{}

	device_extensions := []cstring{vk.KHR_SWAPCHAIN_EXTENSION_NAME}

	vulkan11_features := vk.PhysicalDeviceVulkan11Features {
		sType                = .PHYSICAL_DEVICE_VULKAN_1_1_FEATURES,
		shaderDrawParameters = true,
	}

	create_info := vk.DeviceCreateInfo {
		sType                   = .DEVICE_CREATE_INFO,
		pNext                   = &vulkan11_features,
		queueCreateInfoCount    = u32(len(queue_create_infos)),
		pQueueCreateInfos       = raw_data(queue_create_infos),
		pEnabledFeatures        = &device_feature,
		enabledExtensionCount   = u32(len(device_extensions)),
		ppEnabledExtensionNames = raw_data(device_extensions),
		enabledLayerCount       = 0,
	}

	result := vk.CreateDevice(p_device, &create_info, nil, l_device)
	if result != vk.Result.SUCCESS {
		fmt.eprintfln("Failed to create logical device: %v:", result)
		return false
	}
	vk.load_proc_addresses_device(l_device^)

	vk.GetDeviceQueue(l_device^, graphics_family, 0, g_queue)
	vk.GetDeviceQueue(l_device^, present_family, 0, p_queue)

	fmt.println("Logical Device Created")
	return true
}

Swapchain_Support_Details :: struct {
	capabilities:  vk.SurfaceCapabilitiesKHR,
	present_modes: []vk.PresentModeKHR,
	formats:       []vk.SurfaceFormatKHR,
}
query_swapchain_support :: proc(
	device: vk.PhysicalDevice,
	surface: vk.SurfaceKHR,
) -> Swapchain_Support_Details {

	details: Swapchain_Support_Details
	vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(device, surface, &details.capabilities)

	format_count: u32
	vk.GetPhysicalDeviceSurfaceFormatsKHR(device, surface, &format_count, nil)
	if format_count != 0 {
		details.formats = make([]vk.SurfaceFormatKHR, format_count)
		vk.GetPhysicalDeviceSurfaceFormatsKHR(
			device,
			surface,
			&format_count,
			raw_data(details.formats),
		)
	}

	present_mode_count: u32
	vk.GetPhysicalDeviceSurfacePresentModesKHR(device, surface, &present_mode_count, nil)
	if present_mode_count != 0 {
		details.present_modes = make([]vk.PresentModeKHR, present_mode_count)
		vk.GetPhysicalDeviceSurfacePresentModesKHR(
			device,
			surface,
			&present_mode_count,
			raw_data(details.present_modes),
		)
	}

	return details
}

chose_swap_surface_format :: proc(formats: []vk.SurfaceFormatKHR) -> vk.SurfaceFormatKHR {
	for format in formats {
		if format.format == vk.Format.B8G8R8A8_SRGB &&
		   format.colorSpace == vk.ColorSpaceKHR.SRGB_NONLINEAR {
			return format
		}
	}
	return formats[0]
}

chose_swap_present_mode :: proc(present_modes: []vk.PresentModeKHR) -> vk.PresentModeKHR {
	for mode in present_modes {
		if mode == vk.PresentModeKHR.MAILBOX {
			return mode
		}
	}
	return .FIFO
}


chose_swap_extent :: proc(
	window: glfw.WindowHandle,
	capabilities: vk.SurfaceCapabilitiesKHR,
) -> vk.Extent2D {

	if capabilities.currentExtent.width != max(u32) {
		return capabilities.currentExtent
	}
	width, height := glfw.GetFramebufferSize(window)
	extent := vk.Extent2D {
		width  = u32(width),
		height = u32(height),
	}
	extent.width = la.clamp(
		extent.width,
		capabilities.minImageExtent.width,
		capabilities.maxImageExtent.width,
	)
	extent.height = la.clamp(
		extent.height,
		capabilities.minImageExtent.height,
		capabilities.maxImageExtent.height,
	)
	return extent

}

create_image_views :: proc(device: vk.Device, swap_chain: ^Swap_Chain) -> bool {
	swap_chain.views = make([]vk.ImageView, len(swap_chain.images))

	for image, i in swap_chain.images {
		create_info := vk.ImageViewCreateInfo {
			sType = .IMAGE_VIEW_CREATE_INFO,
			image = image,
			viewType = .D2,
			format = swap_chain.format,
			components = {r = .IDENTITY, g = .IDENTITY, b = .IDENTITY, a = .IDENTITY},
			subresourceRange = {
				aspectMask = {.COLOR},
				baseMipLevel = 0,
				levelCount = 1,
				baseArrayLayer = 0,
				layerCount = 1,
			},
		}

		result := vk.CreateImageView(device, &create_info, nil, &swap_chain.views[i])
		if result != vk.Result.SUCCESS {
			fmt.eprintfln("Failed to create image view %d: %v", i, result)
			return false
		}
	}
	fmt.printfln("Created %d Image views", len(swap_chain.views))
	return true
}

create_swapchain :: proc(
	window: glfw.WindowHandle,
	p_device: vk.PhysicalDevice,
	l_device: vk.Device,
	surface: vk.SurfaceKHR,
	swapchain: ^Swap_Chain,
) -> bool {
	support := query_swapchain_support(p_device, surface)
	defer {
		delete(support.formats)
		delete(support.present_modes)
	}

	present_mode := chose_swap_present_mode(support.present_modes)
	surface_format := chose_swap_surface_format(support.formats)
	extent := chose_swap_extent(window, support.capabilities)

	image_count := support.capabilities.minImageCount + 1
	if support.capabilities.maxImageCount > 0 && image_count > support.capabilities.maxImageCount {
		image_count = support.capabilities.maxImageCount
	}

	create_info := vk.SwapchainCreateInfoKHR {
		sType            = .SWAPCHAIN_CREATE_INFO_KHR,
		surface          = surface,
		minImageCount    = image_count,
		imageFormat      = surface_format.format,
		imageColorSpace  = surface_format.colorSpace,
		imageExtent      = extent,
		imageArrayLayers = 1,
		imageUsage       = {.COLOR_ATTACHMENT},
		preTransform     = support.capabilities.currentTransform,
		compositeAlpha   = {.OPAQUE},
		presentMode      = present_mode,
		clipped          = true,
		oldSwapchain     = 0,
	}
	indices := find_family_queues(p_device, surface)
	graphic_family := indices.graphics_family.?
	present_family := indices.present_family.?

	queue_family_indices := [2]u32{graphic_family, present_family}
	if graphic_family != present_family {
		create_info.imageSharingMode = vk.SharingMode.CONCURRENT
		create_info.queueFamilyIndexCount = 2
		create_info.pQueueFamilyIndices = &queue_family_indices[0]
	} else {
		create_info.imageSharingMode = .EXCLUSIVE
		create_info.queueFamilyIndexCount = 0
		create_info.pQueueFamilyIndices = nil
	}

	result := vk.CreateSwapchainKHR(l_device, &create_info, nil, &swapchain.swapchain)
	if result != .SUCCESS {
		fmt.eprintfln("Failed to create swapchain: %v", result)
		return false
	}

	acutal_count: u32
	vk.GetSwapchainImagesKHR(l_device, swapchain.swapchain, &acutal_count, nil)
	swapchain.images = make([]vk.Image, acutal_count)
	vk.GetSwapchainImagesKHR(
		l_device,
		swapchain.swapchain,
		&acutal_count,
		raw_data(swapchain.images),
	)

	swapchain.format = surface_format.format
	swapchain.extent = extent
	fmt.println("Swap Chain Created")
	fmt.printfln("Image Count: %d", image_count)
	fmt.printfln("Format: %v", surface_format.format)
	fmt.printfln("Extent: %dx%d", extent.width, extent.height)
	fmt.printfln("Present Mode: %v", present_mode)
	fmt.printfln("DEBUG: swapchain.images len = %d", len(swapchain.images))
	return true
}

cleanup_swapchain :: proc(
	device: vk.Device,
	swapchain: ^Swap_Chain,
	render_pipe: ^RenderPipeline,
) {
	for fb in render_pipe.framebuffers {
		vk.DestroyFramebuffer(device, fb, nil)
	}

	delete(render_pipe.framebuffers)
	for view in swapchain.views {
		vk.DestroyImageView(device, view, nil)
	}
	delete(swapchain.views)

	vk.DestroySwapchainKHR(device, swapchain.swapchain, nil)
	delete(swapchain.images)
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

create_command_pool :: proc(
	surface: vk.SurfaceKHR,
	p_device: vk.PhysicalDevice,
	device: vk.Device,
	command_pool: ^vk.CommandPool,
) -> bool {
	indices := find_family_queues(p_device, surface)

	pool_info := vk.CommandPoolCreateInfo {
		sType            = .COMMAND_POOL_CREATE_INFO,
		flags            = {.RESET_COMMAND_BUFFER},
		queueFamilyIndex = indices.graphics_family.?,
	}
	result := vk.CreateCommandPool(device, &pool_info, nil, command_pool)
	if result != vk.Result.SUCCESS {
		fmt.eprint("Failed to create command pool: %d", result)
		return false
	}
	fmt.println("Created Command Pool")
	return true
}

create_command_buffers :: proc(
	device: vk.Device,
	command_pool: vk.CommandPool,
	frame_buffer: []vk.Framebuffer,
	command_buffer: ^[]vk.CommandBuffer,
) -> bool {
	command_buffer^ = make([]vk.CommandBuffer, len(frame_buffer))

	alloc_info := vk.CommandBufferAllocateInfo {
		sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
		commandPool        = command_pool,
		level              = .PRIMARY,
		commandBufferCount = u32(len(command_buffer^)),
	}
	result := vk.AllocateCommandBuffers(device, &alloc_info, raw_data(command_buffer^))
	if result != vk.Result.SUCCESS {
		fmt.eprintfln("Failed to create Command Buffer: %d", result)
		return false
	}
	fmt.println("Created Command Buffers")
	return true

}

create_sync_object :: proc(
	device: vk.Device,
	available_semphore: ^[MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
	fin_semaphore: ^[]vk.Semaphore,
	fences: ^[MAX_FRAMES_IN_FLIGHT]vk.Fence,
	image_count: int,
) -> bool {
	fin_semaphore^ = make([]vk.Semaphore, image_count)
	semaphore_info := vk.SemaphoreCreateInfo {
		sType = .SEMAPHORE_CREATE_INFO,
	}
	fence_info := vk.FenceCreateInfo {
		sType = .FENCE_CREATE_INFO,
		flags = {.SIGNALED},
	}
	for i in 0 ..< image_count {
		result := vk.CreateSemaphore(device, &semaphore_info, nil, &fin_semaphore[i])
		if result != vk.Result.SUCCESS {
			fmt.eprintfln("Failed to create semaphore: %d", result)
			return false
		}
	}
	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		result := vk.CreateSemaphore(device, &semaphore_info, nil, &available_semphore[i])
		if result != vk.Result.SUCCESS {
			fmt.eprintfln("Failed to create semaphore: %d", result)
			return false
		}
		result = vk.CreateFence(device, &fence_info, nil, &fences[i])
		if result != vk.Result.SUCCESS {
			fmt.eprintfln("Failed to create Fence: %d", result)
			return false
		}
	}
	fmt.println("Created Sync Objects: ")
	return true
}

record_command_buffer :: proc(
	command_buffer: vk.CommandBuffer,
	extent: vk.Extent2D,
	renderpass: vk.RenderPass,
	framebuffer: vk.Framebuffer,
	graphics_pipeline: vk.Pipeline,
) {
	begin_info := vk.CommandBufferBeginInfo {
		sType = .COMMAND_BUFFER_BEGIN_INFO,
	}

	if vk.BeginCommandBuffer(command_buffer, &begin_info) != vk.Result.SUCCESS {
		fmt.eprintfln("Failed to  Begin Command Buffer: %d")
		return
	}

	clear_color := vk.ClearValue {
		color = {float32 = {0.0, 0.0, 0.0, 1.0}},
	}

	render_pass_info := vk.RenderPassBeginInfo {
		sType = .RENDER_PASS_BEGIN_INFO,
		renderPass = renderpass,
		framebuffer = framebuffer,
		renderArea = {offset = {0, 0}, extent = extent},
		clearValueCount = 1,
		pClearValues = &clear_color,
	}
	vk.CmdBeginRenderPass(command_buffer, &render_pass_info, .INLINE)
	// draw stuff
	vk.CmdBindPipeline(command_buffer, .GRAPHICS, graphics_pipeline)

	vk.CmdDraw(command_buffer, 3, 1, 0, 0)

	vk.CmdEndRenderPass(command_buffer)
	if vk.EndCommandBuffer(command_buffer) != vk.Result.SUCCESS {
		fmt.eprintfln("Failed to end command buffer")
	}

}


draw_frame :: proc(core: ^Vulkan_Core, rp: ^RenderPipeline, sc: ^Swap_Chain) {
	vk.WaitForFences(
		core.logical_device,
		1,
		&rp.in_flight_fences[rp.current_frame],
		true,
		max(u64),
	)
	vk.ResetFences(core.logical_device, 1, &rp.in_flight_fences[rp.current_frame])

	image_index: u32
	vk.AcquireNextImageKHR(
		core.logical_device,
		sc.swapchain,
		max(u64),
		rp.available_semaphores[rp.current_frame],
		0,
		&image_index,
	)
	vk.ResetCommandBuffer(rp.commandbuffers[image_index], {})
	record_command_buffer(
		rp.commandbuffers[image_index],
		sc.extent,
		rp.render_pass,
		rp.framebuffers[image_index],
		rp.grahpics_pipeline,
	)

	wait_semaphores := [1]vk.Semaphore{rp.available_semaphores[rp.current_frame]}
	wait_stages := [1]vk.PipelineStageFlags{{.COLOR_ATTACHMENT_OUTPUT}}
	signal_semphores := [1]vk.Semaphore{rp.finished_semaphores[image_index]}
	submit_info := vk.SubmitInfo {
		sType                = .SUBMIT_INFO,
		waitSemaphoreCount   = 1,
		pWaitSemaphores      = &wait_semaphores[0],
		pWaitDstStageMask    = &wait_stages[0],
		commandBufferCount   = 1,
		pCommandBuffers      = &rp.commandbuffers[image_index],
		signalSemaphoreCount = 1,
		pSignalSemaphores    = &signal_semphores[0],
	}
	if vk.QueueSubmit(
		   core.graphics_queue,
		   1,
		   &submit_info,
		   rp.in_flight_fences[rp.current_frame],
	   ) !=
	   vk.Result.SUCCESS {
		fmt.eprintln("Failed to submit to queue")
	}

	swaphains := [1]vk.SwapchainKHR{sc.swapchain}
	present_info := vk.PresentInfoKHR {
		sType              = .PRESENT_INFO_KHR,
		waitSemaphoreCount = 1,
		pWaitSemaphores    = &signal_semphores[0],
		swapchainCount     = 1,
		pSwapchains        = &swaphains[0],
		pImageIndices      = &image_index,
	}

	vk.QueuePresentKHR(core.present_queue, &present_info)
	rp.current_frame = (rp.current_frame + 1) % MAX_FRAMES_IN_FLIGHT
}

init_vulkan :: proc(g: ^App_State) -> bool {
	rp := &g.renderpipeline
	sc := &g.swapchain
	core := &g.vk_core

	if !create_instance(&core.instance) do return false
	if !create_debug_messenger(core.instance, &g.debug_messenger) do return false
	if !create_surface(g.window, core.instance, &g.surface) do return false
	if !pick_physical_device(core.instance, g.surface, &core.phyiscal_device) do return false
	if !create_logical_device(core.phyiscal_device, &core.logical_device, &core.graphics_queue, &core.present_queue, g.surface) do return false
	if !create_swapchain(g.window, core.phyiscal_device, core.logical_device, g.surface, sc) do return false
	if !create_image_views(core.logical_device, sc) do return false
	if !create_render_pass(core.logical_device, sc.format, &rp.render_pass) do return false
	if !create_graphics_pipeline(core.logical_device, sc.extent, rp.render_pass, &rp.layout, &rp.grahpics_pipeline) do return false
	if !create_framebuffers(core.logical_device, rp.render_pass, sc.views, sc.extent, &rp.framebuffers) do return false
	if !create_command_pool(g.surface, core.phyiscal_device, core.logical_device, &rp.command_pool) do return false
	if !create_command_buffers(core.logical_device, rp.command_pool, rp.framebuffers, &rp.commandbuffers) do return false
	if !create_sync_object(core.logical_device, &rp.available_semaphores, &rp.finished_semaphores, &rp.in_flight_fences, len(sc.images)) do return false
	return true

}


deinit_vulkan :: proc(g: ^App_State) {
	for i in 0 ..< len(g.swapchain.images) {
		vk.DestroySemaphore(g.vk_core.logical_device, g.renderpipeline.finished_semaphores[i], nil)
	}
	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		vk.DestroySemaphore(
			g.vk_core.logical_device,
			g.renderpipeline.available_semaphores[i],
			nil,
		)
		vk.DestroyFence(g.vk_core.logical_device, g.renderpipeline.in_flight_fences[i], nil)
	}
	vk.DestroyCommandPool(g.vk_core.logical_device, g.renderpipeline.command_pool, nil)
	delete(g.renderpipeline.commandbuffers)

	vk.DestroyPipeline(g.vk_core.logical_device, g.renderpipeline.grahpics_pipeline, nil)
	vk.DestroyPipelineLayout(g.vk_core.logical_device, g.renderpipeline.layout, nil)

	cleanup_swapchain(g.vk_core.logical_device, &g.swapchain, &g.renderpipeline)
	vk.DestroyRenderPass(g.vk_core.logical_device, g.renderpipeline.render_pass, nil)
	vk.DestroyDevice(g.vk_core.logical_device, nil)
	vk.DestroySurfaceKHR(g.vk_core.instance, g.surface, nil)
	vk.DestroyDebugUtilsMessengerEXT(g.vk_core.instance, g.debug_messenger, nil)
	vk.DestroyInstance(g.vk_core.instance, nil)
}


main :: proc() {
	app_state: App_State
	if !glfw.Init() {
		fmt.eprintfln("Failed to init GLFW")
		return
	}
	defer glfw.Terminate()
	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
	glfw.WindowHint(glfw.RESIZABLE, glfw.FALSE)
	app_state.window = glfw.CreateWindow(1280, 720, "Vulkan 3d Editor", nil, nil)

	if app_state.window == nil {
		fmt.eprintfln("Failed to create GLFW window")
		return
	}
	if !init_vulkan(&app_state) {
		fmt.eprintln("Vulkan failed to load")
		return
	}
	defer deinit_vulkan(&app_state)

	for !glfw.WindowShouldClose(app_state.window) {
		free_all(context.temp_allocator)
		glfw.PollEvents()
		draw_frame(&app_state.vk_core, &app_state.renderpipeline, &app_state.swapchain)
	}
	vk.DeviceWaitIdle(app_state.vk_core.logical_device)
}

