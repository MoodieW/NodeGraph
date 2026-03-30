# Lesson 4: Swapchain

**Milestone**: Swapchain created, image count printed.

---

## What You're Building

1. Swapchain (image buffer for presenting)
2. Swapchain image views
3. Surface format/present mode selection

---

## Concepts

- **Swapchain**: Ringbuffer of images to display
- **Double/triple buffering**: Multiple images to avoid tearing
- **Present modes**: FIFO (vsync), IMMEDIATE (no vsync), etc.
- **Image views**: How to interpret image data

**Why this matters**: The swapchain is what gets presented to the screen. You render to swapchain images.

---

## Code Additions

```odin
Swapchain_Support_Details :: struct {
    capabilities: vk.SurfaceCapabilitiesKHR,
    formats: []vk.SurfaceFormatKHR,
    present_modes: []vk.PresentModeKHR,
}

query_swapchain_support :: proc(device: vk.PhysicalDevice) -> Swapchain_Support_Details {
    details: Swapchain_Support_Details

    // Capabilities
    vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(device, g_surface, &details.capabilities)

    // Formats
    format_count: u32
    vk.GetPhysicalDeviceSurfaceFormatsKHR(device, g_surface, &format_count, nil)
    if format_count != 0 {
        details.formats = make([]vk.SurfaceFormatKHR, format_count)
        vk.GetPhysicalDeviceSurfaceFormatsKHR(device, g_surface, &format_count, raw_data(details.formats))
    }

    // Present modes
    present_mode_count: u32
    vk.GetPhysicalDeviceSurfacePresentModesKHR(device, g_surface, &present_mode_count, nil)
    if present_mode_count != 0 {
        details.present_modes = make([]vk.PresentModeKHR, present_mode_count)
        vk.GetPhysicalDeviceSurfacePresentModesKHR(device, g_surface, &present_mode_count, raw_data(details.present_modes))
    }

    return details
}

choose_swap_surface_format :: proc(formats: []vk.SurfaceFormatKHR) -> vk.SurfaceFormatKHR {
    // Prefer SRGB if available
    for format in formats {
        if format.format == vk.Format.B8G8R8A8_SRGB && format.colorSpace == vk.ColorSpaceKHR.SRGB_NONLINEAR {
            return format
        }
    }

    // Fallback to first format
    return formats[0]
}

choose_swap_present_mode :: proc(present_modes: []vk.PresentModeKHR) -> vk.PresentModeKHR {
    // Prefer MAILBOX (triple buffering) if available
    for mode in present_modes {
        if mode == vk.PresentModeKHR.MAILBOX {
            return mode
        }
    }

    // FIFO is always available (vsync)
    return .FIFO
}

choose_swap_extent :: proc(capabilities: vk.SurfaceCapabilitiesKHR) -> vk.Extent2D {
    if capabilities.currentExtent.width != max(u32) {
        return capabilities.currentExtent
    }

    // Window size
    width, height := glfw.GetFramebufferSize(g_window)

    extent := vk.Extent2D{
        width = u32(width),
        height = u32(height),
    }

    // Clamp to supported range
    extent.width = clamp(extent.width, capabilities.minImageExtent.width, capabilities.maxImageExtent.width)
    extent.height = clamp(extent.height, capabilities.minImageExtent.height, capabilities.maxImageExtent.height)

    return extent
}

g_swapchain: vk.SwapchainKHR
g_swapchain_images: []vk.Image
g_swapchain_image_views: []vk.ImageView
g_swapchain_format: vk.Format
g_swapchain_extent: vk.Extent2D

create_swapchain :: proc() -> bool {
    support := query_swapchain_support(g_physical_device)
    defer {
        delete(support.formats)
        delete(support.present_modes)
    }

    surface_format := choose_swap_surface_format(support.formats)
    present_mode := choose_swap_present_mode(support.present_modes)
    extent := choose_swap_extent(support.capabilities)

    // Request one more image than minimum (for triple buffering)
    image_count := support.capabilities.minImageCount + 1
    if support.capabilities.maxImageCount > 0 && image_count > support.capabilities.maxImageCount {
        image_count = support.capabilities.maxImageCount
    }

    // Create swapchain
    create_info := vk.SwapchainCreateInfoKHR{
        sType = vk.StructureType.SWAPCHAIN_CREATE_INFO_KHR,
        surface = g_surface,
        minImageCount = image_count,
        imageFormat = surface_format.format,
        imageColorSpace = surface_format.colorSpace,
        imageExtent = extent,
        imageArrayLayers = 1,
        imageUsage = {.COLOR_ATTACHMENT},
        preTransform = support.capabilities.currentTransform,
        compositeAlpha = {.OPAQUE},
        presentMode = present_mode,
        clipped = true,
        oldSwapchain = 0,
    }

    // Handle queue families
    indices := find_queue_families(g_physical_device)
    graphics_family := indices.graphics_family.?
    present_family := indices.present_family.?

    queue_family_indices := [2]u32{graphics_family, present_family}

    if graphics_family != present_family {
        create_info.imageSharingMode = vk.SharingMode.CONCURRENT
        create_info.queueFamilyIndexCount = 2
        create_info.pQueueFamilyIndices = &queue_family_indices[0]
    } else {
        create_info.imageSharingMode = vk.SharingMode.EXCLUSIVE
    }

    result := vk.CreateSwapchainKHR(g_device, &create_info, nil, &g_swapchain)
    if result != vk.Result.SUCCESS {
        fmt.eprintfln("Failed to create swapchain: %v", result)
        return false
    }

    // Get swapchain images
    vk.GetSwapchainImagesKHR(g_device, g_swapchain, &image_count, nil)
    g_swapchain_images = make([]vk.Image, image_count)
    vk.GetSwapchainImagesKHR(g_device, g_swapchain, &image_count, raw_data(g_swapchain_images))

    g_swapchain_format = surface_format.format
    g_swapchain_extent = extent

    fmt.println("✓ Swapchain created")
    fmt.printfln("  Image count: %d", image_count)
    fmt.printfln("  Format: %v", surface_format.format)
    fmt.printfln("  Extent: %dx%d", extent.width, extent.height)
    fmt.printfln("  Present mode: %v", present_mode)

    return true
}

create_image_views :: proc() -> bool {
    g_swapchain_image_views = make([]vk.ImageView, len(g_swapchain_images))

    for image, i in g_swapchain_images {
        create_info := vk.ImageViewCreateInfo{
            sType = vk.StructureType.IMAGE_VIEW_CREATE_INFO,
            image = image,
            viewType = vk.ImageViewType.D2,
            format = g_swapchain_format,
            components = {
                r = vk.ComponentSwizzle.IDENTITY,
                g = vk.ComponentSwizzle.IDENTITY,
                b = vk.ComponentSwizzle.IDENTITY,
                a = vk.ComponentSwizzle.IDENTITY,
            },
            subresourceRange = {
                aspectMask = {vk.ImageAspectFlag.COLOR},
                baseMipLevel = 0,
                levelCount = 1,
                baseArrayLayer = 0,
                layerCount = 1,
            },
        }

        result := vk.CreateImageView(g_device, &create_info, nil, &g_swapchain_image_views[i])
        if result != vk.Result.SUCCESS {
            fmt.eprintfln("Failed to create image view %d: %v", i, result)
            return false
        }
    }

    fmt.printfln("✓ Created %d image views", len(g_swapchain_image_views))
    return true
}

cleanup_swapchain :: proc() {
    for view in g_swapchain_image_views {
        vk.DestroyImageView(g_device, view, nil)
    }
    delete(g_swapchain_image_views)

    vk.DestroySwapchainKHR(g_device, g_swapchain, nil)
    delete(g_swapchain_images)
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
    return true
}

cleanup_vulkan :: proc() {
    cleanup_swapchain()
    vk.DestroyDevice(g_device, nil)
    vk.DestroySurfaceKHR(g_instance, g_surface, nil)
    vk.DestroyDebugUtilsMessengerEXT(g_instance, g_debug_messenger, nil)
    vk.DestroyInstance(g_instance, nil)
}
```

---

## Milestone Check

- [ ] Console prints swapchain image count (should be 2 or 3)
- [ ] Console prints swapchain format and extent
- [ ] No validation errors

---

## What You Learned

- Swapchain creation
- Surface capability queries
- Format/present mode selection
- Image view creation
