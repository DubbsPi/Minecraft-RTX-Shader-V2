#ifndef INCLUDE_WAVES
#define INCLUDE_WAVES

#include "settings.glsl"
#include "common.glsl"


uniform sampler2D noisetex;


const float WATER_WARP_SCALE = 0.65;
const float WATER_WARP_STRENGTH = 0.37;
const vec2 WATER_NOISE_SCROLL = vec2(0.33, -0.59);


struct GerstnerWave {
    vec2 direction;
    float wavelength;
    float amplitude;
    float steepness;
    float speed;
    float phase;
};

const GerstnerWave WATER_WAVES[5] = GerstnerWave[5](
    GerstnerWave(
        vec2(0.41, 0.73),
        14.0, 0.34,
        0.72, 0.62, 0.4
    ),

    GerstnerWave(
        vec2(-0.36, 0.93),
        9.3, 0.25,
        0.65, 0.8, 2.1
    ),

    GerstnerWave(
        vec2(0.27, -0.96),
        6.8, 0.18,
        0.56, 0.73, 4.4
    ),

    GerstnerWave(
        vec2(0.47, 0.57),
        5.0, 0.125,
        0.45, 0.52, 1.3
    ),

    GerstnerWave(
        vec2(-0.73, -0.68),
        4.0, 0.075,
        0.35, 0.98, 3.5
    )
);


struct WaterDetailWave {
    vec2 direction;
    float wavelength;
    float amplitude;
    float speed;
    float phase;
};

const WaterDetailWave WATER_DETAIL_WAVES[4] = WaterDetailWave[4](
    WaterDetailWave(
        vec2(0.93, -0.36),
        3.2, 0.34,
        0.67, 0.8
    ),

    WaterDetailWave(
        vec2(-0.56, -0.83),
        2.45, 0.22,
        0.55, 4.0
    ),

    WaterDetailWave(
        vec2(0.31, 0.95),
        1.85, 0.14,
        0.48, 2.7
    ),

    WaterDetailWave(
        vec2(-0.92, 0.39),
        1.42, 0.075,
        0.40, 5.2
    )
);


vec2 waterNoiseCell(in ivec2 cell) {
    ivec2 size = textureSize(noisetex, 0);

    ivec2 wrapped = ivec2(
        ((cell.x % size.x) + size.x) % size.x,
        ((cell.y % size.y) + size.y) % size.y
    );

    return texelFetch(noisetex, wrapped, 0).rg * 2.0 - 1.0;
}


void sampleWaterNoise(in vec2 p, in float t, out vec2 noiseValue, out vec2 noiseDx, out vec2 noiseDz) {
    vec2 q = p * WATER_WARP_SCALE + WATER_NOISE_SCROLL * t;

    ivec2 cell = ivec2(floor(q));
    vec2 f = fract(q);
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    vec2 du = 30.0 * f * f * (f * (f - 2.0) + 1.0);

    vec2 n00 = waterNoiseCell(cell);
    vec2 n10 = waterNoiseCell(cell + ivec2(1, 0));
    vec2 n01 = waterNoiseCell(cell + ivec2(0, 1));
    vec2 n11 = waterNoiseCell(cell + ivec2(1, 1));

    vec2 row0 = mix(n00, n10, u.x);
    vec2 row1 = mix(n01, n11, u.x);

    noiseValue = mix(row0, row1, u.y);

    vec2 dNoiseQx = mix(n10 - n00, n11 - n01, u.y) * du.x;
    vec2 dNoiseQz = (row1 - row0) * du.y;

    noiseDx = dNoiseQx * WATER_WARP_SCALE;
    noiseDz = dNoiseQz * WATER_WARP_SCALE;
}


void waterWarp(in vec2 p, in float t, out vec2 warpedP, out vec2 warpDx, out vec2 warpDz) {
    vec2 noiseValue;
    vec2 noiseDx;
    vec2 noiseDz;
    sampleWaterNoise(p, t, noiseValue, noiseDx, noiseDz);

    warpedP = p + noiseValue * WATER_WARP_STRENGTH;
    warpDx = vec2(1, 0) + noiseDx * WATER_WARP_STRENGTH;
    warpDz = vec2(0, 1) + noiseDz * WATER_WARP_STRENGTH;
}


vec3 evaluateWaterDisplacement(in vec2 p, in float t) {
    vec2 warpedP;
    vec2 warpDx;
    vec2 warpDz;
    waterWarp(p, t, warpedP, warpDx, warpDz);

    vec3 displacement = vec3(0);
    for (int i = 0; i < 5; ++i) {
        GerstnerWave w = WATER_WAVES[i];
        vec2 d = normalize(w.direction);

        float k = TAU / w.wavelength;
        float omega = k * w.speed;

        float A = WAVE_HEIGHT * w.amplitude;
        float theta = k * dot(d, warpedP) - omega * t + w.phase;

        float s = sin(theta);
        float c = cos(theta);

        float horizontal = w.steepness * A;

        displacement.x += horizontal * d.x * c;
        displacement.y += A * s;
        displacement.z += horizontal * d.y * c;
    }

    return displacement;
}



void accumulateGerstnerDerivatives(in vec2 p, in float t, in GerstnerWave w, inout vec3 dPdx, inout vec3 dPdz) {
    vec2 d = normalize(w.direction);

    float k = TAU / w.wavelength;
    float omega = k * w.speed;

    float A = WAVE_HEIGHT * w.amplitude;
    float theta = k * dot(d, p) - omega * t + w.phase;

    float s = sin(theta);
    float c = cos(theta);

    float qAk = w.steepness * A * k;
    float Ak = A * k;


    dPdx += vec3(-qAk * d.x * d.x * s, Ak * d.x * c, -qAk * d.x * d.y * s);
    dPdz += vec3(-qAk * d.x * d.y * s, Ak * d.y * c, -qAk * d.y * d.y * s);
}

void accumulateWaterDetail(in vec2 p, in float t, in WaterDetailWave w, inout vec2 gradient) {
    vec2 d = normalize(w.direction);

    float k = TAU / w.wavelength;
    float omega = k * w.speed;
    float A = WAVE_DETAIL * w.amplitude;

    float theta = k * dot(d, p) - omega * t + w.phase;
    float derivative = A * k * cos(theta);

    gradient += derivative * d;
}


vec3 evaluateWaterNormal(in vec2 p, in float t) {
    vec2 warpedP;
    vec2 warpDx;
    vec2 warpDz;
    waterWarp(p, t, warpedP, warpDx, warpDz);


    // Derivatives
    vec3 dPdx = vec3(0);
    vec3 dPdz = vec3(0);

    for (int i = 0; i < 5; ++i) accumulateGerstnerDerivatives(warpedP, t, WATER_WAVES[i], dPdx, dPdz);

    vec3 tangentX = vec3(1, 0, 0) + dPdx * warpDx.x + dPdz * warpDx.y;
    vec3 tangentZ = vec3(0, 0, 1) + dPdx * warpDz.x + dPdz * warpDz.y;

    vec2 detailGradient = vec2(0);
    for (int i = 0; i < 4; ++i) accumulateWaterDetail(warpedP, t, WATER_DETAIL_WAVES[i], detailGradient);

    tangentX.y += dot(detailGradient, warpDx);
    tangentZ.y += dot(detailGradient, warpDz);

    return normalize(cross(tangentZ, tangentX));
}


#endif