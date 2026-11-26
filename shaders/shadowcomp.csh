#version 430 compatibility

#include "lib/vertex_util.glsl"


layout(local_size_x = 64) in;
const ivec3 workGroups = ivec3(1, 1, 1);

void main() {
    uint i = gl_GlobalInvocationID.x;
    if (i > 64) return;

    if (TriCounter.vertexHash[i] == TriCounter.vertexHashPrev[i]) atomicAdd(TriCounter.rebuildFlag, 1u);
    barrier();

    if (i == 0) {
        uint t = TriCounter.rebuildFlag;
        if (t == 64u || t == 65u) TriCounter.rebuildFlag = 0u;
        else TriCounter.rebuildFlag = 1u;
    }
}