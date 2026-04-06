package main

import "core:fmt"

import "./internal/shader"


handle_shader_reload :: proc(path: string) -> bool {
	vertex_spriv, vertex_ok := shader.compile_slang(path, .VERTEX, "vertexMain")
	fragment_spriv, fragment_ok := shader.compile_slang(path, .FRAGMENT, "fragmentMain")
	if !fragment_ok || !vertex_ok {
		fmt.eprintfln("Shader Compilation failed")
		return false
	}
	defer delete(vertex_spriv)
	defer delete(fragment_spriv)
	return true
}

