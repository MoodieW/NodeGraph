# Lesson 6: Command Pools and Buffers

**Milestone**: Command pool created, command buffers allocated.

---

## What You're Building

1. Command pool (memory pool for command buffers)
2. Command buffer allocation

---

## Concepts

- **Command pool**: Allocator for command buffers
- **Command buffer**: Where you record GPU commands
- **Primary/secondary**: Primary submits to queue, secondary called from primary

**Why it matters**: You can't record commands without command buffers.

---

## Code

```odin
g_command_pool: vk.CommandPool
g_command_buffers: []vk.CommandBuffer

create_command_pool :: proc() -> bool {
    indices := find_queue_families(g_physical_device)

    pool_info := vk.CommandPoolCreateInfo{
        sType = vk.StructureType.COMMAND_POOL_CREATE_INFO,
        flags = {.RESET_COMMAND_BUFFER},  // Allow individual resets
        queueFamilyIndex = indices.graphics_family.?,
    }

    result := vk.CreateCommandPool(g_device, &pool_info, nil, &g_command_pool)
    if result != vk.Result.SUCCESS {
        fmt.eprintfln("Failed to create command pool: %v", result)
        return false
    }

    fmt.println("✓ Command pool created")
    return true
}

create_command_buffers :: proc() -> bool {
    g_command_buffers = make([]vk.CommandBuffer, len(g_framebuffers))

    alloc_info := vk.CommandBufferAllocateInfo{
        sType = vk.StructureType.COMMAND_BUFFER_ALLOCATE_INFO,
        commandPool = g_command_pool,
        level = .PRIMARY,
        commandBufferCount = u32(len(g_command_buffers)),
    }

    result := vk.AllocateCommandBuffers(g_device, &alloc_info, raw_data(g_command_buffers))
    if result != vk.Result.SUCCESS {
        fmt.eprintfln("Failed to allocate command buffers: %v", result)
        return false
    }

    fmt.printfln("✓ Allocated %d command buffers", len(g_command_buffers))
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
    return true
}

cleanup_vulkan :: proc() {
    vk.DestroyCommandPool(g_device, g_command_pool, nil)  // Also frees command buffers
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

- [ ] Command pool created
- [ ] Command buffers allocated
- [ ] No validation errors

---

## What You Learned

- Command pool creation
- Command buffer allocation
- Queue family usage
