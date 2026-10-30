#include "settings.glsl"
#include "common.glsl"


layout(std430, binding = 0) buffer PosBuf {uvec2 pos[MAX_VERTS];} VertexPositions;
layout(std430, binding = 1) buffer AttrBuf {uvec2 attr[MAX_VERTS];} VertexAttributes;
layout(std430, binding = 2) buffer Counters {uint vertexCount; uint badQuads;} VertexCounters;


uniform int frameCounter;


uvec2 packPos(vec3 p) {
    ivec3 q = ivec3(round(p * MAX_DIST)) + POS_BIAS;
    uvec3 u = uvec3(clamp(q, 0, (1 << 21) - 1));
    return uvec2(u.x | (u.y << 21), (u.y >> 11) | (u.z << 10));
}

vec3 unpackPos(uvec2 d) {
    uint x =  d.x & 0x1FFFFFu;
    uint y = (d.x >> 21) | ((d.y & 0x3FFu) << 11);
    uint z = (d.y >> 10) & 0x1FFFFFu;
    const float invScale = 1.0 / MAX_DIST;
    return (vec3(ivec3(x, y, z)) - float(POS_BIAS)) * invScale;
}


void emitVertex(in vec3 feetPos, in vec2 uv, in vec4 col) {
    if (any(greaterThan(abs(feetPos), vec3(MAX_DIST)))) return;

    uint i = atomicAdd(VertexCounters.vertexCount, 1u);
    if (i >= MAX_VERTS) return;

    VertexPositions.pos[i] = packPos(feetPos);
    VertexAttributes.attr[i] = uvec2(
        packUnorm2x16(uv),
        packUnorm4x8(col)
    );
}
