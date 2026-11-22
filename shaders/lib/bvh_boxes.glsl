#ifndef INCLUDE_BVH_BOXES
#define INCLUDE_BVH_BOXES


#include "bvh_util.glsl"


layout(std430, binding = 2) restrict readonly buffer SortVals { uint vals[]; };
#ifdef BOXES_WRITE
    layout(std430, binding = 6) coherent buffer Boxes { float nodeBox[]; };
#else
    layout(std430, binding = 6) restrict readonly buffer Boxes { float nodeBox[]; };
#endif


void loadBox(in uint i, in out vec3 lo, in out vec3 hi) {
    uint b = i * 6u;
    lo = vec3(nodeBox[b], nodeBox[b + 1u], nodeBox[b + 2u]);
    hi = vec3(nodeBox[b + 3u], nodeBox[b + 4u], nodeBox[b + 5u]);
}

#ifdef BOXES_WRITE
    void storeBox(in uint i, in vec3 lo, in vec3 hi) {
        uint b = i * 6u;
        nodeBox[b] = lo.x; nodeBox[b + 1u] = lo.y; nodeBox[b + 2u] = lo.z;
        nodeBox[b + 3u] = hi.x; nodeBox[b + 4u] = hi.y; nodeBox[b + 5u] = hi.z;
    }
#endif

void nodeBounds(in uint id, in uint n, in out vec3 lo, in out vec3 hi) {
    if (id >= n - 1u) quadBounds(vals[id - (n - 1u)], lo, hi);
    else loadBox(id, lo, hi);
}


#endif