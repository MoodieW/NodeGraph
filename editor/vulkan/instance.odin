package renderer

import "base:runtime"
import "core:fmt"
import "vendor:glfw"
import vk "vendor:vulkan"

debug_callback :: proc "system" (
	serverity: vk.DebugUtilsMessageSeverityFlagEXT,
	type: vk.DebugUtilsMessageTypeFlagsEXT,
	callback_data: ^vk.DebugUtilsMessengerCallbackDataEXT,
	user_data: rawptr,
) -> b32 {
	context = runtime.default_context()
	fmt.eprintfln("[VULKKAN] %s", callback_data.pMessage)
	return false
}

create_instance :: proc(vk_instance: ^vk.Instance) -> bool {
	fmt.println("Creating application info")
	app_info := vk.ApplicationInfo {
		sType              = vk.StructureType.APPLICATION_INFO,
		pApplicationName   = "3D Editor",
		applicationVersion = vk.MAKE_VERSION(1, 0, 0),
		pEngineName        = "No Engine",
		engineVersion      = vk.MAKE_VERSION(1, 0, 0),
		apiVersion         = vk.API_VERSION_1_3,
	}

	fmt.println("Getting extesions")
	glfw_extension := glfw.GetRequiredInstanceExtensions()

	extensions := make([dynamic]cstring)
	defer delete(extensions)

	for ext in glfw_extension {
		append(&extensions, ext)
	}
	append(&extensions, vk.EXT_DEBUG_UTILS_EXTENSION_NAME)

	layers := []cstring{"VK_LAYER_KHRONOS_validation"}

	fmt.println("Creating instance info")
	create_info := vk.InstanceCreateInfo {
		sType                   = vk.StructureType.INSTANCE_CREATE_INFO,
		pApplicationInfo        = &app_info,
		enabledExtensionCount   = u32(len(extensions)),
		ppEnabledExtensionNames = raw_data(extensions),
		enabledLayerCount       = u32(len(layers)),
		ppEnabledLayerNames     = raw_data(layers),
	}

	fmt.println("Creating Instances")
	fmt.printfln("%v", create_info)
	vk.load_proc_addresses_global(rawptr(glfw.GetInstanceProcAddress))
	result := vk.CreateInstance(&create_info, nil, vk_instance)
	if result != vk.Result.SUCCESS {
		fmt.eprintfln("Failed to create Vulkan instances: %v", result)
		return false
	}
	fmt.println("Created Instances")

	fmt.println("Loadig instance addresses")
	vk.load_proc_addresses(vk_instance^)
	fmt.printfln("Vulkan Instances created")
	return true
}

create_debug_messenger :: proc(
	vk_instance: vk.Instance,
	debug_messenger: ^vk.DebugUtilsMessengerEXT,
) -> bool {
	create_info := vk.DebugUtilsMessengerCreateInfoEXT {
		sType           = vk.StructureType.DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
		messageSeverity = {
			vk.DebugUtilsMessageSeverityFlagEXT.VERBOSE,
			vk.DebugUtilsMessageSeverityFlagEXT.WARNING,
			vk.DebugUtilsMessageSeverityFlagEXT.ERROR,
		},
		messageType     = {
			vk.DebugUtilsMessageTypeFlagEXT.GENERAL,
			vk.DebugUtilsMessageTypeFlagEXT.VALIDATION,
			vk.DebugUtilsMessageTypeFlagEXT.PERFORMANCE,
		},
		pfnUserCallback = vk.ProcDebugUtilsMessengerCallbackEXT(debug_callback),
	}

	result := vk.CreateDebugUtilsMessengerEXT(vk_instance, &create_info, nil, debug_messenger)
	if result != vk.Result.SUCCESS {
		fmt.eprintfln("Failed to create Debug messenger: %v", result)
		return false
	}

	fmt.println("Devug Messenger Created")
	return true
}

create_surface :: proc(
	window: glfw.WindowHandle,
	vk_instance: vk.Instance,
	vk_surface: ^vk.SurfaceKHR,
) -> bool {
	fmt.printfln("filling out surface %d", vk_surface^)
	result := glfw.CreateWindowSurface(vk_instance, window, nil, vk_surface)
	if result != vk.Result.SUCCESS {
		fmt.eprintfln("Failed to create window surface: %v", result)
		return false
	}
	fmt.printfln("window surface created: %d", vk_surface^)
	return true
}
