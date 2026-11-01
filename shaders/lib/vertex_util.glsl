#ifndef INCLUDE_VERTEX_UTIL
#define INCLUDE_VERTEX_UTIL


#include "settings.glsl"


layout(std430, binding = 0) buffer Counters {uint quadCount; uint vertexCount;} TriCounter;

layout(rg32ui, binding = 0) uniform uimage2D vertexPositions;
layout(rg32ui, binding = 1) uniform uimage2D vertexAttributes;


const uint TRIS_PER_ROW = uint(MAX_VERTS_SQRT / 2);
const int POS_BIAS = 1 << 20;


uvec2 packPos(in vec3 p) {
    float posScale = float(POS_BIAS) / ACTUAL_MAX_DIST;

    ivec3 q = ivec3(round(p * posScale)) + POS_BIAS;
    uvec3 u = uvec3(clamp(q, 0, (1 << 21) - 1));

    return uvec2(u.x | (u.y << 21), (u.y >> 11) | (u.z << 10));
}

vec3 unpackPos(in uvec2 d) {
    uint x = d.x & 0x1FFFFFu;
    uint y = (d.x >> 21) | ((d.y & 0x3FFu) << 11);
    uint z = d.y >> 10;

    float invScale = ACTUAL_MAX_DIST / float(POS_BIAS);

    return (vec3(ivec3(x, y, z)) - float(POS_BIAS)) * invScale;
}


uvec2 packAttributes(in vec2 uv, in vec4 glColor) {
    return uvec2(
        packUnorm2x16(uv),
        packUnorm4x8(glColor)
    );
}

void unpackAttributes(in uvec2 data, out vec2 uv, out vec4 glColor) {
    uv = unpackUnorm2x16(data.x);
    glColor = unpackUnorm4x8(data.y);
}


void getQuadPos(in uint idx, out vec3 v[4]) {
    ivec2 base = ivec2(idx % TRIS_PER_ROW, idx / TRIS_PER_ROW) * 2;
    v[0] = unpackPos(imageLoad(vertexPositions, base).xy);
    v[1] = unpackPos(imageLoad(vertexPositions, base + ivec2(1, 0)).xy);
    v[2] = unpackPos(imageLoad(vertexPositions, base + ivec2(0, 1)).xy);
    v[3] = unpackPos(imageLoad(vertexPositions, base + ivec2(1, 1)).xy);
}

void getTriAttributes(in uint idx, in bool first, out vec2 uv[3], out vec4 glColor[3]) {
    ivec2 base = ivec2(idx % TRIS_PER_ROW, idx / TRIS_PER_ROW) * 2;

    if (first) {
        unpackAttributes(imageLoad(vertexAttributes, base).xy, uv[0], glColor[0]);
        unpackAttributes(imageLoad(vertexAttributes, base + ivec2(1, 0)).xy, uv[1], glColor[1]);
        unpackAttributes(imageLoad(vertexAttributes, base + ivec2(0, 1)).xy, uv[2], glColor[2]);
    } else {
        unpackAttributes(imageLoad(vertexAttributes, base + ivec2(0, 1)).xy, uv[0], glColor[0]);
        unpackAttributes(imageLoad(vertexAttributes, base + ivec2(1, 1)).xy, uv[1], glColor[1]);
        unpackAttributes(imageLoad(vertexAttributes, base).xy, uv[2], glColor[2]);
    }
}


#endif