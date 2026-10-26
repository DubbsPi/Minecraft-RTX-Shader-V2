#version 430 compatibility

#include "lib/settings.glsl"
#include "lib/random.glsl"
#include "lib/sky.glsl"
#include "lib/pbr.glsl"
#include "lib/ssr.glsl"


uniform sampler2D colortex0;   // opaque scene
uniform sampler2D colortex5;   // translucent tint
uniform sampler2D colortex6;   // translucent normal

uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;

uniform vec3 shadowLightPosition;
uniform vec3 fogColor;
uniform vec3 cameraPosition;

uniform float far;
uniform float viewHeight;
uniform float viewWidth;

uniform int frameCounter;


in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;


//#define WATER_DEBUG 1


void main() {
    uint rngState = randInt(ivec2(gl_FragCoord.xy), ivec2(viewWidth, viewHeight), frameCounter);

    vec3 scene = texture(colortex0, texcoord).rgb;
    vec4 tr = texture(colortex5, texcoord);
    vec4 nd = texture(colortex6, texcoord);

    if (dot(nd.xyz, nd.xyz) < 0.25) {outColor = vec4(scene, 1.0); return;}


    bool isWater = nd.w >= 1.5;
    float skyL = isWater ? nd.w - 2.0 : nd.w;
    vec3 N = normalize(nd.xyz);

    float d0 = texture(depthtex0, texcoord).r;
    float d1 = texture(depthtex1, texcoord).r;

    #if WATER_DEBUG == 1
        outColor = vec4(tr.rgb, 1.0); return;
    #elif WATER_DEBUG == 2
        outColor = vec4(nd.xyz * 0.5 + 0.5, 1.0); return;
    #elif WATER_DEBUG == 3
        outColor = vec4(vec3(nd.w / 3.0), 1.0); return;
    #elif WATER_DEBUG == 4
        outColor = vec4(scene, 1.0); return;
    #elif WATER_DEBUG == 5
        outColor = vec4(vec3(d0 != d1 ? 1.0 : 0.0), 1.0); return;
    #endif
    
    vec3 P = toView(texcoord, d0);
    vec3 V = normalize(-P);
    float NdotV = max(dot(N, V), 1e-3);

    vec3 sunDirW  = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    vec3 moonDirW = normalize(mat3(gbufferModelViewInverse) * moonPosition);
    float day = smoothstep(-0.1, 0.25, dot(normalize(sunPosition), normalize(upPosition)));


    float t0 = (d1 >= 1.0) ? 32.0 : distance(P, toView(texcoord, d1));
    float ior = isWater ? 1.0 / WATER_IOR : 1.0 / 1.5;
    vec3 Rr = refract(-V, N, ior);

    vec2 uvR = texcoord;
    if (dot(Rr, Rr) > 0.0) {
        vec2 u = viewToScreen(P + Rr * t0).xy;
        bool onScreen = all(greaterThan(u, vec2(0.0))) && all(lessThan(u, vec2(1.0)));
        if (onScreen && viewZ(texture(depthtex0, u).r) <= viewZ(d0) + 0.5) uvR = u;
    }

    float dR = texture(depthtex1, uvR).r;
    float thick = (dR >= 1.0) ? 32.0 : distance(P, toView(uvR, dR));
    vec3 behind = texture(colortex0, uvR).rgb;


    vec3 transmitted;
    if (isWater) {
        vec3 tint = pow(tr.rgb, vec3(2.2));
        vec3 sigma = (vec3(1.0) - tint) * WATER_DENSITY;
        vec3 T = exp(-sigma * thick);
        vec3 scatter = tint * mix(0.02, 0.30, day) * skyL;
        transmitted = behind * T + scatter * (vec3(1.0) - T);
    } else {
        vec3 tint = tr.a > 0.001 ? pow(tr.rgb / tr.a, vec3(2.2)) : vec3(1.0);
        transmitted = behind * mix(vec3(1.0), tint, tr.a);
    }


    float F0 = isWater? 0.02 : 0.04;
    float F = fresnelSchlick(NdotV, vec3(F0)).x;

    vec3 R = reflect(-V, N);
    vec2 hitUV;
    bool hit = traceSSR(P + N * 0.03, R, rand(rngState), hitUV);

    vec3 refl = vec3(0.0);
    float fade = 0.0;
    if (hit) {
        vec2 e = min(hitUV, 1.0 - hitUV);
        fade = smoothstep(0.0, 0.1, min(e.x, e.y));
        refl = texture(colortex0, hitUV).rgb;
    }
    if (!hit || fade < 1.0) {
        vec3 dirW = normalize(mat3(gbufferModelViewInverse) * R);
        vec3 skyCol = skyReflection(dirW, sunDirW, moonDirW) * skyL * skyL;
        refl = mix(skyCol, refl, fade);
    }

    vec3 L = normalize(shadowLightPosition);
    PBRMaterial wm;
    wm.roughness = WATER_ROUGHNESS;
    wm.metallic  = 0.0;
    wm.f0 = F0;
    Lobes lb = evalLobes(N, V, L, wm, vec3(0), vec3(F0));
    vec3 sunE = sunTransmittance(sunDirW, cameraPosition.y) * PI;
    vec3 glint = lb.spec * sunE * max(dot(N, L), 0.0) * skyL * skyL;

    vec3 color = transmitted * (1.0 - F) + refl * F + glint;

    float f = smoothstep(0.75, 1.0, length(P) / far);
    
    bool bad = any(isnan(color)) || any(isinf(color)) || any(lessThan(color, vec3(-0.001))) || any(greaterThan(color, vec3(500.0)));

    #if WATER_DEBUG == 6
        outColor = vec4(bad? vec3(1.0, 0.0, 1.0) : color, 1.0);
    #else
        outColor = vec4(bad? scene : color, 1.0);
    #endif
}
