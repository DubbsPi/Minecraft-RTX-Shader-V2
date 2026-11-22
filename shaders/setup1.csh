#version 430 compatibility

#include "lib/settings.glsl"


layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(16384, 1, 1);


layout(std430, binding = 1) restrict writeonly buffer SrcKeys { uint srcKeys[]; };
layout(std430, binding = 2) restrict writeonly buffer SrcVals { uint srcVals[]; };
layout(std430, binding = 4) restrict writeonly buffer Children { uvec2 childOf[]; };
layout(std430, binding = 7) restrict writeonly buffer Flags { uint visitCount[]; };
layout(std430, binding = 8) restrict writeonly buffer DstKeys { uint dstKeys[]; };
layout(std430, binding = 9) restrict writeonly buffer DstVals { uint dstVals[]; };
layout(std430, binding = 10) restrict writeonly buffer RadixHist { uint hist[]; };
layout(std430, binding = 11) restrict writeonly buffer EntitySlots { uint entitySlots[]; };


void main() {
    uint i = gl_GlobalInvocationID.x;
    if (i >= MAX_QUADS) return;

    srcKeys[i] = 0u;
    srcVals[i] = 0u;
    childOf[i] = uvec2(0u);
    visitCount[i] = 0u;
    dstKeys[i] = 0u;
    dstVals[i] = 0u;
    hist[i] = 0u;
    entitySlots[i] = 0u;
}
