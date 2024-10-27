package ui

import "core:c"
import "core:fmt"
import glm "core:math/linalg/glsl"
import "src:shaders"
import gl "vendor:OpenGL"
import "vendor:microui"
import "vendor:sdl2"

Vertex :: struct {
	position: [3]f32,
	color:    [4]f32,
	texCoord: [2]f32,
}

ViewProjectionMatrix :: matrix[4, 4]f32

Context :: struct {
	micro_context:                                    ^microui.Context,
	vertices:                                         [dynamic]Vertex,
	shader_program_id, vao_id, vbo_id, font_atlas_id: u32,
	view_projection_mat:                              ViewProjectionMatrix,
	vertex_index:                                     u32,
}

create_context :: proc(window: ^sdl2.Window) -> Context {
	ctx := new(microui.Context)

	microui.init(ctx)

	ctx.text_width = microui.default_atlas_text_width
	ctx.text_height = microui.default_atlas_text_height

	vertices := make([dynamic]Vertex)

	vbo_id, vao_id: u32
	gl.GenBuffers(1, &vbo_id)
	gl.GenVertexArrays(1, &vao_id)
	gl.BindVertexArray(vao_id)

	gl.VertexAttribPointer(0, 9, gl.FLOAT, false, 9 * size_of(f32), 0)
	gl.EnableVertexArrayAttrib(vao_id, 0)

	font_atlas_id, err := shaders.create_font_atlas()

	if err != nil {
		panic(fmt.tprintf("Could not create font atlas because %v", err))
	}

	w, h: i32
	sdl2.GetWindowSize(window, &w, &h)
	aspect_ratio := f32(w) / f32(h)

	projection_matrix := glm.mat4Ortho3d(-aspect_ratio, aspect_ratio, -1, 1, 0.001, 1000)
	view_mat := glm.mat4

	// @TODO: Add vao and shader program
	return Context {
		ctx,
		vertices,
		0,
		vbo_id,
		vao_id,
		font_atlas_id,
		glm.mat4Perspective(180, 1.3, 0.1, 100.0),
		0,
	}
}

handle_events :: proc(ctx: ^Context, event: ^sdl2.Event) {
	#partial switch event.type {
	case .MOUSEMOTION:
		microui.input_mouse_move(ctx.micro_context, event.motion.x, event.motion.y)
	case .MOUSEWHEEL:
		microui.input_scroll(ctx.micro_context, event.wheel.x, event.wheel.y)
	case .TEXTINPUT:
		microui.input_text(ctx.micro_context, string(cstring(&event.text.text[0])))
	case .MOUSEBUTTONUP, .MOUSEBUTTONDOWN:
		fn :=
			microui.input_mouse_down if event.type == .MOUSEBUTTONDOWN else microui.input_mouse_up
		switch event.button.button {
		case sdl2.BUTTON_LEFT:
			fn(ctx.micro_context, event.button.x, event.button.y, .LEFT)
		case sdl2.BUTTON_MIDDLE:
			fn(ctx.micro_context, event.button.x, event.button.y, .MIDDLE)
		case sdl2.BUTTON_RIGHT:
			fn(ctx.micro_context, event.button.x, event.button.y, .RIGHT)
		}
	case .KEYDOWN, .KEYUP:
		if event.type == .KEYUP && event.key.keysym.sym == .ESCAPE {
			sdl2.PushEvent(&sdl2.Event{type = .QUIT})
		}

		fn := microui.input_key_down if event.type == .KEYDOWN else microui.input_key_up

		#partial switch event.key.keysym.sym {
		case .LSHIFT:
			fn(ctx.micro_context, .SHIFT)
		case .RSHIFT:
			fn(ctx.micro_context, .SHIFT)
		case .LCTRL:
			fn(ctx.micro_context, .CTRL)
		case .RCTRL:
			fn(ctx.micro_context, .CTRL)
		case .LALT:
			fn(ctx.micro_context, .ALT)
		case .RALT:
			fn(ctx.micro_context, .ALT)
		case .RETURN:
			fn(ctx.micro_context, .RETURN)
		case .KP_ENTER:
			fn(ctx.micro_context, .RETURN)
		case .BACKSPACE:
			fn(ctx.micro_context, .BACKSPACE)

		case .LEFT:
			fn(ctx.micro_context, .LEFT)
		case .RIGHT:
			fn(ctx.micro_context, .RIGHT)
		case .HOME:
			fn(ctx.micro_context, .HOME)
		case .END:
			fn(ctx.micro_context, .END)
		case .A:
			fn(ctx.micro_context, .A)
		case .X:
			fn(ctx.micro_context, .X)
		case .C:
			fn(ctx.micro_context, .C)
		case .V:
			fn(ctx.micro_context, .V)
		}
	}
}

VboSize :: 1024

render :: proc(ctx: ^Context) {
	command: ^microui.Command
	for variant in microui.next_command_iterator(ctx.micro_context, &command) {
		switch cmd in variant {
		case ^microui.Command_Text:
		case ^microui.Command_Rect:
		case ^microui.Command_Icon:
		case ^microui.Command_Clip:
		case ^microui.Command_Jump:
			unreachable()
		}
	}

	ctx.vertex_index = 0
	render_vertices(ctx)
}

render_vertices :: proc(ctx: ^Context) {
	size_of_vertices := len(ctx.vertices) * size_of(Vertex)
	draw_call_count := (size_of_vertices / VboSize) + 1

	for i in 0 ..< draw_call_count {
		vertex := &ctx.vertices[i * VboSize]

		vertex_count: i32 = i32(
			(size_of_vertices % VboSize) / size_of(Vertex) if (i == draw_call_count - 1) else VboSize / (size_of(Vertex) * 6),
		)

		uniform_location := gl.GetUniformLocation(ctx.shader_program_id, "uViewProjectionMat")
		gl.UniformMatrix4fv(uniform_location, 1, gl.TRUE, &ctx.view_projection_mat[0, 0])

		gl.BindVertexArray(ctx.vao_id)
		gl.BindBuffer(gl.ARRAY_BUFFER, ctx.vbo_id)
		gl.BufferSubData(
			gl.ARRAY_BUFFER,
			0,
			size_of_vertices % VboSize if i == draw_call_count else VboSize,
			vertex,
		)
		gl.DrawArrays(gl.TRIANGLES, 0, vertex_count)
	}
}
draw_text :: proc(ctx: ^Context, text: string, position: [3]f32, color: [4]f32, size: f32) {
	position := position
	for i in 0 ..< len(text) {
		ch := text[i]
		packed_char := &shaders.PackedChars[ch - shaders.FirstChar]
		aligned_quad := &shaders.AlignedQuads[ch - shaders.FirstChar]

		pixel_scale :: 2

		glyph_size: [2]f32 = {
			f32((packed_char.x1 - packed_char.x0) * pixel_scale) * size,
			f32((packed_char.y1 - packed_char.y0) * pixel_scale) * size,
		}

		glyph_bounding_box_bottom_left: [2]f32 = {
			position.x + (packed_char.xoff * pixel_scale * size),
			position.y -
			(packed_char.yoff + f32(packed_char.y1) - f32(packed_char.y0)) * pixel_scale * size,
		}

		glyph_vertices: [4][2]f32 = {
			{
				glyph_bounding_box_bottom_left.x + glyph_size.x,
				glyph_bounding_box_bottom_left.y + glyph_size.y,
			}, // top right
			{glyph_bounding_box_bottom_left.x, glyph_bounding_box_bottom_left.y + glyph_size.y}, // top left
			{glyph_bounding_box_bottom_left.x, glyph_bounding_box_bottom_left.y}, // bottom left
			{glyph_bounding_box_bottom_left.x + glyph_size.x, glyph_bounding_box_bottom_left.y}, // bottom right
		}

		glyph_texture_coords: [4][2]f32 = {
			{aligned_quad.s1, aligned_quad.t0},
			{aligned_quad.s0, aligned_quad.t0},
			{aligned_quad.s0, aligned_quad.t1},
			{aligned_quad.s1, aligned_quad.t1},
		}

		order: [6]i32 = {0, 1, 2, 0, 2, 3}

		for i in 0 ..< 6 {
			append(
				&ctx.vertices,
				Vertex {
					position = {
						glyph_vertices[order[i]].x,
						glyph_vertices[order[i]].y,
						position.z,
					},
					color = color,
					texCoord = glyph_texture_coords[order[i]],
				},
			)
		}

		position.x += packed_char.xadvance * pixel_scale * size
	}
}

destroy :: proc(ctx: Context) {
	free(ctx.micro_context)
}
