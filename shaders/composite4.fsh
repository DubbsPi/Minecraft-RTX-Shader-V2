#version 430 compatibility
#include "/lib/denoise.glsl"


#ifndef ATROUS_STEP
#define ATROUS_STEP 1
#endif

#define SIGMA_N 48.0
#define SIGMA_L 3.0


in vec2 texcoord;

/* RENDERTARGETS: 4 */
layout(location = 0) out vec4 outRefl;


const float K[3] = float[](1.0, 2.0 / 3.0, 1.0 / 6.0);


void main() {
    ivec2 px = ivec2(gl_FragCoord.xy);
    ivec2 maxP = ivec2(viewSize) - 1;
    vec4 c0 = texelFetch(colortex4, px, 0);
    float depth = getDenoiseDepth(px);
    float rough = getDenoiseRoughness(px);
    bool translucent = hasTranslucentSurface(px);

    if (depth >= 1.0 || rough < 0.02) { outRefl = c0; return; }

    vec3 n = getDenoiseNormal(px);
    vec3 pos = getViewPos(texcoord, depth);
    float dist = length(pos);
    float lum0 = luma(c0.rgb);

    float var = 0.0;
    for (int y = -1; y <= 1; y++)
    for (int x = -1; x <= 1; x++) {
        float k = (x == 0 ? 0.5 : 0.25) * (y == 0 ? 0.5 : 0.25);
        var += k * texelFetch(colortex4, clamp(px + ivec2(x, y), ivec2(0), maxP), 0).a;
    }
    float sigmaL = SIGMA_L * sqrt(max(var, 0.0)) + 1e-4;

    vec3 sum = vec3(0);
    float vsum = 0.0, wsum = 0.0;

    for (int y = -2; y <= 2; y++)
    for (int x = -2; x <= 2; x++) {
        ivec2 q = px + ivec2(x, y) * ATROUS_STEP;
        if (any(lessThan(q, ivec2(0))) || any(greaterThan(q, maxP))) continue;
        if (hasTranslucentSurface(q) != translucent) continue;

        vec4 cq = texelFetch(colortex4, q, 0);
        float dq = getDenoiseDepth(q);
        if (dq >= 1.0) continue;

        vec3 posq = getViewPos((vec2(q) + 0.5) / viewSize, dq);
        float wN = pow(clamp(dot(n, getDenoiseNormal(q)), 0.0, 1.0), SIGMA_N);
        float wZ = exp(-abs(dot(n, posq - pos)) / (0.01 * dist + 0.02));
        float wL = exp(-abs(lum0 - luma(cq.rgb)) / sigmaL);

        float w = K[abs(x)] * K[abs(y)] * wN * wZ * wL;
        sum += w * cq.rgb;
        vsum += w * w * cq.a;
        wsum += w;
    }

    wsum = max(wsum, 1e-5);
    outRefl = vec4(sum / wsum, vsum / (wsum * wsum));
}