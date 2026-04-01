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
}


_linux_create :: proc() -> (Watcher, bool) {
	fd, err := linux.inotify_init()
	if err != os.ERROR_NONE {
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
	if os.is_dir(path) {
		mask = {.CREATE, .DELETE}
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
	return false
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
	if result != os.ERROR_NONE {
		fmt.eprintfln("Failed to remove wach for: %s", path)
		return false
	}
	delete(w.watch_descriptor[wd_to_remove])
	delete_key(&w.watch_descriptor, wd_to_remove)
	return true
}

_linux_destroy_watch :: proc(w: ^Watcher) {
	for wd, path in w.watch_descriptor {
		delete(path)
		delete_key(&w.watch_descriptor, wd)
	}
	delete(w.watch_descriptor)
	linux.close(w.fd)

}

