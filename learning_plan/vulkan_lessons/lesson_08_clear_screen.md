# Lesson 8: Clearing the Screen

**Milestone**: Window clears to blue color every frame.

---

## What You're Building

1. Render loop with frame synchronization
2. Command buffer recording (just clear)
3. Queue submission and present

**This is where it all comes together.**

---

## Code

```odin
g_current_frame: int = 0

record_command_buffer :: proc(command_buffer: vk.CommandBuffer, image_index: u32) {
    // Begin command buffer
    begin_info := vk.CommandBufferBeginInfo{
        sType = vk.StructureType.COMMAND_BUFFER_BEGIN_INFO,
    }

    if vk.BeginCommandBuffer(command_buffer, &begin_info) != .SUCCESS {
        fmt.eprintln("Failed to begin command buffer")
        return
    }

    // Begin render pass
    clear_color := vk.ClearValue{
        color = {float32 = {0.0, 0.0, 0.5, 1.0}},  // Blue
    }

    render_pass_info := vk.RenderPassBeginInfo{
        sType = vk.StructureType.RENDER_PASS_BEGIN_INFO,
        renderPass = g_render_pass,
        framebuffer = g_framebuffers[image_index],
        renderArea = {
            offset = {0, 0},
            extent = g_swapchain_extent,
        },
        clearValueCount = 1,
        pClearValues = &clear_color,
    }

    vk.CmdBeginRenderPass(command_buffer, &render_pass_info, .INLINE)

    // (Nothing to draw yet)

    vk.CmdEndRenderPass(command_buffer)

    if vk.EndCommandBuffer(command_buffer) != .SUCCESS {
        fmt.eprintln("Failed to end command buffer")
    }
}

draw_frame :: proc() {
    // Wait for previous frame
    vk.WaitForFences(g_device, 1, &g_in_flight_fences[g_current_frame], true, max(u64))
    vk.ResetFences(g_device, 1, &g_in_flight_fences[g_current_frame])

    // Acquire next swapchain image
    image_index: u32
    vk.AcquireNextImageKHR(
        g_device,
        g_swapchain,
        max(u64),
        g_image_available_semaphores[g_current_frame],
        0,
        &image_index,
    )

    // Reset and record command buffer
    vk.ResetCommandBuffer(g_command_buffers[image_index], {})
    record_command_buffer(g_command_buffers[image_index], image_index)

    // Submit command buffer
    wait_semaphores := [1]vk.Semaphore{g_image_available_semaphores[g_current_frame]}
    wait_stages := [1]vk.PipelineStageFlags{{.COLOR_ATTACHMENT_OUTPUT}}
    signal_semaphores := [1]vk.Semaphore{g_render_finished_semaphores[g_current_frame]}

    submit_info := vk.SubmitInfo{
        sType = vk.StructureType.SUBMIT_INFO,
        waitSemaphoreCount = 1,
        pWaitSemaphores = &wait_semaphores[0],
        pWaitDstStageMask = &wait_stages[0],
        commandBufferCount = 1,
        pCommandBuffers = &g_command_buffers[image_index],
        signalSemaphoreCount = 1,
        pSignalSemaphores = &signal_semaphores[0],
    }

    if vk.QueueSubmit(g_graphics_queue, 1, &submit_info, g_in_flight_fences[g_current_frame]) != .SUCCESS {
        fmt.eprintln("Failed to submit draw command buffer")
    }

    // Present
    swapchains := [1]vk.SwapchainKHR{g_swapchain}

    present_info := vk.PresentInfoKHR{
        sType = vk.StructureType.PRESENT_INFO_KHR,
        waitSemaphoreCount = 1,
        pWaitSemaphores = &signal_semaphores[0],
        swapchainCount = 1,
        pSwapchains = &swapchains[0],
        pImageIndices = &image_index,
    }

    vk.QueuePresentKHR(g_present_queue, &present_info)

    // Advance frame
    g_current_frame = (g_current_frame + 1) % MAX_FRAMES_IN_FLIGHT
}

main :: proc() {
    // GLFW init
    if !glfw.Init() {
        fmt.eprintln("Failed to init GLFW")
        return
    }
    defer glfw.Terminate()

    glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
    glfw.WindowHint(glfw.RESIZABLE, glfw.FALSE)

    g_window = glfw.CreateWindow(1280, 720, "Vulkan 3D Editor", nil, nil)
    if g_window == nil {
        fmt.eprintln("Failed to create window")
        return
    }

    // Vulkan init
    if !init_vulkan() {
        return
    }
    defer cleanup_vulkan()

    fmt.println("\n=== RENDERING STARTED ===")
    fmt.println("Blue screen should be visible!")

    // Main loop
    for !glfw.WindowShouldClose(g_window) {
        glfw.PollEvents()
        draw_frame()
    }

    // Wait for device to finish before cleanup
    vk.DeviceWaitIdle(g_device)
}
```

---

## The Render Loop Explained

```
1. Wait for fence (CPU waits for GPU to finish previous frame)
2. Reset fence
3. Acquire swapchain image (get next image to render to)
4. Reset command buffer
5. Record commands:
   - Begin command buffer
   - Begin render pass (clears to blue)
   - End render pass
   - End command buffer
6. Submit to queue with:
   - Wait semaphore (wait for image available)
   - Signal semaphore (signal render finished)
   - Fence (signal CPU when done)
7. Present image to screen
8. Advance to next frame
```

---

## Milestone Check

- [ ] Window displays solid blue color
- [ ] No flickering
- [ ] No validation errors
- [ ] Console silent (no errors)

---

## What You Learned

- Command buffer recording
- Render pass execution
- Synchronization flow
- Queue submission and present
- The complete Vulkan render loop

---

## First Visual Confirmation!

You've just completed the hardest part of Vulkan. ~1000 lines of code to clear the screen to blue.

But now you understand:
- How the GPU gets commands
- How CPU and GPU synchronize
- How swapchain images work
- How render passes structure rendering

**Next: Draw a triangle.**
