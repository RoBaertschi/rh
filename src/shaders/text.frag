// vim:ft=glsl:

#version 330 core

in vec4 color;
in vec2 texCoord;

uniform sampler2D uFontAtlasTexture;

out vec4 fragColor;

void main() {
    fragColor = vec4(texture(uFontAtlasTexture, texCoord).r) * color;
}
