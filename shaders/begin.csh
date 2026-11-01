#version 430 compatibility

#include "lib/vertex_util.glsl"


// Due to the way GPU drivers work, this 16x16 with only the first thread doing something
// runs about 0.22ms less on a 5070. Not sure why that big off a diff though
layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;
const ivec3 workgroups = ivec3(1, 1, 1);


void main() {
    if (gl_GlobalInvocationID.x == 0) {
        TriCounter.quadCount = 0u;
        TriCounter.vertexCount = 0u;
    }
}
