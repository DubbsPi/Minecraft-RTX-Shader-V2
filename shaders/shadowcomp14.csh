#version 430 compatibility

#include "lib/settings.glsl"

#define BOXES_WRITE
#include "lib/bvh_boxes.glsl"
#include "lib/vertex_util.glsl"


layout(local_size_x = 128) in;
const ivec3 workGroups = ivec3(MAX_QUADS_OVER_128, 1, 1);


layout(std430, binding = 4) restrict readonly buffer Children { uvec2 childOf[]; };
layout(std430, binding = 5) restrict readonly buffer Parents { uint parentOf[]; };
layout(std430, binding = 7) coherent buffer Flags { uint visitCount[]; };


void main() {
    uint j = gl_GlobalInvocationID.x;
    uint n = TriCounter.quadCount;
    if (n < 2u || j >= n) return;
    
    uint cur = n - 1u + j;
    vec3 lo, hi;
    quadBounds(vals[j], lo, hi);

    while (cur != 0u) {
        uint p = parentOf[cur];

        memoryBarrierBuffer();
        if (atomicAdd(visitCount[p], 1u) == 0u) return;
        memoryBarrierBuffer();

        uvec2 c = childOf[p];

        uint sib;
        if (c.x == cur) sib = c.y;
        else if (c.y == cur) sib = c.x;
        else return;
        
        vec3 slo, shi;
        nodeBounds(sib, n, slo, shi);

        lo = min(lo, slo);
        hi = max(hi, shi);
        storeBox(p, lo, hi);
        cur = p;
    }
}