package main

import "core:fmt"
import "core:os"
import "core:strings"

import sdl  "vendor:sdl2"
import gl   "vendor:OpenGL"

Application :: struct {
    windows : map[u32]^Window,
}

app : ^Application;

app_init :: proc() {
	app = new(Application);

	sdl.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, OPENGL_VERSION_MAJOR);
	sdl.GL_SetAttribute(.CONTEXT_MINOR_VERSION, OPENGL_VERSION_MINOR);

	if sdl.Init({.VIDEO, .EVENTS}) != 0 {
	    fmt.println("failed to init: ", sdl.GetErrorString());
		return
	}

}
app_release :: proc() {
    free(app);
}

app_run :: proc() {
	using app;

	main_window := create_main_window();
	helper_window := create_helper_window();

	register_window(&main_window);
	register_window(&helper_window);

    evt := sdl.Event{};

	for len(windows) > 0 {
		if sdl.PollEvent(&evt) {
			if evt.window.type == .WINDOWEVENT {
				wid := evt.window.windowID;
				if wnd, has := windows[wid]; has && wnd.handler != nil {
					wnd.handler(wnd, evt);
				}
			}
		} 
		{
			// rendering
			for id, wnd in &windows {
				if wnd.render != nil {
					if wnd.is_opengl_window {
						assert(sdl.GL_MakeCurrent(wnd.window, wnd.gl_context) == 0, 
							fmt.tprintf("Failed to switch gl context, because: {}\n", sdl.GetError()));
					}
					if wnd.render != nil do wnd.render(wnd);
				}
			}
		}
	}

	sdl.Quit();
}

register_window :: proc(wnd:^Window) {
	using app;
	window_instantiate(wnd);

	id := window_get_id(wnd);
	has := id in windows;
	if !has do windows[id] = wnd;
	else do fmt.println("window has been registered");

	wnd.before_destroy = proc(wnd:^Window) {
		remove_id := window_get_id(wnd);
		remove_window(remove_id);
	};
}

remove_window :: proc(id:u32) {
	using app;
	if id in windows {
        delete_key(&windows, id);
		fmt.println("window: ", id, " removed, now ", len(windows), " windows left.");
	}
}
