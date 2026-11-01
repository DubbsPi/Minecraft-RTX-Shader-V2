#version 430 compatibility

#include "lib/settings.glsl"
#ifdef VERTEX_COUNT_DEBUG
    #include "lib/vertex_util.glsl"
    uniform float viewWidth;
#endif

uniform sampler2D colortex0;
uniform sampler2D skyLutSampler;


in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;


vec3 acesTonemap(in vec3 color) {
    const float a = 2.51f;
    const float b = 0.03f;
    const float c = 2.43f;
    const float d = 0.59f;
    const float e = 0.14f;
    return clamp((color * (a * color + b)) / (color * (c * color + d) + e), 0.0f, 1.0f);
}

float bayerDither(in vec2 p) {
    int x = int(p.x) & 3;
    int y = int(p.y) & 3;
    
    int i = x + y * 4;
    
    const float pattern[16] = float[16](
        0.0 / 16.0, 8.0 / 16.0, 2.0 / 16.0, 10.0 / 16.0,
        12.0 / 16.0, 4.0 / 16.0, 14.0 / 16.0, 6.0 / 16.0,
        3.0 / 16.0, 11.0 / 16.0, 1.0 / 16.0, 9.0 / 16.0,
        15.0 / 16.0, 7.0 / 16.0, 13.0 / 16.0, 5.0 / 16.0
    );
    
    return pattern[i] - 0.5;
}


void main() {
    vec3 color = texture(colortex0, texcoord).rgb;

    // Tonemap + gamma
    color = acesTonemap(color);
    color = pow(color, vec3(0.454545454545));

    // Dithering
    float dither = bayerDither(gl_FragCoord.xy);
    const float depth = 1.0 / 255.0;
    color += dither * depth;

    #ifdef VERTEX_COUNT_DEBUG
    if (texcoord.y < 0.02) {
        float triUsage = min(float(TriCounter.quadCount) / float(MAX_TRIS), 1.0);
        color = vec3(0.05);

        if (texcoord.x < triUsage) color = vec3(texcoord.x, 1.0 - texcoord.x, 0.0);
    }
    #endif

    outColor = vec4(color, 1);
}