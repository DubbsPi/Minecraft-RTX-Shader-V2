#version 330 compatibility


uniform sampler2D gtexture;

in vec2 texcoord;
in vec4 glcolor;
flat in float vIsWater;

layout(location = 0) out vec4 color;


void main() {
    color = texture(gtexture, texcoord) * glcolor;
    if (color.a < 0.1 || vIsWater > 0.5) discard;
}