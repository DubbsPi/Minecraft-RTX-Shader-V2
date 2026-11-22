#version 430 compatibility

#include "lib/settings.glsl"
#include "lib/vertex_util.glsl"


layout(local_size_x = 128) in;
const ivec3 workGroups = ivec3(MAX_QUADS_OVER_128, 1, 1);


layout(std430, binding = 1) restrict readonly buffer SortKeys { uint keys[]; };
layout(std430, binding = 4) restrict writeonly buffer Children { uvec2 childOf[]; };
layout(std430, binding = 5) restrict writeonly buffer Parents { uint parentOf[]; };


int delta(in int i, in uint ki, in int j, in int n) {
    if (j < 0 || j >= n) return -1;
    uint kj = keys[j];
    return (ki == kj)? 63 - findMSB(uint(i ^ j)) : 31 - findMSB(ki ^ kj);
}


void main() {
    int i = int(gl_GlobalInvocationID.x);
    int n = int(TriCounter.quadCount);
    if (i >= n - 1) return;

    uint ki = keys[i];

    int d = sign(delta(i, ki, i + 1, n) - delta(i, ki, i - 1, n));
    int dmin = delta(i, ki, i - d, n);

    int lmax = 2;
    while (delta(i, ki, i + lmax * d, n) > dmin) lmax *= 2;

    int l = 0;
    for (int t = lmax / 2; t >= 1; t /= 2)
        if (delta(i, ki, i + (l + t) * d, n) > dmin) l += t;
    int j = i + l * d;

    int dnode = delta(i, ki, j, n);
    int s = 0;
    int t = l;
    do {
        t = (t + 1) >> 1;
        if (delta(i, ki, i + (s + t) * d, n) > dnode) s += t;
    } while (t > 1);

    int gamma = i + s * d + min(d, 0);

    uint cl = (min(i, j) == gamma)? uint(n - 1 + gamma) : uint(gamma);
    uint cr = (max(i, j) == gamma + 1)? uint(n - 1 + gamma + 1) : uint(gamma + 1);

    childOf[i] = uvec2(cl, cr);
    parentOf[cl] = uint(i);
    parentOf[cr] = uint(i);
}