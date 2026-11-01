#ifndef INCLUDE_RTX
#define INCLUDE_RTX


#include "vertex_util.glsl"


#define MAX_BRUTE_FORCE_TESTS 4096


bool intersectTriangle(in vec3 ro, in vec3 rd, in vec3 a, in vec3 b, in vec3 c, out float t, out vec2 uv) {
    vec3 e1 = b - a;
    vec3 e2 = c - a;

    vec3 p = cross(rd, e2);
    float det = dot(e1, p);

    if (abs(det) < 1e-8) return false;
    
    float invDet = 1.0 / det;
    vec3 s = ro - a;
    float u = dot(s, p) * invDet;

    if (u < 0.0 || u > 1.0) return false;

    vec3 q = cross(s, e1);
    float v = dot(rd, q) * invDet;

    if (v < 0.0 || u + v > 1.0) return false;

    t = dot(e2, q) * invDet;
    uv = vec2(u, v);
    return t > 0.0;
}


bool bruteForceTrace(in vec3 ro, in vec3 rd,
    out float closestT, out vec2 uv,
    out uint hitIdx, out bool first
 ) {
    closestT = 1e20;
    bool hit = false;
    uint qc = TriCounter.quadCount;

    for (uint i = 0; i < MAX_BRUTE_FORCE_TESTS; ++i) {
        if (i > qc) break;

        vec3 v[4];
        getQuadPos(i, v);

        float t1; vec2 uv1;
        bool hit1 = intersectTriangle(ro, rd, v[0], v[1], v[2], t1, uv1);

        if (hit1 && t1 < closestT) {
            hit = true;
            closestT = t1;
            uv = uv1;
            hitIdx = i;
            first = true;
            continue;
        }

        float t2; vec2 uv2;
        bool hit2 = intersectTriangle(ro, rd, v[2], v[3], v[0], t2, uv2);

        if (hit2 && t2 < closestT) {
            hit = true;
            closestT = t2;
            uv = uv2;
            hitIdx = i;
            first = false;
        }
    }

    return hit;
}


#endif