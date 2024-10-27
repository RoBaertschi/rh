package main

import "core:fmt"
import "src:window"
import gl "vendor:OpenGL"
import mu "vendor:microui"

main :: proc() {
	fmt.println("Hello World!")

	win, err := window.open_window()
	if err != nil {
		fmt.printfln("could not create window because %v")
		return
	}
	defer window.close_window(win)

	for !window.should_close(&win) {
		window.handle_events(&win)

		mu.begin(win.ui_ctx.micro_context)

		using win.ui_ctx

		if mu.window(micro_context, "rh", {}) {
		}
		mu.end(micro_context)

		gl.ClearColor(1, 1, 1, 0)
		gl.Clear(gl.COLOR_BUFFER_BIT)


		window.end_frame(&win)
	}

}
