#ifndef INCLUDE_VERTEX_UTIL
#define INCLUDE_VERTEX_UTIL


#include "settings.glsl"
#include "random.glsl"


layout(std430, binding = 0) buffer Counters {
    uint quadCount;
    uint vertexCount;

    uint rebuildFlag;
    uint vertexHash[64];
    uint vertexHashPrev[64];
    vec3 buildCameraPosition;

    uint textureHashes[1024];
    ivec2 texSize[1024];
} TriCounter;

layout(std430, binding = 11) buffer EntitySlots { uint entitySlots[]; } Slots;


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
    bool isEntity = uv.x < 0.0;
    vec2 packedUv = isEntity ? uv - entityTexcoordOffset : uv;
    uint packedU = uint(round(clamp(packedUv.x, 0.0, 1.0) * 32767.0));
    if (isEntity) packedU |= 0x8000u;
    uint packedV = uint(round(clamp(packedUv.y, 0.0, 1.0) * 65535.0));

    return uvec2(
        packedU | (packedV << 16u),
        packUnorm4x8(glColor)
    );
}

void unpackAttributes(in uvec2 data, out vec2 uv, out vec4 glColor) {
    bool isEntity = (data.x & 0x8000u) != 0u;
    uv.x = float(data.x & 0x7fffu) / 32767.0;
    uv.y = float(data.x >> 16u) / 65535.0;
    if (isEntity) uv += entityTexcoordOffset;
    glColor = unpackUnorm4x8(data.y);
}


uint hashVertex(in vec3 p) {
    ivec3 i = ivec3(p * 0.01);
    return hash3(i);
}

uint getSlot(in vec3 p) {
    ivec3 signRegion = ivec3(
        p.x < 0.0? 1 : 0,
        p.y < 0.0? 1 : 0,
        p.z < 0.0? 1 : 0
    );

    ivec3 cell = ivec3(floor(abs(p)));
    ivec3 region = cell & 1;

    region = (region + signRegion * 2) & 3;

    return region.x + region.y * 4 + region.z * 16;
}


#endif