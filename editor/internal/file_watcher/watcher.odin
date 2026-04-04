package watcher


import "core:fmt"
import "core:os"
import "core:path/filepath"


File_Event_Type :: enum {
	Modified,
	Created,
	Deleted,
}

File_Event :: struct {
	path: string,
	type: File_Event_Type,
}

create :: proc() -> (Watcher, bool) {
	when ODIN_OS == .Linux do return _linux_create()
}

add_watch :: proc(path: string, w: ^Watcher) -> bool {
	when ODIN_OS == .Linux do return _linux_add_watch(path, w)
}

destroy_watch :: proc(w: ^Watcher) {
	when ODIN_OS == .Linux do _linux_destroy_watch(w)
}

remove_watch :: proc(path: string, w: ^Watcher) -> bool {
	when ODIN_OS == .Linux do return _linux_remove_watch(path, w)
}

poll_events :: proc(
	w: ^Watcher,
	allactor := context.temp_allocator,
) -> (
	[dynamic]File_Event,
	bool,
) {
	when ODIN_OS == .Linux do return _linux_poll_events(w, allactor)
}


main :: proc() {
	w, ok := create()
	if !ok {
		fmt.eprintfln("Could not create watcher")
	}
	defer destroy_watch(&w)
	test_path := filepath.join({#file, ".."})
	fmt.printfln("%s", test_path)
	add_watch(test_path, &w)
	for {
		poll_events(&w)
	}
}

