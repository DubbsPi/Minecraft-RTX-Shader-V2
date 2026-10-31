#version 430 compatibility

#include "lib/settings.glsl"
#include "lib/vertex_util.glsl"


layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;


uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelViewInverse;


in VertexData {
    vec2 texcoord;
    vec4 glcolor;
    vec4 shadowClipPos;
    float vIsWater;
} gIn[3];

out vec2 texcoord;
out vec4 glcolor;
flat out float vIsWater;


void main() {
    for (int i = 0; i < 3; ++i) {
        gl_Position = gl_in[i].gl_Position;

        texcoord = gIn[i].texcoord;
        glcolor = gIn[i].glcolor;
        vIsWater = gIn[i].vIsWater;

        EmitVertex();
    }
    
    #ifdef RTX_FEATURES
    vec3 feetPos[3];
    for (int i = 0; i < 3; ++i) {
        vec3 shadowViewPos = (shadowProjectionInverse * gIn[i].shadowClipPos).xyz;
        feetPos[i] = (shadowModelViewInverse * vec4(shadowViewPos, 1)).xyz;
    }
    vec2 triUV[3];
    for (int i = 0; i < 3; ++i) {
        triUV[i] = gIn[i].texcoord;
    }
    vec4 color[3];
    for (int i = 0; i < 3; ++i) {
        color[i] = gIn[i].glcolor;
    }

    storeTriangle(feetPos, triUV, color, uint(gl_PrimitiveIDIn), gIn[0].vIsWater > 0.5);
    #endif

    EndPrimitive();
}
