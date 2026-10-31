#ifndef INCLUDE_RTX
#define INCLUDE_RTX


#include "vertex_util.glsl"


vec4 intersectTriangle(in vec3 ro, in vec3 rd, in vec3 a, in vec3 b, in vec3 c) {
    vec3 e1 = b - a;
    vec3 e2 = c - a;

    vec3 p = cross(rd, e2);
    float det = dot(e1, p);

    if (abs(det) < RAY_EPSILON) return vec4(-1);

    float invDet = 1.0 / det;
    vec3 s = ro - a;
    float u = dot(s, p) * invDet;

    if (u < 0.0 || u > 1.0) return vec4(-1);

    vec3 q = cross(s, e1);
    float v = dot(rd, q) * invDet;

    if (v < 0.0 || u + v > 1.0) return vec4(-1);
    
    float t = dot(e2, q) * invDet;

    return vec4(t, u, v, 1.0 - u - v);
}

vec4 intersectQuad(in vec3 ro, in vec3 rd, in uvec2 verts[4]) {
    vec3 a = unpackPos(verts[0]);
    vec3 b = unpackPos(verts[1]);
    vec3 c = unpackPos(verts[2]);

    vec4 hit = intersectTriangle(ro, rd, a, b, c);
    if (hit.x > RAY_EPSILON) return hit;

    vec3 d = unpackPos(verts[3]);
    hit = intersectTriangle(ro, rd, c, d, a);
    if (hit.x > RAY_EPSILON) return hit;

    return vec4(-1);
}


vec4 bruteForceTrace(in vec3 ro, in vec3 rd) {
    const uint CAP = 1024u;
    uint quadCount = min(VertexCounters.vertexCount / 4u, CAP);

    float bestT = 1e18;
    vec4 best = vec4(-1);

    for (uint i = 0u; i < quadCount; ++i) {
        uint base = i * 4u;
        uvec2 verts[4];
        for (uint v = 0u; v < 4u; ++v) verts[v] = VertexPositions.pos[base + v];

        vec4 h = intersectQuad(ro, rd, verts);
        if (h.x > RAY_EPSILON && h.x < bestT) {
            bestT = h.x;
            best = h;
        }
    }
    return best;
}


#endif