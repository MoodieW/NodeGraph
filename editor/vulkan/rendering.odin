package renderer

import "core:fmt"
import vk "vendor:vulkan"

draw_frame :: proc(
	logical_device: vk.Device,
	graphics_queue: vk.Queue,
	present_queue: vk.Queue,
	rp: ^RenderPipeline,
	sc: ^Swap_Chain,
	pipeline: Maybe(vk.Pipeline) = nil,
) {
	vk.WaitForFences(logical_device, 1, &rp.in_flight_fences[rp.current_frame], true, max(u64))
	vk.ResetFences(logical_device, 1, &rp.in_flight_fences[rp.current_frame])

	image_index: u32
	vk.AcquireNextImageKHR(
		logical_device,
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
		pipeline,
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
	if vk.QueueSubmit(graphics_queue, 1, &submit_info, rp.in_flight_fences[rp.current_frame]) !=
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

	vk.QueuePresentKHR(present_queue, &present_info)
	rp.current_frame = (rp.current_frame + 1) % MAX_FRAMES_IN_FLIGHT
}

