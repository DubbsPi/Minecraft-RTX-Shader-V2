#ifndef INCLUDE_RANDOM
#define INCLUDE_RANDOM


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


uint pcg(inout uint state) {
    uint prev = state * 747796405u + 2891336453u;
    uint word = ((prev >> ((prev >> 28u) + 4u)) ^ prev) * 277803737u;
    state = prev;
    return (word >> 22u) ^ word;
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


#endif