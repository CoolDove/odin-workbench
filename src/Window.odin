package main

import "core:fmt"
import "core:os"
import "core:strings"
import sdl  "vendor:sdl2"
import gl   "vendor:OpenGL"


OPENGL_VERSION_MAJOR :: 3
OPENGL_VERSION_MINOR :: 1

Window :: struct {
	handler  : proc(wnd:^Window, event:sdl.Event),
	render   : proc(wnd:^Window),

	before_destroy : proc(wnd:^Window), // not necessary

	position, size : IVec2,

	name     : string,

	window_flags   : sdl.WindowFlags,
	renderer_flags : sdl.RendererFlags,

    window   : ^sdl.Window,
	renderer : ^sdl.Renderer,

	is_opengl_window : bool,
	gl_context : sdl.GLContext,
}

IVec2 :: [2]i32

Event :: struct {
	event : ^sdl.Event,
}

window_get_basic_template :: proc(name: string, size : IVec2 = IVec2{800, 600}, is_opengl_window : bool = true) -> Window {
	wnd : Window;
	wnd.name = name;
	wnd.handler = nil;
	wnd.render = nil;
	wnd.is_opengl_window = is_opengl_window;
	if is_opengl_window {
		wnd.window_flags |= {.OPENGL};
	} 
	wnd.position = sdl.WINDOWPOS_CENTERED;
	wnd.size = size;
    return wnd;
}

window_instantiate :: proc(using wnd:^Window) -> bool {
	window = sdl.CreateWindow(
	    strings.clone_to_cstring(name, context.temp_allocator),
	    position.x, position.y, size.x, size.y,
	    window_flags);

	if !window_is_good(wnd) {
        fmt.println("failed to instantiate window: ", name);
		return false;
	}

	if is_opengl_window {
		gl_context = sdl.GL_CreateContext(window);
		assert(gl_context != nil, fmt.tprintf("Failed to create GLContext for window: {}, because: {}.\n", name, sdl.GetError()));
		fmt.println("GLContext inited, GLContext: ", gl_context);

		sdl.GL_MakeCurrent(window, gl_context);
		gl.load_up_to(3, 1, sdl.gl_set_proc_address)
	} else {
		renderer = sdl.CreateRenderer(window, -1, renderer_flags);
		assert(renderer != nil, fmt.tprintf("Failed to create renderer for window: {}, because: {}.\n", name, sdl.GetError()));
	}

	return true;
}

window_destroy :: proc(using wnd:^Window) {
	if !window_is_good(wnd) do return

	if before_destroy!=nil do before_destroy(wnd);

	sdl.DestroyWindow(window);
	sdl.DestroyRenderer(renderer);
	window = nil;
    renderer = nil;
}

window_is_good :: proc(using wnd:^Window) -> bool {
	return window != nil;
}

window_get_id :: proc(using wnd:^Window) -> u32 {
	return sdl.GetWindowID(window);
}