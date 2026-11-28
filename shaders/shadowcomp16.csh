#version 430 compatibility

#include "lib/settings.glsl"

#define BVH_BUILD_ONLY
#include "lib/bvh_boxes.glsl"
#include "lib/vertex_util.glsl"


layout(local_size_x = 64) in;
const ivec3 workGroups = ivec3(MAX_QUADS_OVER_64, 1, 1);


layout(std430, binding = 4) restrict readonly buffer Children {uvec2 childOf[];};
layout(std430, binding = 5) restrict readonly buffer Parents {uint parentOf[];};
layout(std430, binding = 8) restrict writeonly buffer PackedNodeParents {uint packedNodeParent[];};


#define COLLAPSE_SKIP_ODD


uvec2 gatherSlots(in uint child, in uint n) {
    return (child >= n - 1u)? uvec2(child, EMPTY_REF) : childOf[child];
}

ivec3 ceilLog2(in vec3 x) {
    ivec3 b = floatBitsToInt(x);
    return ((b >> 23) & 255) - 127 + ivec3(notEqual(b & 0x7FFFFF, ivec3(0)));
}


void main() {
    if (TriCounter.captureFlag == 0u) return;

    uint i = gl_GlobalInvocationID.x;
    uint n = TriCounter.quadCount;
    if (n < 2u || i >= n - 1u) return;

    #ifdef COLLAPSE_SKIP_ODD
        uint hops = 0u;
        for (uint c = i; c != 0u; c = parentOf[c]) hops++;
        if ((hops & 1u) != 0u) return;
    #endif

    uvec2 c = childOf[i];
    uvec2 a = gatherSlots(c.x, n);
    uvec2 b = gatherSlots(c.y, n);
    uint ids[4] = uint[4](a.x, a.y, b.x, b.y);

    vec3 lo, hi;
    loadBox(i, lo, hi);
    vec3 ext = (hi - lo) * 1.001 + 1e-4;

    ivec3 e = clamp(ceilLog2(ext * (1.0 / 255.0)), ivec3(-120), ivec3(100));
    vec3 scale = vec3(pow2f(e.x), pow2f(e.y), pow2f(e.z));
    e += ivec3(greaterThan(ext, scale * 255.0));

    scale = vec3(pow2f(e.x), pow2f(e.y), pow2f(e.z));
    vec3 invScale = 1.0 / scale;

    uint refs[4];
    uvec3 L = uvec3(0u), H = uvec3(0u);
    uint count = 0u;
    for (uint k = 0u; k < 4u; k++) {
        refs[k] = EMPTY_REF;
        uint id = ids[k];
        if (id == EMPTY_REF) continue;

        vec3 cl, ch;
        nodeBounds(id, n, cl, ch);
        // Round outwards to ensure nothing is missed
        ivec3 qli = ivec3(clamp(floor((cl - lo) * invScale), 0.0, 255.0));
        ivec3 qhi = ivec3(clamp(ceil ((ch - lo) * invScale), 0.0, 255.0));
        qli -= ivec3(greaterThan(lo + vec3(qli) * scale, cl));
        qhi += ivec3(lessThan(lo + vec3(qhi) * scale, ch));
        uvec3 ql = uvec3(clamp(qli, 0, 255));
        uvec3 qh = uvec3(clamp(qhi, 0, 255));

        L |= ql << (8u * k);
        H |= qh << (8u * k);
        if (id >= n - 1u) {
            refs[k] = LEAF_BIT | vals[id - (n - 1u)];
        } else {
            refs[k] = id;
            packedNodeParent[id] = (i << 2u) | k;
        }
        count++;
    }

    uint ex = uint(e.x + 127) | (uint(e.y + 127) << 8) | (uint(e.z + 127) << 16);
    ivec2 bt = nodeTexel(i);
    imageStore(bvhNodes, bt, uvec4(floatBitsToUint(lo), ex));
    imageStore(bvhNodes, bt + ivec2(1,0), uvec4(refs[0], refs[1], refs[2], refs[3]));
    imageStore(bvhNodes, bt + ivec2(0,1), uvec4(L.x, L.y, L.z, H.x));
    imageStore(bvhNodes, bt + ivec2(1,1), uvec4(H.y, H.z, count, 0u));
}