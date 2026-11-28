#ifndef INCLUDE_LIGHTING
#define INCLUDE_LIGHTING


#include "settings.glsl"
#include "pbr.glsl"
#include "random.glsl"
#include "shadow_util.glsl"
#include "rtx.glsl"


vec3 jitterRaySun(in vec3 rd, inout uint rngState) {
    const float maxAngleRad = radians(SUN_RADIUS_DEG);

    float u1 = rand(rngState);
    float u2 = rand(rngState);

    const float cosAngle = mix(1.0, cos(maxAngleRad), u1);
    const float sinAngle = sqrt(max(0.0, 1.0 - cosAngle * cosAngle));
    float phi = TAU * u2;
    
    vec3 localDir = vec3(cos(phi) * sinAngle, sin(phi) * sinAngle, cosAngle);
    vec3 up = abs(rd.y) < 0.999? vec3(0, 1, 0) : vec3(1, 0, 0);
    vec3 tangent = normalize(cross(up, rd));
    vec3 bitangent = cross(rd, tangent);
    
    return normalize(tangent * localDir.x + bitangent * localDir.y + rd * localDir.z);
}

vec3 getNormalShadows(in vec3 P, in vec3 N, inout uint rngState) {
    vec3 shadow = vec3(1);
    vec3 shadowWorldPos = (gbufferModelViewInverse * vec4(P, 1.0)).xyz;
    #ifdef PIXELATED_SHADOWS
        vec3 worldNormal = normalize(mat3(gbufferModelViewInverse) * N);
        shadowWorldPos = snapToShadowGrid(shadowWorldPos, worldNormal);
    #endif

    vec3 shadowViewPos = (shadowModelView * vec4(shadowWorldPos, 1.0)).xyz;
    vec3 shadowClipPos = projectAndDivide(shadowProjection, shadowViewPos);

    bool inShadowMap = all(lessThan(abs(shadowClipPos.xy), vec2(0.95)));

    shadowClipPos.z -= 0.001;  // Bias
    if (inShadowMap) {
        #ifdef VARIABLE_PENUMBRA_SHADOWS
            shadow = getPCSSShadow(shadowClipPos, rand(rngState));
        #else
            shadow = getSoftShadow(shadowClipPos, FIXED_SHADOW_RADIUS, rand(rngState));
        #endif
    }
    return shadow;
}


bool shadowMapSaysClear(in vec3 worldPos, in vec3 sunN, in float rawNdotL) {
    ivec2 res = textureSize(shadowtex0, 0);
    float halfExtent = 1.0 / abs(shadowProjection[0][0]);
    float texelWorld = 2.0 * halfExtent / float(res.x);
    float depthScale = 2.0 / abs(shadowProjection[2][2]);

    vec3 p = worldPos + sunN * texelWorld;
    vec3 clip = projectAndDivide(shadowProjection, (shadowModelView * vec4(p, 1)).xyz);
    if (any(greaterThan(abs(clip.xy), vec2(0.9)))) return false;

    vec3 sc = clip * 0.5 + 0.5;
    vec2 tp = sc.xy * vec2(res);
    ivec2 base = ivec2(floor(tp));
    vec2 inTexel = tp - vec2(base);

    float c = max(abs(rawNdotL), 0.1);
    float tanTheta = sqrt(max(1.0 - c * c, 0.0)) / c;
    float baseBias = texelWorld * (1.5 + 0.5 * min(tanTheta, 4.0));

    const int R = CULL_TAP_RADIUS;
    for (int j = -R; j <= R; j++) {
        for (int i = -R; i <= R; i++) {
            vec2 gap = max(abs(vec2(i, j) + 0.5 - inTexel) - 0.5, 0.0);
            float o = length(gap) * texelWorld;
            float d = texelFetch(shadowtex0, base + ivec2(i, j), 0).r;
            if ((sc.z - d) * depthScale > baseBias) return false;
        }
    }
    return true;
}


vec3 getLightingV(
    in vec3 albedo, in vec3 N, in vec3 P, in vec3 V,
    in vec2 lightmap, in PBRMaterial mat,
    inout uint rngState,
    out vec4 reflectionWeight
 ) {
    vec3 L = normalize(shadowLightPosition);
    vec3 lightDirW = normalize(mat3(gbufferModelViewInverse) * L);

    float NdotV = max(dot(N, V), 1e-3);
    
    float rawNdotL = dot(N, L);
    float NdotL = max(rawNdotL, 0.0);

    // Day/night
    float sunUp = dot(normalize(sunPosition), normalize(upPosition));
    float day = smoothstep(-0.1, 0.25, sunUp);

    // Lightmap
    float skyLight = lightmap.y * lightmap.y;
    float blockLight = pow(lightmap.x, 3.0);

    vec3 F0 = mix(vec3(mat.f0), albedo, mat.metallic);

    // Sun/moon light
    vec3 lightDirectionW = day > 0.0? sunDirW : moonDirW;
    vec3 lightTransmittance = sunTransmittance(lightDirectionW, cameraPosition.y);

    float lightIntensity = max(day, 0.1);
    if (day <= 0.0) lightIntensity *= moonPhaseMult;
    vec3 lightEnergy = lightTransmittance * PI * skyLight * lightIntensity;

    // Shadow calculation
    vec3 shadow = vec3(1);
    bool traced = false;
    #if !defined REFLECTION_BUFFER || defined RTX_REFLECTION_SHADOWS
        #if defined RTX_SHADOWS && defined RTX_FEATURES
            vec3 worldPos = (gbufferModelViewInverse * vec4(P, 1.0)).xyz;
            vec3 worldN = normalize(mat3(gbufferModelViewInverse) * N);

            bool sunOnFront = rawNdotL >= 0.0;
            vec3 sunN = sunOnFront? worldN : -worldN;
            bool wantsSSS = SSS_STRENGTH > 0.0;

            #ifdef PIXELATED_SHADOWS
                worldPos = snapToShadowGrid(worldPos, sunN);
            #endif

            bool needsTrace = true;
            if (!sunOnFront && !wantsSSS) {shadow = vec3(0); needsTrace = false;}
            else if (abs(rawNdotL) <= 0.0) {shadow = vec3(1); needsTrace = false;}
            else if (skyLight < 0.003) {shadow = vec3(1); needsTrace = false;}
            #ifdef RTX_SHADOW_CULLING
                else if (shadowMapSaysClear(worldPos, sunN, rawNdotL)) {shadow = vec3(1); needsTrace = false;}
            #endif

            if (needsTrace) {
                vec3 accumulatedShadow = vec3(0);
                for (int i = 0; i < RTX_SHADOW_SAMPLES; ++i) {
                    traced = true;
                    vec3 roW = worldPos + sunN * 0.01;
                    #ifdef PIXELATED_SHADOWS
                        uvec3 cell = uvec3(ivec3(floor(worldPos * float(SHADOW_PIXELS_PER_BLOCK))) + 100000);
                        uint cellSeed = cell.x * 1973u ^ cell.y * 9277u ^ cell.z * 26699u;
                        cellSeed ^= uint(frameCounter) * 747796405u;
                        vec3 rdW = jitterRaySun(lightDirW, cellSeed);
                    #else
                        vec3 rdW = jitterRaySun(lightDirW, rngState);
                    #endif
                    accumulatedShadow += bvhTintedShadow(roW, rdW, MAX_DIST);
                }
                shadow = accumulatedShadow / float(RTX_SHADOW_SAMPLES);
            }
        #else
            shadow = getNormalShadows(P, N, rngState);
        #endif
    #endif


    Lobes lobes = evalLobes(N, V, L, mat, albedo, F0);

    // Direct
    vec3 directDiffuse = lobes.diffuse * lightEnergy * NdotL * shadow;
    vec3 directSpecular = lobes.spec * lightEnergy * NdotL * shadow;

    // SSS
    float backFacing = max(-rawNdotL, 0.0);
    backFacing *= backFacing;
    vec3 directSSS = albedo * (SSS_STRENGTH * INV_PI) * backFacing * lightEnergy * shadow;

    // Ambient lighting
    vec3 ambientColor = mix( vec3(0.02, 0.03, 0.06), vec3(0.35, 0.45, 0.65), day);
    vec3 envBRDF = envBRDFApprox(F0, mat.roughness, NdotV);
    vec3 ambientDiffuse = albedo * (1.0 - mat.metallic) * max(vec3(1) - envBRDF, vec3(0)) * ambientColor * skyLight;

    // Block lighting
    vec3 blockLightColor = vec3(1, 0.6, 0.3);
    vec3 indirectBlockLight = albedo * mix(1.0, 0.35, mat.metallic) * blockLightColor * blockLight * 2.0;


    // Combine lighting
    vec3 color = ambientDiffuse + indirectBlockLight + directDiffuse + directSpecular + directSSS;
    color += albedo * 0.01;

    // Distance fog
    float fogAmount = smoothstep(0.75, 1.0, length(P) / max(far, 1e-3));

    vec3 fogColorLinear = pow(max(fogColor, vec3(0)), vec3(2.2));
    color = mix(color, fogColorLinear, fogAmount);

    float reflectionMask = mat.roughness < SSR_MAX_ROUGHNESS? 1.0 : 0.0;
    reflectionWeight = vec4(clamp(envBRDF * (1.0 - fogAmount) * reflectionMask, 0.0, 1.0), mat.roughness);

    #ifdef DEBUG_RT_CULL
        color = mix(color, traced? vec3(1, 0.2, 0.2) : vec3(0.2, 1, 0.2), 0.4);
    #endif

    return color;
}


vec3 getLighting(
    in vec3 albedo, in vec3 N, in vec3 P,
    in vec2 lightmap, in PBRMaterial mat,
    inout uint rngState,
    out vec4 reflectionWeight
 ) {
    return getLightingV(albedo, N, P, normalize(-P), lightmap, mat, rngState, reflectionWeight);
}


#endif