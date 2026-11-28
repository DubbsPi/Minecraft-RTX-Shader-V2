#version 430 compatibility

#include "lib/settings.glsl"
#include "lib/random.glsl"
#include "lib/ssr.glsl"
#include "lib/sky.glsl"
#include "lib/pbr.glsl"
#include "lib/common.glsl"

#ifdef RTX_FEATURES
#include "lib/vertex_util.glsl"
#include "lib/rtx.glsl"
#endif


uniform sampler2D colortex0;  // opaque scene
uniform sampler2D colortex1;  // opaque normals
uniform sampler2D colortex4;  // reflection weight
uniform sampler2D colortex5;  // translucent tint
uniform sampler2D colortex6;  // translucent normal
//uniform sampler2D colortex8;  // texture atlas, defined in rtx.glsl
uniform sampler2D colortex9;  // normal atlas
uniform sampler2D colortex10; // specular atlas


uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;

uniform vec3 fogColor;

uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform vec3 shadowLightPosition;

uniform float viewHeight;
uniform float viewWidth;
uniform int frameCounter;


#define REFLECTION_BUFFER
#include "lib/lighting.glsl"


in vec2 texcoord;

/* RENDERTARGETS: 4,7 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 relfDepth;


vec3 skyFromWorld(in vec3 dirW, in vec3 scene) {
    return sampleSky(dirW, moonRelativeDirection(dirW), scene, true);
}

bool traceScreenReflection(in vec3 P, in vec3 N, in vec3 R, in float jitter, in float edgeWidth, out vec3 col, out float fade) {
    col = vec3(0.0);
    fade = 0.0;
    vec2 hitUV;
    if (!traceSSR(P + N * 0.03, R, jitter, hitUV)) return false;

    vec2 e = min(hitUV, 1.0 - hitUV);
    fade = smoothstep(0.0, edgeWidth, min(e.x, e.y));
    col = texture(colortex0, hitUV).rgb;
    return true;
}


#ifdef RTX_FEATURES
    vec3 shadeRTHit(in RTHit hit, in vec3 roW, in vec3 rdW, inout uint rngState) {
        RTSurface s = fetchSurface(hit, rdW);

        vec3 hitPosWorld = roW + rdW * hit.t;
        vec3 viewPos = (gbufferModelView * vec4(hitPosWorld, 1.0)).xyz;
        vec3 nView = normalize(mat3(gbufferModelView) * s.normal);

        PBRMaterial mat;
        if (s.uv.x < 0.0) {
            mat.roughness = 1.0;
            mat.metallic = 0.0;
            mat.f0 = 0.04;
        } else {
            vec4 specular = textureLod(colortex10, s.uv, 0.0);
            mat = getMaterial(vec4(pow(1.0 - specular.r, 2.0), specular.g, 0.0, 1.0));
        }

        vec4 reflWeight = vec4(0);
        return getLighting(s.albedo, nView, viewPos, s.lm, mat, rngState, reflWeight);
    }
#endif

#ifdef RTX_REFLECTIONS
    bool traceRTReflection(in vec3 P, in vec3 N, in vec3 R, in vec3 scene, inout uint rngState, out vec3 refl, out float dist) {
        refl = vec3(0);
        dist = 0.0;

        vec3 roW = (gbufferModelViewInverse * vec4(P + N * 0.03, 1.0)).xyz;
        vec3 rdW = normalize(mat3(gbufferModelViewInverse) * R);
        if (any(greaterThanEqual(abs(roW), vec3(ACTUAL_MAX_DIST)))) return false;

        float tExit = rayExitDist(roW, rdW, ACTUAL_MAX_DIST);
        if (tExit <= 0.1) return false;

        RTHit hit; vec3 trans;
        if (bvhTraceTinted(roW, rdW, tExit, hit, trans)) {
            refl = shadeRTHit(hit, roW, rdW, rngState) * trans;
            dist = hit.t;
        } else {
            refl = skyFromWorld(rdW, scene) * trans;
            dist = tExit;
        }
        return true;
    }
#endif

#ifdef RTX_REFRACTION
    bool traceRTRefraction(in vec3 P, in vec3 Rr, in vec3 scene, inout uint rngState, out vec3 behind, out float thick) {
        behind = vec3(0);
        thick = 32.0;

        vec3 roW = (gbufferModelViewInverse * vec4(P + Rr * 0.01, 1.0)).xyz;
        vec3 rdW = normalize(mat3(gbufferModelViewInverse) * Rr);
        if (any(greaterThanEqual(abs(roW), vec3(ACTUAL_MAX_DIST)))) return false;

        float tExit = rayExitDist(roW, rdW, ACTUAL_MAX_DIST);
        if (tExit <= 0.1) return false;

        RTHit hit;
        vec3 trans;
        if (bvhTraceTinted(roW, rdW, tExit, hit, trans)) {
            behind = shadeRTHit(hit, roW, rdW, rngState) * trans;
            thick = hit.t;
        } else {
            behind = skyFromWorld(rdW, scene);
        }
        return true;
    }
#endif


void main() {
    uint rngState = randInt(uvec2(gl_FragCoord.xy), uvec2(viewWidth, viewHeight), uint(frameCounter));

    vec4 nd = texture(colortex6, texcoord);
    bool translucent = dot(nd.xyz, nd.xyz) >= 0.25;
    float d0 = texture(depthtex0, texcoord).r;
    outColor = vec4(0);
    relfDepth = vec4(1, 0, 0, 1);

    vec4 rw = vec4(0);
    if (!translucent) {
        rw = texture(colortex4, texcoord);
        if (d0 >= 1.0 || luma(rw.rgb) <= 0.01) {
            outColor = vec4(0, 0, 0, rw.a);
            return;
        }
        relfDepth = vec4(d0, 0, 1, 1);
    }

    vec3 scene = vec3(0);
    vec4 tr = vec4(0);
    float d1 = d0;
    if (translucent) {
        scene = texture(colortex0, texcoord).rgb;
        tr = texture(colortex5, texcoord);
        d1 = texture(depthtex1, texcoord).r;

        #if WATER_DEBUG == 1
            outColor = vec4(tr.rgb, 1.0); return;
        #elif WATER_DEBUG == 2
            outColor = vec4(nd.xyz * 0.5 + 0.5, 1.0); return;
        #elif WATER_DEBUG == 3
            outColor = vec4(vec3(nd.w / 3.0), 1.0); return;
        #elif WATER_DEBUG == 4
            outColor = vec4(scene, 1.0); return;
        #elif WATER_DEBUG == 5
            outColor = vec4(vec3(d0 != d1? 1.0 : 0.0), 1.0); return;
        #endif
    }

    vec3 P = toView(texcoord, d0);
    vec3 V = normalize(-P);
    vec3 N;
    vec3 R;
    bool doTrace = true;

    if (translucent) {
        N = normalize(nd.xyz);
        R = reflect(-V, N);
    } else {
        N = normalize(texture(colortex1, texcoord).xyz * 2.0 - 1.0);

        float alpha = max(rw.a * rw.a, 1e-6);
        vec3 up = abs(N.z) < 0.999? vec3(0, 0, 1) : vec3(1, 0, 0);
        vec3 T = normalize(cross(up, N));
        vec3 B = cross(N, T);
        vec3 Ve = vec3(dot(V, T), dot(V, B), dot(V, N));
        vec3 Hl = sampleGGXVNDF(Ve, alpha, vec2(rand(rngState), rand(rngState)));
        vec3 H = T * Hl.x + B * Hl.y + N * Hl.z;
        R = reflect(-V, H);
        if (dot(R, N) <= 0.0) R = reflect(-V, N);

        doTrace = rw.a < SSR_MAX_ROUGHNESS;
    }


    float edgeWidth = translucent? 0.1 : 0.05;
    vec3 ssCol = vec3(0);
    float ssFade = 0.0;
    bool rtUsed = false;
    vec3 rtCol = vec3(0);
    float rtDist = 0.0;

    #ifdef SSR_FIRST
        if (doTrace && R.z < 0.0) traceScreenReflection(P, N, R, rand(rngState), edgeWidth, ssCol, ssFade);
    #endif

    #ifdef RTX_REFLECTIONS
        if (doTrace && ssFade < 1.0) rtUsed = traceRTReflection(P, N, R, scene, rngState, rtCol, rtDist);
    #endif

    #ifndef SSR_FIRST
        if (doTrace && !rtUsed) traceScreenReflection(P, N, R, rand(rngState), edgeWidth, ssCol, ssFade);
    #endif

    vec3 baseCol = vec3(0);
    if (rtUsed) {
        baseCol = rtCol;
        float virtDist = min(length(P) + rtDist, VIRT_MAX);
        relfDepth = vec4(virtDist / VIRT_MAX, translucent? 0.0 : 1.0, 0, 1);
    } else if (ssFade < 1.0) {
        baseCol = skyFromWorld(normalize(mat3(gbufferModelViewInverse) * R), scene);
    }
    vec3 refl = mix(baseCol, ssCol, ssFade);

    if (!translucent) {
        outColor = vec4(refl * rw.rgb, rw.a);
        return;
    }


    // Water/glass
    bool isWater = nd.w >= 1.5;
    bool waterViewedFromBelow = isWater && dot(N, V) < 0.0;
    float skyL = isWater? nd.w - 2.0 : nd.w;
    float NdotV = max(abs(dot(N, V)), 1e-3);

    float day = smoothstep(-0.1, 0.25, dot(normalize(sunPosition), normalize(upPosition)));

    // Refraction
    float t0 = (d1 >= 1.0)? 32.0 : distance(P, toView(texcoord, d1));
    float ior = isWater
        ? (waterViewedFromBelow? WATER_IOR : 1.0 / WATER_IOR)
        : 1.0 / 1.5;
    vec3 refractionNormal = waterViewedFromBelow? -N : N;
    vec3 Rr = refract(-V, refractionNormal, ior);
    bool tir = dot(Rr, Rr) <= 0.0;  // Total internal reflection

    vec2 uvR = texcoord;
    bool ssRefractOK = false;

    #ifdef SS_REFRACTION_FIRST
        if (!tir) {
            vec2 u = viewToScreen(P + Rr * t0).xy;
            bool onScreen = all(greaterThan(u, vec2(0.0))) && all(lessThan(u, vec2(1.0)));
            if (onScreen && viewZ(texture(depthtex0, u).r) <= viewZ(d0) + 0.5) {
                uvR = u;
                ssRefractOK = true;
            }
        }
    #endif

    float thick = 32.0;
    vec3 behind = vec3(0);
    bool refractionDone = false;

    #if defined RTX_REFRACTION && defined RTX_FEATURES
        if (!tir && !ssRefractOK) refractionDone = traceRTRefraction(P, Rr, scene, rngState, behind, thick);
    #endif

    if (!refractionDone) {
        float dR = texture(depthtex1, uvR).r;
        thick = (dR >= 1.0)? 32.0 : distance(P, toView(uvR, dR));
        behind = texture(colortex0, uvR).rgb;
    }

    // Transmission
    vec3 tint = tr.a > 0.001? pow(tr.rgb / tr.a, vec3(2.2)) : vec3(1);
    vec3 transmitted;
    if (isWater) {
        vec3 sigma = (vec3(1.0) - tint) * WATER_DENSITY;
        vec3 T = exp(-sigma * thick);
        vec3 scatter = tint * mix(0.02, 0.30, day) * skyL;
        transmitted = behind * T + scatter * (vec3(1.0) - T);
    } else {
        transmitted = behind * mix(vec3(1.0), tint, tr.a);
    }

    // Fresnel
    float F0 = isWater? 0.02 : 0.04;
    float F = fresnelSchlick(NdotV, vec3(F0)).x;
    if (isWater) F = clamp(F * WATER_REFLECTION_STRENGTH, 0.0, 1.0);
    if (tir) F = 1.0;  // nothing gets through, it's all mirror

    // Glint
    vec3 L = normalize(shadowLightPosition);
    PBRMaterial wm;
    wm.roughness = WATER_ROUGHNESS;
    wm.metallic  = 0.0;
    wm.f0 = F0;
    Lobes lb = evalLobes(N, V, L, wm, vec3(0), vec3(F0));


    vec3 sunE = sunTransmittance(sunDirW, cameraPosition.y) * PI;
    vec3 glint = lb.spec * sunE * max(dot(N, L), 0.0) * skyL * skyL;

    vec3 color = transmitted * (1.0 - F) + refl * F + glint;

    #if WATER_DEBUG == 6
        bool bad = any(isnan(color)) || any(isinf(color)) || any(lessThan(color, vec3(-0.001))) || any(greaterThan(color, vec3(500.0)));
        outColor = vec4(bad? vec3(1.0, 0.0, 1.0) : color, wm.roughness);
    #else
        outColor = vec4(color, wm.roughness);
    #endif
}
