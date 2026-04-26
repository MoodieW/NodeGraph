package renderer

import "core:fmt"
import la "core:math/linalg"
import "vendor:glfw"
import vk "vendor:vulkan"

MAX_FRAMES_IN_FLIGHT :: 2

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
	geo_mem:              GeoMemory,
}

GeoMemory :: struct {
	vertex_buffer:        vk.Buffer,
	vertex_buffer_memory: vk.DeviceMemory,
	index_buffer:         vk.Buffer,
	index_buffer_memory:  vk.DeviceMemory,
	index_count:          u32,
}

Swapchain_Support_Details :: struct {
	capabilities:  vk.SurfaceCapabilitiesKHR,
	present_modes: []vk.PresentModeKHR,
	formats:       []vk.SurfaceFormatKHR,
}


remove_geo :: proc(device: vk.Device, geo_mem: ^GeoMemory) {
	vk.DestroyBuffer(device, geo_mem.index_buffer, nil)
	vk.FreeMemory(device, geo_mem.index_buffer_memory, nil)
	vk.DestroyBuffer(device, geo_mem.vertex_buffer, nil)
	vk.FreeMemory(device, geo_mem.vertex_buffer_memory, nil)
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

