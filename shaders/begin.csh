#version 430 compatibility

#include "lib/vertex_util.glsl"


// Due to the way GPU drivers work, this 16x16 with only the first thread doing something
// runs about 0.22ms less on a 5070. Not sure why that big off a diff though
layout(local_size_x = 64) in;
const ivec3 workGroups = ivec3(1, 1, 1);


uniform vec3 cameraPosition;


void main() {
    uint i = gl_LocalInvocationIndex;

    if (i == 0) {
        TriCounter.frameVertexCount = 0u;
        TriCounter.captureFlag = (TriCounter.rebuildFlag != 0u || TriCounter.quadCount == 0u)? 1u : 0u;
        if (TriCounter.captureFlag != 0u) {
            TriCounter.quadCount = 0u;
            TriCounter.vertexCount = 0u;
            TriCounter.dynamicQuadCount = 0u;
            TriCounter.dynamicVertexCount = 0u;
            TriCounter.buildCameraPosition = cameraPosition;
        }
    }
}
