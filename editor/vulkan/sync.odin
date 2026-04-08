package renderer

import "core:fmt"
import vk "vendor:vulkan"

create_sync_object :: proc(
	device: vk.Device,
	available_semphore: ^[2]vk.Semaphore,
	fin_semaphore: ^[]vk.Semaphore,
	fences: ^[2]vk.Fence,
	image_count: int,
) -> bool {
	fin_semaphore^ = make([]vk.Semaphore, image_count)
	semaphore_info := vk.SemaphoreCreateInfo {
		sType = .SEMAPHORE_CREATE_INFO,
	}
	fence_info := vk.FenceCreateInfo {
		sType = .FENCE_CREATE_INFO,
		flags = {.SIGNALED},
	}
	for i in 0 ..< image_count {
		result := vk.CreateSemaphore(device, &semaphore_info, nil, &fin_semaphore[i])
		if result != vk.Result.SUCCESS {
			fmt.eprintfln("Failed to create semaphore: %d", result)
			return false
		}
	}
	for i in 0 ..< 2 {
		result := vk.CreateSemaphore(device, &semaphore_info, nil, &available_semphore[i])
		if result != vk.Result.SUCCESS {
			fmt.eprintfln("Failed to create semaphore: %d", result)
			return false
		}
		result = vk.CreateFence(device, &fence_info, nil, &fences[i])
		if result != vk.Result.SUCCESS {
			fmt.eprintfln("Failed to create Fence: %d", result)
			return false
		}
	}
	fmt.println("Created Sync Objects: ")
	return true
}
