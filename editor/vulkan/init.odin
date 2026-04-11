package renderer

import "vendor:glfw"
import vk "vendor:vulkan"

init_vulkan :: proc(
	window: glfw.WindowHandle,
	vk_instance: ^vk.Instance,
	debug_messenger: ^vk.DebugUtilsMessengerEXT,
	surface: ^vk.SurfaceKHR,
	physical_device: ^vk.PhysicalDevice,
	logical_device: ^vk.Device,
	graphics_queue: ^vk.Queue,
	present_queue: ^vk.Queue,
	sc: ^Swap_Chain,
	rp: ^RenderPipeline,
	shader_cache: ^Shader_Cache,
) -> bool {
	if !create_instance(vk_instance) do return false
	if !create_debug_messenger(vk_instance^, debug_messenger) do return false
	if !create_surface(window, vk_instance^, surface) do return false
	if !pick_physical_device(vk_instance^, surface^, physical_device) do return false
	if !create_logical_device(physical_device^, logical_device, graphics_queue, present_queue, surface^) do return false
	if !create_swapchain(window, physical_device^, logical_device^, surface^, sc) do return false
	if !create_image_views(logical_device^, sc) do return false
	if !create_render_pass(logical_device^, sc.format, &rp.render_pass) do return false
	create_shader_cache(shader_cache)
	// if !create_graphics_pipeline(logical_device^, sc.extent, rp.render_pass, &rp.layout, &rp.grahpics_pipeline) do return false
	if !create_framebuffers(logical_device^, rp.render_pass, sc.views, sc.extent, &rp.framebuffers) do return false
	if !create_command_pool(surface^, physical_device^, logical_device^, &rp.command_pool) do return false
	if !create_command_buffers(logical_device^, rp.command_pool, rp.framebuffers, &rp.commandbuffers) do return false
	if !create_sync_object(logical_device^, &rp.available_semaphores, &rp.finished_semaphores, &rp.in_flight_fences, len(sc.images)) do return false
	return true
}

deinit_vulkan :: proc(
	vk_instance: vk.Instance,
	debug_messenger: vk.DebugUtilsMessengerEXT,
	surface: vk.SurfaceKHR,
	logical_device: vk.Device,
	sc: ^Swap_Chain,
	rp: ^RenderPipeline,
	shader_cache: ^Shader_Cache,
) {
	for i in 0 ..< len(sc.images) {
		vk.DestroySemaphore(logical_device, rp.finished_semaphores[i], nil)
	}
	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		vk.DestroySemaphore(logical_device, rp.available_semaphores[i], nil)
		vk.DestroyFence(logical_device, rp.in_flight_fences[i], nil)
	}
	vk.DestroyCommandPool(logical_device, rp.command_pool, nil)
	delete(rp.commandbuffers)

	cleanup_swapchain(logical_device, sc, rp)
	remove_shader_cache(logical_device, shader_cache)
	vk.DestroyRenderPass(logical_device, rp.render_pass, nil)
	vk.DestroyDevice(logical_device, nil)
	vk.DestroySurfaceKHR(vk_instance, surface, nil)
	vk.DestroyDebugUtilsMessengerEXT(vk_instance, debug_messenger, nil)
	vk.DestroyInstance(vk_instance, nil)
}

