#version 430 compatibility

#include "lib/settings.glsl"

layout(local_size_x = 1024) in;
const ivec3 workGroups = ivec3(1, 1, 1);

#define SORT_PASS 2
#define SORT_STAGE 1

#include "lib/radix_sort.glsl"