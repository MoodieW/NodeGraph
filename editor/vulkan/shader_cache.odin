package renderer

import vk "vendor:vulkan"

Shader :: struct {
	layout:   vk.PipelineLayout,
	pipeline: vk.Pipeline,
}

Shader_Cache :: struct {
	shaders: map[string]^Shader,
}

create_shader_cache :: proc(sc: ^Shader_Cache) {
	sc.shaders = make(map[string]^Shader)
}

remove_shader :: proc(device: vk.Device, sc: ^Shader_Cache, key: string) {
	vk.DestroyPipeline(device, sc.shaders[key].pipeline, nil)
	vk.DestroyPipelineLayout(device, sc.shaders[key].layout, nil)
	free(&sc.shaders[key])
	delete_key(&sc.shaders, key)
}

remove_shader_cache :: proc(device: vk.Device, sc: ^Shader_Cache) {
	for _, shader in sc.shaders {
		vk.DestroyPipeline(device, shader.pipeline, nil)
		vk.DestroyPipelineLayout(device, shader.layout, nil)
		free(shader)
	}
	delete(sc.shaders)
}

