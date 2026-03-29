package main

import "core:fmt"
import "core:mem"

Particle :: struct {
	position: [3]f32,
	velocity: [3]f32,
}

particle_system_create :: proc(count: int) -> []Particle {
	particles := make([]Particle, count)
	for i in 0 ..< count {
		particles[i].position = {0, 0, 0}
		particles[i].velocity = {1, 1, 1}
	}
	return particles
}


main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer {
		if len(track.allocation_map) > 0 {
			fmt.println("Meomery leaks detected!")
			for _, entry in track.allocation_map {
				fmt.printfln("Leaked %d bytes", entry.size)
			}
		}
		mem.tracking_allocator_destroy(&track)
	}
	particles := particle_system_create(100)
	defer delete(particles)
}
