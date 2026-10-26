#ifndef INCLUDE_PBR
#define INCLUDE_PBR

#include "common.glsl"


struct PBRMaterial {
    float roughness;
    float metallic;
    float f0;
};


float pbrPow5(in float x) {
    float x2 = x * x;
    return x2 * x2 * x;
}

vec3 fresnelSchlick(in float cosTheta, in vec3 F0) {
    return F0 + (vec3(1.0) - F0) * pbrPow5(clamp(1.0 - cosTheta, 0.0, 1.0));
}

float D_GGX(in float NdotH, in float alpha) {
    float a2 = alpha * alpha;
    float d = NdotH * NdotH * (a2 - 1.0) + 1.0;
    return a2 / max(PI * d * d, 1e-8);
}

float smithG1(in float NdotX, in float alpha) {
    float a2 = alpha * alpha;
    return 2.0 * NdotX / (NdotX + sqrt(a2 + (1.0 - a2) * NdotX * NdotX));
}

float smithG(in float NdotV, in float NdotL, in float alpha) {
    return smithG1(NdotV, alpha) * smithG1(NdotL, alpha);
}

vec3 envBRDFApprox(in vec3 F0, in float roughness, in float NdotV) {
    const vec4 c0 = vec4(-1.0, -0.0275, -0.572, 0.022);
    const vec4 c1 = vec4(1.0, 0.0425, 1.04, -0.04);
    vec4 r = roughness * c0 + c1;
    float a004 = min(r.x * r.x, exp2(-9.28 * NdotV)) * r.x + r.y;
    vec2 AB = vec2(-1.04, 1.04) * a004 + r.zw;
    return F0 * AB.x + AB.y;
}


struct Lobes {
    vec3 diffuse;
    vec3 spec;
};

Lobes evalLobes(in vec3 N, in vec3 V, in vec3 L, in PBRMaterial mat, in vec3 albedo, in vec3 F0) {
    Lobes o;
    o.diffuse = o.spec = vec3(0);

    float NdotL = dot(N, L);
    if (NdotL <= 0.0) return o;

    float NdotV = max(dot(N, V), 1e-4);
    vec3  H = normalize(V + L);
    float NdotH = max(dot(N, H), 0.0);
    float VdotH = max(dot(V, H), 0.0);

    vec3 kd = vec3(1) - fresnelSchlick(NdotV, F0);
    o.diffuse = albedo * (1.0 - mat.metallic) * kd * INV_PI;

    float alpha = max(mat.roughness, 0.02);
    alpha *= alpha;
    o.spec = fresnelSchlick(VdotH, F0)
           * (D_GGX(NdotH, alpha) * smithG(NdotV, NdotL, alpha) / max(4.0 * NdotV * NdotL, 1e-6));

    return o;
}


float hgPhase(in float c, in float g) {
    float g2 = g * g;
    return (1.0 - g2) / pow(max(1.0 + g2 - 2.0 * g * c, 1e-3), 1.5);
}

vec3 sampleGGXVNDF(in vec3 Ve, in float alpha, in vec2 xi) {
    alpha = max(alpha, 1e-4);
    vec3 Vh = normalize(vec3(alpha * Ve.x, alpha * Ve.y, max(Ve.z, 1e-5)));
    float lensq = dot(Vh.xy, Vh.xy);

    vec3 T1 = lensq > 1e-8 ? vec3(-Vh.y, Vh.x, 0) / sqrt(lensq) : vec3(1, 0, 0);
    vec3 T2 = cross(Vh, T1);

    float r = sqrt(xi.x);
    float phi = 2.0 * PI * xi.y;
    float t1 = r * cos(phi);
    float t2 = r * sin(phi);

    float s = 0.5 * (1.0 + Vh.z);
    t2 = (1.0 - s) * sqrt(max(1.0 - t1 * t1, 0.0)) + s * t2;

    vec3 Nh = t1 * T1 + t2 * T2 + sqrt(max(1.0 - t1 * t1 - t2 * t2, 0.0)) * Vh;
    return normalize(vec3(alpha * Nh.x, alpha * Nh.y, max(Nh.z, 0.0)));
}


PBRMaterial getMaterial(in vec4 d) {
    PBRMaterial m;
    m.roughness = d.x;
    m.metallic = d.y >= 229.5 / 255.0? 1.0 : 0.0;
    m.f0 = max(d.y, 0.04);
    return m;
}


#endif