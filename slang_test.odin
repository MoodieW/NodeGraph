package main

import "core:fmt"
import "core:os"
import "vendor:stb/easy_font"

// Import slang bindings
import sp "editor/deps/odin-slang/slang"

// main :: proc() {
// 	g_session: ^sp.IGlobalSession
// 	slang_check(sp.createGlobalSession(sp.API_VERSION, &g_session) == sp.OK)
// 	fmt.printfln("Slang session: %v", g_session)
// 	defer g_session->release()

// 	session: ^sp.ISession
// 	desc := sp.SessionDesc{}
// 	slang_check(g_session->createSession(desc, &session))
// 	// Load math lib
// 	defer session->release()
// 	math_lib_source, ok := os.read_entire_file("editor/assets/shaders/math_lib.slang")
// 	if !ok {
// 		fmt.eprintln("Failed to read math_lib.slang")
// 		return
// 	}
// 	defer delete(math_lib_source)

// 	math_module := session->loadModuleFromSourceString(
// 		"math_lib",
// 		"math_lib.slang",
// 		cstring(raw_data(math_lib_source)),
// 		nil,
// 	)
// 	if math_module == nil {
// 		fmt.eprintln("Failed to load math_lib module")
// 		return
// 	}
// 	math_module->link()

// 	fmt.println("Math lib loaded successfully!")

// 	// Get module reflection
// 	module_reflection := math_module->getModuleReflection()
// 	child_count := sp.ReflectionDecl_getChildrenCount(module_reflection)
// 	fmt.printfln("Found %d declarations:", child_count)

// 	for i in 0 ..< child_count {
// 		decl := sp.ReflectionDecl_getChild(module_reflection, u32(i))
// 		name := sp.ReflectionDecl_getName(decl)
// 		parms := sp.ReflectionDecl_castToVariable

// 		func := sp.ReflectionDecl_castToFunction(decl)
// 		if func != nil {
// 			param_count := sp.ReflectionFunction_GetParameterCount(func)
// 			fmt.printfln("  - %s (function, %d params)", name, param_count)

// 			for j in 0 ..< param_count {
// 				param := sp.ReflectionFunction_GetParameter(func, u32(j))
// 				param_name := sp.ReflectionVariable_GetName(param)
// 				param_type := sp.ReflectionVariable_GetType(param)
// 				param_type_name := sp.ReflectionType_GetName(param_type)

// 				fmt.printfln("      - %s: %s", param_name, param_type_name)
// 			}
// 		}
// 	}

// }

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
} // TODO: Copy the slang_check helper from example.odin
// slang_check :: #force_inline proc(#any_int result: int, loc := #caller_location) {
//     ...
// }

