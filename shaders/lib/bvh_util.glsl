#ifndef INCLUDE_BVH_UTIL
#define INCLUDE_BVH_UTIL


#include "settings.glsl"
#include "vertex_util.glsl"


#ifndef DONT_INLCUDE_READONLY_VERTS
    layout(rg32ui, binding = 0) uniform readonly restrict uimage2D vertexPositions;
#endif

#ifdef BVH_TRACE_ONLY
    layout(rgba32ui, binding = 2) uniform restrict readonly uimage2D bvhNodes;
#elif defined BVH_BUILD_ONLY
    layout(rgba32ui, binding = 2) uniform restrict writeonly uimage2D bvhNodes;
#else
    layout(rgba32ui, binding = 2) uniform uimage2D bvhNodes;
#endif


const uint LEAF_BIT = 0x80000000u;
const uint EMPTY_REF = 0xFFFFFFFFu;


uniform int frameCounter;
#define currentBuildStep (frameCounter & 7)


ivec2 nodeTexel(in uint n) {
    return ivec2(n % TRIS_PER_ROW, n / TRIS_PER_ROW) * 2;
}

float pow2f(in int e) {
    return uintBitsToFloat(uint(e + 127) << 23);
}


uint expandBits(in uint v) {
    v = (v * 0x00010001u) & 0xFF0000FFu;
    v = (v * 0x00000101u) & 0x0F00F00Fu;
    v = (v * 0x00000011u) & 0xC30C30C3u;
    v = (v * 0x00000005u) & 0x49249249u;
    return v;
}

uint morton3D(in vec3 n) {
    uvec3 q = uvec3(clamp(n * 1024.0, 0.0, 1023.0));
    return (expandBits(q.x) << 2) | (expandBits(q.y) << 1) | expandBits(q.z);
}


#ifndef DONT_INLCUDE_READONLY_VERTS
void getQuadPos(in uint idx, out vec3 v[4]) {
    ivec2 base = ivec2(idx % TRIS_PER_ROW, idx / TRIS_PER_ROW) * 2;
    v[0] = unpackPos(imageLoad(vertexPositions, base).xy);
    v[1] = unpackPos(imageLoad(vertexPositions, base + ivec2(1, 0)).xy);
    v[2] = unpackPos(imageLoad(vertexPositions, base + ivec2(0, 1)).xy);
    v[3] = unpackPos(imageLoad(vertexPositions, base + ivec2(1, 1)).xy);
}


void quadBounds(uint q, out vec3 mn, out vec3 mx) {
    vec3 v[4];
    getQuadPos(q, v);
    mn = min(min(v[0], v[1]), min(v[2], v[3])) - 0.002;
    mx = max(max(v[0], v[1]), max(v[2], v[3])) + 0.002;
}
#endif


#endif