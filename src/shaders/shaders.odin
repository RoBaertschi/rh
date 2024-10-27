package shaders

import "core:c"
import "core:fmt"
import "core:log"
import gl "vendor:OpenGL"
import "vendor:sdl2"
import tt "vendor:stb/truetype"

font := #load("NotoSans-VariableFont.ttf")

text_vert := #load("text.vert", cstring)
text_frag := #load("text.frag", cstring)

compile_shaders :: proc(vert: ^cstring, frag: ^cstring) -> u32 {
	vertex_id, frag_id: u32

	vertex_id = gl.CreateShader(gl.VERTEX_SHADER)
	gl.ShaderSource(vertex_id, 1, vert, nil)
	gl.CompileShader(vertex_id)

	frag_id = gl.CreateShader(gl.FRAGMENT_SHADER)
	gl.ShaderSource(frag_id, 1, frag, nil)
	gl.CompileShader(frag_id)

	success: i32
	info_log: [512]u8

	gl.GetShaderiv(vertex_id, gl.COMPILE_STATUS, &success)
	if (success == 0) {
		gl.GetShaderInfoLog(vertex_id, 512, nil, raw_data(info_log[:]))
		log.errorf("Could not compile vertex shader %v", info_log)
	}

	gl.GetShaderiv(frag_id, gl.COMPILE_STATUS, &success)
	if (success == 0) {
		gl.GetShaderInfoLog(frag_id, 512, nil, raw_data(info_log[:]))
		log.errorf("Could not compile fragment shader %v", info_log)
	}

	shdProgId := gl.CreateProgram()
	gl.AttachShader(shdProgId, vertex_id)
	gl.AttachShader(shdProgId, frag_id)

	gl.LinkProgram(shdProgId)

	gl.DeleteShader(vertex_id)
	gl.DeleteShader(frag_id)

	gl.GetProgramiv(frag_id, gl.LINK_STATUS, &success)
	if (success == 0) {
		gl.GetProgramInfoLog(frag_id, 512, nil, raw_data(info_log[:]))
		log.errorf("Could not link shader program %v", info_log)
	}

	return shdProgId
}

// Space
FirstChar :: 32
// To ~
ToInclude :: 95
FontSize :: 64.0

FontAtlasWidth :: 1024
FontAtlasHeight :: 1024
FontAtlasBitmap :: distinct [FontAtlasWidth * FontAtlasHeight]u8

PackedChars: [ToInclude]tt.packedchar = {}
AlignedQuads: [ToInclude]tt.aligned_quad = {}

CreateFontAtlasError :: enum {
	NoValidFontData,
}

create_font_atlas :: proc() -> (texId: u32, err: CreateFontAtlasError) {
	err = nil
	fonts := tt.GetNumberOfFonts(raw_data(font[:]))

	if (fonts == -1) {
		err = .NoValidFontData
		return
	}

	log.infof("Found %i fonts", fonts)

	fontAtlasBitmap := new(FontAtlasBitmap)

	ctx: tt.pack_context = {}

	tt.PackBegin(&ctx, raw_data(fontAtlasBitmap[:]), FontAtlasWidth, FontAtlasHeight, 0, 1, nil)
	tt.PackFontRange(&ctx, raw_data(font[:]), 0, FontSize, FirstChar, ToInclude, &PackedChars[0])
	tt.PackEnd(&ctx)

	for i in 0 ..< ToInclude {
		unusedY: f32 = 0
		unusedX: f32 = 0

		tt.GetPackedQuad(
			&PackedChars[0],
			FontAtlasWidth,
			FontAtlasHeight,
			c.int(i),
			&unusedX,
			&unusedY,
			&AlignedQuads[i],
			false,
		)
	}

	gl.GenTextures(1, &texId)
	gl.BindTexture(gl.TEXTURE_2D, texId)

	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		gl.R8,
		FontAtlasWidth,
		FontAtlasHeight,
		0,
		gl.RED,
		gl.UNSIGNED_BYTE,
		fontAtlasBitmap,
	)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)

	free(fontAtlasBitmap)

	return
}
