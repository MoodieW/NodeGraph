package main

import "base:runtime"
import "core:fmt"
import "core:time"
import "vendor:glfw"
import vk "vendor:vulkan"

import watcher "internal/file_watcher"
import renderer "vulkan"

App_State :: struct {
	window:           glfw.WindowHandle,
	vk_core:          Vulkan_Core,
	swapchain:        renderer.Swap_Chain,
	renderpipeline:   renderer.RenderPipeline,
	shader_cache:     renderer.Shader_Cache,
	debug_messenger:  vk.DebugUtilsMessengerEXT,
	surface:          vk.SurfaceKHR,
	file_watcher:     watcher.Watcher,
	shader_poll_time: time.Time,
}

Vulkan_Core :: struct {
	instance:        vk.Instance,
	phyiscal_device: vk.PhysicalDevice,
	logical_device:  vk.Device,
	graphics_queue:  vk.Queue,
	present_queue:   vk.Queue,
}

main :: proc() {
	app_state: App_State
	if !glfw.Init() {
		fmt.eprintfln("Failed to init GLFW")
		return
	}
	defer glfw.Terminate()
	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
	glfw.WindowHint(glfw.RESIZABLE, glfw.FALSE)
	app_state.window = glfw.CreateWindow(1280, 720, "Vulkan 3d Editor", nil, nil)

	if app_state.window == nil {
		fmt.eprintfln("Failed to create GLFW window")
		return
	}
	if !renderer.init_vulkan(
		app_state.window,
		&app_state.vk_core.instance,
		&app_state.debug_messenger,
		&app_state.surface,
		&app_state.vk_core.phyiscal_device,
		&app_state.vk_core.logical_device,
		&app_state.vk_core.graphics_queue,
		&app_state.vk_core.present_queue,
		&app_state.swapchain,
		&app_state.renderpipeline,
		&app_state.shader_cache,
	) {
		fmt.eprintln("Vulkan failed to load")
		return
	}
	defer renderer.deinit_vulkan(
		app_state.vk_core.instance,
		app_state.debug_messenger,
		app_state.surface,
		app_state.vk_core.logical_device,
		&app_state.swapchain,
		&app_state.renderpipeline,
		&app_state.shader_cache,
	)
	shader_watcher, ok := watcher.create()
	if !ok {
		fmt.eprintfln("Could not create watch")
		return
	}
	defer watcher.destroy_watch(&app_state.file_watcher)
	app_state.file_watcher = shader_watcher
	if !watcher.add_watch("./assets/shaders", &app_state.file_watcher) {
		fmt.eprintfln("Could not add shader module to watch")
		return
	}
	quad_ok := renderer.create_quad_geo(
		app_state.vk_core.logical_device,
		app_state.vk_core.phyiscal_device,
		&app_state.renderpipeline.geo_mem,
	)
	if !quad_ok {
		fmt.eprintln("Failed to create quad")
		return
	}
	tri: Maybe(vk.Pipeline) = nil
	default_shader_path := "./assets/shaders/triangle.slang"
	app_state.shader_cache.shaders[default_shader_path] = new(renderer.Shader)
	if handle_shader_reload(
		default_shader_path,
		app_state.vk_core.logical_device,
		app_state.swapchain.extent,
		app_state.renderpipeline.render_pass,
		&app_state.shader_cache.shaders[default_shader_path].layout,
		&app_state.shader_cache.shaders[default_shader_path].pipeline,
	) {
		tri = app_state.shader_cache.shaders[default_shader_path].pipeline
	}
	app_state.shader_poll_time = time.now()
	last := time.now()
	space_was_down := false
	for !glfw.WindowShouldClose(app_state.window) {
		free_all(context.temp_allocator)

		glfw.PollEvents()
		space_is_down := glfw.GetKey(app_state.window, glfw.KEY_SPACE) == glfw.PRESS
		if space_is_down && !space_was_down {
			if !app_state.renderpipeline.offscreen_target_valid {
				target, ok := renderer.create_offscreen_target(
					app_state.vk_core.logical_device,
					app_state.vk_core.phyiscal_device,
					app_state.renderpipeline.offscreen_render_pass,
					app_state.swapchain.extent,
					app_state.swapchain.format,
				)
				if ok {
					fmt.println("Offscreen Toggle on")
					app_state.renderpipeline.offscreen_target_valid = !app_state.renderpipeline.offscreen_target_valid
					app_state.renderpipeline.offscrent_target = target
					app_state.renderpipeline.offscreen_dirty = true
				}
			} else {
				fmt.println("Offscreen Toggle off")
				app_state.renderpipeline.offscreen_target_valid = !app_state.renderpipeline.offscreen_target_valid
				renderer.remove_off_screen_target(
					app_state.vk_core.logical_device,
					&app_state.renderpipeline.offscrent_target,
				)
			}
		}
		space_was_down = space_is_down

		// 	fmt.println("after poll")

		now := time.now()
		frame_time := time.diff(last, now)
		fps := 1.0 / time.duration_seconds(frame_time)
		last = now
		glfw.SetWindowTitle(app_state.window, fmt.ctprintf("Vulkand Editor | FPS: %.0f", fps))
		if time.diff(app_state.shader_poll_time, now) > 500 * time.Millisecond {
			app_state.shader_poll_time = now
			events, event_ok := watcher.poll_events(
				&app_state.file_watcher,
				".slang",
				context.temp_allocator,
			)
			for event in events {
				fmt.println(event)
				if event.type == .Modified {
					shader, exists := app_state.shader_cache.shaders[event.path]
					if !exists {
						app_state.shader_cache.shaders[event.path] = new(renderer.Shader)
					}
					fmt.println("reloading shader")
					handle_shader_reload(
						event.path,
						app_state.vk_core.logical_device,
						app_state.swapchain.extent,
						app_state.renderpipeline.render_pass,
						&app_state.shader_cache.shaders[event.path].layout,
						&app_state.shader_cache.shaders[event.path].pipeline,
					)
					tri = app_state.shader_cache.shaders[event.path].pipeline
				}
			}
		}
		renderer.draw_frame(
			app_state.vk_core.logical_device,
			app_state.vk_core.graphics_queue,
			app_state.vk_core.present_queue,
			&app_state.renderpipeline,
			&app_state.swapchain,
			tri,
		)
	}
	vk.DeviceWaitIdle(app_state.vk_core.logical_device)
}

