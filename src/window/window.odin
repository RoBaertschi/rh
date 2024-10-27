package window

import "core:strconv"
import "src:ui"
import gl "vendor:OpenGL"
import "vendor:sdl2"

Window :: struct {
	window_ptr: ^sdl2.Window,
	gl_ctx:     sdl2.GLContext,
	close:      bool,
	ui_ctx:     ui.Context,
}

WindowCreationError :: enum {
	InitFailed,
	CouldNotCreateWindow,
	CouldNotCreateOpenGLContext,
}

open_window :: proc() -> (window: Window, error: WindowCreationError) {
	error = nil
	if sdl2.Init({.VIDEO}) != 0 {
		return Window{}, .InitFailed
	}

	win := sdl2.CreateWindow(
		"rh",
		sdl2.WINDOWPOS_CENTERED,
		sdl2.WINDOWPOS_CENTERED,
		800,
		600,
		{.OPENGL, .RESIZABLE},
	)

	if win == nil {
		sdl2.Quit()
		return Window{}, .CouldNotCreateWindow
	}

	gl_ctx := sdl2.GL_CreateContext(win)

	if gl_ctx == nil {
		return Window{}, .CouldNotCreateOpenGLContext
	}

	sdl2.GL_MakeCurrent(win, gl_ctx)

	gl.load_up_to(4, 6, sdl2.gl_set_proc_address)

	window = Window{win, gl_ctx, false, ui.Context{}}

	window.ui_ctx = ui.create_context()
	return
}

handle_events :: proc(window: ^Window) {
	event: sdl2.Event = {}

	for sdl2.PollEvent(&event) {
		#partial switch event.type {
		case .QUIT:
			window.close = true
		}

		ui.handle_events(&window.ui_ctx, &event)
	}
}

should_close :: proc(window: ^Window) -> bool {
	return window.close
}

end_frame :: proc(window: ^Window) {
	ui.render(window.ui_ctx)

	sdl2.GL_SwapWindow(window.window_ptr)
}

close_window :: proc(window: Window) {
	ui.destroy(window.ui_ctx)

	sdl2.DestroyWindow(window.window_ptr)

	sdl2.Quit()
}
