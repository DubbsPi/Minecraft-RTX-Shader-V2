#ifndef INCLUDE_RTX
#define INCLUDE_RTX


#define BVH_TRACE_ONLY
#include "bvh_util.glsl"
#include "vertex_util.glsl"
#include "settings.glsl"


uniform sampler2D colortex8;  // texture atlas
uniform sampler2D entityAtlasSampler;  // self explanitory
uniform isampler2D triangleTestSampler;  // self explanitory


layout(rg32ui, binding = 1) uniform readonly restrict uimage2D vertexAttributes;
layout(r32i, binding = 4) uniform iimage2D triangleTests;
layout(std430, binding = 8) restrict readonly buffer PackedNodeParents { uint packedNodeParent[]; };


uniform float viewHeight;
uniform float viewWidth;


#define MAX_BRUTE_FORCE_TESTS 4096


vec4 u8x4(uint w) {
    return vec4(uvec4(w, w >> 8u, w >> 16u, w >> 24u) & 255u);
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


ivec2 slotToTexel(in uint slot) {
    const int slotsPerRow = ENTITY_ATLAS_SIZE / ENTITY_ATLAS_SLOT_SIZE;
    ivec2 slotCoord = ivec2(int(slot) % slotsPerRow, int(slot) / slotsPerRow);
    return slotCoord * ENTITY_ATLAS_SLOT_SIZE;
}

vec3 sampleTracedTexture(in vec2 hitTexcoord, in uint triIdx) {
    vec3 c;
    if (hitTexcoord.x < 0.0) {
        hitTexcoord -= entityTexcoordOffset;

        uint slot = Slots.entitySlots[triIdx];
        ivec2 texSize = TriCounter.texSize[slot];
        ivec2 pos = slotToTexel(slot);
        ivec2 texel = clamp(ivec2(hitTexcoord * texSize), ivec2(0), texSize - 1);
        
        c = texelFetch(entityAtlasSampler, pos + texel, 0).rgb;
    } else
        c = texture(colortex8, hitTexcoord).rgb;
    
    c = pow(max(c, vec3(0)), vec3(2.2));
    return c;
}

float sampleTracedAlpha(in vec2 hitTexcoord, in uint triIdx) {
    float c;
    if (hitTexcoord.x < 0.0) {
        hitTexcoord -= entityTexcoordOffset;

        uint slot = Slots.entitySlots[triIdx];
        ivec2 texSize = TriCounter.texSize[slot];
        ivec2 pos = slotToTexel(slot);
        ivec2 texel = clamp(ivec2(hitTexcoord * texSize), ivec2(0), texSize - 1);
        
        c = texelFetch(entityAtlasSampler, pos + texel, 0).a;
    } else
        c = textureLod(colortex8, hitTexcoord, 0.0).a;
    return c;
}

vec4 sampleTracedAll(in vec2 hitTexcoord, in uint triIdx) {
    vec4 c;
    if (hitTexcoord.x < 0.0) {
        hitTexcoord -= entityTexcoordOffset;

        uint slot = Slots.entitySlots[triIdx];
        ivec2 texSize = TriCounter.texSize[slot];
        ivec2 pos = slotToTexel(slot);
        ivec2 texel = clamp(ivec2(hitTexcoord * texSize), ivec2(0), texSize - 1);
        
        c = texelFetch(entityAtlasSampler, pos + texel, 0);
    } else
        c = textureLod(colortex8, hitTexcoord, 0.0);
    return c;
}


bool intersectTriangle(in vec3 ro, in vec3 rd, in vec3 a, in vec3 b, in vec3 c, out float t, out vec2 uv) {
    vec3 e1 = b - a;
    vec3 e2 = c - a;

    vec3 p = cross(rd, e2);
    float det = dot(e1, p);

    if (abs(det) < 1e-8) return false;
    
    float invDet = 1.0 / det;
    vec3 s = ro - a;
    float u = dot(s, p) * invDet;

    if (u < 0.0 || u > 1.0) return false;

    vec3 q = cross(s, e1);
    float v = dot(rd, q) * invDet;

    if (v < 0.0 || u + v > 1.0) return false;

    t = dot(e2, q) * invDet;
    uv = vec2(u, v);
    return t > 0.0;
}


bool bruteForceTrace(in vec3 ro, in vec3 rd,
    out float closestT, out vec2 uv,
    out uint hitIdx, out bool first
 ) {
    closestT = 1e20;
    bool hit = false;
    uint qc = TriCounter.quadCount;

    for (uint i = 0; i < MAX_BRUTE_FORCE_TESTS; ++i) {
        if (i >= qc) break;

        vec3 v[4];
        getQuadPos(i, v);

        float t1; vec2 uv1;
        bool hit1 = intersectTriangle(ro, rd, v[0], v[1], v[2], t1, uv1);

        if (hit1 && t1 < closestT) {
            hit = true;
            closestT = t1;
            uv = uv1;
            hitIdx = i;
            first = true;
            continue;
        }

        float t2; vec2 uv2;
        bool hit2 = intersectTriangle(ro, rd, v[2], v[3], v[0], t2, uv2);

        if (hit2 && t2 < closestT) {
            hit = true;
            closestT = t2;
            uv = uv2;
            hitIdx = i;
            first = false;
        }
    }

    return hit;
}


bool rayAnyHit(in uint quadIdx, in bool first, in vec2 bary) {
    vec2 uv[3]; vec4 glColor[3];
    getTriAttributes(quadIdx, first, uv, glColor);

    float w0 = 1.0 - bary.x - bary.y;
    vec2 tc = uv[0] * w0 + uv[1] * bary.x + uv[2] * bary.y;

    return sampleTracedAlpha(tc, quadIdx) >= RT_ALPHA_CUTOFF;
}


bool traceNode(in uint node, in uint startLane, in vec3 ro, in vec3 rd, in vec3 invD,
    inout float closestT, inout vec2 uv, inout uint hitIdx, inout bool first, inout bool found,
    out uint child, out uint childLane) {
    ivec2 b = nodeTexel(node);
    uvec4 t0 = imageLoad(bvhNodes, b);
    uvec4 refs = imageLoad(bvhNodes, b + ivec2(1, 0));
    uvec4 t2 = imageLoad(bvhNodes, b + ivec2(0, 1));
    uvec4 t3 = imageLoad(bvhNodes, b + ivec2(1, 1));

    vec3 p = uintBitsToFloat(t0.xyz);
    vec3 s = vec3(
        uintBitsToFloat((t0.w & 255u) << 23),
        uintBitsToFloat(((t0.w >> 8u) & 255u) << 23),
        uintBitsToFloat(((t0.w >> 16u) & 255u) << 23)
    );
    vec3 A = (p - ro) * invD;
    vec3 B = s * invD;

    vec4 x0 = A.x + u8x4(t2.x) * B.x,  x1 = A.x + u8x4(t2.w) * B.x;
    vec4 y0 = A.y + u8x4(t2.y) * B.y,  y1 = A.y + u8x4(t3.x) * B.y;
    vec4 z0 = A.z + u8x4(t2.z) * B.z,  z1 = A.z + u8x4(t3.y) * B.z;

    vec4 tN = max(max(min(x0, x1), min(y0, y1)), max(min(z0, z1), vec4(0.0)));
    vec4 tF = min(min(max(x0, x1), max(y0, y1)), max(z0, z1));

    for (uint lane = startLane; lane < 4u; lane++) {
        uint ref = refs[lane];
        if (ref == EMPTY_REF) continue;

        float farT = min(tF[lane], closestT);
        if (tN[lane] > farT + 1e-5 * (1.0 + abs(farT))) continue;

        if ((ref & LEAF_BIT) == 0u) {
            child = ref;
            childLane = lane;
            return true;
        }

        uint q = ref & ~LEAF_BIT;
        vec3 v[4];
        getQuadPos(q, v);
        float t; vec2 hitUV;

        if (intersectTriangle(ro, rd, v[0], v[1], v[2], t, hitUV)
            && t < closestT && rayAnyHit(q, true, hitUV)) {
            closestT = t; uv = hitUV; hitIdx = q; first = true; found = true;
        }

        if (intersectTriangle(ro, rd, v[2], v[3], v[0], t, hitUV)
            && t < closestT && rayAnyHit(q, false, hitUV)) {
            closestT = t; uv = hitUV; hitIdx = q; first = false; found = true;
        }
    }

    return false;
}


bool traceNodeAnyHit(in uint node, in uint startLane, in vec3 ro, in vec3 rd, in vec3 invD,
    in float tMax, out uint child, out uint childLane, out bool found) {
    ivec2 b = nodeTexel(node);
    uvec4 t0 = imageLoad(bvhNodes, b);
    uvec4 refs = imageLoad(bvhNodes, b + ivec2(1, 0));
    uvec4 t2 = imageLoad(bvhNodes, b + ivec2(0, 1));
    uvec4 t3 = imageLoad(bvhNodes, b + ivec2(1, 1));

    vec3 p = uintBitsToFloat(t0.xyz);
    vec3 s = vec3(
        uintBitsToFloat((t0.w & 255u) << 23),
        uintBitsToFloat(((t0.w >> 8u) & 255u) << 23),
        uintBitsToFloat(((t0.w >> 16u) & 255u) << 23)
    );
    vec3 A = (p - ro) * invD;
    vec3 B = s * invD;

    vec4 x0 = A.x + u8x4(t2.x) * B.x,  x1 = A.x + u8x4(t2.w) * B.x;
    vec4 y0 = A.y + u8x4(t2.y) * B.y,  y1 = A.y + u8x4(t3.x) * B.y;
    vec4 z0 = A.z + u8x4(t2.z) * B.z,  z1 = A.z + u8x4(t3.y) * B.z;

    vec4 tN = max(max(min(x0, x1), min(y0, y1)), max(min(z0, z1), vec4(0.0)));
    vec4 tF = min(min(max(x0, x1), max(y0, y1)), max(z0, z1));

    found = false;
    for (uint lane = startLane; lane < 4u; lane++) {
        uint ref = refs[lane];
        if (ref == EMPTY_REF) continue;

        float farT = min(tF[lane], tMax);
        if (tN[lane] > farT + 1e-5 * (1.0 + abs(farT))) continue;

        if ((ref & LEAF_BIT) == 0u) {
            child = ref;
            childLane = lane;
            return true;
        }

        uint q = ref & ~LEAF_BIT;
        vec3 v[4];
        getQuadPos(q, v);
        float t; vec2 hitUV;

        if (intersectTriangle(ro, rd, v[0], v[1], v[2], t, hitUV)
            && t < tMax && rayAnyHit(q, true, hitUV)) {
            found = true;
            return false;
        }

        if (intersectTriangle(ro, rd, v[2], v[3], v[0], t, hitUV)
            && t < tMax && rayAnyHit(q, false, hitUV)) {
            found = true;
            return false;
        }
    }

    return false;
}


float rayExitDist(in vec3 ro, in vec3 rd, in float maxDist) {
    vec3 safeRd = mix(rd, vec3(1e-8), lessThan(abs(rd), vec3(1e-8)));
    vec3 bound  = mix(vec3(-maxDist), vec3(maxDist), greaterThan(safeRd, vec3(0.0)));
    vec3 t = (bound - ro) / safeRd;
    return min(min(t.x, t.y), t.z);
}


bool bvhTrace(in vec3 ro, in vec3 rd, in float tMax, out float closestT, out vec2 uv, out uint hitIdx, out bool first) {
    closestT = tMax; uv = vec2(0); hitIdx = 0u; first = true;
    uint n = TriCounter.quadCount;
    if (n < 2u) return false;
    
    vec3 raySign = mix(vec3(-1), vec3(1.0), greaterThanEqual(rd, vec3(0.0)));
    vec3 invD = raySign / max(abs(rd), vec3(1e-8));

    uint node = 0u;
    uint startLane = 0u;
    bool found = false;

    for (;;) {
        uint child; uint childLane;
        if (!traceNode(node, startLane, ro, rd, invD, closestT, uv, hitIdx, first, found, child, childLane)) {
            if (node == 0u) return found;
            
            uint parentLane = packedNodeParent[node];
            node = parentLane >> 2u;
            startLane = (parentLane & 3u) + 1u;
            continue;
        }

        startLane = childLane + 1u;
        node = child;
        startLane = 0u;
    }
}


bool bvhAnyHit(in vec3 ro, in vec3 rd, in float tMax) {
    uint n = TriCounter.quadCount;
    if (n == 0u) return false;

    if (n == 1u) {
        vec3 v[4];
        getQuadPos(0u, v);
        float t; vec2 hitUV;
        if (intersectTriangle(ro, rd, v[0], v[1], v[2], t, hitUV)
            && t < tMax && rayAnyHit(0u, true, hitUV)) return true;
        return intersectTriangle(ro, rd, v[2], v[3], v[0], t, hitUV)
            && t < tMax && rayAnyHit(0u, false, hitUV);
    }

    vec3 raySign = mix(vec3(-1), vec3(1.0), greaterThanEqual(rd, vec3(0.0)));
    vec3 invD = raySign / max(abs(rd), vec3(1e-8));

    uint node = 0u;
    uint startLane = 0u;

    for (;;) {
        uint child; uint childLane; bool found;
        bool hasChild = traceNodeAnyHit(node, startLane, ro, rd, invD, tMax, child, childLane, found);
        if (found) return true;
        if (!hasChild) {
            if (node == 0u) return false;

            uint parentLane = packedNodeParent[node];
            node = parentLane >> 2u;
            startLane = (parentLane & 3u) + 1u;
            continue;
        }

        node = child;
        startLane = 0u;
    }
}


void intersectNodeBoxes(in uint node, in vec3 ro, in vec3 invD, out uvec4 refs, out vec4 tN, out vec4 tF) {
    ivec2 b = nodeTexel(node);
    uvec4 t0 = imageLoad(bvhNodes, b);
    refs = imageLoad(bvhNodes, b + ivec2(1, 0));
    uvec4 t2 = imageLoad(bvhNodes, b + ivec2(0, 1));
    uvec4 t3 = imageLoad(bvhNodes, b + ivec2(1, 1));

    vec3 p = uintBitsToFloat(t0.xyz);
    vec3 s = vec3(
        uintBitsToFloat((t0.w & 255u) << 23),
        uintBitsToFloat(((t0.w >> 8u) & 255u) << 23),
        uintBitsToFloat(((t0.w >> 16u) & 255u) << 23)
    );
    vec3 A = (p - ro) * invD;
    vec3 B = s * invD;

    vec4 x0 = A.x + u8x4(t2.x) * B.x,  x1 = A.x + u8x4(t2.w) * B.x;
    vec4 y0 = A.y + u8x4(t2.y) * B.y,  y1 = A.y + u8x4(t3.x) * B.y;
    vec4 z0 = A.z + u8x4(t2.z) * B.z,  z1 = A.z + u8x4(t3.y) * B.z;

    tN = max(max(min(x0, x1), min(y0, y1)), max(min(z0, z1), vec4(0.0)));
    tF = min(min(max(x0, x1), max(y0, y1)), max(z0, z1));
}

uint rayTintHit(in uint quadIdx, in bool first, in vec2 bary, in bool frontFacing, out vec3 tint) {
    tint = vec3(1);

    vec2 uv[3]; vec4 glColor[3];
    getTriAttributes(quadIdx, first, uv, glColor);

    float w0 = 1.0 - bary.x - bary.y;
    vec2 tc = uv[0] * w0 + uv[1] * bary.x + uv[2] * bary.y;

    vec4 tex = sampleTracedAll(tc, quadIdx);
    if (tex.a < RT_ALPHA_CUTOFF) return 0u;
    if (tex.a >= RT_OPAQUE_ALPHA) return 2u;
    if (!frontFacing) return 0u;

    vec3 vc = glColor[0].rgb * w0 + glColor[1].rgb * bary.x + glColor[2].rgb * bary.y;
    vec3 c = pow(max(tex.rgb * vc, vec3(0)), vec3(2.2));
    tint = mix(vec3(1), c, tex.a);
    return 1u;
}

bool tintQuad(in uint q, in vec3 ro, in vec3 rd, in float tMax, inout vec3 trans) {
    vec3 v[4];
    getQuadPos(q, v);

    float t; vec2 hitUV;
    bool first = true;
    bool hit = intersectTriangle(ro, rd, v[0], v[1], v[2], t, hitUV) && t < tMax;
    if (!hit) {
        first = false;
        hit = intersectTriangle(ro, rd, v[2], v[3], v[0], t, hitUV) && t < tMax;
    }
    if (!hit) return false;

    bool frontFacing = dot(cross(v[2] - v[0], v[3] - v[1]), rd) < 0.0;

    vec3 tint;
    uint kind = rayTintHit(q, first, hitUV, frontFacing, tint);
    if (kind == 2u) return true;
    trans *= tint;
    return false;
}


bool traceNodeTint(in uint node, in uint startLane, in vec3 ro, in vec3 rd, in vec3 invD,
    in float tMax, inout vec3 trans, out uint child, out uint childLane, out bool blocked) {
    uvec4 refs; vec4 tN, tF;
    intersectNodeBoxes(node, ro, invD, refs, tN, tF);

    blocked = false;
    for (uint lane = startLane; lane < 4u; lane++) {
        uint ref = refs[lane];
        if (ref == EMPTY_REF) continue;

        float farT = min(tF[lane], tMax);
        if (tN[lane] > farT + 1e-5 * (1.0 + abs(farT))) continue;

        if ((ref & LEAF_BIT) == 0u) {
            child = ref;
            childLane = lane;
            return true;
        }

        if (tintQuad(ref & ~LEAF_BIT, ro, rd, tMax, trans)
            || (trans.r + trans.g + trans.b) < RT_TINT_MIN_ENERGY) {
            blocked = true;
            return false;
        }
    }
    return false;
}


bool bvhTraceTinted(in vec3 ro, in vec3 rd, in float tMax, out float closestT, out vec2 uv, out uint hitIdx, out bool first, out vec3 transmittance) {
    transmittance = vec3(1);
    closestT = tMax; uv = vec2(0); hitIdx = 0u; first = true;
    float travelled = 0.0;

    for (int layer = 0; layer < MAX_TINT_LAYERS; layer++) {
        float t;
        if (!bvhTrace(ro, rd, tMax - travelled, t, uv, hitIdx, first)) return false;

        vec3 v[4];
        getQuadPos(hitIdx, v);
        bool front = dot(cross(v[2] - v[0], v[3] - v[1]), rd) < 0.0;

        vec3 tint;
        uint kind = rayTintHit(hitIdx, first, uv, front, tint);

        if (kind == 2u || layer == MAX_TINT_LAYERS - 1) {
            closestT = travelled + t;
            return true;
        }

        transmittance *= tint;
        float step = t + RT_TINT_EPS;
        ro += rd * step;
        travelled += step;
        if (travelled >= tMax) return false;
    }
    return false;
}

vec3 bvhTintedShadow(in vec3 ro, in vec3 rd, in float tMax) {
    uint n = TriCounter.quadCount;
    vec3 trans = vec3(1);
    if (n == 0u) return trans;
    if (n == 1u) return tintQuad(0u, ro, rd, tMax, trans) ? vec3(0.0) : trans;

    vec3 raySign = mix(vec3(-1), vec3(1.0), greaterThanEqual(rd, vec3(0.0)));
    vec3 invD = raySign / max(abs(rd), vec3(1e-8));

    uint node = 0u;
    uint startLane = 0u;

    for (;;) {
        uint child; uint childLane; bool blocked;
        bool hasChild = traceNodeTint(node, startLane, ro, rd, invD, tMax, trans, child, childLane, blocked);
        if (blocked) return vec3(0.0);

        if (!hasChild) {
            if (node == 0u) return trans;
            uint parentLane = packedNodeParent[node];
            node = parentLane >> 2u;
            startLane = (parentLane & 3u) + 1u;
            continue;
        }

        node = child;
        startLane = 0u;
    }
}


#endif