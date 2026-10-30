#version 430 compatibility

#include "lib/settings.glsl"
#include "lib/shadow_util.glsl"
#include "lib/vertex_util.glsl"


uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelViewInverse;


in vec3 mc_Entity;

out vec2 texcoord;
out vec4 glcolor;
flat out float vIsWater;


void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;
    vec4 shadowClipPos = ftransform();
    gl_Position = shadowClipPos;
    gl_Position.xyz = distortShadowClipPos(gl_Position.xyz);

    vIsWater = (mc_Entity.x == 10001.0)? 1.0 : 0.0;

    #ifdef RTX_FEATURES
        vec3 shadowViewPos = (shadowProjectionInverse * shadowClipPos).xyz;
        vec3 feetPos = (shadowModelViewInverse * vec4(shadowViewPos, 1)).xyz;
        emitVertex(feetPos, texcoord, glcolor);
    #endif
}