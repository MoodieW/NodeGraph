package renderer

import "core:fmt"
import vk "vendor:vulkan"

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

record_command_buffer :: proc(
	command_buffer: vk.CommandBuffer,
	extent: vk.Extent2D,
	renderpass: vk.RenderPass,
	framebuffer: vk.Framebuffer,
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
	vk.CmdEndRenderPass(command_buffer)
	if vk.EndCommandBuffer(command_buffer) != vk.Result.SUCCESS {
		fmt.eprintfln("Failed to end command buffer")
	}
}

