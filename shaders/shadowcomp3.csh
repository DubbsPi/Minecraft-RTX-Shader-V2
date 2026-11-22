#version 430 compatibility

#include "lib/settings.glsl"

layout(local_size_x = 256) in;
const ivec3 workGroups = ivec3(MAX_QUADS_OVER_4096, 1, 1);

#define SORT_PASS 0
#define SORT_STAGE 2

#include "lib/radix_sort.glsl"