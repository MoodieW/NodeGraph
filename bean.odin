package vfx_tools

import "core:fmt"
import "core:mem"

main :: proc() {
	fmt.println("Context Allocator: ", context.allocator)
}
