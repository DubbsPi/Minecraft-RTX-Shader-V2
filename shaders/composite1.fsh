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


#include "lib/lighting.glsl"


in vec2 texcoord;

/* RENDERTARGETS: 4,7 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 relfDepth;


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
            outColor = vec4(vec3(d0 != d1 ? 1.0 : 0.0), 1.0); return;
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

    vec3 refl = vec3(0);
    bool outsideRTXRange = true;

    #if defined RTX_REFLECTIONS && defined RTX_FEATURES
        if (doTrace) {
            vec3 roW = (gbufferModelViewInverse * vec4(P + N * 0.03, 1)).xyz;
            vec3 rdW = normalize(mat3(gbufferModelViewInverse) * R);
            if (all(lessThan(abs(roW), vec3(ACTUAL_MAX_DIST)))) {
                float tExit = rayExitDist(roW, rdW, ACTUAL_MAX_DIST);
                float tHit = MAX_DIST;

                if (tExit > 0.1) {
                    outsideRTXRange = false;

                    vec2 hitUV;
                    uint triIdx; bool first; vec3 trans;
                    bool hit = bvhTraceTinted(roW, rdW, tExit, tHit, hitUV, triIdx, first, trans);

                    if (hit) {
                        vec3 v[4];
                        vec2 triUV[3]; vec4 triGlColor[3];
                        getQuadPos(triIdx, v);
                        getTriAttributes(triIdx, first, triUV, triGlColor);

                        vec3 triPos[3] = first? vec3[](v[0], v[1], v[2]) : vec3[](v[2], v[3], v[0]);

                        float w0 = 1.0 - hitUV.x - hitUV.y;
                        vec2 hitTexcoord = triUV[0] * w0 + triUV[1] * hitUV.x + triUV[2] * hitUV.y;
                        vec4 hitGlColor = triGlColor[0] * w0 + triGlColor[1] * hitUV.x + triGlColor[2] * hitUV.y;
                        vec3 hitPosWorld = roW + rdW * tHit;

                        vec3 albedo = sampleTracedTexture(hitTexcoord, triIdx);
                        albedo *= hitGlColor.rgb;

                        vec3 e1 = triPos[1] - triPos[0];
                        vec3 e2 = triPos[2] - triPos[0];
                        vec3 hitNormalWorld = normalize(cross(e1, e2));
                        if (dot(hitNormalWorld, rdW) > 0.0) hitNormalWorld = -hitNormalWorld;
                        vec3 hitNormalView = normalize(mat3(gbufferModelView) * hitNormalWorld);

                        vec2 lightmap = vec2(0.5);
                        PBRMaterial mat;
                        if (hitTexcoord.x < 0.0) {
                            mat.roughness = 1.0;
                            mat.metallic = 0.0;
                            mat.f0 = 0.04;
                        } else {
                            vec4 specular = textureLod(colortex10, hitTexcoord, 0.0);
                            mat = getMaterial(vec4(pow(1.0 - specular.r, 2.0), specular.g, 0.0, 1.0));
                        }

                        vec3 viewPos = (gbufferModelView * vec4(hitPosWorld, 1)).xyz;
                        vec4 reflWeight = vec4(0);
                            
                        refl = getLighting(
                            albedo, hitNormalView, viewPos,
                            lightmap, mat, rngState,
                            reflWeight
                        ) * trans;

                        float virtDist = min(length(P) + tHit, VIRT_MAX);
                        relfDepth = vec4(virtDist / VIRT_MAX, translucent ? 0.0 : 1.0, 0, 1);
                    } else {
                        vec3 spaceDir = moonRelativeDirection(rdW);
                        refl = sampleSky(rdW, spaceDir, scene, true);
                    }
                } else {
                    vec3 spaceDir = moonRelativeDirection(rdW);
                    refl = sampleSky(rdW, spaceDir, scene, true);
                }

                float virtDist = min(length(P) + tHit, VIRT_MAX);
                relfDepth = vec4(virtDist / VIRT_MAX, translucent? 0.0 : 1.0, 0, 1);
            }
        }

        if (!translucent && !outsideRTXRange) {
            outColor = vec4(refl * rw.rgb, rw.a);
            return;
        }
    #endif
    
    if (outsideRTXRange) {
        bool hit = false;
        vec2 hitUV = vec2(0);
        if (doTrace) hit = traceSSR(P + N * 0.03, R, rand(rngState), hitUV);

        float fade = 0.0;
        if (hit) {
            vec2 e = min(hitUV, 1.0 - hitUV);
            fade = smoothstep(0.0, translucent ? 0.1 : 0.05, min(e.x, e.y));
            refl = texture(colortex0, hitUV).rgb;
        }
        if (!hit || fade < 1.0) {
            vec3 dirW = normalize(mat3(gbufferModelViewInverse) * R);
            vec3 spaceDir = moonRelativeDirection(dirW);
            vec3 sky = sampleSky(dirW, spaceDir, scene, true);
            refl = mix(sky, refl, fade);
        }

        if (!translucent) {
            outColor = vec4(refl * rw.rgb, rw.a);
            return;
        }
    }


    bool isWater = nd.w >= 1.5;
    bool waterViewedFromBelow = isWater && dot(N, V) < 0.0;
    float skyL = isWater ? nd.w - 2.0 : nd.w;
    float NdotV = max(abs(dot(N, V)), 1e-3);


    float day = smoothstep(-0.1, 0.25, dot(normalize(sunPosition), normalize(upPosition)));

    // Refraction
    float t0 = (d1 >= 1.0) ? 32.0 : distance(P, toView(texcoord, d1));
    float ior = isWater
        ? (waterViewedFromBelow? WATER_IOR : 1.0 / WATER_IOR)
        : 1.0 / 1.5;
    vec3 refractionNormal = waterViewedFromBelow ? -N : N;
    vec3 Rr = refract(-V, refractionNormal, ior);

    vec2 uvR = texcoord;
    if (dot(Rr, Rr) > 0.0) {
        vec2 u = viewToScreen(P + Rr * t0).xy;
        bool onScreen = all(greaterThan(u, vec2(0.0))) && all(lessThan(u, vec2(1.0)));
        if (onScreen && viewZ(texture(depthtex0, u).r) <= viewZ(d0) + 0.5) uvR = u;
    }

    float dR = texture(depthtex1, uvR).r;
    float thick = (dR >= 1.0) ? 32.0 : distance(P, toView(uvR, dR));
    vec3 behind = texture(colortex0, uvR).rgb;

    // Transmission
    vec3 tint = tr.a > 0.001 ? pow(tr.rgb / tr.a, vec3(2.2)) : vec3(1);
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
    float F0 = isWater ? 0.02 : 0.04;
    float F = fresnelSchlick(NdotV, vec3(F0)).x;
    if (isWater) F = clamp(F * WATER_REFLECTION_STRENGTH, 0.0, 1.0);

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
