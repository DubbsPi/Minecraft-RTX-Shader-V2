#ifndef INCLUDE_VERTEX_UTIL
#define INCLUDE_VERTEX_UTIL


#include "settings.glsl"
#include "random.glsl"


layout(std430, binding = 0) buffer Counters {
    uint quadCount;
    uint vertexCount;
    uint dynamicQuadCount;
    uint dynamicVertexCount;

    uint rebuildFlag;
    uint captureFlag;
    uint vertexCountPrev;
    uint frameVertexCount;
    vec3 buildCameraPosition;

    uint textureHashes[1024];
    ivec2 texSize[1024];
} TriCounter;

layout(std430, binding = 11) buffer EntitySlots {uint entitySlots[];} Slots;


const uint TRIS_PER_ROW = uint(MAX_VERTS_SQRT / 2);
const float POS_BIAS = float(1 << 20);
const float INV_POS_BIAS = 1.0 / POS_BIAS;


// More documentation!!
// KIND 0  double triangle test
// KIND 1  planar parallelogram
// KIND 2+ aa rectangle: 2 + 2 * axis + (normal negative? 1 : 0)

#define QUAD_KIND_TRIS 0u
#define QUAD_KIND_PARALLEL 1u
#define QUAD_KIND_AXIS_BASE 2u


// Packing functions
uvec2 packPos(in vec3 p, in uint flagBit) {
    const float invAct = 1.0 / MAX_DIST;
    const float posScale = POS_BIAS * invAct;
 
    ivec3 q = ivec3(round(p * posScale) + POS_BIAS);
    uvec3 u = uvec3(clamp(q, 0, (1 << 21) - 1));
 
    return uvec2(
        u.x | (u.y << 21),
        (u.y >> 11) | (u.z << 10) | ((flagBit & 1u) << 31)
    );
}

vec3 unpackPos(in uvec2 d) {
    uint x = d.x & 0x1FFFFFu;
    uint y = (d.x >> 21) | ((d.y & 0x3FFu) << 11);
    uint z = (d.y >> 10) & 0x1FFFFFu;
 
    float invScale = MAX_DIST * INV_POS_BIAS;
 
    return (vec3(ivec3(x, y, z)) - POS_BIAS) * invScale;
}


// Flag functions
uvec2 setPosFlagBit(in uvec2 d, in uint bit) {
    d.y = (d.y & 0x7FFFFFFFu) | ((bit & 1u) << 31);
    return d;
}

uint getPosFlagBit(in uvec2 d) { return d.y >> 31; }
 
uint gatherQuadFlags(in uvec2 d0, in uvec2 d1, in uvec2 d2, in uvec2 d3) {
    return getPosFlagBit(d0)
        | (getPosFlagBit(d1) << 1)
        | (getPosFlagBit(d2) << 2)
        | (getPosFlagBit(d3) << 3);
}


bool quadIsOpaque(in uint flags) { return (flags & 1u) != 0u; }
uint quadKind(in uint flags) { return flags >> 1; }
bool kindIsAxis(in uint kind) { return kind >= QUAD_KIND_AXIS_BASE; }
uint kindAxis(in uint kind) { return (kind - QUAD_KIND_AXIS_BASE) >> 1; }
bool kindNegative(in uint kind) { return ((kind - QUAD_KIND_AXIS_BASE) & 1u) != 0u; }


uint classifyQuadKind(in vec3 v0, in vec3 v1, in vec3 v2, in vec3 v3) {
    const float eps = 2.0 * MAX_DIST * INV_POS_BIAS;
 
    vec3 e1 = v1 - v0;
    vec3 e2 = v3 - v0;
 
    if (any(greaterThan(abs(v0 + v2 - v1 - v3), vec3(eps)))) return QUAD_KIND_TRIS;
 
    vec3 n = cross(e1, e2);
    if (dot(n, n) < 1e-10) return QUAD_KIND_TRIS;
 
    for (int a = 0; a < 3; ++a) {
        if (abs(e1[a]) < eps && abs(e2[a]) < eps) {
            int b = (a + 1) % 3;
            int c = (a + 2) % 3;
            bool rect = (abs(e1[b]) < eps && abs(e2[c]) < eps)
                     || (abs(e1[c]) < eps && abs(e2[b]) < eps);
            if (rect) return QUAD_KIND_AXIS_BASE + 2u * uint(a) + (n[a] < 0.0? 1u : 0u);
        }
    }
    return QUAD_KIND_PARALLEL;
}


// Attribute functions
uvec2 packAttributes(in vec2 uv, in vec4 glColor, in vec2 light) {
    uint packedU = uint(round(clamp(uv.x, 0.0, 1.0) * 32767.0));
    uint packedV = uint(round(clamp(uv.y, 0.0, 1.0) * 65535.0));
 
    uint bl = uint(round(clamp(light.x, 0.0, 1.0) * 15.0));
    uint sl = uint(round(clamp(light.y, 0.0, 1.0) * 15.0));
    uint lightByte = bl | (sl << 4);
 
    uint rgb = packUnorm4x8(vec4(glColor.rgb, 0));
 
    return uvec2(packedU | (packedV << 16u), rgb | (lightByte << 24));
}

void unpackAttributes(in uvec2 data, out vec2 uv, out vec4 glColor) {
    uv.x = float(data.x & 0x7fffu) / 32767.0;
    uv.y = float(data.x >> 16u) / 65535.0;
    glColor = unpackUnorm4x8(data.y | 0xFF000000u);
}

vec2 unpackLight(in uvec2 data) {
    uint lb = data.y >> 24;
    return vec2(float(lb & 15u), float(lb >> 4)) / 15.0;
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