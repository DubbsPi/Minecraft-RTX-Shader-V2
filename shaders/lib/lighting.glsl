#ifndef INCLUDE_LIGHTING
#define INCLUDE_LIGHTING


#include "settings.glsl"
#include "pbr.glsl"
#include "random.glsl"
#include "shadow_util.glsl"
#include "random.glsl"
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
    vec3 shadow;
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


vec3 getLighting(
    in vec3 albedo, in vec3 N, in vec3 P,
    in vec2 lightmap, in PBRMaterial mat,
    inout uint rngState,
    out vec4 reflectionWeight
 ) {
    vec3 V = normalize(-P);
    vec3 L = normalize(shadowLightPosition);

    float NdotV = max(dot(N, V), 1e-4);
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
    #ifndef RTX_SHADOWS
        shadow = getNormalShadows(P, N, rngState);
    #else
        vec3 roW = (gbufferModelViewInverse * vec4(P + N * 0.01, 1)).xyz;
        vec3 rdW = jitterRaySun(sunDirW, rngState);

        ivec2 px = ivec2(gl_FragCoord.xy);

        bool occluded = rawNdotL < 0.0;
        shadow = occluded? vec3(0) : bvhTintedShadow(roW, rdW, MAX_DIST);
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
    vec3 ambientDiffuse = albedo * (1.0 - mat.metallic) * (vec3(1.0) - envBRDF) * ambientColor * skyLight;

    // Block lighting
    vec3 blockLightColor = vec3(1.0, 0.6, 0.3);
    vec3 indirectBlockLight = albedo * mix(1.0, 0.35, mat.metallic) * blockLightColor * blockLight * 2.0;


    // Combine lighting
    vec3 color = ambientDiffuse + indirectBlockLight + directDiffuse + directSpecular + directSSS;
    color += albedo * 0.01;

    // Distance fog
    float fogAmount = smoothstep(
        0.75,
        1.0,
        length(P) / max(far, 1e-3)
    );

    vec3 fogColorLinear = pow(
        max(fogColor, vec3(0.0)),
        vec3(2.2)
    );

    color = mix(color, fogColorLinear, fogAmount);

    float reflectionMask = mat.roughness < SSR_MAX_ROUGHNESS ? 1.0 : 0.0;
    reflectionWeight = vec4(
        clamp(envBRDF * (1.0 - fogAmount) * reflectionMask, 0.0, 1.0),
        mat.roughness
    );

    return color;
}


#endif