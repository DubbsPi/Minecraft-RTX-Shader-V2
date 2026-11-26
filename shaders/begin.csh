#version 430 compatibility

#include "lib/vertex_util.glsl"


// Due to the way GPU drivers work, this 16x16 with only the first thread doing something
// runs about 0.22ms less on a 5070. Not sure why that big off a diff though
layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);


uniform vec3 cameraPosition;


void main() {
    uint i = gl_LocalInvocationIndex;

    if (i == 0) {
        TriCounter.quadCount = 0u;
        TriCounter.vertexCount = 0u;
        TriCounter.rebuildFlag = 1u;

        if (TriCounter.rebuildFlag == 1u)
            TriCounter.buildCameraPosition = cameraPosition;
    }

    if (i < 64) TriCounter.vertexHash[i] = 0u;
}
