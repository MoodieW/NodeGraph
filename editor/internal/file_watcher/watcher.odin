package watcher


import "core:fmt"
import "core:os"
import "core:path/filepath"


create :: proc(path: string) -> (Watcher, bool) {
	when ODIN_OS == .Linux {
		return _linux_create(path)
	}
}

find_slang_files :: proc(dir: string, slang_files: ^[dynamic]os.File_Info) {

	fd, err := os.open(dir)
	if err != os.ERROR_NONE {
		fmt.eprintln("Failed to open dir:", err)
		return
	}
	defer os.close(fd)

	infos, read_err := os.read_dir(fd, -1) // -1 = all entries
	if read_err != os.ERROR_NONE {
		fmt.eprintln("Failed to read dir:", read_err)
		return
	}
	defer os.file_info_slice_delete(infos)

	for info in infos {
		if info.is_dir {
			continue
		}
		if filepath.ext(info.name) == ".slang" && info.size > 0 {
			append(slang_files, info)
		}
	}
}


main :: proc() {
	shaders := filepath.join({#file, "..", "..", "..", "shaders"})
	slang_files: [dynamic]os.File_Info
	defer delete(slang_files)
	find_slang_files(shaders, &slang_files)

	for i in slang_files {
		fmt.printfln("%d", i)
	}
}

