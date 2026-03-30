# Lesson 2: Surface + Physical Device Selection

**Milestone**: Program prints GPU name and memory info.

---

## What You're Building

1. Window surface (Vulkan ↔ GLFW connection)
2. Physical device enumeration
3. Physical device selection logic
4. Queue family discovery

---

## Concepts

- **Surface**: Platform-specific display target (GLFW creates it)
- **Physical device**: Actual GPU hardware
- **Queue families**: Different GPU command queues (graphics, compute, transfer, present)
- **Device suitability**: Not all GPUs support all features

---

## Code Additions

```odin
g_surface: vk.SurfaceKHR
g_physical_device: vk.PhysicalDevice

create_surface :: proc() -> bool {
    result := glfw.CreateWindowSurface(g_instance, g_window, nil, &g_surface)
    if result != vk.Result.SUCCESS {
        fmt.eprintfln("Failed to create surface: %v", result)
        return false
    }

    fmt.println("✓ Window surface created")
    return true
}

Queue_Family_Indices :: struct {
    graphics_family: Maybe(u32),
    present_family: Maybe(u32),
}

is_complete :: proc(indices: Queue_Family_Indices) -> bool {
    return indices.graphics_family != nil && indices.present_family != nil
}

find_queue_families :: proc(device: vk.PhysicalDevice) -> Queue_Family_Indices {
    indices: Queue_Family_Indices

    // Get queue families
    queue_family_count: u32
    vk.GetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, nil)

    queue_families := make([]vk.QueueFamilyProperties, queue_family_count)
    defer delete(queue_families)

    vk.GetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, raw_data(queue_families))

    // Find graphics and present queues
    for family, i in queue_families {
        // Check for graphics support
        if vk.QueueFlag.GRAPHICS in family.queueFlags {
            indices.graphics_family = u32(i)
        }

        // Check for present support
        present_support: b32
        vk.GetPhysicalDeviceSurfaceSupportKHR(device, u32(i), g_surface, &present_support)
        if present_support {
            indices.present_family = u32(i)
        }

        if is_complete(indices) {
            break
        }
    }

    return indices
}

is_device_suitable :: proc(device: vk.PhysicalDevice) -> bool {
    // Check queue families
    indices := find_queue_families(device)
    if !is_complete(indices) {
        return false
    }

    // Check for swapchain extension support
    extension_count: u32
    vk.EnumerateDeviceExtensionProperties(device, nil, &extension_count, nil)

    available_extensions := make([]vk.ExtensionProperties, extension_count)
    defer delete(available_extensions)

    vk.EnumerateDeviceExtensionProperties(device, nil, &extension_count, raw_data(available_extensions))

    // Check if swapchain extension exists
    has_swapchain := false
    for ext in available_extensions {
        ext_name := cstring(&ext.extensionName[0])
        if ext_name == vk.KHR_SWAPCHAIN_EXTENSION_NAME {
            has_swapchain = true
            break
        }
    }

    return has_swapchain
}

pick_physical_device :: proc() -> bool {
    device_count: u32
    vk.EnumeratePhysicalDevices(g_instance, &device_count, nil)

    if device_count == 0 {
        fmt.eprintln("No Vulkan-capable GPUs found")
        return false
    }

    devices := make([]vk.PhysicalDevice, device_count)
    defer delete(devices)

    vk.EnumeratePhysicalDevices(g_instance, &device_count, raw_data(devices))

    // Find suitable device
    for device in devices {
        if is_device_suitable(device) {
            g_physical_device = device

            // Print device info
            props: vk.PhysicalDeviceProperties
            vk.GetPhysicalDeviceProperties(device, &props)

            device_name := cstring(&props.deviceName[0])
            fmt.printfln("✓ Selected GPU: %s", device_name)
            fmt.printfln("  API Version: %d.%d.%d",
                vk.VERSION_MAJOR(props.apiVersion),
                vk.VERSION_MINOR(props.apiVersion),
                vk.VERSION_PATCH(props.apiVersion))

            return true
        }
    }

    fmt.eprintln("No suitable GPU found")
    return false
}
```

---

## Update `init_vulkan`

```odin
init_vulkan :: proc() -> bool {
    if !create_instance() do return false
    if !create_debug_messenger() do return false
    if !create_surface() do return false
    if !pick_physical_device() do return false
    return true
}

cleanup_vulkan :: proc() {
    vk.DestroySurfaceKHR(g_instance, g_surface, nil)
    vk.DestroyDebugUtilsMessengerEXT(g_instance, g_debug_messenger, nil)
    vk.DestroyInstance(g_instance, nil)
}
```

---

## Milestone Check

- [ ] Console prints your GPU name (e.g., "Selected GPU: NVIDIA GeForce RTX 3080")
- [ ] Console prints API version
- [ ] No errors about missing extensions

---

## What You Learned

- Physical device enumeration
- Queue family queries
- Device suitability checking
- Surface creation
