#version 430 compatibility

#include "lib/settings.glsl"

#ifdef VERTEX_HASH_DEBUG
    #include "lib/vertex_util.glsl"
#endif
#ifdef VERTEX_COUNT_DEBUG
    #include "lib/vertex_util.glsl"
    uniform float viewWidth;
#endif
#ifdef RADIX_SORT_DEBUG
    #define BVH_TRACE_ONLY
    #include "lib/bvh_boxes.glsl"
    layout(std430, binding = 1) restrict readonly buffer SortKeys { uint keys[]; };
#endif
#ifdef BVH_DEBUG
    #ifndef BVH_TRACE_ONLY
        #define BVH_TRACE_ONLY
    #endif
    #include "lib/bvh_boxes.glsl"
    #include "lib/random.glsl"
    layout(std430, binding = 4) restrict readonly buffer Children { uvec2 childOf[]; };
    layout(std430, binding = 5) restrict readonly buffer Parents { uint parentOf[]; };
#endif
#ifdef TRACE_DEBUG
    #include "lib/rtx.glsl"
    uniform mat4 gbufferProjectionInverse;
    uniform mat4 gbufferModelViewInverse;
#endif
#ifdef ENTITY_ATLAS_DEBUG
    uniform image2D entityAtlasSampler;
#endif

uniform sampler2D colortex0;
uniform sampler2D skyLutSampler;

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;


vec3 acesTonemap(in vec3 color) {
    const float a = 2.51f;
    const float b = 0.03f;
    const float c = 2.43f;
    const float d = 0.59f;
    const float e = 0.14f;
    return clamp((color * (a * color + b)) / (color * (c * color + d) + e), 0.0f, 1.0f);
}

float bayerDither(in vec2 p) {
    int x = int(p.x) & 3;
    int y = int(p.y) & 3;
    
    int i = x + y * 4;
    
    const float pattern[16] = float[16](
        0.0 / 16.0, 8.0 / 16.0, 2.0 / 16.0, 10.0 / 16.0,
        12.0 / 16.0, 4.0 / 16.0, 14.0 / 16.0, 6.0 / 16.0,
        3.0 / 16.0, 11.0 / 16.0, 1.0 / 16.0, 9.0 / 16.0,
        15.0 / 16.0, 7.0 / 16.0, 13.0 / 16.0, 5.0 / 16.0
    );
    
    return pattern[i] - 0.5;
}


#ifdef BVH_DEBUG
    uvec2 gatherSlots(in uint child, in uint n) {
        return (child >= n - 1u)? uvec2(child, EMPTY_REF) : childOf[child];
    }

    uint byteOf(in uint w, in uint k) {
        return (w >> (8u * k)) & 255u;
    }

    float mx3(in vec3 v) {
        return max(v.x, max(v.y, v.z));
    }
#endif
#ifdef TRACE_DEBUG
    vec3 primaryRayDir(in vec2 uv) {
        vec4 v = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, 1.0, 1.0);
        return normalize(mat3(gbufferModelViewInverse) * (v.xyz / v.w));
    }
#endif


void main() {
    vec3 color = texture(colortex0, texcoord).rgb;

    // Tonemap + gamma
    color = acesTonemap(color);
    color = pow(color, vec3(0.454545454545));

    // Dithering
    float dither = bayerDither(gl_FragCoord.xy);
    const float depth = 1.0 / 255.0;
    color += dither * depth;

    #ifdef VERTEX_COUNT_DEBUG
        if (texcoord.y < 0.02) {
            uint n = TriCounter.quadCount;
            float triUsage = min(float(n) / float(MAX_QUADS), 1.0);
            color = vec3(0.05);

            if (texcoord.x < triUsage) color = vec3(texcoord.x, 1.0 - texcoord.x, 0.0);
        }
    #endif
    #ifdef RADIX_SORT_DEBUG
        if (texcoord.y > 0.02 && texcoord.y < 0.04) {
            uint n = TriCounter.quadCount;
            color.rgb = vec3(0.1);
            if (n > 1u) {
                uvec2 p = uvec2(gl_FragCoord.xy);
                uint h = (p.x * 1973u + p.y * 9277u + uint(frameCounter) * 26699u) * 747796405u;
                h = (h ^ (h >> 16u)) * 2246822519u;
                uint i = (h ^ (h >> 13u)) % (n - 1u);

                vec3 mn, mx; quadBounds(vals[i], mn, mx);
                uint expect = morton3D(((mn + mx) * 0.5) / (2.0 * MAX_DIST) + 0.5);

                color.rgb = vec3(0, 0.8, 0);
                if (keys[i] > keys[i + 1u]) color.rgb = vec3(1.0, 0.0, 0.0);
                if (keys[i] != expect) color.rgb = vec3(1.0, 0.0, 1.0);
            }
        }
    #endif
    #ifdef BVH_DEBUG
        if (texcoord.y > 0.04 && texcoord.y < 0.06) {
            uint n = TriCounter.quadCount;
            color.rgb = vec3(0.05);
            if (n >= 2u) {
                uvec2 p = uvec2(gl_FragCoord.xy);
                uint h1 = p.x + p.y * 4099u + uint(frameCounter) * 65537u;
                h1 = pcg(h1);
                uint h2 = pcg(h1);

                uint id = 1u + h1 % (2u * n - 2u);
                uint par = parentOf[id];
                bool ok = par < n - 1u && (childOf[par].x == id || childOf[par].y == id);

                uint in_ = h2 % (n - 1u);
                uvec2 c  = childOf[in_];
                ok = ok && c.x < 2u * n - 1u && c.y < 2u * n - 1u && parentOf[c.x] == in_ && parentOf[c.y] == in_;

                color.rgb = ok? vec3(0, 0.75, 0) : vec3(1, 0, 0);
            }
        } else if (texcoord.y > 0.06 && texcoord.y < 0.08) {
            uint n = TriCounter.quadCount;
            color.rgb = vec3(0.1);
            if (n >= 2u) {
                uvec2 p = uvec2(gl_FragCoord.xy);
                uint j = p.x * 7919u + p.y * 4099u + uint(frameCounter) * 65537u;
                j = pcg(j) % n;

                vec3 llo, lhi;
                quadBounds(vals[j], llo, lhi);

                uint cur = n - 1u + j;
                bool ok = true;
                for (int s = 0; s < 80 && cur != 0u; ++s) {
                    cur = parentOf[cur];
                    vec3 blo, bhi; loadBox(cur, blo, bhi);
                    ok = ok && all(lessThanEqual(blo, llo)) && all(greaterThanEqual(bhi, lhi));
                }
                ok = ok && cur == 0u;
                color.rgb = ok? vec3(0, 0.8, 0) : vec3(1, 0, 0);
            }
        } else if (texcoord.y > 0.08 && texcoord.y < 0.10) {
            uint n = TriCounter.quadCount;
            color.rgb = vec3(0.1);
            if (n >= 2u) {
                uvec2 px = uvec2(gl_FragCoord.xy);
                uint i = px.x * 7919u + px.y * 4099u + uint(frameCounter) * 65537u;
                i = pcg(i) % (n - 1u);

                uvec2 c = childOf[i];
                uvec2 a = gatherSlots(c.x, n), b = gatherSlots(c.y, n);
                uint ids[4] = uint[4](a.x, a.y, b.x, b.y);

                ivec2 bt = nodeTexel(i);
                uvec4 t0 = imageLoad(bvhNodes, bt);
                uvec4 t1 = imageLoad(bvhNodes, bt + ivec2(1, 0));
                uvec4 t2 = imageLoad(bvhNodes, bt + ivec2(0, 1));
                uvec4 t3 = imageLoad(bvhNodes, bt + ivec2(1, 1));

                vec3 p = uintBitsToFloat(t0.xyz);
                vec3 s = vec3(
                    uintBitsToFloat((t0.w & 255u) << 23),
                    uintBitsToFloat(((t0.w >> 8u) & 255u) << 23),
                    uintBitsToFloat(((t0.w >> 16u) & 255u) << 23)
                );

                bool refsOk = true; float over = 0.0, loose = 0.0;
                for (uint k = 0u; k < 4u; k++) {
                    uint id = ids[k];
                    if (id == EMPTY_REF) { refsOk = refsOk && t1[k] == EMPTY_REF; continue; }
                    refsOk = refsOk && t1[k] == ((id >= n - 1u) ? (LEAF_BIT | vals[id - (n - 1u)]) : id);

                    vec3 dlo = p + vec3(byteOf(t2.x, k), byteOf(t2.y, k), byteOf(t2.z, k)) * s;
                    vec3 dhi = p + vec3(byteOf(t2.w, k), byteOf(t3.x, k), byteOf(t3.y, k)) * s;
                    vec3 tlo, thi; nodeBounds(id, n, tlo, thi);

                    over  = max(over,  max(mx3(dlo - tlo), mx3(thi - dhi)));
                    loose = max(loose, max(mx3((tlo - dlo) / s), mx3((dhi - thi) / s)));
                }
                color.rgb = !refsOk?    vec3(1, 0, 1)
                        : over > 1e-4?  vec3(1, 0, 0)
                        : loose > 1.05? vec3(1, 0.5, 0)
                        :               vec3(0, 0.75, 0);
            }
        }
    #endif
    #if TRACE_DEBUG == 1
        float t; vec2 b; uint idx; bool f;
        if (bvhTrace(vec3(0), primaryRayDir(texcoord), t, b, idx, f))
            color.rgb = vec3(exp(-t * 0.03));
    #elif TRACE_DEBUG == 2
        uvec2 px = uvec2(gl_FragCoord.xy);

        if (((px.x | px.y) & 7u) == 0u) {
            if (TriCounter.quadCount > uint(MAX_BRUTE_FORCE_TESTS)) {
                color.rgb = vec3(0, 1, 1);
            } else {
                vec3 rd = primaryRayDir(texcoord);
                float tB, tR; vec2 uvB, uvR; uint iB, iR; bool fB, fR;
                bool hB = bvhTrace(vec3(0), rd, tB, uvB, iB, fB);
                bool hR = bruteForceTrace(vec3(0), rd, tR, uvR, iR, fR);

                bool agree = (hB == hR) && (!hB || iB == iR || abs(tB - tR) < 1e-3);
                color.rgb = agree? vec3(0, 1, 0)
                    : (hR && !hB)? vec3(1, 0, 0)
                    : (hB && !hR)? vec3(0, 0.3, 1)
                    :              vec3(1, 1, 0);
            }
        }
    #endif
    #ifdef ENTITY_ATLAS_DEBUG
        color = texture(entityAtlasSampler, texcoord).rgb;
    #endif

    #ifdef VERTEX_HASH_DEBUG
        uint pixelY = uint(gl_FragCoord.y);
        uint debugHeight = max(uint(viewHeight * 0.1), 64u);
        if (pixelY < debugHeight) {
            uint bucket = min(pixelY * 64u / debugHeight, 63u);
            color = unpackUnorm4x8(TriCounter.vertexHash[bucket]).rgb;

            if (pixelY == 0u || bucket != ((pixelY - 1u) * 64u / debugHeight)) color *= 0.35;
        }
    #endif
    
    outColor = vec4(color, 1);
}