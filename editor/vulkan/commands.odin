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
	rp: ^RenderPipeline,
	image_index: u32,
	pipeline: Maybe(vk.Pipeline) = nil,
) {
	// Start command Capture
	begin_info := vk.CommandBufferBeginInfo {
		sType = .COMMAND_BUFFER_BEGIN_INFO,
	}
	if vk.BeginCommandBuffer(command_buffer, &begin_info) != vk.Result.SUCCESS {
		fmt.eprintln("Failed tot create offscreen Command Buffer")
		return
	}
	// Build commands
	if rp.offscreen_target_valid && rp.offscreen_dirty {

		record_offscreen_pass(command_buffer, extent, rp)
		rp.offscreen_dirty = false
	}
	record_swapchain_pass(command_buffer, extent, rp, image_index, pipeline)

	// end Command buffer
	if vk.EndCommandBuffer(command_buffer) != vk.Result.SUCCESS {
		fmt.eprintfln("Failed to end command buffer")
	}
}

record_offscreen_pass :: proc(
	command_buffer: vk.CommandBuffer,
	extent: vk.Extent2D,
	rp: ^RenderPipeline,
) {
	fmt.println("rendering to the  offscreen command buffer")
	clear_color := vk.ClearValue {
		color = {float32 = {0.0, 0.0, 0.0, 1.0}},
	}
	render_pass_info := vk.RenderPassBeginInfo {
		sType = .RENDER_PASS_BEGIN_INFO,
		renderPass = rp.offscreen_render_pass,
		framebuffer = rp.offscrent_target.frame_buffer,
		renderArea = {offset = {0, 0}, extent = extent},
		clearValueCount = 1,
		pClearValues = &clear_color,
	}

	vk.CmdBeginRenderPass(command_buffer, &render_pass_info, .INLINE)
	vk.CmdEndRenderPass(command_buffer)
}
record_swapchain_pass :: proc(
	command_buffer: vk.CommandBuffer,
	extent: vk.Extent2D,
	rp: ^RenderPipeline,
	image_index: u32,
	pipeline: Maybe(vk.Pipeline) = nil,
) {
	clear_color := vk.ClearValue {
		color = {float32 = {0.0, 0.0, 0.0, 1.0}},
	}

	render_pass_info := vk.RenderPassBeginInfo {
		sType = .RENDER_PASS_BEGIN_INFO,
		renderPass = rp.render_pass,
		framebuffer = rp.framebuffers[image_index],
		renderArea = {offset = {0, 0}, extent = extent},
		clearValueCount = 1,
		pClearValues = &clear_color,
	}
	vk.CmdBeginRenderPass(command_buffer, &render_pass_info, .INLINE)
	if pipeline != nil {
		vertex_buffers := [1]vk.Buffer{rp.geo_mem.vertex_buffer}
		offsets := [1]vk.DeviceSize{0}
		vk.CmdBindPipeline(command_buffer, .GRAPHICS, pipeline.?)
		vk.CmdBindVertexBuffers(command_buffer, 0, 1, &vertex_buffers[0], &offsets[0])
		vk.CmdBindIndexBuffer(command_buffer, rp.geo_mem.index_buffer, 0, .UINT32)
		vk.CmdDrawIndexed(command_buffer, rp.geo_mem.index_count, 1, 0, 0, 0)
	}
	vk.CmdEndRenderPass(command_buffer)
}

