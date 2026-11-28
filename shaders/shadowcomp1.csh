#version 430 compatibility


#include "lib/settings.glsl"
#include "lib/bvh_util.glsl"
#include "lib/vertex_util.glsl"


layout(local_size_x = 128) in;
const ivec3 workGroups = ivec3(MAX_QUADS_OVER_128, 1, 1);


layout(std430, binding = 1) restrict writeonly buffer SortKeys { uint keys[]; };
layout(std430, binding = 2) restrict writeonly buffer SortVals { uint vals[]; };
layout(std430, binding = 7) restrict writeonly buffer Flags { uint visitCount[]; };


void main() {
    if (TriCounter.captureFlag == 0u) return;

    uint q = gl_GlobalInvocationID.x;
    if (q >= TriCounter.quadCount) return;

    vec3 mn, mx;
    quadBounds(q, mn, mx);

    keys[q] = morton3D(((mn + mx) * 0.5) / (2.0 * MAX_DIST) + 0.5);
    vals[q] = q;
    visitCount[q] = 0u;
}
