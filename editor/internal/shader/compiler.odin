package shader

import "core:fmt"
import "core:image/bmp"
import "core:os"
import "core:os/os2"
import "core:path/filepath"
import "core:strings"
import "core:time"

// Compile a Slang shader to SPIR-V
// slang_path: Path to .slang file (e.g., "shaders/triangle.slang")
// stage: Shader stage ("vertex", "fragment", "compute", etc.)
// entry: Entry point function name (e.g., "vertexMain", "fragmentMain")
// Returns: SPIR-V bytecode and success boolean
Stages :: enum {
	VERTEX,
	FRAGMENT,
	COMPUTE,
}

stage_map := [Stages]string {
	.VERTEX   = "vertex",
	.FRAGMENT = "fragment",
	.COMPUTE  = "compute",
}

compile_slang :: proc(
	slang_path: string,
	stage: Stages,
	entry: string,
) -> (
	spirv: []byte,
	ok: bool,
) {
	file_dir := filepath.dir(slang_path)
	file_name := filepath.stem(slang_path)
	compiled_stem := fmt.tprintf("%s_%s.spv", file_name, stage_map[stage])
	compile_file_path := filepath.join({file_dir, compiled_stem})
	desc := os2.Process_Desc {
		command = {
			"nix",
			"develop",
			"-c",
			"slangc",
			slang_path,
			"-target",
			"spirv",
			"-entry",
			entry,
			"-stage",
			stage_map[stage],
			"-o",
			compile_file_path,
		},
	}
	defer os.remove(compile_file_path)
	state, stdout, stderr, err := os2.process_exec(desc, context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Could not compile shader: %v", err)
		fmt.eprintfln("State:  %v", state)
		fmt.eprintfln("Stderr: %s", string(stderr))
		return nil, false
	}
	return load_spirv(compile_file_path)
}

// Load pre-compiled SPIR-V from disk
// path: Path to .spv file
// Returns: SPIR-V bytecode and success boolean
load_spirv :: proc(path: string) -> (spirv: []byte, ok: bool) {
	spirv, ok = os.read_entire_file(path)
	if !ok {
		fmt.eprintfln("Failed to read slang file: %s", path)
		return nil, ok
	}
	return spirv, ok
}

main :: proc() {
	spriv, ok := compile_slang(
		"/home/moodie/dev/vfx_tools/editor/shaders/triangle.slang",
		.VERTEX,
		"vertexMain",
	)
	if !ok {
		fmt.eprintln("Word")
	}
	fmt.println(len(spriv))
	defer delete(spriv)
}

