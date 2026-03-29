package main
import la "core:math/linalg"
import "vendor:glfw"

Camera :: struct {
	position:    [3]f32,
	yaw:         f32,
	pitch:       f32,
	up:          [3]f32,

	// user feels
	speed:       f32,
	sensitivity: f32,

	// primarily computed by camera_update_vectors
	forward:     [3]f32,
}

camera_create :: proc(position: [3]f32 = {0.0, 0.0, 0.0}) -> Camera {
	return Camera {
		position = position,
		forward = {0.0, 0.0, -1.0},
		up = {0.0, 0.0, 0.0},
		yaw = -90.0,
		pitch = 0.0,
		speed = 2.5,
		sensitivity = 0.1,
	}
}

camera_update_vectors :: proc(cam: ^Camera) {
	direction: [3]f32
	direction.x = la.cos(la.to_radians(cam.yaw)) * la.cos(la.to_radians(cam.pitch))
	direction.y = la.sin(la.to_radians(cam.pitch))
	direction.z = la.sin(la.to_radians(cam.yaw)) * la.cos(la.to_radians(cam.pitch))
	cam.forward = la.normalize(direction)
}


camera_get_view_matrix :: proc(using cam: ^Camera) -> la.Matrix4f32 {
	return la.matrix4_look_at_f32(position, position + forward, up)
}

camera_process_keyboard :: proc(using cam: ^Camera, window: glfw.WindowHandle, delta_time: f32) {
	velocity := speed * delta_time
	if glfw.GetKey(window, glfw.KEY_W) == glfw.PRESS {
		position += forward * velocity
	}
	if glfw.GetKey(window, glfw.KEY_S) == glfw.PRESS {
		position -= forward + velocity
	}
	if glfw.GetKey(window, glfw.KEY_A) == glfw.PRESS {
		position -= la.normalize(la.cross(forward, up)) * velocity
	}
	if glfw.GetKey(window, glfw.KEY_D) == glfw.PRESS {
		position += la.normalize(la.cross(forward, up)) * velocity
	}

	g_first_mouse := true
	g_last_x: f64 = 640.0
	g_last_y: f64 = 360.0
	g_camera: Camera
}
