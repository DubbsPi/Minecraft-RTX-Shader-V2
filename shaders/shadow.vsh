#version 430 compatibility

#include "lib/settings.glsl"
#include "lib/shadow_util.glsl"
#include "lib/vertex_util.glsl"


uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelViewInverse;


in vec3 mc_Entity;

out VertexData {
    vec2 texcoord;
    vec4 glcolor;
    vec4 shadowClipPos;
    float vIsWater;
} vOut;


void main() {
    vOut.texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vOut.glcolor = gl_Color;
    vOut.shadowClipPos = ftransform();
    gl_Position = vOut.shadowClipPos;
    gl_Position.xyz = distortShadowClipPos(gl_Position.xyz);
    
    vOut.vIsWater = (mc_Entity.x == 10001.0)? 1.0 : 0.0;
}