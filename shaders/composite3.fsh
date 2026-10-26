#version 430 compatibility

#include "lib/settings.glsl"
#include "lib/common.glsl"


uniform sampler2D colortex0;  // albedo
uniform sampler2D colortex7;  // history
uniform sampler2D depthtex0;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float viewWidth;
uniform float viewHeight;
uniform int frameCounter;


in vec2 texcoord;

/* RENDERTARGETS: 0,7 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outHistory;


vec3 compress(in vec3 c) { return c / (1.0 + luma(c)); }
vec3 decompress(in vec3 c) { return c / max(1.0 - luma(c), 1e-4); }


vec3 projDiv(in mat4 m, in vec3 p) {
    vec4 h = m * vec4(p, 1.0);
    return h.xyz / h.w;
}

vec2 reproject(in vec2 uv, in float depth) {
    vec3 view = projDiv(gbufferProjectionInverse, vec3(uv, depth) * 2.0 - 1.0);
    vec3 rel  = (gbufferModelViewInverse * vec4(view, 1)).xyz;
    if (depth < 1.0) rel += cameraPosition - previousCameraPosition;
    vec3 prevView = (gbufferPreviousModelView * vec4(rel, 1)).xyz;
    if (prevView.z >= 0.0) return vec2(-1);
    return projDiv(gbufferPreviousProjection, prevView).xy * 0.5 + 0.5;
}


void main() {
    ivec2 size  = ivec2(viewWidth, viewHeight);
    ivec2 px = ivec2(gl_FragCoord.xy);
    float depth = texelFetch(depthtex0, px, 0).r;

    vec3 cur = compress(texelFetch(colortex0, px, 0).rgb);


    vec3 m1 = vec3(0), m2 = vec3(0), mn = vec3(1e9), mx = vec3(-1e9);
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            ivec2 p = clamp(px + ivec2(x, y), ivec2(0), size - 1);
            vec3 c = compress(texelFetch(colortex0, p, 0).rgb);
            m1 += c; m2 += c * c;
            mn = min(mn, c); mx = max(mx, c);
        }
    }
    vec3 mean  = m1 / 9.0;
    vec3 sigma = sqrt(max(m2 / 9.0 - mean * mean, 0.0));
    vec3 lo = max(mn, mean - VARIANCE_GAMMA * sigma);
    vec3 hi = min(mx, mean + VARIANCE_GAMMA * sigma);

    bool isHand = depth < 0.56;
    vec2 prevUV = isHand ? texcoord : reproject(texcoord, depth);

    bool valid = frameCounter > 0 && all(greaterThanEqual(prevUV, vec2(0))) && all(lessThan(prevUV, vec2(1)));

    vec3 hist = clamp(compress(texture(colortex7, prevUV).rgb), lo, hi);


    float velPx = length((prevUV - texcoord) * vec2(size));
    float blend = mix(BASE_BLEND, 0.4, clamp(velPx / 8.0, 0.0, 1.0));
    if (!valid) blend = 1.0;

    vec3 result = decompress(mix(hist, cur, blend));
    outColor = vec4(result, 1);
    outHistory = vec4(result, 1);
}
