#ifndef INCLUDE_VERTEX_UTIL
#define INCLUDE_VERTEX_UTIL


#include "settings.glsl"


layout(std430, binding = 0) buffer Counters {uint triCount;} TriCounter;

layout(rg32ui, binding = 0) uniform uimage2D vertexPositions;


const uint TRIS_PER_ROW = uint(MAX_VERTS_SQRT / 2);


uvec2 packPos(in vec3 p) {
    ivec3 q = ivec3(round(p * MAX_DIST)) + POS_BIAS;
    uvec3 u = uvec3(clamp(q, 0, (1 << 21) - 1));
    return uvec2(u.x | (u.y << 21), (u.y >> 11) | (u.z << 10) | 0x80000000u);
}

vec3 unpackPos(in uvec2 d) {
    uint x =  d.x & 0x1FFFFFu;
    uint y = (d.x >> 21) | ((d.y & 0x3FFu) << 11);
    uint z = (d.y >> 10) & 0x1FFFFFu;
    const float invScale = 1.0 / MAX_DIST;
    return (vec3(ivec3(x, y, z)) - float(POS_BIAS)) * invScale;
}


void storeTriangle(in vec3 p[3], in vec2 uv[3], in vec4 col[3], uint primID, bool exactTri) {
    for (int i = 0; i < 3; ++i) if (any(greaterThan(abs(p[i]), vec3(MAX_DIST)))) return;

    vec3 p3; vec2 uv3; vec4 col3;
    if (exactTri) {
        p3 = vec3(999999); uv3 = vec2(0); col3 = vec4(0);
    } else {
        if ((primID & 1u) == 1u) return;
        p3 = p[0] + p[2] - p[1];
        uv3 = uv[0] + uv[2] - uv[1];
        col3 = clamp(col[0] + col[2] - col[1], 0.0, 1.0);
    }

    if (any(greaterThan(abs(p3), vec3(MAX_DIST)))) return;

    uint idx = atomicAdd(TriCounter.triCount, 1u);
    if (idx >= uint(MAX_TRIS)) return;

    ivec2 base = ivec2(idx % TRIS_PER_ROW, idx / TRIS_PER_ROW) * 2;
    imageStore(vertexPositions, base, uvec4(packPos(p[0]), 0u, 0u));
    imageStore(vertexPositions, base + ivec2(1, 0), uvec4(packPos(p[1]), 0u, 0u));
    imageStore(vertexPositions, base + ivec2(0, 1), uvec4(packPos(p[2]), 0u, 0u));
    imageStore(vertexPositions, base + ivec2(1, 1), uvec4(packPos(p3), 0u, 0u));
}


void getQuadPos(in uint idx, out vec3 v[4]) {
    ivec2 base = ivec2(idx % TRIS_PER_ROW, idx / TRIS_PER_ROW) * 2;
    v[0] = unpackPos(imageLoad(vertexPositions, base).xy);
    v[1] = unpackPos(imageLoad(vertexPositions, base + ivec2(1, 0)).xy);
    v[2] = unpackPos(imageLoad(vertexPositions, base + ivec2(0, 1)).xy);
    v[3] = unpackPos(imageLoad(vertexPositions, base + ivec2(1, 1)).xy);
}


#endif