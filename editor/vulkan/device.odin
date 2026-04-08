package renderer

import "core:fmt"
import vk "vendor:vulkan"

Queue_Family_Indices :: struct {
	graphics_family: Maybe(u32),
	present_family:  Maybe(u32),
}

is_complete :: proc(indices: Queue_Family_Indices) -> bool {
	return indices.graphics_family != nil && indices.present_family != nil
}

find_family_queues :: proc(
	device: vk.PhysicalDevice,
	surface: vk.SurfaceKHR,
) -> Queue_Family_Indices {
	indices: Queue_Family_Indices
	queue_family_count: u32
	vk.GetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, nil)
	queue_familes := make([]vk.QueueFamilyProperties, queue_family_count)
	defer delete(queue_familes)

	vk.GetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, raw_data(queue_familes))

	for family, i in queue_familes {
		if vk.QueueFlag.GRAPHICS in family.queueFlags {
			indices.graphics_family = u32(i)
		}
		present_support: b32
		vk.GetPhysicalDeviceSurfaceSupportKHR(device, u32(i), surface, &present_support)

		if present_support {
			indices.present_family = u32(i)
		}

		if is_complete(indices) {
			break
		}
	}
	return indices
}

is_device_suitable :: proc(device: vk.PhysicalDevice, surface: vk.SurfaceKHR) -> bool {
	fmt.printfln("Checking if device is suitable: %d", device)
	indices := find_family_queues(device, surface)
	if !is_complete(indices) {
		return false
	}
	fmt.println("Found device Families")
	extensions_count: u32
	fmt.println("Getting Props count")
	vk.EnumerateDeviceExtensionProperties(device, nil, &extensions_count, nil)

	available_extensions := make([]vk.ExtensionProperties, extensions_count)
	defer delete(available_extensions)

	fmt.println("Filling out props")
	vk.EnumerateDeviceExtensionProperties(
		device,
		nil,
		&extensions_count,
		raw_data(available_extensions),
	)

	has_swapchain := false
	for ext in available_extensions {
		name := ext.extensionName
		ext_name := cstring(raw_data(name[:]))
		if ext_name == vk.KHR_SWAPCHAIN_EXTENSION_NAME {
			has_swapchain = true
			break
		}
	}
	return has_swapchain
}

pick_physical_device :: proc(
	instance: vk.Instance,
	surface: vk.SurfaceKHR,
	store_device: ^vk.PhysicalDevice,
) -> bool {
	fmt.printfln("func %d", vk.EnumeratePhysicalDevices)
	if vk.EnumeratePhysicalDevices == nil {
		fmt.eprintln("vk.EnumeratePhysicalDevices is NULL! Proc addresses not loaded!")
		return false
	}

	device_count: u32
	fmt.println(type_info_of(type_of(surface)))
	fmt.println("Getting Device Count")
	vk.EnumeratePhysicalDevices(instance, &device_count, nil)

	if device_count == 0 {
		fmt.eprintln("No Vulkan Gpus found")
		return false
	}
	devices := make([]vk.PhysicalDevice, device_count)
	defer delete(devices)

	vk.EnumeratePhysicalDevices(instance, &device_count, raw_data(devices))

	for device, i in devices {
		if !is_device_suitable(device, surface) {
			continue
		}

		props: vk.PhysicalDeviceProperties
		vk.GetPhysicalDeviceProperties(device, &props)
		device_name := cstring(&props.deviceName[0])
		fmt.printfln("Selected GPU: %d", device_name)
		store_device^ = device
		return true
	}
	fmt.eprintln("No Suitable GPU")
	return false
}

create_logical_device :: proc(
	p_device: vk.PhysicalDevice,
	l_device: ^vk.Device,
	g_queue: ^vk.Queue,
	p_queue: ^vk.Queue,
	surface: vk.SurfaceKHR,
) -> bool {
	fmt.println("Find Family Queues")
	indices := find_family_queues(p_device, surface)
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
		queue_info := vk.DeviceQueueCreateInfo {
			sType            = .DEVICE_QUEUE_CREATE_INFO,
			queueFamilyIndex = family,
			queueCount       = 1,
			pQueuePriorities = &queue_priority,
		}
		append(&queue_create_infos, queue_info)
	}

	device_feature := vk.PhysicalDeviceFeatures{}
	device_extensions := []cstring{vk.KHR_SWAPCHAIN_EXTENSION_NAME}

	vulkan11_features := vk.PhysicalDeviceVulkan11Features {
		sType                = .PHYSICAL_DEVICE_VULKAN_1_1_FEATURES,
		shaderDrawParameters = true,
	}

	create_info := vk.DeviceCreateInfo {
		sType                   = .DEVICE_CREATE_INFO,
		pNext                   = &vulkan11_features,
		queueCreateInfoCount    = u32(len(queue_create_infos)),
		pQueueCreateInfos       = raw_data(queue_create_infos),
		pEnabledFeatures        = &device_feature,
		enabledExtensionCount   = u32(len(device_extensions)),
		ppEnabledExtensionNames = raw_data(device_extensions),
		enabledLayerCount       = 0,
	}

	result := vk.CreateDevice(p_device, &create_info, nil, l_device)
	if result != vk.Result.SUCCESS {
		fmt.eprintfln("Failed to create logical device: %v:", result)
		return false
	}
	vk.load_proc_addresses_device(l_device^)

	vk.GetDeviceQueue(l_device^, graphics_family, 0, g_queue)
	vk.GetDeviceQueue(l_device^, present_family, 0, p_queue)

	fmt.println("Logical Device Created")
	return true
}
