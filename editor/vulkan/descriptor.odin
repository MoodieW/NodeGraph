package renderer

import vk "vendor:vulkan"


create_texture_descriptor_set_layout :: proc(
	device: vk.Device,
	layout: ^vk.DescriptorSetLayout,
) -> bool {
	binding := vk.DescriptorSetLayoutBinding {
		binding         = 0,
		descriptorType  = .COMBINED_IMAGE_SAMPLER,
		descriptorCount = 1,
		stageFlags      = {.FRAGMENT},
	}

	info := vk.DescriptorSetLayoutCreateInfo {
		sType        = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = 1,
		pBindings    = &binding,
	}

	if vk.CreateDescriptorSetLayout(device, &info, nil, layout) != vk.Result.SUCCESS {
		return false
	}
	return true
}

create_texture_descriptor_pool :: proc(device: vk.Device, pool: ^vk.DescriptorPool) -> bool {
	descript_count := vk.DescriptorPoolSize {
		type            = .COMBINED_IMAGE_SAMPLER,
		descriptorCount = 1,
	}

	pool_info := vk.DescriptorPoolCreateInfo {
		sType         = .DESCRIPTOR_POOL_CREATE_INFO,
		maxSets       = 1,
		poolSizeCount = 1,
		pPoolSizes    = &descript_count,
	}
	if vk.CreateDescriptorPool(device, &pool_info, nil, pool) != vk.Result.SUCCESS {
		return false
	}
	return true
}

allocate_texture_descripotr_set :: proc(
	device: vk.Device,
	pool: vk.DescriptorPool,
	layout: ^vk.DescriptorSetLayout,
	set: ^vk.DescriptorSet,
) -> bool {
	alloc_in := vk.DescriptorSetAllocateInfo {
		sType              = .DESCRIPTOR_SET_ALLOCATE_INFO,
		descriptorPool     = pool,
		descriptorSetCount = 1,
		pSetLayouts        = layout,
	}

	if vk.AllocateDescriptorSets(device, &alloc_in, set) != vk.Result.SUCCESS {
		return false
	}
	return true
}

update_texture_descriptor_set :: proc(
	device: vk.Device,
	set: vk.DescriptorSet,
	image_view: vk.ImageView,
	sampler: vk.Sampler,
) {
	image_info := vk.DescriptorImageInfo {
		sampler     = sampler,
		imageView   = image_view,
		imageLayout = .SHADER_READ_ONLY_OPTIMAL,
	}

	write := vk.WriteDescriptorSet {
		sType           = .WRITE_DESCRIPTOR_SET,
		dstSet          = set,
		dstBinding      = 0,
		dstArrayElement = 0,
		descriptorType  = .COMBINED_IMAGE_SAMPLER,
		descriptorCount = 1,
		pImageInfo      = &image_info,
	}
	vk.UpdateDescriptorSets(device, 1, &write, 0, nil)
}

remove_texture_descriptors :: proc(device: vk.Device, rp: ^RenderPipeline) {

	vk.DestroyDescriptorPool(device, rp.texture_descriptor_pool, nil)
	vk.DestroyDescriptorSetLayout(device, rp.texture_descriptor_set_layout, nil)
}

