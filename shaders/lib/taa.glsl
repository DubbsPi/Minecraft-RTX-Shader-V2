#ifndef TAA_GLSL
#define TAA_GLSL

#include "settings.glsl"


uniform int frameCounter;
uniform float viewWidth;
uniform float viewHeight;


float halton(in int index, in int base) {
    float f = 1.0, r = 0.0;
    while (index > 0) {
        f /= float(base);
        r += f * float(index % base);
        index /= base;
    }
    return r;
}

vec2 taaJitter() {
    int i = frameCounter % 8 + 1;
    vec2 h = vec2(halton(i, 2), halton(i, 3)) - 0.5;
    return h * 2.0 / vec2(viewWidth, viewHeight);
}


#endif