#version 330 compatibility


#define GAMMA_CLIP 2.0
#define DEPTH_TOL 0.05
#define FIREFLY_MAX 8.0


uniform sampler2D colortex4;  // reflections
uniform sampler2D reflectionAccumSampler;

uniform sampler2D depthtex0;


uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform float viewWidth;
uniform float viewHeight;


in vec2 texcoord;

/* RENDERTARGETS: 4 */
layout(location = 0) out vec4 outColor;
layout(rgba16f) uniform image2D reflectionAccum;


vec3 viewPosFrom(vec2 uv, float depth) {
    vec4 p = gbufferProjectionInverse * vec4(vec3(uv, depth) * 2.0 - 1.0, 1.0);
    return p.xyz / p.w;
}


void main() {
    vec2 res = vec2(viewWidth, viewHeight);
    ivec2 px = ivec2(gl_FragCoord.xy);
    ivec2 maxPx = ivec2(res) - 1;

    float depth = texelFetch(depthtex0, px, 0).r;
    vec4 cur = texelFetch(colortex4, px, 0);

    if (depth >= 1.0) {
        outColor = cur;
        imageStore(reflectionAccum, ivec2(gl_FragCoord.xy), vec4(cur.rgb, 0));
        return;
    }

    float roughness = cur.a;
    cur.rgb = min(cur.rgb, vec3(FIREFLY_MAX));

    vec2 uv = (vec2(px) + 0.5) / res;
    vec3 viewPos = viewPosFrom(uv, depth);
    vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz + cameraPosition;

    vec3 prevView = (gbufferPreviousModelView * vec4(worldPos - previousCameraPosition, 1.0)).xyz;
    vec4 prevClip = gbufferPreviousProjection * vec4(prevView, 1.0);
    vec2 prevUV = prevClip.xy / prevClip.w * 0.5 + 0.5;

    float expectedDepth = -prevView.z;

    vec2 prevPx = prevUV * res - 0.5;
    ivec2 base = ivec2(floor(prevPx));
    vec2 f = fract(prevPx);
    float bw[4] = float[]((1.0 - f.x) * (1.0 - f.y), f.x * (1.0 - f.y), (1.0 - f.x) * f.y, f.x * f.y);

    vec3 histSum = vec3(0);
    float histW = 0.0;

    for (int i = 0; i < 4; i++) {
        ivec2 tp = base + ivec2(i & 1, i >> 1);
        if (any(lessThan(tp, ivec2(0))) || any(greaterThan(tp, maxPx))) continue;

        vec4 h = texelFetch(reflectionAccumSampler, tp, 0);
        if (h.a <= 0.0) continue;

        if (abs(h.a - expectedDepth) > DEPTH_TOL * expectedDepth) continue;

        histSum += h.rgb * bw[i];
        histW += bw[i];
    }

    vec3 result = cur.rgb;

    if (histW > 0.01) {
        vec3 hist = histSum / histW;

        vec3 m1 = vec3(0), m2 = vec3(0);
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                vec3 c = min(texelFetch(colortex4, clamp(px + ivec2(x, y), ivec2(0), maxPx), 0).rgb, vec3(FIREFLY_MAX));
                m1 += c;
                m2 += c * c;
            }
        }
        vec3 mean = m1 / 9.0;
        vec3 sigma = sqrt(max(m2 / 9.0 - mean * mean, 0.0));
        hist = clamp(hist, mean - GAMMA_CLIP * sigma, mean + GAMMA_CLIP * sigma);

        float maxHist = smoothstep(0.05, 0.5, roughness);
        float blend = 1.0 - maxHist * histW;

        result = mix(hist, cur.rgb, blend * 0.05);
    }

    outColor = vec4(result, roughness);
    imageStore(reflectionAccum, ivec2(gl_FragCoord.xy), vec4(result, -viewPos.z));
}