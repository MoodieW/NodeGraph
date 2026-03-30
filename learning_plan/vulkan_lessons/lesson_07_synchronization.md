# Lesson 7: Synchronization Objects

**Milestone**: Semaphores and fences created, ready for rendering.

---

## What You're Building

1. Semaphores (GPU-GPU sync)
2. Fences (CPU-GPU sync)

---

## Concepts

- **Semaphore**: Signal between GPU operations (e.g., image available → rendering done)
- **Fence**: CPU waits for GPU to finish
- **In-flight frames**: Render multiple frames concurrently

**Critical distinction**:
- `image_available_semaphores`: Per frame in flight (indexed by `current_frame`)
- `image_finished_semaphores`: Per swapchain image (indexed by `image_index`)

**Why different counts?** The acquire→submit→present flow uses two separate indices:
- Frames cycle: 0, 1, 0, 1... (CPU pacing)
- Images acquired: 2, 0, 1, 3... (whatever the swapchain gives you)

The finished semaphore gets locked by `vkQueuePresentKHR` until that specific image is re-acquired. No fence/signal tells you when presentation finishes—only acquiring the same image again guarantees its presentation semaphore is free.

**Why it matters**: Without sync, you get corruption and crashes. With wrong indexing, you violate the spec by reusing semaphores that are still in use.

---

## Code

```odin
MAX_FRAMES_IN_FLIGHT :: 2

RenderPipeline :: struct {
    // ... other fields
    image_available_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,  // Per frame in flight
    image_finished_semaphores:  []vk.Semaphore,                      // Per swapchain image
    in_flight_fences:           [MAX_FRAMES_IN_FLIGHT]vk.Fence,
    current_frame:              int,
}

create_sync_objects :: proc(
    device: vk.Device,
    available_semaphore: ^[MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
    finished_semaphore: ^[]vk.Semaphore,
    fences: ^[MAX_FRAMES_IN_FLIGHT]vk.Fence,
    image_count: int,
) -> bool {
    // Allocate finished semaphores based on swapchain image count
    finished_semaphore^ = make([]vk.Semaphore, image_count)

    semaphore_info := vk.SemaphoreCreateInfo{
        sType = .SEMAPHORE_CREATE_INFO,
    }

    fence_info := vk.FenceCreateInfo{
        sType = .FENCE_CREATE_INFO,
        flags = {.SIGNALED},  // Start signaled (first frame doesn't wait)
    }

    // Create finished semaphores (one per swapchain image)
    for i in 0 ..< image_count {
        result := vk.CreateSemaphore(device, &semaphore_info, nil, &finished_semaphore[i])
        if result != .SUCCESS {
            fmt.eprintfln("Failed to create finished semaphore %d: %v", i, result)
            return false
        }
    }

    // Create available semaphores and fences (one per frame in flight)
    for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
        result := vk.CreateSemaphore(device, &semaphore_info, nil, &available_semaphore[i])
        if result != .SUCCESS {
            fmt.eprintfln("Failed to create available semaphore %d: %v", i, result)
            return false
        }
        result = vk.CreateFence(device, &fence_info, nil, &fences[i])
        if result != .SUCCESS {
            fmt.eprintfln("Failed to create fence %d: %v", i, result)
            return false
        }
    }

    fmt.printfln("✓ Created %d finished semaphores (per image)", image_count)
    fmt.printfln("✓ Created %d available semaphores + fences (per frame)", MAX_FRAMES_IN_FLIGHT)
    return true
}
```

---

## Update Init/Cleanup

```odin
init_vulkan :: proc(g: ^App_State) -> bool {
    if !create_instance(&g.vk_core.instance) do return false
    if !create_debug_messenger(g.vk_core.instance, &g.debug_messenger) do return false
    if !create_surface(g.window, g.vk_core.instance, &g.surface) do return false
    if !pick_physical_device(g.vk_core.instance, g.surface, &g.vk_core.physical_device) do return false
    if !create_logical_device(
        g.vk_core.physical_device,
        &g.vk_core.logical_device,
        &g.vk_core.graphics_queue,
        &g.vk_core.present_queue,
        g.surface,
    ) do return false
    if !create_swapchain(g.window, g.vk_core.physical_device, g.vk_core.logical_device, g.surface, &g.swapchain) do return false
    if !create_image_views(g.vk_core.logical_device, &g.swapchain) do return false
    if !create_render_pass(g.vk_core.logical_device, g.swapchain.format, &g.renderpipeline.render_pass) do return false
    if !create_framebuffers(g.vk_core.logical_device, g.renderpipeline.render_pass, g.swapchain.views, g.swapchain.extent, &g.renderpipeline.framebuffers) do return false
    if !create_command_pool(g.surface, g.vk_core.physical_device, g.vk_core.logical_device, &g.renderpipeline.command_pool) do return false
    if !create_command_buffers(g.vk_core.logical_device, g.renderpipeline.command_pool, g.renderpipeline.framebuffers, &g.renderpipeline.commandbuffers) do return false

    // Pass swapchain image count to sync object creation
    if !create_sync_objects(
        g.vk_core.logical_device,
        &g.renderpipeline.image_available_semaphores,
        &g.renderpipeline.image_finished_semaphores,
        &g.renderpipeline.in_flight_fences,
        len(g.swapchain.images),  // ← Image count determined by swapchain
    ) do return false

    return true
}

deinit_vulkan :: proc(g: ^App_State) {
    // Destroy finished semaphores (per swapchain image)
    for i in 0 ..< len(g.swapchain.images) {
        vk.DestroySemaphore(g.vk_core.logical_device, g.renderpipeline.image_finished_semaphores[i], nil)
    }
    delete(g.renderpipeline.image_finished_semaphores)  // Free the slice

    // Destroy available semaphores and fences (per frame in flight)
    for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
        vk.DestroySemaphore(g.vk_core.logical_device, g.renderpipeline.image_available_semaphores[i], nil)
        vk.DestroyFence(g.vk_core.logical_device, g.renderpipeline.in_flight_fences[i], nil)
    }

    vk.DestroyCommandPool(g.vk_core.logical_device, g.renderpipeline.command_pool, nil)
    delete(g.renderpipeline.commandbuffers)

    cleanup_swapchain(g.vk_core.logical_device, &g.swapchain, &g.renderpipeline)
    vk.DestroyRenderPass(g.vk_core.logical_device, g.renderpipeline.render_pass, nil)
    vk.DestroyDevice(g.vk_core.logical_device, nil)
    vk.DestroySurfaceKHR(g.vk_core.instance, g.surface, nil)
    vk.DestroyDebugUtilsMessengerEXT(g.vk_core.instance, g.debug_messenger, nil)
    vk.DestroyInstance(g.vk_core.instance, nil)
}
```

---

## Usage in Render Loop

When you implement the draw frame loop, use the correct indexing:

```odin
draw_frame :: proc(core: ^Vulkan_Core, rp: ^RenderPipeline, sc: ^Swap_Chain) {
    // 1. Wait for fence (indexed by current_frame)
    vk.WaitForFences(core.logical_device, 1, &rp.in_flight_fences[rp.current_frame], true, max(u64))
    vk.ResetFences(core.logical_device, 1, &rp.in_flight_fences[rp.current_frame])

    // 2. Acquire image (signal available semaphore indexed by current_frame)
    image_index: u32
    vk.AcquireNextImageKHR(
        core.logical_device,
        sc.swapchain,
        max(u64),
        rp.image_available_semaphores[rp.current_frame],  // ← current_frame
        0,
        &image_index,
    )

    // 3. Record commands for the acquired image
    vk.ResetCommandBuffer(rp.commandbuffers[image_index], {})
    record_command_buffer(rp.commandbuffers[image_index], sc.extent, rp.render_pass, rp.framebuffers[image_index])

    // 4. Submit (wait on available[current_frame], signal finished[image_index])
    wait_semaphores := [1]vk.Semaphore{rp.image_available_semaphores[rp.current_frame]}  // ← current_frame
    wait_stages := [1]vk.PipelineStageFlags{{.COLOR_ATTACHMENT_OUTPUT}}
    signal_semaphores := [1]vk.Semaphore{rp.image_finished_semaphores[image_index]}      // ← image_index

    submit_info := vk.SubmitInfo{
        sType                = .SUBMIT_INFO,
        waitSemaphoreCount   = 1,
        pWaitSemaphores      = &wait_semaphores[0],
        pWaitDstStageMask    = &wait_stages[0],
        commandBufferCount   = 1,
        pCommandBuffers      = &rp.commandbuffers[image_index],
        signalSemaphoreCount = 1,
        pSignalSemaphores    = &signal_semaphores[0],
    }

    vk.QueueSubmit(core.graphics_queue, 1, &submit_info, rp.in_flight_fences[rp.current_frame])

    // 5. Present (wait on finished[image_index])
    swapchains := [1]vk.SwapchainKHR{sc.swapchain}
    present_info := vk.PresentInfoKHR{
        sType              = .PRESENT_INFO_KHR,
        waitSemaphoreCount = 1,
        pWaitSemaphores    = &signal_semaphores[0],  // ← same finished[image_index]
        swapchainCount     = 1,
        pSwapchains        = &swapchains[0],
        pImageIndices      = &image_index,
    }

    vk.QueuePresentKHR(core.present_queue, &present_info)

    // 6. Advance frame counter
    rp.current_frame = (rp.current_frame + 1) % MAX_FRAMES_IN_FLIGHT
}
```

**Key pattern:**
- Fences: `[current_frame]` (CPU waits for this frame's GPU work)
- Available semaphores: `[current_frame]` (CPU cycles through frames)
- Finished semaphores: `[image_index]` (GPU waits for specific image)

---

## Milestone Check

- [ ] Sync objects created
- [ ] No validation errors
- [ ] Ready to start rendering loop

---

## Common Mistakes

**Wrong: Both semaphore arrays sized by MAX_FRAMES_IN_FLIGHT**
```odin
image_available_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore
image_finished_semaphores:  [MAX_FRAMES_IN_FLIGHT]vk.Semaphore  // ✗ WRONG
```

This causes validation errors:
```
vkQueueSubmit(): pSignalSemaphores[0] is being signaled by VkQueue,
but it may still be in use by VkSwapchainKHR.
```

**Why it fails:**

Frame 0: Acquire image 0 → signal `finished[0]` → present waits on `finished[0]`
Frame 1: Acquire image 1 → signal `finished[1]` → present waits on `finished[1]`
Frame 2: Acquire image 2 → signal `finished[0]` ← **ERROR: finished[0] still locked by image 0's presentation!**

The swapchain has 3 images but you only have 2 finished semaphores. When you cycle back to `finished[0]`, image 0 hasn't been re-acquired yet, so its presentation operation still owns that semaphore.

**Correct: Finished semaphores sized by swapchain image count**
```odin
image_available_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore
image_finished_semaphores:  []vk.Semaphore  // ✓ Allocated to len(swapchain.images)
```

Now each image has its own finished semaphore. No conflicts.

---

## What You Learned

- Semaphore creation (two different allocation strategies)
- Fence creation
- Multi-frame synchronization
- Difference between frame-in-flight index and swapchain image index
- Vulkan's swapchain semaphore reuse requirements

---

## Phase 1 Complete!

You now have the complete Vulkan pipeline ready. Every object needed to render is initialized:

✓ Instance
✓ Debug messenger
✓ Surface
✓ Physical device
✓ Logical device
✓ Queues
✓ Swapchain
✓ Image views
✓ Render pass
✓ Framebuffers
✓ Command pool
✓ Command buffers
✓ Sync objects

**Next: Actually render something.**
