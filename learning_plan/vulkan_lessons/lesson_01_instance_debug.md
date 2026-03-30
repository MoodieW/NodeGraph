# Lesson 1: Window + Vulkan Instance + Debug Messenger

**Milestone**: Window opens, validation layers active, debug messenger prints.

---

## What You're Building

1. GLFW window (same as OpenGL)
2. Vulkan instance (global Vulkan state)
3. Debug messenger (validation layer output)

---

## Concepts

- **Vulkan instance**: Global context, like opening a connection to Vulkan
- **Extensions**: Features you need (surface, debug utils)
- **Layers**: Validation, API dumps, etc.

---

## Code

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
        sType = vk.StructureType.APPLICATION_INFO,
        pApplicationName = "3D Editor",
        applicationVersion = vk.MAKE_VERSION(1, 0, 0),
        pEngineName = "No Engine",
        engineVersion = vk.MAKE_VERSION(1, 0, 0),
        apiVersion = vk.API_VERSION_1_3,
    }

    // Get GLFW required extensions
    glfw_extensions := glfw.GetRequiredInstanceExtensions()

    // Add debug extension
    extensions := make([dynamic]cstring)
    defer delete(extensions)

    for ext in glfw_extensions {
        append(&extensions, ext)
    }
    append(&extensions, vk.EXT_DEBUG_UTILS_EXTENSION_NAME)

    // Validation layers
    layers := []cstring{
        "VK_LAYER_KHRONOS_validation",
    }

    // Create instance
    create_info := vk.InstanceCreateInfo{
        sType = vk.StructureType.INSTANCE_CREATE_INFO,
        pApplicationInfo = &app_info,
        enabledExtensionCount = u32(len(extensions)),
        ppEnabledExtensionNames = raw_data(extensions),
        enabledLayerCount = u32(len(layers)),
        ppEnabledLayerNames = raw_data(layers),
    }

    result := vk.CreateInstance(&create_info, nil, &g_instance)
    if result != vk.Result.SUCCESS {
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
        sType = vk.StructureType.DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
        messageSeverity = {
            vk.DebugUtilsMessageSeverityFlagEXT.VERBOSE,
            vk.DebugUtilsMessageSeverityFlagEXT.WARNING,
            vk.DebugUtilsMessageSeverityFlagEXT.ERROR,
        },
        messageType = {
            vk.DebugUtilsMessageTypeFlagEXT.GENERAL,
            vk.DebugUtilsMessageTypeFlagEXT.VALIDATION,
            vk.DebugUtilsMessageTypeFlagEXT.PERFORMANCE,
        },
        pfnUserCallback = debug_callback,
    }

    result := vk.CreateDebugUtilsMessengerEXT(g_instance, &create_info, nil, &g_debug_messenger)
    if result != vk.Result.SUCCESS {
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

---

## Milestone Check

- [ ] Window opens
- [ ] Console prints "✓ Vulkan instance created"
- [ ] Console prints "✓ Debug messenger created"
- [ ] No Vulkan errors in console

---

## What You Learned

- Vulkan instance creation
- Extension/layer management
- Debug callback setup
- Validation layer integration
