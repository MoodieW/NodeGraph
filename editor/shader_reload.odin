package main

import "./internal/shader"
import "core:fmt"
import "core:slice"
import vk "vendor:vulkan"
import renderer "vulkan"

import sp "deps/odin-slang/slang"

in_mem_handle_reload :: proc(path: string) -> Maybe([]byte) {
	global_session: ^sp.IGlobalSession

	ensure(sp.createGlobalSession(sp.API_VERSION, &global_session) == sp.OK)
	fmt.println(global_session)

	code, diagnostic: ^sp.IBlob
	r: sp.Result
	target_desc := sp.TargetDesc {
		structureSize = size_of(sp.TargetDesc),
		format        = .SPIRV,
		flags         = {.GENERATE_SPIRV_DIRECTLY},
		profile       = global_session->findProfile("sm_6_0"),
	}

	session_desc := sp.SessionDesc {
		structureSize = size_of(sp.SessionDesc),
		targets       = &target_desc,
		targetCount   = 1,
	}

	session: ^sp.ISession
	slang_check(global_session->createSession(session_desc, &session))
	defer session->release()

	blob: ^sp.IBlob
	module: ^sp.IModule = session->loadModule(
		"./deps/odin-slang/example/triangle.slang",
		&diagnostic,
	)
	if module == nil {
		fmt.println("shader compile error! ", diagnostic)
		return nil
	}
	defer module->release()
	diagnostics_check(diagnostic)
	name := module->getName()

	print_reflection(module)

	fragment_entry: ^sp.IEntryPoint
	r = module->findEntryPointByName("fragmentmain", &fragment_entry)
	slang_check(r)

	vertex_entry: ^sp.IEntryPoint
	r = module->findEntryPointByName("vertexmain", &vertex_entry)
	slang_check(r)

	if vertex_entry == nil {
		fmt.println("Expected Vertex Main entry poit")
		return nil
	}
	if fragment_entry == nil {
		fmt.println("Expected Fragment Entry point")
		return nil
	}

	components: [3]^sp.IComponentType = {module, vertex_entry, fragment_entry}
	linked_program: ^sp.IComponentType
	r = session->createCompositeComponentType(
		&components[0],
		len(components),
		&linked_program,
		&diagnostic,
	)
	diagnostics_check(diagnostic)
	slang_check(r)

	target_code: ^sp.IBlob
	r = linked_program->getTargetCode(0, &target_code, &diagnostic)
	diagnostics_check(diagnostic)
	slang_check(r)

	code_size := target_code->getBufferSize()
	source_code := slice.bytes_from_ptr(target_code->getBufferPointer(), auto_cast code_size)
	return source_code
}


print_reflection :: proc(module: ^sp.IModule) {
	module_reflection := module->getModuleReflection()
	child_count := sp.ReflectionDecl_getChildrenCount(module_reflection)
	fmt.printfln("Found %d declarations:", child_count)

	for i in 0 ..< child_count {
		decl := sp.ReflectionDecl_getChild(module_reflection, u32(i))
		name := sp.ReflectionDecl_getName(decl)
		parms := sp.ReflectionDecl_castToVariable

		func := sp.ReflectionDecl_castToFunction(decl)
		if func != nil {
			param_count := sp.ReflectionFunction_GetParameterCount(func)
			fmt.printfln("  - %s (function, %d params)", name, param_count)

			for j in 0 ..< param_count {
				param := sp.ReflectionFunction_GetParameter(func, u32(j))
				param_name := sp.ReflectionVariable_GetName(param)
				param_type := sp.ReflectionVariable_GetType(param)
				param_type_name := sp.ReflectionType_GetName(param_type)

				fmt.printfln("      - %s: %s", param_name, param_type_name)
			}
		}
	}
}

handle_shader_reload :: proc(
	path: string,
	device: vk.Device,
	extent: vk.Extent2D,
	rp: vk.RenderPass,
	layout: ^vk.PipelineLayout,
	gp: ^vk.Pipeline,
) -> bool {
	code := in_mem_handle_reload(path)
	if code == nil {
		return false
	}
	vk.DeviceWaitIdle(device)
	if gp^ != 0 {
		vk.DestroyPipeline(device, gp^, nil)
		vk.DestroyPipelineLayout(device, layout^, nil)
	}
	return renderer._create_graphics_pipeline(code.?, device, extent, rp, layout, gp)
}

slang_check :: #force_inline proc(#any_int result: int, loc := #caller_location) {
	result := sp.Result(result)
	if sp.FAILED(result) {
		code := sp.GET_RESULT_CODE(result)
		facility := sp.GET_RESULT_FACILITY(result)
		estr: string
		switch sp.Result(result) {
		case:
			estr = "Unknown error"
		case sp.E_NOT_IMPLEMENTED():
			estr = "E_NOT_IMPLEMENTED"
		case sp.E_NO_INTERFACE():
			estr = "E_NO_INTERFACE"
		case sp.E_ABORT():
			estr = "E_ABORT"
		case sp.E_INVALID_HANDLE():
			estr = "E_INVALID_HANDLE"
		case sp.E_INVALID_ARG():
			estr = "E_INVALID_ARG"
		case sp.E_OUT_OF_MEMORY():
			estr = "E_OUT_OF_MEMORY"
		case sp.E_BUFFER_TOO_SMALL():
			estr = "E_BUFFER_TOO_SMALL"
		case sp.E_UNINITIALIZED():
			estr = "E_UNINITIALIZED"
		case sp.E_PENDING():
			estr = "E_PENDING"
		case sp.E_CANNOT_OPEN():
			estr = "E_CANNOT_OPEN"
		case sp.E_NOT_FOUND():
			estr = "E_NOT_FOUND"
		case sp.E_INTERNAL_FAIL():
			estr = "E_INTERNAL_FAIL"
		case sp.E_NOT_AVAILABLE():
			estr = "E_NOT_AVAILABLE"
		case sp.E_TIME_OUT():
			estr = "E_TIME_OUT"
		}

		fmt.panicf("Failed with error: %v (%v) Facility: %v", estr, code, facility, loc = loc)
	}
}

diagnostics_check :: #force_inline proc(diagnostics: ^sp.IBlob, loc := #caller_location) {
	if diagnostics != nil {
		buffer := slice.bytes_from_ptr(
			diagnostics->getBufferPointer(),
			int(diagnostics->getBufferSize()),
		)
		assert(false, string(buffer), loc)
	}
}


// main :: proc() {
// 	in_mem_handle_reload("./assets/shaders/triangle.slang")
// }

