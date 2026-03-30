# Lesson 3: Logical Device + Queues

**Milestone**: Program prints "Graphics queue" and "Present queue" handles.

---

## What You're Building

1. Logical device (interface to GPU)
2. Queue handles (for command submission)

---

## Concepts

- **Logical device**: Your application's connection to the physical device
- **Queues**: Where you submit command buffers
- **Device features**: Optional GPU capabilities (geometry shaders, tessellation, etc.)

---

## Code Additions

```odin
g_device: vk.Device
g_graphics_queue: vk.Queue
g_present_queue: vk.Queue

create_logical_device :: proc() -> bool {
    indices := find_queue_families(g_physical_device)

    // Create queue create infos
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
        queue_info := vk.DeviceQueueCreateInfo{
            sType = vk.StructureType.DEVICE_QUEUE_CREATE_INFO,
            queueFamilyIndex = family,
            queueCount = 1,
            pQueuePriorities = &queue_priority,
        }
        append(&queue_create_infos, queue_info)
    }

    // Device features (empty for now)
    device_features := vk.PhysicalDeviceFeatures{}

    // Device extensions
    device_extensions := []cstring{
        vk.KHR_SWAPCHAIN_EXTENSION_NAME,
    }

    // Create logical device
    create_info := vk.DeviceCreateInfo{
        sType = vk.StructureType.DEVICE_CREATE_INFO,
        queueCreateInfoCount = u32(len(queue_create_infos)),
        pQueueCreateInfos = raw_data(queue_create_infos),
        pEnabledFeatures = &device_features,
        enabledExtensionCount = u32(len(device_extensions)),
        ppEnabledExtensionNames = raw_data(device_extensions),
        enabledLayerCount = 0,
    }

    result := vk.CreateDevice(g_physical_device, &create_info, nil, &g_device)
    if result != vk.Result.SUCCESS {
        fmt.eprintfln("Failed to create logical device: %v", result)
        return false
    }

    // Load device-level functions
    vk.load_proc_addresses(g_device)

    // Get queue handles
    vk.GetDeviceQueue(g_device, graphics_family, 0, &g_graphics_queue)
    vk.GetDeviceQueue(g_device, present_family, 0, &g_present_queue)

    fmt.println("✓ Logical device created")
    fmt.printfln("  Graphics queue: %p", g_graphics_queue)
    fmt.printfln("  Present queue: %p", g_present_queue)

    return true
}
```

---

## Update Initialization

```odin
init_vulkan :: proc() -> bool {
    if !create_instance() do return false
    if !create_debug_messenger() do return false
    if !create_surface() do return false
    if !pick_physical_device() do return false
    if !create_logical_device() do return false
    return true
}

cleanup_vulkan :: proc() {
    vk.DestroyDevice(g_device, nil)
    vk.DestroySurfaceKHR(g_instance, g_surface, nil)
    vk.DestroyDebugUtilsMessengerEXT(g_instance, g_debug_messenger, nil)
    vk.DestroyInstance(g_instance, nil)
}
```

---

## Milestone Check

- [ ] Console prints queue handles (non-zero pointers)
- [ ] No validation errors
- [ ] Device creation succeeds

---

## What You Learned

- Logical device creation
- Queue retrieval
- Device extensions
- Handling multiple queue families
