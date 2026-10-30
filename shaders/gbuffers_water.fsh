#version 430 compatibility

#include "lib/settings.glsl"
#include "lib/waves.glsl"


uniform sampler2D gtexture;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform float frameTimeCounter;


in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 vNormal;
in vec3 vWorldPos;
flat in float vIsWater;


/* RENDERTARGETS: 5,6 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outNormal;


void main() {
    vec3 N = normalize(vNormal);
    float skyL = clamp(lmcoord.y, 0.0, 1.0);
    
    if (vIsWater > 0.5) {
        vec3 nW = mat3(gbufferModelViewInverse) * N;
        if (nW.y > 0.9) {
            vec2 p = vWorldPos.xz;

            #ifdef WATER_PIXELATED
                const float invSppb = 1.0 / float(SHADOW_PIXELS_PER_BLOCK);
                p = floor(p * float(SHADOW_PIXELS_PER_BLOCK)) * invSppb;
            #endif

            nW = evaluateWaterNormal(p, frameTimeCounter);
            N = normalize(mat3(gbufferModelView) * nW);
        }

        outColor = glcolor;
    } else {
        outColor = texture(gtexture, texcoord) * glcolor;
    }

    outNormal = vec4(N, skyL + (vIsWater > 0.5? 2.0 : 0.0));
}
