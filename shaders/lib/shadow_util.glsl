#ifndef INCLUDE_SHADOW_UTIL
#define INCLUDE_SHADOW_UTIL

#include "settings.glsl"
#include "common.glsl"


const float tauForHereOnlyIdkWhyItWontImport = 6.28318530718;  // Self explanitory


uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

uniform mat4 shadowProjection;

uniform vec3 cameraPosition;


vec3 distortShadowClipPos(in vec3 shadowClipPos){
    float distortionFactor = length(shadowClipPos.xy);
    distortionFactor += 0.1;

    shadowClipPos.xy /= distortionFactor;
    shadowClipPos.z *= 0.5;
    return shadowClipPos;
}

vec3 snapToShadowGrid(in vec3 feetPlayerPos, in vec3 worldNormal) {
    const float ppb = float(SHADOW_PIXELS_PER_BLOCK);
    vec3 world = feetPlayerPos + cameraPosition;
    vec3 inside = world - worldNormal * (0.25 / ppb);
    vec3 cell = (floor(inside * ppb) + 0.5) / ppb;
    vec3 snapped = cell + worldNormal * (0.5 / ppb + 0.003);
    return snapped - cameraPosition;
}

float interleavedGradientNoise(in vec2 p) {
    return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

vec2 vogelDisk(in int i, in int n, in float phi) {
    float r = sqrt((float(i) + 0.5) / float(n));
    float theta = float(i) * 2.39996323 + phi;
    return r * vec2(cos(theta), sin(theta));
}


vec3 getShadow(in vec3 shadowScreenPos){
    float transparentShadow = step(shadowScreenPos.z, texture(shadowtex0, shadowScreenPos.xy).r); // sample the shadow map containing everything
    if(transparentShadow == 1.0) return vec3(1);

    float opaqueShadow = step(shadowScreenPos.z, texture(shadowtex1, shadowScreenPos.xy).r);
    if(opaqueShadow == 0.0) return vec3(0);

    vec4 shadowColor = texture(shadowcolor0, shadowScreenPos.xy);
    return shadowColor.rgb * (1.0 - shadowColor.a);
}

vec3 getSoftShadow(in vec3 shadowClipPos, in float radius, in float noise) {
    float phi = noise * tauForHereOnlyIdkWhyItWontImport;
    vec3 sum = vec3(0);

    for (int i = 0; i < SHADOW_SAMPLES; i++) {
        vec3 c = shadowClipPos;
        c.xy += vogelDisk(i, SHADOW_SAMPLES, phi) * radius;
        vec3 s = distortShadowClipPos(c) * 0.5 + 0.5;
        if (any(lessThan(s.xy, vec2(0))) || any(greaterThan(s.xy, vec2(1))) || s.z > 1.0) {
            sum += vec3(1);
            continue;
        }
        sum += getShadow(s);
    }
    return sum / float(SHADOW_SAMPLES);
}


float findBlockerDistance(in vec3 shadowClipPos, in float phi) {
    vec3 distortedReceiver = distortShadowClipPos(shadowClipPos);
    float searchRadius = SEARCH_RADIUS_BLOCKS * abs(shadowProjection[0][0]);

    float sum = 0.0, count = 0.0;
    for (int i = 0; i < PCSS_BLOCKER_SAMPLES; i++) {
        vec3 c = shadowClipPos;
        c.xy += vogelDisk(i, PCSS_BLOCKER_SAMPLES, phi) * searchRadius;
        vec3 distorted = distortShadowClipPos(c);
        vec3 screenPos = distorted * 0.5 + 0.5;
        if (screenPos.x < 0.0 || screenPos.x > 1.0 || screenPos.y < 0.0 || screenPos.y > 1.0) continue;

        float blockerDepth = texture(shadowtex1, screenPos.xy).r * 2.0 - 1.0;
        if (blockerDepth < distortedReceiver.z) {
            sum += blockerDepth;
            count += 1.0;
        }
    }
    if (count == 0.0) return -1.0;

    float blockerClipZ = sum / count;
    return abs((distortedReceiver.z - blockerClipZ) / shadowProjection[2][2]);
}

vec3 getPCSSShadow(in vec3 shadowClipPos, in float noise) {
    float phi = noise * tauForHereOnlyIdkWhyItWontImport;
    float blockerDist = findBlockerDistance(shadowClipPos, phi);
    if (blockerDist < 0.0) return vec3(1);

    float radiusBlocks = clamp(blockerDist * PENUMBRA_SCALE, MIN_RADIUS_BLOCKS, MAX_RADIUS_BLOCKS);
    float radiusClip = radiusBlocks * abs(shadowProjection[0][0]);
    return getSoftShadow(shadowClipPos, radiusClip, noise);
}


float shadowThickness(in vec3 shadowNdc) {
    vec3 sp = shadowNdc * 0.5 + 0.5;
    float blocker = texture(shadowtex0, sp.xy).r;
    float dz = max(sp.z - blocker, 0.0);
    return dz * (2.0 / abs(shadowProjection[2][2]));
}


#endif