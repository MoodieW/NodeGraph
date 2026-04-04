#+build linux
package watcher

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:sys/linux"

Watcher :: struct {
	fd:               linux.Fd,
	watch_descriptor: map[linux.Wd]string,
	buffer:           [4096]byte,
	// add to file extension filter
}


_linux_create :: proc() -> (Watcher, bool) {
	// TODO add file filters
	fd, err := linux.inotify_init1({.NONBLOCK})
	if err != .NONE {
		fmt.eprintfln("Could not build Notify: %d", err)
		return {}, false
	}
	watcher := Watcher {
		fd               = fd,
		watch_descriptor = make(map[linux.Wd]string),
	}
	return watcher, true
}

_linux_add_watch :: proc(path: string, w: ^Watcher) -> bool {
	mask: linux.Inotify_Event_Mask
	if !os.exists(path) {
		fmt.eprintfln("Given path does not exists: %s", path)
		return false
	}
	if os.is_dir(path) {
		mask = {.CREATE, .DELETE, .MODIFY, .CLOSE_WRITE}
	} else {
		mask = {.MODIFY, .CLOSE_WRITE, .DELETE}
	}
	cpath := strings.clone_to_cstring(path)
	defer delete(cpath)
	wd, err := linux.inotify_add_watch(w.fd, cpath, mask)
	if err != os.ERROR_NONE {
		fmt.eprintfln("Could not create watch: %d", err)
		return false
	}
	w.watch_descriptor[wd] = strings.clone(path)
	return true
}


_linux_remove_watch :: proc(path: string, w: ^Watcher) -> bool {
	wd_to_remove: linux.Wd
	found := false

	for wd, watched_path in w.watch_descriptor {
		if watched_path == path {
			wd_to_remove = wd
			found = true
			break
		}
	}
	if !found {
		fmt.eprintln("Path not found in watcher")
		return false
	}
	result := linux.inotify_rm_watch(w.fd, wd_to_remove)
	if result != .NONE {
		fmt.eprintfln("Failed to remove wach for: %s", path)
		return false
	}
	delete(w.watch_descriptor[wd_to_remove])
	delete_key(&w.watch_descriptor, wd_to_remove)
	return true
}

_linux_destroy_watch :: proc(w: ^Watcher) {
	for wd, path in w.watch_descriptor {
		linux.inotify_rm_watch(w.fd, wd)
		delete(path)
	}
	delete(w.watch_descriptor)
	linux.close(w.fd)

}

_linux_poll_events :: proc(
	w: ^Watcher,
	allocator := context.temp_allocator,
) -> (
	[dynamic]File_Event,
	bool,
) {
	file_events := make([dynamic]File_Event, allocator)
	n, err := linux.read(w.fd, w.buffer[:])
	if err == .EAGAIN do return file_events, false
	if err != .NONE {
		fmt.eprintfln("Failed to read Events: %v", err)
		return file_events, false
	}
	offset := 0
	// get the event log
	for offset < n {
		event := (^linux.Inotify_Event)(raw_data(w.buffer[offset:]))
		event_size := size_of(linux.Inotify_Event) + int(event.len)

		if linux.Inotify_Event_Bits.IGNORED in event.mask {
			if path, ok := w.watch_descriptor[event.wd]; ok {
				delete(path)
				delete_key(&w.watch_descriptor, event.wd)
			}
			offset += event_size
			continue
		}

		name := ""
		if event.len > 0 {
			name_bytes := w.buffer[offset + size_of(linux.Inotify_Event):][:event.len]
			name = strings.clone_from_cstring(cstring(raw_data(name_bytes)), allocator)
		}
		// read each item
		if path, ok := w.watch_descriptor[event.wd]; ok {
			event_type: File_Event_Type
			if .CREATE in event.mask {
				event_type = .Created
			}
			if .DELETE in event.mask {
				event_type = .Deleted
			}
			if .MODIFY in event.mask || .CLOSE_WRITE in event.mask {
				event_type = .Modified
			}
			append(&file_events, File_Event{path, event_type})
			fmt.printfln("%s/%s mask=%v\n", path, name, event.mask)
		}
		offset += event_size
	}
	return file_events, true
}

