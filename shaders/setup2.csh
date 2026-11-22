#version 430 compatibility

#include "lib/settings.glsl"


layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(32768, 1, 1);


layout(std430, binding = 5) restrict writeonly buffer Parents { uint parentOf[]; };


void main() {
    uint i = gl_GlobalInvocationID.x;
    if (i > MAX_QUADS) return;

    parentOf[i] = 0u;
}
