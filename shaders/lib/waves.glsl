#ifndef INCLUDE_WAVES
#define INCLUDE_WAVES

#include "settings.glsl"
#include "common.glsl"


uniform sampler2D noisetex;



struct WaterWave {
    vec2 dir;
    float k;
    float omega;
    float amp;
    float phase;
    float q;
};

WaterWave getWaterWave(int i) {
    WaterWave w;
    float fi = float(i);
    float u = fi / float(WATER_TOTAL_WAVES - 1);

    float spread = mix(WATER_SWELL_SPREAD, TAU, u * u);
    float angle = WATER_WIND_ANGLE + (fract(fi * TWO_INV_PI + 0.13) - 0.5) * spread;
    w.dir = vec2(cos(angle), sin(angle));

    float wavelength = WATER_WAVE_LENGTH_0 * pow(WATER_WAVE_LENGTH_RATIO, fi);
    w.k = TAU / wavelength;
    w.omega = sqrt(WATER_GRAVITY * w.k) * WATER_TIME_SCALE;
    w.phase = TAU * fract(fi * 0.7548 + 0.41);

    w.q = 0.0;
    if (i < WATER_SWELL_WAVES) {
        w.amp = WATER_SWELL_AMP_0 * pow(WATER_SWELL_AMP_RATIO, fi);
        w.q = WATER_STEEPNESS / (float(WATER_SWELL_WAVES) * w.k * w.amp);
    } else {
        w.amp = WATER_DETAIL_AMP_0 * pow(WATER_DETAIL_AMP_RATIO, fi - float(WATER_SWELL_WAVES));
    }

    return w;
}


vec3 waterNoiseCell(in ivec2 cell) {
    ivec2 size = textureSize(noisetex, 0);

    ivec2 wrapped = ivec2(
        ((cell.x % size.x) + size.x) % size.x,
        ((cell.y % size.y) + size.y) % size.y
    );

    return texelFetch(noisetex, wrapped, 0).rgb * 2.0 - 1.0;
}

void sampleWaterNoise(
    in vec2 p, in float t,
    in float scale, in float angle, in vec2 scroll,
    out vec3 value, out vec2 dx, out vec2 dz
 ) {
    float c = cos(angle);
    float s = sin(angle);
    mat2 M = scale * mat2(c, s, -s, c);

    vec2 q = M * p + scroll * t;

    ivec2 cell = ivec2(floor(q));
    vec2 f = fract(q);
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    vec2 du = 30.0 * f * f * (f * (f - 2.0) + 1.0);

    vec3 n00 = waterNoiseCell(cell);
    vec3 n10 = waterNoiseCell(cell + ivec2(1, 0));
    vec3 n01 = waterNoiseCell(cell + ivec2(0, 1));
    vec3 n11 = waterNoiseCell(cell + ivec2(1, 1));

    vec3 row0 = mix(n00, n10, u.x);
    vec3 row1 = mix(n01, n11, u.x);
    value = mix(row0, row1, u.y);

    vec2 dQx = mix(n10 - n00, n11 - n01, u.y).xy * du.x;
    vec2 dQz = (row1 - row0).xy * du.y;

    // Chain rule (learned this in calc fairly recently)
    dx = dQx * M[0].x + dQz * M[0].y;
    dz = dQx * M[1].x + dQz * M[1].y;
}


struct WaterWarp {
    vec2 p;
    vec2 dx;
    vec2 dz;
    float gust;
};

WaterWarp waterWarpCoarse(in vec2 p, in float t) {
    vec3 n;
    vec2 nDx;
    vec2 nDz;
    sampleWaterNoise(p, t, WATER_COARSE_SCALE, WATER_COARSE_ROTATION, WATER_COARSE_SCROLL, n, nDx, nDz);

    WaterWarp w;
    w.p    = p + n.xy * WATER_COARSE_STRENGTH;
    w.dx   = vec2(1, 0) + nDx * WATER_COARSE_STRENGTH;
    w.dz   = vec2(0, 1) + nDz * WATER_COARSE_STRENGTH;
    w.gust = n.z;
    return w;
}

WaterWarp waterWarpFine(in vec2 p, in float t, in WaterWarp base) {
    vec3 n;
    vec2 nDx;
    vec2 nDz;
    sampleWaterNoise(p, t, WATER_FINE_SCALE, WATER_FINE_ROTATION, WATER_FINE_SCROLL, n, nDx, nDz);

    WaterWarp w = base;
    w.p  += n.xy * WATER_FINE_STRENGTH;
    w.dx += nDx * WATER_FINE_STRENGTH;
    w.dz += nDz * WATER_FINE_STRENGTH;
    return w;
}


vec3 evaluateWaterDisplacement(in vec2 p, in float t) {
    WaterWarp warp = waterWarpCoarse(p, t);
    float swellState = 1.0 + WATER_SWELL_GUST * warp.gust;

    vec3 displacement = vec3(0);
    for (int i = 0; i < WATER_SWELL_WAVES; ++i) {
        WaterWave w = getWaterWave(i);

        float A = WAVE_HEIGHT * swellState * w.amp;
        float theta = w.k * dot(w.dir, warp.p) - w.omega * t + w.phase;

        float s = sin(theta);
        float c = cos(theta);

        float horizontal = w.q * A;

        displacement.x += horizontal * w.dir.x * c;
        displacement.y += A * s;
        displacement.z += horizontal * w.dir.y * c;
    }

    return displacement;
}


void accumulateSwellDerivatives(in WaterWave w, in vec2 p, in float t, in float swellState, inout vec3 dPdx, inout vec3 dPdz) {
    float A = WAVE_HEIGHT * swellState * w.amp;
    float theta = w.k * dot(w.dir, p) - w.omega * t + w.phase;

    float s = sin(theta);
    float c = cos(theta);

    float qAk = w.q * A * w.k;
    float Ak  = A * w.k;

    dPdx += vec3(-qAk * w.dir.x * w.dir.x * s, Ak * w.dir.x * c, -qAk * w.dir.x * w.dir.y * s);
    dPdz += vec3(-qAk * w.dir.x * w.dir.y * s, Ak * w.dir.y * c, -qAk * w.dir.y * w.dir.y * s);
}


void accumulateDetailGradient(in WaterWave w, in vec2 p, in float t, in float detailState, inout vec2 gradient) {
    float A = WAVE_DETAIL * detailState * w.amp;
    float theta = w.k * dot(w.dir, p) - w.omega * t + w.phase;

    float derivative = A * w.k * cos(theta) * exp(sin(theta) - 1.0);
    gradient += derivative * w.dir;
}


vec3 evaluateWaterNormal(in vec2 p, in float t) {
    WaterWarp warpC = waterWarpCoarse(p, t);
    WaterWarp warpF = waterWarpFine(p, t, warpC);

    float swellState = 1.0 + WATER_SWELL_GUST * warpC.gust;
    float detailState = clamp(1.0 + WATER_DETAIL_GUST * warpC.gust, 0.25, 2.0);

    vec3 dPdx = vec3(0);
    vec3 dPdz = vec3(0);

    for (int i = 0; i < WATER_SWELL_WAVES; ++i)
        accumulateSwellDerivatives(getWaterWave(i), warpC.p, t, swellState, dPdx, dPdz);

    vec3 tangentX = vec3(1, 0, 0) + dPdx * warpC.dx.x + dPdz * warpC.dx.y;
    vec3 tangentZ = vec3(0, 0, 1) + dPdx * warpC.dz.x + dPdz * warpC.dz.y;

    vec2 detailGradient = vec2(0);
    for (int i = WATER_SWELL_WAVES; i < WATER_TOTAL_WAVES; ++i)
        accumulateDetailGradient(getWaterWave(i), warpF.p, t, detailState, detailGradient);

    tangentX.y += dot(detailGradient, warpF.dx);
    tangentZ.y += dot(detailGradient, warpF.dz);

    return normalize(cross(tangentZ, tangentX));
}


#endif
