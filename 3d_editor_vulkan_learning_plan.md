# 3D Model Editor - Vulkan Learning Plan (Odin)

> Learning Vulkan and 3D graphics from first principles.
> Each lesson implements one major Vulkan system with visible/debuggable milestones.

---

## Table of Contents
1. [Introduction](#introduction)
2. [Phase 0: Vulkan Mental Model](#phase-0-vulkan-mental-model)
3. [Phase 1: Vulkan Bootstrap (The Gauntlet)](#phase-1-vulkan-bootstrap-the-gauntlet)
4. [Phase 2: First Triangle](#phase-2-first-triangle)
5. [Phase 3: 3D Rendering](#phase-3-3d-rendering)
6. [Phase 4: Textures and Materials](#phase-4-textures-and-materials)
7. [Phase 5: Model Loading](#phase-5-model-loading)
8. [Phase 6: Editor Features](#phase-6-editor-features)
9. [Resources](#resources)

---

## Introduction

### Why Vulkan Instead of OpenGL?

You're going against all advice. Good. Here's what you get:

**Pros:**
- **Understand everything**: Vulkan hides nothing. You'll know exactly what the GPU is doing.
- **Explicit control**: Memory management, synchronization, command recording - you control it all.
- **Modern API**: This is how graphics APIs work now (DX12, Metal are similar).
- **Performance**: When you know what you're doing, Vulkan is faster.
- **Pipeline knowledge**: Understanding Vulkan teaches you GPU architecture.

**Cons:**
- **Massive boilerplate**: 1000+ lines before you draw a triangle.
- **Easy to crash**: Validation layers will yell at you constantly (this is good).
- **Synchronization hell**: CPU-GPU sync is manual. Mess it up = artifacts or crashes.
- **Steep learning curve**: You need to understand GPU architecture, not just API calls.

### What's Different from OpenGL?

| Concept | OpenGL | Vulkan |
|---------|--------|--------|
| **State** | Global state machine | Explicit state objects |
| **Errors** | Query errors after calls | Validation layers (debug only) |
| **Commands** | Immediate execution | Record into command buffers |
| **Sync** | Implicit (mostly) | Explicit fences/semaphores |
| **Memory** | Driver manages | You manage GPU memory |
| **Shaders** | GLSL text at runtime | SPIR-V bytecode (Slang compiled ahead) |
| **Setup** | ~50 lines | ~1000+ lines |

### The Vulkan Mindset

Vulkan doesn't hold your hand. It trusts you to know what you're doing. You need to think like the GPU:

1. **Everything is explicit**: If you don't tell Vulkan something, it doesn't happen.
2. **Asynchronous execution**: CPU records commands, GPU executes later.
3. **Resource lifetimes**: You must ensure resources live until GPU is done with them.
4. **Synchronization**: You tell Vulkan when CPU and GPU need to coordinate.

### Development Environment

Same Nix flake, but add Vulkan packages:

```nix
# In flake.nix, update buildInputs:
buildInputs = [
  odin
  ols
  glfw
  vulkan-headers
  vulkan-loader
  vulkan-validation-layers
  slang  # Slang shader compiler (to SPIR-V)
];
```

Build commands remain the same:
```bash
odin build . -debug
```

---

## Phase 0: Vulkan Mental Model

- [x] **Phase 0 Complete**

📄 **[Full Lesson: Mental Model](vulkan_lessons/lesson_00_mental_model.md)**

**Goal**: Understand Vulkan's architecture before writing code.

### Lesson 0.1: The Vulkan Pipeline Overview

Vulkan separates concerns that OpenGL mixes together. Here's the full stack:

```
Application (Odin)
    ↓
Vulkan Instance (vkCreateInstance)
    ↓
Physical Device (GPU hardware query)
    ↓
Logical Device (interface to GPU)
    ↓
Queue Family (command submission pipeline)
    ↓
Swapchain (images to present to screen)
    ↓
Render Pass (describes rendering operations)
    ↓
Framebuffer (attachments for render pass)
    ↓
Pipeline (complete GPU state: shaders, blending, etc.)
    ↓
Command Buffer (recorded GPU commands)
    ↓
Submission (send to GPU)
    ↓
Synchronization (fences/semaphores)
    ↓
Present (show image on screen)
```

**Every single one of these is mandatory.** You can't skip steps.

### Lesson 0.2: Memory Model

Vulkan has multiple memory heaps and types. You must:

1. **Query available memory types** (VRAM, RAM, cached, etc.)
2. **Allocate memory** from appropriate heap
3. **Bind memory** to resources (buffers, images)
4. **Map/unmap** for CPU access if needed
5. **Free memory** when done

**No automatic memory management.** You allocate, you free.

### Lesson 0.3: Command Recording vs Execution

OpenGL:
```c
glDrawArrays(...)  // Executes immediately (mostly)
```

Vulkan:
```odin
// 1. Begin recording
vk.BeginCommandBuffer(cmd_buffer, &begin_info)

// 2. Record commands (GPU not executing yet!)
vk.CmdDraw(cmd_buffer, 3, 1, 0, 0)

// 3. End recording
vk.EndCommandBuffer(cmd_buffer)

// 4. Submit to queue (GPU starts executing)
vk.QueueSubmit(queue, 1, &submit_info, fence)

// 5. Wait for GPU to finish
vk.WaitForFences(device, 1, &fence, true, UINT64_MAX)
```

**Recording is fast** (CPU just writes commands).
**Execution is async** (GPU processes commands later).

### Lesson 0.4: Synchronization Primitives

You need to coordinate:
- **CPU ↔ GPU**: Use **fences** (CPU waits for GPU)
- **GPU ↔ GPU**: Use **semaphores** (GPU waits for GPU)
- **Memory visibility**: Use **pipeline barriers** (ensure writes are visible)

Example:
```
Frame N:
  CPU records commands → Submit to GPU with fence
  GPU renders while CPU moves on

Frame N+1:
  CPU waits for Frame N fence before reusing command buffer
  CPU records new commands
  Submit with semaphore (wait for swapchain image available)
```

**Miss synchronization = corruption, crashes, or GPU hangs.**

### Lesson 0.5: Validation Layers

Vulkan's safety net. Catches:
- Invalid API usage
- Memory leaks
- Synchronization errors
- Performance warnings

**Enable validation layers during development.** They're verbose but essential.

```odin
// Add validation layers to instance creation
instance_layers := []cstring{"VK_LAYER_KHRONOS_validation"}
```

Validation layers print messages like:
```
VKLOG: Validation Error: [ VUID-vkCmdDraw-None-02697 ]
Object 0: handle = 0x..., type = VK_OBJECT_TYPE_COMMAND_BUFFER
Draw cannot be called prior to binding a pipeline.
```

**Read these messages.** They tell you exactly what's wrong.

### Checklist for Phase 0:
- [ ] Understand Vulkan's multi-stage setup
- [ ] Know difference between physical/logical device
- [ ] Understand command recording vs execution
- [ ] Know when to use fences vs semaphores
- [ ] Understand validation layers purpose

---

## Phase 1: Vulkan Bootstrap (The Gauntlet)

**Goal**: Set up all Vulkan infrastructure to display a colored window.

This phase is **pure boilerplate**. No rendering yet. Just getting the pipeline ready.

Each lesson adds one major system with a milestone to verify it works.

### Lesson 1: Window + Vulkan Instance

📄 **[Full Lesson: Instance + Debug](vulkan_lessons/lesson_01_instance_debug.md)**

**Milestone**: Window opens, validation layers active, debug messenger prints.

**What you're building**:
1. GLFW window (same as OpenGL)
2. Vulkan instance (global Vulkan state)
3. Debug messenger (validation layer output)

**Concepts**:
- Vulkan instance: Global context, like opening a connection to Vulkan
- Extensions: Features you need (surface, debug utils)
- Layers: Validation, API dumps, etc.

**Code structure**:
```odin
package main

import "core:fmt"
import "core:c"
import "vendor:glfw"
import vk "vendor:vulkan"

// Global state (Vulkan apps need some globals)
g_window: glfw.WindowHandle
g_instance: vk.Instance
g_debug_messenger: vk.DebugUtilsMessengerEXT

// Debug callback
debug_callback :: proc "system" (
    severity: vk.DebugUtilsMessageSeverityFlagsEXT,
    type: vk.DebugUtilsMessageTypeFlagsEXT,
    callback_data: ^vk.DebugUtilsMessengerCallbackDataEXT,
    user_data: rawptr,
) -> b32 {
    context = runtime.default_context()  // Restore Odin context

    fmt.eprintfln("[VULKAN] %s", callback_data.pMessage)
    return false  // Don't abort
}

create_instance :: proc() -> bool {
    // Application info
    app_info := vk.ApplicationInfo{
        sType = .APPLICATION_INFO,
        pApplicationName = "3D Editor",
        applicationVersion = vk.MAKE_VERSION(1, 0, 0),
        pEngineName = "No Engine",
        engineVersion = vk.MAKE_VERSION(1, 0, 0),
        apiVersion = vk.API_VERSION_1_3,
    }

    // Get GLFW required extensions
    glfw_ext_count: u32
    glfw_extensions := glfw.GetRequiredInstanceExtensions(&glfw_ext_count)

    // Add debug extension
    extensions := make([dynamic]cstring)
    defer delete(extensions)

    for i in 0..<glfw_ext_count {
        append(&extensions, glfw_extensions[i])
    }
    append(&extensions, vk.EXT_DEBUG_UTILS_EXTENSION_NAME)

    // Validation layers
    layers := []cstring{
        "VK_LAYER_KHRONOS_validation",
    }

    // Create instance
    create_info := vk.InstanceCreateInfo{
        sType = .INSTANCE_CREATE_INFO,
        pApplicationInfo = &app_info,
        enabledExtensionCount = u32(len(extensions)),
        ppEnabledExtensionNames = raw_data(extensions),
        enabledLayerCount = u32(len(layers)),
        ppEnabledLayerNames = raw_data(layers),
    }

    result := vk.CreateInstance(&create_info, nil, &g_instance)
    if result != .SUCCESS {
        fmt.eprintfln("Failed to create Vulkan instance: %v", result)
        return false
    }

    // Load instance-level functions
    vk.load_proc_addresses(g_instance)

    fmt.println("✓ Vulkan instance created")
    return true
}

create_debug_messenger :: proc() -> bool {
    create_info := vk.DebugUtilsMessengerCreateInfoEXT{
        sType = .DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
        messageSeverity = {.VERBOSE, .WARNING, .ERROR},
        messageType = {.GENERAL, .VALIDATION, .PERFORMANCE},
        pfnUserCallback = debug_callback,
    }

    result := vk.CreateDebugUtilsMessengerEXT(g_instance, &create_info, nil, &g_debug_messenger)
    if result != .SUCCESS {
        fmt.eprintfln("Failed to create debug messenger: %v", result)
        return false
    }

    fmt.println("✓ Debug messenger created")
    return true
}

init_vulkan :: proc() -> bool {
    if !create_instance() do return false
    if !create_debug_messenger() do return false
    return true
}

cleanup_vulkan :: proc() {
    vk.DestroyDebugUtilsMessengerEXT(g_instance, g_debug_messenger, nil)
    vk.DestroyInstance(g_instance, nil)
}

main :: proc() {
    // Initialize GLFW
    if !glfw.Init() {
        fmt.eprintln("Failed to init GLFW")
        return
    }
    defer glfw.Terminate()

    // Create window (no OpenGL context!)
    glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
    glfw.WindowHint(glfw.RESIZABLE, glfw.FALSE)

    g_window = glfw.CreateWindow(1280, 720, "Vulkan 3D Editor", nil, nil)
    if g_window == nil {
        fmt.eprintln("Failed to create window")
        return
    }

    // Initialize Vulkan
    if !init_vulkan() {
        return
    }
    defer cleanup_vulkan()

    fmt.println("✓ Vulkan initialization complete")
    fmt.println("Window should be open. Validation layers active.")

    // Main loop
    for !glfw.WindowShouldClose(g_window) {
        glfw.PollEvents()
    }
}
```

**Milestone Check**:
- Window opens
- Console prints "✓ Vulkan instance created"
- Console prints "✓ Debug messenger created"
- No Vulkan errors in console

**What you learned**:
- Vulkan instance creation
- Extension/layer management
- Debug callback setup
- Validation layer integration

---

### Lesson 2: Surface + Physical Device Selection

📄 **[Full Lesson: Surface + Physical Device](vulkan_lessons/lesson_02_surface_physical_device.md)**

**Milestone**: Program prints GPU name and memory info.

**What you're building**:
1. Window surface (Vulkan ↔ GLFW connection)
2. Physical device enumeration
3. Physical device selection logic
4. Queue family discovery

**Concepts**:
- **Surface**: Platform-specific display target (GLFW creates it)
- **Physical device**: Actual GPU hardware
- **Queue families**: Different GPU command queues (graphics, compute, transfer, present)
- **Device suitability**: Not all GPUs support all features

**Code additions**:
```odin
g_surface: vk.SurfaceKHR
g_physical_device: vk.PhysicalDevice

create_surface :: proc() -> bool {
    result := glfw.CreateWindowSurface(g_instance, g_window, nil, &g_surface)
    if result != .SUCCESS {
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
        if .GRAPHICS in family.queueFlags {
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

**Update `init_vulkan`**:
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

**Milestone Check**:
- Console prints your GPU name (e.g., "Selected GPU: NVIDIA GeForce RTX 3080")
- Console prints API version
- No errors about missing extensions

**What you learned**:
- Physical device enumeration
- Queue family queries
- Device suitability checking
- Surface creation

---

### Lesson 3: Logical Device + Queues

📄 **[Full Lesson: Logical Device + Queues](vulkan_lessons/lesson_03_logical_device_queues.md)**

**Milestone**: Program prints "Graphics queue" and "Present queue" handles.

**What you're building**:
1. Logical device (interface to GPU)
2. Queue handles (for command submission)

**Concepts**:
- **Logical device**: Your application's connection to the physical device
- **Queues**: Where you submit command buffers
- **Device features**: Optional GPU capabilities (geometry shaders, tessellation, etc.)

**Code additions**:
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
            sType = .DEVICE_QUEUE_CREATE_INFO,
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
        sType = .DEVICE_CREATE_INFO,
        queueCreateInfoCount = u32(len(queue_create_infos)),
        pQueueCreateInfos = raw_data(queue_create_infos),
        pEnabledFeatures = &device_features,
        enabledExtensionCount = u32(len(device_extensions)),
        ppEnabledExtensionNames = raw_data(device_extensions),
        // Validation layers (deprecated but some implementations need it)
        enabledLayerCount = 0,
    }

    result := vk.CreateDevice(g_physical_device, &create_info, nil, &g_device)
    if result != .SUCCESS {
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

**Update initialization**:
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

**Milestone Check**:
- Console prints queue handles (non-zero pointers)
- No validation errors
- Device creation succeeds

**What you learned**:
- Logical device creation
- Queue retrieval
- Device extensions
- Handling multiple queue families

---

### Lesson 4: Swapchain

📄 **[Full Lesson: Swapchain](vulkan_lessons/lesson_04_swapchain.md)**

**Milestone**: Swapchain created, image count printed.

**What you're building**:
1. Swapchain (image buffer for presenting)
2. Swapchain image views
3. Surface format/present mode selection

**Concepts**:
- **Swapchain**: Ringbuffer of images to display
- **Double/triple buffering**: Multiple images to avoid tearing
- **Present modes**: FIFO (vsync), IMMEDIATE (no vsync), etc.
- **Image views**: How to interpret image data

**Why this matters**: The swapchain is what gets presented to the screen. You render to swapchain images.

**Code additions**:
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
        if format.format == .B8G8R8A8_SRGB && format.colorSpace == .SRGB_NONLINEAR {
            return format
        }
    }

    // Fallback to first format
    return formats[0]
}

choose_swap_present_mode :: proc(present_modes: []vk.PresentModeKHR) -> vk.PresentModeKHR {
    // Prefer MAILBOX (triple buffering) if available
    for mode in present_modes {
        if mode == .MAILBOX {
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
        sType = .SWAPCHAIN_CREATE_INFO_KHR,
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
        create_info.imageSharingMode = .CONCURRENT
        create_info.queueFamilyIndexCount = 2
        create_info.pQueueFamilyIndices = &queue_family_indices[0]
    } else {
        create_info.imageSharingMode = .EXCLUSIVE
    }

    result := vk.CreateSwapchainKHR(g_device, &create_info, nil, &g_swapchain)
    if result != .SUCCESS {
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
            sType = .IMAGE_VIEW_CREATE_INFO,
            image = image,
            viewType = .D2,
            format = g_swapchain_format,
            components = {
                r = .IDENTITY,
                g = .IDENTITY,
                b = .IDENTITY,
                a = .IDENTITY,
            },
            subresourceRange = {
                aspectMask = {.COLOR},
                baseMipLevel = 0,
                levelCount = 1,
                baseArrayLayer = 0,
                layerCount = 1,
            },
        }

        result := vk.CreateImageView(g_device, &create_info, nil, &g_swapchain_image_views[i])
        if result != .SUCCESS {
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

**Update init/cleanup**:
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

**Milestone Check**:
- Console prints swapchain image count (should be 2 or 3)
- Console prints swapchain format and extent
- No validation errors

**What you learned**:
- Swapchain creation
- Surface capability queries
- Format/present mode selection
- Image view creation

---

### Lesson 5: Render Pass + Framebuffers

📄 **[Full Lesson: Render Pass](vulkan_lessons/lesson_05_render_pass.md)**

**Milestone**: Render pass created, framebuffers created.

**What you're building**:
1. Render pass (describes rendering structure)
2. Framebuffers (attachments for each swapchain image)

**Concepts**:
- **Render pass**: Template for rendering operations
- **Attachments**: Images to render to (color, depth, etc.)
- **Subpasses**: Stages of rendering within a pass
- **Framebuffer**: Actual images bound to attachment points

**Why it matters**: You can't render without a render pass. It tells Vulkan what images you're rendering to and how.

**Code**:
```odin
g_render_pass: vk.RenderPass
g_framebuffers: []vk.Framebuffer

create_render_pass :: proc() -> bool {
    // Color attachment (swapchain image)
    color_attachment := vk.AttachmentDescription{
        format = g_swapchain_format,
        samples = {._1},
        loadOp = .CLEAR,  // Clear before rendering
        storeOp = .STORE,  // Store result
        stencilLoadOp = .DONT_CARE,
        stencilStoreOp = .DONT_CARE,
        initialLayout = .UNDEFINED,
        finalLayout = .PRESENT_SRC_KHR,
    }

    // Attachment reference
    color_attachment_ref := vk.AttachmentReference{
        attachment = 0,
        layout = .COLOR_ATTACHMENT_OPTIMAL,
    }

    // Subpass
    subpass := vk.SubpassDescription{
        pipelineBindPoint = .GRAPHICS,
        colorAttachmentCount = 1,
        pColorAttachments = &color_attachment_ref,
    }

    // Subpass dependency (for image layout transitions)
    dependency := vk.SubpassDependency{
        srcSubpass = vk.SUBPASS_EXTERNAL,
        dstSubpass = 0,
        srcStageMask = {.COLOR_ATTACHMENT_OUTPUT},
        srcAccessMask = {},
        dstStageMask = {.COLOR_ATTACHMENT_OUTPUT},
        dstAccessMask = {.COLOR_ATTACHMENT_WRITE},
    }

    // Create render pass
    render_pass_info := vk.RenderPassCreateInfo{
        sType = .RENDER_PASS_CREATE_INFO,
        attachmentCount = 1,
        pAttachments = &color_attachment,
        subpassCount = 1,
        pSubpasses = &subpass,
        dependencyCount = 1,
        pDependencies = &dependency,
    }

    result := vk.CreateRenderPass(g_device, &render_pass_info, nil, &g_render_pass)
    if result != .SUCCESS {
        fmt.eprintfln("Failed to create render pass: %v", result)
        return false
    }

    fmt.println("✓ Render pass created")
    return true
}

create_framebuffers :: proc() -> bool {
    g_framebuffers = make([]vk.Framebuffer, len(g_swapchain_image_views))

    for view, i in g_swapchain_image_views {
        attachments := [1]vk.ImageView{view}

        framebuffer_info := vk.FramebufferCreateInfo{
            sType = .FRAMEBUFFER_CREATE_INFO,
            renderPass = g_render_pass,
            attachmentCount = 1,
            pAttachments = &attachments[0],
            width = g_swapchain_extent.width,
            height = g_swapchain_extent.height,
            layers = 1,
        }

        result := vk.CreateFramebuffer(g_device, &framebuffer_info, nil, &g_framebuffers[i])
        if result != .SUCCESS {
            fmt.eprintfln("Failed to create framebuffer %d: %v", i, result)
            return false
        }
    }

    fmt.printfln("✓ Created %d framebuffers", len(g_framebuffers))
    return true
}

cleanup_swapchain :: proc() {
    for fb in g_framebuffers {
        vk.DestroyFramebuffer(g_device, fb, nil)
    }
    delete(g_framebuffers)

    for view in g_swapchain_image_views {
        vk.DestroyImageView(g_device, view, nil)
    }
    delete(g_swapchain_image_views)

    vk.DestroySwapchainKHR(g_device, g_swapchain, nil)
    delete(g_swapchain_images)
}
```

**Update init/cleanup**:
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
    return true
}

cleanup_vulkan :: proc() {
    cleanup_swapchain()
    vk.DestroyRenderPass(g_device, g_render_pass, nil)
    vk.DestroyDevice(g_device, nil)
    vk.DestroySurfaceKHR(g_instance, g_surface, nil)
    vk.DestroyDebugUtilsMessengerEXT(g_instance, g_debug_messenger, nil)
    vk.DestroyInstance(g_instance, nil)
}
```

**Milestone Check**:
- Console prints "✓ Render pass created"
- Console prints framebuffer count
- No validation errors

**What you learned**:
- Render pass creation
- Attachment descriptions
- Subpasses and dependencies
- Framebuffer creation

---

### Lesson 6: Command Pools and Buffers

📄 **[Full Lesson: Command Buffers](vulkan_lessons/lesson_06_command_buffers.md)**

**Milestone**: Command pool created, command buffers allocated.

**What you're building**:
1. Command pool (memory pool for command buffers)
2. Command buffer allocation

**Concepts**:
- **Command pool**: Allocator for command buffers
- **Command buffer**: Where you record GPU commands
- **Primary/secondary**: Primary submits to queue, secondary called from primary

**Why it matters**: You can't record commands without command buffers.

**Code**:
```odin
g_command_pool: vk.CommandPool
g_command_buffers: []vk.CommandBuffer

create_command_pool :: proc() -> bool {
    indices := find_queue_families(g_physical_device)

    pool_info := vk.CommandPoolCreateInfo{
        sType = .COMMAND_POOL_CREATE_INFO,
        flags = {.RESET_COMMAND_BUFFER},  // Allow individual resets
        queueFamilyIndex = indices.graphics_family.?,
    }

    result := vk.CreateCommandPool(g_device, &pool_info, nil, &g_command_pool)
    if result != .SUCCESS {
        fmt.eprintfln("Failed to create command pool: %v", result)
        return false
    }

    fmt.println("✓ Command pool created")
    return true
}

create_command_buffers :: proc() -> bool {
    g_command_buffers = make([]vk.CommandBuffer, len(g_framebuffers))

    alloc_info := vk.CommandBufferAllocateInfo{
        sType = .COMMAND_BUFFER_ALLOCATE_INFO,
        commandPool = g_command_pool,
        level = .PRIMARY,
        commandBufferCount = u32(len(g_command_buffers)),
    }

    result := vk.AllocateCommandBuffers(g_device, &alloc_info, raw_data(g_command_buffers))
    if result != .SUCCESS {
        fmt.eprintfln("Failed to allocate command buffers: %v", result)
        return false
    }

    fmt.printfln("✓ Allocated %d command buffers", len(g_command_buffers))
    return true
}
```

**Update init/cleanup**:
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

**Milestone Check**:
- Command pool created
- Command buffers allocated
- No validation errors

**What you learned**:
- Command pool creation
- Command buffer allocation
- Queue family usage

---

### Lesson 7: Synchronization Objects

📄 **[Full Lesson: Synchronization](vulkan_lessons/lesson_07_synchronization.md)**

**Milestone**: Semaphores and fences created, ready for rendering.

**What you're building**:
1. Semaphores (GPU-GPU sync)
2. Fences (CPU-GPU sync)

**Concepts**:
- **Semaphore**: Signal between GPU operations (e.g., image available → rendering done)
- **Fence**: CPU waits for GPU to finish
- **In-flight frames**: Render multiple frames concurrently

**Why it matters**: Without sync, you get corruption and crashes.

**Code**:
```odin
MAX_FRAMES_IN_FLIGHT :: 2

g_image_available_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore
g_render_finished_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore
g_in_flight_fences: [MAX_FRAMES_IN_FLIGHT]vk.Fence

create_sync_objects :: proc() -> bool {
    semaphore_info := vk.SemaphoreCreateInfo{
        sType = .SEMAPHORE_CREATE_INFO,
    }

    fence_info := vk.FenceCreateInfo{
        sType = .FENCE_CREATE_INFO,
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

**Update cleanup**:
```odin
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

**Milestone Check**:
- Sync objects created
- No validation errors
- Ready to start rendering loop

**What you learned**:
- Semaphore creation
- Fence creation
- Multi-frame synchronization

---

### Checklist for Phase 1:
- [ ] Instance, debug messenger, surface created
- [ ] Physical device selected and logged
- [ ] Logical device and queues created
- [ ] Swapchain and image views created
- [ ] Render pass and framebuffers created
- [ ] Command pool and buffers allocated
- [ ] Sync objects created
- [ ] No validation errors throughout

**You now have the complete Vulkan pipeline ready. Next phase: actually rendering something.**

---

## Phase 2: First Triangle

**Goal**: Clear the screen to a color, then draw a triangle.

### Lesson 8: Clearing the Screen

📄 **[Full Lesson: Clear Screen](vulkan_lessons/lesson_08_clear_screen.md)**

**Milestone**: Window clears to blue color every frame.

**What you're building**:
1. Render loop with frame synchronization
2. Command buffer recording (just clear)
3. Queue submission and present

**This is where it all comes together.**

**Code**:
```odin
g_current_frame: int = 0

record_command_buffer :: proc(command_buffer: vk.CommandBuffer, image_index: u32) {
    // Begin command buffer
    begin_info := vk.CommandBufferBeginInfo{
        sType = .COMMAND_BUFFER_BEGIN_INFO,
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
        sType = .RENDER_PASS_BEGIN_INFO,
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
        sType = .SUBMIT_INFO,
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
        sType = .PRESENT_INFO_KHR,
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
    // GLFW and Vulkan init...

    // Main loop
    for !glfw.WindowShouldClose(g_window) {
        glfw.PollEvents()
        draw_frame()
    }

    // Wait for device to finish before cleanup
    vk.DeviceWaitIdle(g_device)

    cleanup_vulkan()
}
```

**Milestone Check**:
- Window displays solid blue color
- No flickering
- No validation errors
- Console silent (no errors)

**What you learned**:
- Command buffer recording
- Render pass execution
- Synchronization flow
- Queue submission and present

---

### Lesson 9: Graphics Pipeline + Triangle

📄 **[Full Lesson: Triangle](vulkan_lessons/lesson_09_triangle.md)**

**Milestone**: RGB triangle rendered on screen.

**What you're building**:
1. Shader modules (SPIR-V)
2. Graphics pipeline
3. Triangle vertex data
4. Draw command

**This is the big one. The pipeline is complex.**

**First: Compile shaders to SPIR-V**

Create `shaders/triangle.slang`:
```slang
// Vertex shader entry point
[shader("vertex")]
float4 vertexMain(uint vertexID : SV_VertexID, out float3 fragColor : COLOR) : SV_Position
{
    static const float2 positions[3] = {
        float2(0.0, -0.5),
        float2(0.5, 0.5),
        float2(-0.5, 0.5)
    };

    static const float3 colors[3] = {
        float3(1.0, 0.0, 0.0),
        float3(0.0, 1.0, 0.0),
        float3(0.0, 0.0, 1.0)
    };

    fragColor = colors[vertexID];
    return float4(positions[vertexID], 0.0, 1.0);
}

// Fragment shader entry point
[shader("fragment")]
float4 fragmentMain(float3 fragColor : COLOR) : SV_Target
{
    return float4(fragColor, 1.0);
}
```

**Compile**:
```bash
slangc shaders/triangle.slang -target spirv -entry vertexMain -stage vertex -o shaders/triangle.vert.spv
slangc shaders/triangle.slang -target spirv -entry fragmentMain -stage fragment -o shaders/triangle.frag.spv
```

**Odin code**:
```odin
g_pipeline_layout: vk.PipelineLayout
g_graphics_pipeline: vk.Pipeline

read_file :: proc(filepath: string) -> ([]byte, bool) {
    data, ok := os.read_entire_file(filepath)
    if !ok {
        fmt.eprintfln("Failed to read file: %s", filepath)
        return nil, false
    }
    return data, true
}

create_shader_module :: proc(code: []byte) -> (vk.ShaderModule, bool) {
    create_info := vk.ShaderModuleCreateInfo{
        sType = .SHADER_MODULE_CREATE_INFO,
        codeSize = len(code),
        pCode = cast(^u32)raw_data(code),
    }

    shader_module: vk.ShaderModule
    result := vk.CreateShaderModule(g_device, &create_info, nil, &shader_module)
    if result != .SUCCESS {
        fmt.eprintfln("Failed to create shader module: %v", result)
        return 0, false
    }

    return shader_module, true
}

create_graphics_pipeline :: proc() -> bool {
    // Load shader code
    vert_code, vert_ok := read_file("shaders/triangle.vert.spv")
    if !vert_ok do return false
    defer delete(vert_code)

    frag_code, frag_ok := read_file("shaders/triangle.frag.spv")
    if !frag_ok do return false
    defer delete(frag_code)

    // Create shader modules
    vert_module, vert_module_ok := create_shader_module(vert_code)
    if !vert_module_ok do return false
    defer vk.DestroyShaderModule(g_device, vert_module, nil)

    frag_module, frag_module_ok := create_shader_module(frag_code)
    if !frag_module_ok do return false
    defer vk.DestroyShaderModule(g_device, frag_module, nil)

    // Shader stages
    vert_stage := vk.PipelineShaderStageCreateInfo{
        sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
        stage = {.VERTEX},
        module = vert_module,
        pName = "main",
    }

    frag_stage := vk.PipelineShaderStageCreateInfo{
        sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
        stage = {.FRAGMENT},
        module = frag_module,
        pName = "main",
    }

    shader_stages := [2]vk.PipelineShaderStageCreateInfo{vert_stage, frag_stage}

    // Vertex input (none - hardcoded in shader)
    vertex_input_info := vk.PipelineVertexInputStateCreateInfo{
        sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        vertexBindingDescriptionCount = 0,
        vertexAttributeDescriptionCount = 0,
    }

    // Input assembly
    input_assembly := vk.PipelineInputAssemblyStateCreateInfo{
        sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        topology = .TRIANGLE_LIST,
        primitiveRestartEnable = false,
    }

    // Viewport and scissor
    viewport := vk.Viewport{
        x = 0.0,
        y = 0.0,
        width = f32(g_swapchain_extent.width),
        height = f32(g_swapchain_extent.height),
        minDepth = 0.0,
        maxDepth = 1.0,
    }

    scissor := vk.Rect2D{
        offset = {0, 0},
        extent = g_swapchain_extent,
    }

    viewport_state := vk.PipelineViewportStateCreateInfo{
        sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        viewportCount = 1,
        pViewports = &viewport,
        scissorCount = 1,
        pScissors = &scissor,
    }

    // Rasterizer
    rasterizer := vk.PipelineRasterizationStateCreateInfo{
        sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        depthClampEnable = false,
        rasterizerDiscardEnable = false,
        polygonMode = .FILL,
        lineWidth = 1.0,
        cullMode = {.BACK},
        frontFace = .CLOCKWISE,
        depthBiasEnable = false,
    }

    // Multisampling (disabled)
    multisampling := vk.PipelineMultisampleStateCreateInfo{
        sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        sampleShadingEnable = false,
        rasterizationSamples = {._1},
    }

    // Color blending
    color_blend_attachment := vk.PipelineColorBlendAttachmentState{
        colorWriteMask = {.R, .G, .B, .A},
        blendEnable = false,
    }

    color_blending := vk.PipelineColorBlendStateCreateInfo{
        sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        logicOpEnable = false,
        logicOp = .COPY,
        attachmentCount = 1,
        pAttachments = &color_blend_attachment,
    }

    // Pipeline layout
    layout_info := vk.PipelineLayoutCreateInfo{
        sType = .PIPELINE_LAYOUT_CREATE_INFO,
    }

    if vk.CreatePipelineLayout(g_device, &layout_info, nil, &g_pipeline_layout) != .SUCCESS {
        fmt.eprintln("Failed to create pipeline layout")
        return false
    }

    // Create graphics pipeline
    pipeline_info := vk.GraphicsPipelineCreateInfo{
        sType = .GRAPHICS_PIPELINE_CREATE_INFO,
        stageCount = 2,
        pStages = &shader_stages[0],
        pVertexInputState = &vertex_input_info,
        pInputAssemblyState = &input_assembly,
        pViewportState = &viewport_state,
        pRasterizationState = &rasterizer,
        pMultisampleState = &multisampling,
        pColorBlendState = &color_blending,
        layout = g_pipeline_layout,
        renderPass = g_render_pass,
        subpass = 0,
    }

    result := vk.CreateGraphicsPipelines(g_device, 0, 1, &pipeline_info, nil, &g_graphics_pipeline)
    if result != .SUCCESS {
        fmt.eprintfln("Failed to create graphics pipeline: %v", result)
        return false
    }

    fmt.println("✓ Graphics pipeline created")
    return true
}
```

**Update command recording**:
```odin
record_command_buffer :: proc(command_buffer: vk.CommandBuffer, image_index: u32) {
    begin_info := vk.CommandBufferBeginInfo{
        sType = .COMMAND_BUFFER_BEGIN_INFO,
    }

    if vk.BeginCommandBuffer(command_buffer, &begin_info) != .SUCCESS {
        fmt.eprintln("Failed to begin command buffer")
        return
    }

    clear_color := vk.ClearValue{
        color = {float32 = {0.0, 0.0, 0.5, 1.0}},
    }

    render_pass_info := vk.RenderPassBeginInfo{
        sType = .RENDER_PASS_BEGIN_INFO,
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

    // Bind pipeline
    vk.CmdBindPipeline(command_buffer, .GRAPHICS, g_graphics_pipeline)

    // Draw triangle
    vk.CmdDraw(command_buffer, 3, 1, 0, 0)

    vk.CmdEndRenderPass(command_buffer)

    if vk.EndCommandBuffer(command_buffer) != .SUCCESS {
        fmt.eprintln("Failed to end command buffer")
    }
}
```

**Update cleanup**:
```odin
cleanup_vulkan :: proc() {
    vk.DestroyPipeline(g_device, g_graphics_pipeline, nil)
    vk.DestroyPipelineLayout(g_device, g_pipeline_layout, nil)

    // ... rest of cleanup
}
```

**Milestone Check**:
- RGB-colored triangle renders on blue background
- Triangle is visible and correctly colored
- No validation errors

**What you learned**:
- Slang shader language
- Shader compilation to SPIR-V (Slang → SPIR-V)
- Shader module creation
- Graphics pipeline creation (all the stages!)
- Draw commands

---

### Checklist for Phase 2:
- [ ] Screen clears to solid color
- [ ] Triangle renders with vertex colors
- [ ] No validation errors
- [ ] Understand entire render loop flow

---

## Phase 3: 3D Rendering

**Goal**: Render a spinning 3D cube with camera.

### Lesson 10: Uniform Buffers (MVP Matrices)

**Milestone**: Cube rotates using uniform buffer.

**What you're building**:
1. Uniform buffer for matrices
2. Descriptor sets
3. Updated vertex shader with uniforms

### Lesson 11: Vertex Buffers

**Milestone**: Cube vertex data in GPU buffer.

### Lesson 12: Index Buffers

**Milestone**: Indexed cube rendering (fewer vertices).

### Lesson 13: Depth Testing

**Milestone**: Depth buffer working, no z-fighting.

---

## Phase 4: Textures and Materials

### Lesson 14: Image and Sampler

**Milestone**: Texture loaded and displayed on cube.

### Lesson 15: Combined Image Samplers

**Milestone**: Multiple textures working.

---

## Phase 5: Model Loading

### Lesson 16: Staging Buffers

**Milestone**: Large mesh data uploaded efficiently.

### Lesson 17: OBJ Loader

**Milestone**: OBJ file loaded and rendered.

---

## Phase 6: Editor Features

### Lesson 18: ImGui Integration

### Lesson 19: Camera System

### Lesson 20: Object Selection

---

## Resources

**Vulkan Learning**:
- **Vulkan Tutorial**: https://vulkan-tutorial.com (C++, translate to Odin)
- **Vulkan Guide**: https://vkguide.dev (excellent explanations)
- **Vulkan Spec**: https://registry.khronos.org/vulkan/

**Odin Vulkan**:
- Check `vendor:vulkan` in Odin source
- Look for Vulkan examples in Odin community

**Tools**:
- **RenderDoc**: Frame debugger for Vulkan
- **Vulkan Configurator**: Manage layers and settings

---

## Final Notes

Vulkan is **hard**. You'll spend more time fighting validation errors than writing rendering code initially. That's normal.

The payoff: you'll understand **exactly** what's happening between your code and the GPU. No magic, no hidden state, no "it just works" (until you make it work).

Take each lesson slowly. Get each milestone working before moving on. Use validation layers religiously. Read the error messages.

You're learning how modern GPUs actually work. That knowledge is worth the pain.
