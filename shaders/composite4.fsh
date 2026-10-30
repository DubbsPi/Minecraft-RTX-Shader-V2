#version 430 compatibility


uniform sampler2D colortex1;  // view space normal
uniform sampler2D colortex4;  // reflections
uniform sampler2D colortex6;  // translucent normal and material tag
uniform sampler2D depthtex0;

uniform mat4 gbufferProjectionInverse;
uniform float viewWidth;
uniform float viewHeight;


#ifndef STEP
#define STEP 1
#endif
//#define DEBUG_DENOISE


in vec2 texcoord;

/* RENDERTARGETS: 4 */
layout(location = 0) out vec4 outColor;


const float kernel[5] = float[](
    1.0 / 16.0, 1.0 / 4.0, 3.0 / 8.0, 1.0 / 4.0, 1.0 / 16.0
);


vec3 viewPosFrom(in ivec2 px, in float depth) {
    vec2 uv = (vec2(px) + 0.5) / vec2(viewWidth, viewHeight);
    vec4 p = gbufferProjectionInverse * vec4(vec3(uv, depth) * 2.0 - 1.0, 1.0);
    return p.xyz / p.w;
}


void main() {
    ivec2 px = ivec2(gl_FragCoord.xy);
    ivec2 maxPx = ivec2(viewWidth, viewHeight) - 1;

    float cDepth = texelFetch(depthtex0, px, 0).r;
    vec4 cSample = texelFetch(colortex4, px, 0);
    vec4 cWater = texelFetch(colortex6, px, 0);
    bool cIsWater = cWater.w >= 1.5;

    float roughness = cSample.a;
    if (cDepth >= 1.0 || (roughness < 0.04)) {outColor = cSample; return;}

    vec3 cN = cIsWater? normalize(cWater.xyz) : normalize(texture(colortex1, texcoord).xyz * 2.0 - 1.0);
    vec3 cPos = viewPosFrom(px, cDepth);

    int stride = max(1, int(float(STEP) * mix(0.5, 1.5, roughness) + 0.5));

    vec3 sum = vec3(0);
    float wSum = 0.0;
    float rejected = 0.0;

    for (int y = -2; y <= 2; y++) {
        for (int x = -2; x <= 2; x++) {
            ivec2 sp = clamp(px + ivec2(x, y) * stride, ivec2(0), maxPx);

            float sDepth = texelFetch(depthtex0, sp, 0).r;
            if (sDepth >= 1.0) continue;

            vec4 sWater = texelFetch(colortex6, sp, 0);
            bool sIsWater = sWater.w >= 1.5;
            if (cIsWater != sIsWater) continue;

            vec3 sN = sIsWater? normalize(sWater.xyz) : normalize(texelFetch(colortex1, sp, 0).xyz * 2.0 - 1.0);
            vec3 sPos = viewPosFrom(sp, sDepth);

            float wN = pow(max(dot(cN, sN), 0.0), 32.0);

            float planeDist = abs(dot(cN, sPos - cPos));
            float wZ = exp(-planeDist / (0.02 * abs(cPos.z) + 1e-4));

            float w = kernel[x + 2] * kernel[y + 2] * wN * wZ;

            sum += texelFetch(colortex4, sp, 0).rgb * w;
            wSum += w;
            rejected += (1.0 - wN * wZ) * kernel[x + 2] * kernel[y + 2];
        }
    }

    vec3 result = wSum > 1e-5? sum / wSum : cSample.rgb;

    #ifdef DEBUG_DENOISE
    result = mix(result, vec3(1, 0, 1), clamp(rejected * 4.0, 0.0, 1.0));
    #endif

    outColor = vec4(result, roughness);
}