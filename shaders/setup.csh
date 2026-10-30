#version 430 compatibility

#include "lib/settings.glsl"
#include "lib/lut_uitl.glsl"
#include "lib/sky.glsl"


layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;
const ivec3 workGroups = ivec3(256, 256, 1);


layout(rgb10_a2, binding = 0) uniform image2D skyLut;


void main() {
    ivec2 texelCoord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 lutSize = imageSize(skyLut);

    if (any(greaterThanEqual(texelCoord, lutSize))) return;

    vec2 uv = (vec2(texelCoord) + 0.5) / vec2(lutSize);
    vec3 rayDir = equirectToDir(uv);
    vec3 color = getSkyLut(rayDir);

    imageStore(skyLut, texelCoord, vec4(color, 1));
}
