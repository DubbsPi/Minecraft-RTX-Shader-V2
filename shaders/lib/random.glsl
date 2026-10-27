#ifndef INCLUDE_RANDOM
#define INCLUDE_RANDOM


const mat3 FBM_ROT = mat3(
    0.00, 0.80, 0.60,
    -0.80, 0.36, -0.48,
    -0.60, -0.48, 0.64
);


uint pcg(inout uint state) {
    uint prev = state * 747796405u + 2891336453u;
    uint word = ((prev >> ((prev >> 28u) + 4u)) ^ prev) * 277803737u;
    state = prev;
    return (word >> 22u) ^ word;
}

uint hash(in uint x) {
    x ^= x >> 17; x *= 0xbf324c81u;
    x ^= x >> 11; x *= 0x68bc2a9du;
    x ^= x >> 16;
    return x;
}

uint hash2(uvec2 p) {
    return hash(p.x ^ hash(p.y + 0x9e3779b9u));
}

uint hash3(in ivec3 c) {
    return hash2(uvec2(hash2(uvec2(uint(c.x), uint(c.y))), uint(c.z)));
}

float hash13i(in ivec3 c) {
    uint state = uint(c.x) + 0x9e3779b9u;
    pcg(state);
    state += uint(c.y);
    pcg(state);
    state += uint(c.z);
    uint h = pcg(state);
    return float(h) * (1.0 / 4294967295.0);
}


float rand(inout uint seed) {
    seed = pcg(seed);
    return float(seed) / float(0xFFFFFFFFu);
}

uint randInt(in uvec2 pixel, in uvec2 resolution, in uint frameIndex) {
    uint seed = pixel.x + pixel.y * resolution.x;
    seed = hash(seed ^ hash(frameIndex));
    return seed;
}


float valueNoise(in vec3 p) {
    ivec3 i = ivec3(floor(p));
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float n000 = hash13i(i + ivec3(0, 0, 0));
    float n100 = hash13i(i + ivec3(1, 0, 0));
    float n010 = hash13i(i + ivec3(0, 1, 0));
    float n110 = hash13i(i + ivec3(1, 1, 0));
    float n001 = hash13i(i + ivec3(0, 0, 1));
    float n101 = hash13i(i + ivec3(1, 0, 1));
    float n011 = hash13i(i + ivec3(0, 1, 1));
    float n111 = hash13i(i + ivec3(1, 1, 1));

    return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
               mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}


float fbm(in vec3 p, in int octaves) {
    float sum = 0.0;
    float amp = 0.5;
    float norm = 0.0;
    for (int i = 0; i < octaves; ++i) {
        sum += valueNoise(p) * amp;
        norm += amp;
        p = FBM_ROT * p * 2.03;
        amp *= 0.5;
    }
    return sum / norm;
}


#endif