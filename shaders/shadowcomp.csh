#version 430 compatibility

#include "lib/settings.glsl"
#include "lib/vertex_util.glsl"


layout(local_size_x = 64) in;
const ivec3 workGroups = ivec3(1, 1, 1);

void main() {
    #ifdef BVH_REUSE
        uint i = gl_GlobalInvocationID.x;
        if (i > 0) return;

        uint tc = TriCounter.frameVertexCount;
        TriCounter.rebuildFlag = TriCounter.vertexCountPrev == tc? 0u : 1u;
        TriCounter.vertexCountPrev = tc;
    #else
        TriCounter.rebuildFlag = 1u;
    #endif
}