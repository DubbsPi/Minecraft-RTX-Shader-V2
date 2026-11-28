#ifndef INCLUDE_DENOISE
#define INCLUDE_DENOISE

uniform sampler2D colortex1;  // opaque normals
uniform sampler2D colortex3;  // pbr material data

#include "common.glsl"


uniform sampler2D colortex4;  // reflection weight
uniform sampler2D colortex5;  // translucent tint
uniform sampler2D colortex6;  // translucent normal
uniform sampler2D colortex7;  // reflection depth

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;


uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float viewWidth;
uniform float viewHeight;

uniform int frameCounter;


#define viewSize vec2(viewWidth, viewHeight)

#include "settings.glsl"


bool hasTranslucentSurface(in ivec2 px) {
    vec3 n = texelFetch(colortex6, px, 0).xyz;
    return dot(n, n) >= 0.25;
}

vec3 getDenoiseNormal(in ivec2 px) {
    vec3 translucentNormal = texelFetch(colortex6, px, 0).xyz;
    return hasTranslucentSurface(px)? normalize(translucentNormal) : getNormal(px);
}

float getDenoiseDepth(in ivec2 px) {
    return hasTranslucentSurface(px)
        ? texelFetch(depthtex1, px, 0).r
        : texelFetch(depthtex0, px, 0).r;
}

float getDenoiseRoughness(in ivec2 px) {
    vec4 translucentData = texelFetch(colortex6, px, 0);
    return translucentData.w >= 1.5? WATER_ROUGHNESS : getRoughness(px);
}


vec3 getViewPos(in vec2 uv, in float depth) {
    vec4 p = gbufferProjectionInverse * vec4(vec3(uv, depth) * 2.0 - 1.0, 1.0);
    return p.xyz / p.w;
}


vec2 octEncode(in vec3 n) {
    n /= (abs(n.x) + abs(n.y) + abs(n.z));
    vec2 s = vec2(n.x >= 0.0? 1.0 : -1.0, n.y >= 0.0? 1.0 : -1.0);
    vec2 e = n.z >= 0.0? n.xy : (1.0 - abs(n.yx)) * s;
    return e * 0.5 + 0.5;
}

vec3 octDecode(in vec2 f) {
    f = f * 2.0 - 1.0;
    vec3 n = vec3(f, 1.0 - abs(f.x) - abs(f.y));
    float t = max(-n.z, 0.0);
    n.xy += vec2(n.x >= 0.0? -t : t, n.y >= 0.0? -t : t);
    return normalize(n);
}


#endif