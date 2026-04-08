package main

import "./internal/shader"
import "core:fmt"
import vk "vendor:vulkan"


handle_shader_reload :: proc(
	path: string,
	device: vk.Device,
	extent: vk.Extent2D,
	rp: vk.RenderPass,
	layout: ^vk.PipelineLayout,
	gp: ^vk.Pipeline,
) -> bool {
	vertex_spriv, vertex_ok := shader.compile_slang(path, .VERTEX, "vertexMain")
	fragment_spriv, fragment_ok := shader.compile_slang(path, .FRAGMENT, "fragmentMain")
	if !fragment_ok || !vertex_ok {
		fmt.eprintfln("Shader Compilation failed")
		return false
	}
	defer delete(vertex_spriv)
	defer delete(fragment_spriv)
	vk.DeviceWaitIdle(device)
	vk.DestroyPipeline(device, gp^, nil)
	vk.DestroyPipelineLayout(device, layout^, nil)
	return _create_graphics_pipeline(fragment_spriv, vertex_spriv, device, extent, rp, layout, gp)
}

