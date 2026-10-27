#version 430 compatibility

#include "lib/settings.glsl"
#include "lib/random.glsl"
#include "lib/sky.glsl"
#include "lib/pbr.glsl"
#include "lib/common.glsl"
#include "lib/ssr.glsl"


uniform sampler2D colortex0;  // scene color
uniform sampler2D colortex1;  // normals
uniform sampler2D colortex2;  // lightmap
uniform sampler2D colortex4;  // reflection weight and roughness


uniform mat4 gbufferModelViewInverse;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform float viewHeight;
uniform float viewWidth;

uniform int frameCounter;


in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;


void main() {
    uint rngState = randInt(ivec2(gl_FragCoord.xy), ivec2(viewWidth, viewHeight), frameCounter);

    vec3 scene = texture(colortex0, texcoord).rgb;
    vec4 rw = texture(colortex4, texcoord);
    float depth = texture(depthtex0, texcoord).r;

    vec3 result = scene;
    vec3 dbg = vec3(0);

    if (depth < 1.0 && luma(rw.rgb) > 0.01) {
        vec3 N = normalize(texture(colortex1, texcoord).xyz * 2.0 - 1.0);
        float skyLight = texture(colortex2, texcoord).y;
        vec3 P = toView(texcoord, depth);
        vec3 V = normalize(-P);

        float rough = rw.a;
        float alpha = max(rough * rough, 1e-3);

        vec3 up = abs(N.z) < 0.999 ? vec3(0, 0, 1) : vec3(1, 0, 0);
        vec3 T = normalize(cross(up, N));
        vec3 B = cross(N, T);
        vec3 Ve = vec3(dot(V, T), dot(V, B), dot(V, N));
        vec3 Hl = sampleGGXVNDF(Ve, alpha, vec2(rand(rngState), rand(rngState)));
        vec3 H = T * Hl.x + B * Hl.y + N * Hl.z;
        vec3 R = reflect(-V, H);
        if (dot(R, N) <= 0.0) R = reflect(-V, N);   // sampled below the surface, fall back to mirror

        bool hit = false;
        vec2 hitUV;
        if (rough < SSR_MAX_ROUGHNESS) {
            hit = traceSSR(P + N * 0.03, R, rand(rngState), hitUV);
        }

        vec3 refl = vec3(0);
        float fade = 0.0;
        if (hit) {
            vec2 e = min(hitUV, 1.0 - hitUV);
            fade = smoothstep(0.0, 0.05, min(e.x, e.y));
            refl = texture(colortex0, hitUV).rgb;
        }

        if (!hit || fade < 1.0) {
            vec3 sunDirW  = normalize(mat3(gbufferModelViewInverse) * sunPosition);
            vec3 moonDirW = normalize(mat3(gbufferModelViewInverse) * moonPosition);
            vec3 dirW = normalize(mat3(gbufferModelViewInverse) * R);
            vec3 skyCol = skyReflection(dirW, sunDirW, moonDirW) * skyLight * skyLight;
            refl = mix(skyCol, refl, fade);
        }

        result = scene + refl * rw.rgb;
        dbg = (hit ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 1.0)) * clamp(luma(rw.rgb) * 4.0, 0.15, 1.0);
    }

    outColor = vec4(result, 1.0);
}
