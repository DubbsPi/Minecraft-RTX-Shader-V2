#version 430 compatibility

#include "lib/shadow_util.glsl"


in vec3 mc_Entity;

out vec2 texcoord;
out vec4 glcolor;
flat out float vIsWater;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;
    gl_Position = ftransform();
    gl_Position.xyz = distortShadowClipPos(gl_Position.xyz);

    vIsWater = (mc_Entity.x == 10001.0)? 1.0 : 0.0;
}