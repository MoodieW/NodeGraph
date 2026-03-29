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

**Why it matters**: Without sync, you get corruption and crashes.

---

## Code

```odin
MAX_FRAMES_IN_FLIGHT :: 2

g_image_available_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore
g_render_finished_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore
g_in_flight_fences: [MAX_FRAMES_IN_FLIGHT]vk.Fence

create_sync_objects :: proc() -> bool {
    semaphore_info := vk.SemaphoreCreateInfo{
        sType = vk.StructureType.SEMAPHORE_CREATE_INFO,
    }

    fence_info := vk.FenceCreateInfo{
        sType = vk.StructureType.FENCE_CREATE_INFO,
        flags = {.SIGNALED},  // Start signaled (first frame doesn't wait)
    }

    for i in 0..<MAX_FRAMES_IN_FLIGHT {
        if vk.CreateSemaphore(g_device, &semaphore_info, nil, &g_image_available_semaphores[i]) != .SUCCESS ||
           vk.CreateSemaphore(g_device, &semaphore_info, nil, &g_render_finished_semaphores[i]) != .SUCCESS ||
           vk.CreateFence(g_device, &fence_info, nil, &g_in_flight_fences[i]) != .SUCCESS {
            fmt.eprintfln("Failed to create sync objects for frame %d", i)
            return false
        }
    }

    fmt.printfln("✓ Created sync objects for %d frames in flight", MAX_FRAMES_IN_FLIGHT)
    return true
}
```

---

## Update Init/Cleanup

```odin
init_vulkan :: proc() -> bool {
    if !create_instance() do return false
    if !create_debug_messenger() do return false
    if !create_surface() do return false
    if !pick_physical_device() do return false
    if !create_logical_device() do return false
    if !create_swapchain() do return false
    if !create_image_views() do return false
    if !create_render_pass() do return false
    if !create_framebuffers() do return false
    if !create_command_pool() do return false
    if !create_command_buffers() do return false
    if !create_sync_objects() do return false
    return true
}

cleanup_vulkan :: proc() {
    for i in 0..<MAX_FRAMES_IN_FLIGHT {
        vk.DestroySemaphore(g_device, g_image_available_semaphores[i], nil)
        vk.DestroySemaphore(g_device, g_render_finished_semaphores[i], nil)
        vk.DestroyFence(g_device, g_in_flight_fences[i], nil)
    }

    vk.DestroyCommandPool(g_device, g_command_pool, nil)
    delete(g_command_buffers)

    cleanup_swapchain()
    vk.DestroyRenderPass(g_device, g_render_pass, nil)
    vk.DestroyDevice(g_device, nil)
    vk.DestroySurfaceKHR(g_instance, g_surface, nil)
    vk.DestroyDebugUtilsMessengerEXT(g_instance, g_debug_messenger, nil)
    vk.DestroyInstance(g_instance, nil)
}
```

---

## Milestone Check

- [ ] Sync objects created
- [ ] No validation errors
- [ ] Ready to start rendering loop

---

## What You Learned

- Semaphore creation
- Fence creation
- Multi-frame synchronization

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
