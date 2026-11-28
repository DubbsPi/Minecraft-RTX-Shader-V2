#ifndef INCLUDE_RTX
#define INCLUDE_RTX

#ifdef RTX_FEATURES

//  I suppose I should actually start documenting my stuff a bit, huh
//  bvhTraceOpaque(ro, rd, tMax, hit)
//  bvhTraceTinted(ro, rd, tMax, hit, trans)
//  bvhTintedShadow(ro, rd, tMax) -> vec3
//  fetchSurface(hit, rd) -> RTSurface


#define BVH_TRACE_ONLY
#include "bvh_util.glsl"
#include "vertex_util.glsl"
#include "settings.glsl"


uniform sampler2D colortex8;  // texture atlas
uniform sampler2D entityAtlasSampler;
uniform isampler2D triangleTestSampler;


layout(rg32ui, binding = 1) uniform readonly restrict uimage2D vertexAttributes;
layout(r32i, binding = 4) uniform iimage2D triangleTests;
layout(std430, binding = 8) restrict readonly buffer PackedNodeParents {uint packedNodeParent[];};


uniform float viewHeight;
uniform float viewWidth;


#define RT_MODE_OPAQUE 0
#define RT_MODE_TINTED 1
#define RT_MODE_SHADOW 2

#define RT_BOX_EPS 1e-5


struct RTHit {
    float t;
    vec2 bary;
    uint quad;
    bool first;
};

struct RTSurface {
    vec3 normal;
    vec2 uv;
    vec3 albedo;
    vec2 lm;
};


// Helpers
vec4 u8x4(uint w) {
    return vec4(uvec4(w, w >> 8u, w >> 16u, w >> 24u) & 255u);
}

vec3 toBuildSpace(in vec3 position) {
    return position + cameraPosition - TriCounter.buildCameraPosition;
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

void getTriLighting(in uint idx, in bool first, out vec2 lm[3]) {
    ivec2 base = ivec2(idx % TRIS_PER_ROW, idx / TRIS_PER_ROW) * 2;

    if (first) {
        lm[0] = unpackLight(imageLoad(vertexAttributes, base).xy);
        lm[1] = unpackLight(imageLoad(vertexAttributes, base + ivec2(1, 0)).xy);
        lm[2] = unpackLight(imageLoad(vertexAttributes, base + ivec2(0, 1)).xy);
    } else {
        lm[0] = unpackLight(imageLoad(vertexAttributes, base + ivec2(0, 1)).xy);
        lm[1] = unpackLight(imageLoad(vertexAttributes, base + ivec2(1, 1)).xy);
        lm[2] = unpackLight(imageLoad(vertexAttributes, base).xy);
    }
}

ivec2 slotToTexel(in uint slot) {
    const int slotsPerRow = ENTITY_ATLAS_SIZE / ENTITY_ATLAS_SLOT_SIZE;
    ivec2 slotCoord = ivec2(int(slot) % slotsPerRow, int(slot) / slotsPerRow);
    return slotCoord * ENTITY_ATLAS_SLOT_SIZE;
}

vec4 sampleTraced(in vec2 tc, in uint triIdx, in bool isEntity) {
    if (isEntity) {
        uint slot = Slots.entitySlots[triIdx];
        ivec2 texSize = TriCounter.texSize[slot];
        ivec2 pos = slotToTexel(slot);
        ivec2 texel = clamp(ivec2(tc * texSize), ivec2(0), texSize - 1);
        return texelFetch(entityAtlasSampler, pos + texel, 0);
    }
    return textureLod(colortex8, tc, 0.0);
}

vec3 sampleTracedTexture(in vec2 tc, in uint triIdx, in bool isEntity) {
    return pow(max(sampleTraced(tc, triIdx, isEntity).rgb, vec3(0)), vec3(2.2));
}


// Intersection functions
bool intersectTriangle(in vec3 ro, in vec3 rd, in vec3 a, in vec3 b, in vec3 c, in float tLimit, out float t, out vec2 uv) {
    vec3 e1 = b - a;
    vec3 e2 = c - a;

    vec3 p = cross(rd, e2);
    float det = dot(e1, p);
    float adet = abs(det);
    if (adet < 1e-8) return false;

    float sgn = det < 0.0? -1.0 : 1.0;

    vec3 s = ro - a;
    float u = dot(s, p) * sgn;
    if (u < 0.0 || u > adet) return false;

    vec3 q = cross(s, e1);
    float v = dot(rd, q) * sgn;
    if (v < 0.0 || u + v > adet) return false;

    float tn = dot(e2, q) * sgn;
    if (tn <= 0.0 || tn >= tLimit * adet) return false;

    float inv = 1.0 / adet;
    t = tn * inv;
    uv = vec2(u, v) * inv;
    return true;
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

    vec4 x0 = A.x + u8x4(t2.x) * B.x, x1 = A.x + u8x4(t2.w) * B.x;
    vec4 y0 = A.y + u8x4(t2.y) * B.y, y1 = A.y + u8x4(t3.x) * B.y;
    vec4 z0 = A.z + u8x4(t2.z) * B.z, z1 = A.z + u8x4(t3.y) * B.z;

    tN = max(max(min(x0, x1), min(y0, y1)), max(min(z0, z1), vec4(0.0)));
    tF = min(min(max(x0, x1), max(y0, y1)), max(z0, z1));
}


uint classifyHit(in uint q, in bool first, in vec2 bary, in bool front, in bool wantTint, out vec3 tint) {
    tint = vec3(1);

    vec2 uv[3]; vec4 glColor[3];
    getTriAttributes(q, first, uv, glColor);

    float w0 = 1.0 - bary.x - bary.y;
    vec2 tc = uv[0] * w0 + uv[1] * bary.x + uv[2] * bary.y;

    vec4 tex = sampleTraced(tc, q, false);  // Dynamic not yet implemented
    if (tex.a < RT_ALPHA_CUTOFF) return 0u; // Gotta make sure I don't forget this later lol
    if (tex.a >= RT_OPAQUE_ALPHA) return 2u;
    if (!front) return 0u;
    if (!wantTint) return 1u;

    vec3 vc = glColor[0].rgb * w0 + glColor[1].rgb * bary.x + glColor[2].rgb * bary.y;
    vec3 c = pow(max(tex.rgb * vc, vec3(0)), vec3(2.2));
    tint = mix(vec3(1.0), c, tex.a);
    return 1u;
}


// Traversal functions
bool bvhTraverse(in vec3 ro, in vec3 rd, in float tMax, in int mode, out RTHit hit, out vec3 trans) {
    hit = RTHit(tMax, vec2(0), 0u, true);
    trans = vec3(1);
    if (TriCounter.quadCount < 2u) return false;

    vec3 buildRo = toBuildSpace(ro);
    vec3 raySign = mix(vec3(-1.0), vec3(1.0), greaterThanEqual(rd, vec3(0.0)));
    vec3 invD = raySign / max(abs(rd), vec3(1e-8));

    float layerT[MAX_TINT_LAYERS];
    vec3 layerTint[MAX_TINT_LAYERS];
    for (int i = 0; i < MAX_TINT_LAYERS; ++i) {
        layerT[i] = 1e30;
        layerTint[i] = vec3(1.0);
    }

    bool found = false;
    uint node = 0u;
    uint resume = 4u;

    for (;;) {
        uvec4 refs; vec4 tN, tF;
        intersectNodeBoxes(node, buildRo, invD, refs, tN, tF);

        vec4 key = (mode == RT_MODE_SHADOW)? vec4(0.0, 1.0, 2.0, 3.0) : tN;
        float lastKey = (resume < 4u)? key[resume] : -1.0;
        uint lastLane = resume;

        bool descended = false;
        for (int iter = 0; iter < 4; ++iter) {
            uint lane = 4u;
            float bestKey = 1e30;
            for (uint l = 0u; l < 4u; ++l) {
                if (refs[l] == EMPTY_REF) continue;

                float farT = min(tF[l], hit.t);
                if (tN[l] > farT + RT_BOX_EPS * (1.0 + abs(farT))) continue;

                float k = key[l];
                if (k < lastKey || (k == lastKey && l <= lastLane)) continue;
                if (k < bestKey) { bestKey = k; lane = l; }
            }
            if (lane == 4u) break;

            lastKey = bestKey;
            lastLane = lane;

            uint ref = refs[lane];
            if ((ref & LEAF_BIT) == 0u) {
                node = ref;
                resume = 4u;
                descended = true;
                break;
            }

            uint q = ref & ~LEAF_BIT;
            vec3 v[4];
            getQuadPos(q, v);
            bool front = dot(cross(v[2] - v[0], v[3] - v[1]), rd) < 0.0;

            for (int tri = 0; tri < 2; ++tri) {
                bool first = (tri == 0);
                float t; vec2 bary;
                bool h;
                if (first) h = intersectTriangle(buildRo, rd, v[0], v[1], v[2], hit.t, t, bary);
                else       h = intersectTriangle(buildRo, rd, v[2], v[3], v[0], hit.t, t, bary);
                if (!h) continue;

                vec3 tint;
                uint kind = classifyHit(q, first, bary, front, mode != RT_MODE_OPAQUE, tint);
                if (kind == 0u) continue;

                if (kind == 2u) {
                    hit = RTHit(t, bary, q, first);
                    found = true;
                    if (mode == RT_MODE_SHADOW) { trans = vec3(0.0); return true; }
                    continue;
                }

                // Translucent
                if (mode == RT_MODE_OPAQUE) continue;
                if (mode == RT_MODE_SHADOW) {
                    trans *= tint;
                    if (trans.r + trans.g + trans.b < RT_TINT_MIN_ENERGY) { trans = vec3(0.0); return true; }
                } else {
                    int worst = 0;
                    for (int i = 1; i < MAX_TINT_LAYERS; ++i)
                        if (layerT[i] > layerT[worst]) worst = i;
                    if (t < layerT[worst]) { layerT[worst] = t; layerTint[worst] = tint; }
                }
            }
        }

        if (descended) continue;

        if (node == 0u) break;
        uint parentLane = packedNodeParent[node];
        node = parentLane >> 2u;
        resume = parentLane & 3u;
    }

    if (mode == RT_MODE_TINTED) {
        for (int i = 0; i < MAX_TINT_LAYERS; ++i)
            if (layerT[i] < hit.t) trans *= layerTint[i];
    }

    return found;
}


// Wrapper functions to make my life simpler
bool bvhTraceOpaque(in vec3 ro, in vec3 rd, in float tMax, out RTHit hit) {
    vec3 trans;
    return bvhTraverse(ro, rd, tMax, RT_MODE_OPAQUE, hit, trans);
}

bool bvhTraceTinted(in vec3 ro, in vec3 rd, in float tMax, out RTHit hit, out vec3 trans) {
    return bvhTraverse(ro, rd, tMax, RT_MODE_TINTED, hit, trans);
}

vec3 bvhTintedShadow(in vec3 ro, in vec3 rd, in float tMax) {
    RTHit hit; vec3 trans;
    bvhTraverse(ro, rd, tMax, RT_MODE_SHADOW, hit, trans);
    return trans;
}


RTSurface fetchSurface(in RTHit h, in vec3 rd) {
    vec3 v[4];
    getQuadPos(h.quad, v);

    vec2 uv[3]; vec4 glColor[3];
    getTriAttributes(h.quad, h.first, uv, glColor);

    vec3 p0 = h.first? v[0] : v[2];
    vec3 p1 = h.first? v[1] : v[3];
    vec3 p2 = h.first? v[2] : v[0];

    float w0 = 1.0 - h.bary.x - h.bary.y;

    RTSurface s;
    s.uv = uv[0] * w0 + uv[1] * h.bary.x + uv[2] * h.bary.y;
    vec4 vc = glColor[0] * w0 + glColor[1] * h.bary.x + glColor[2] * h.bary.y;

    vec4 tex = sampleTraced(s.uv, h.quad, false);
    s.albedo = pow(max(tex.rgb * vc.rgb, vec3(0)), vec3(2.2));

    vec3 n = normalize(cross(p1 - p0, p2 - p0));
    s.normal = dot(n, rd) > 0.0? -n : n;

    vec2 lm[3];
    getTriLighting(h.quad, h.first, lm);
    s.lm = lm[0] * w0 + lm[1] * h.bary.x + lm[2] * h.bary.y;

    return s;
}


float rayExitDist(in vec3 ro, in vec3 rd, in float maxDist) {
    vec3 buildRo = toBuildSpace(ro);
    vec3 safeRd = mix(rd, vec3(1e-8), lessThan(abs(rd), vec3(1e-8)));
    vec3 bound  = mix(vec3(-maxDist), vec3(maxDist), greaterThan(safeRd, vec3(0.0)));
    vec3 t = (bound - buildRo) / safeRd;
    return min(min(t.x, t.y), t.z);
}


#endif
#endif