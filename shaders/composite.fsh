#version 430 compatibility

#include "lib/settings.glsl"
#include "lib/random.glsl"
#include "lib/taa.glsl"
#include "lib/sky.glsl"
#include "lib/pbr.glsl"
#include "lib/lighting.glsl"


uniform sampler2D colortex0;  // albedo
uniform sampler2D colortex1;  // view space normal
uniform sampler2D colortex2;  // lightmap (x = block, y = sky)
uniform sampler2D colortex3;  // pbr

uniform sampler2D depthtex0;


uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;

uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;

uniform vec3 upPosition;
uniform vec3 fogColor;
uniform float far;


in vec2 texcoord;

/* RENDERTARGETS: 0,4 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 reflWeight;


void main() {
    uint rngState = randInt(uvec2(gl_FragCoord.xy), uvec2(viewWidth, viewHeight), uint(frameCounter));

    vec4 src = texture(colortex0, texcoord);
    float depth = texture(depthtex0, texcoord).r;

    vec3 color = vec3(0);
    reflWeight = vec4(0);

    vec3 NDCPos = vec3(texcoord, depth) * 2.0 - 1.0;
    NDCPos.xy -= taaJitter();
    vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);

    vec3 rayDirView = normalize(viewPos);
    vec3 rayDirWorld = normalize((gbufferModelViewInverse * vec4(rayDirView, 0.0)).xyz);

    // Sky
    bool isSky = depth >= 1.0;
    if (isSky) {
        #ifdef VANILLA_STARS
            const bool useVanilla = true;
        #else
            const bool useVanilla = false;
        #endif

        vec3 spaceDir = moonRelativeDirection(rayDirWorld);
        color = sampleSky(rayDirWorld, spaceDir, src.rgb, useVanilla);
    } else {
        vec3 albedo = pow(max(src.rgb, vec3(0)), vec3(2.2));
        vec3 N = normalize(texture(colortex1, texcoord).xyz * 2.0 - 1.0);
        vec2 lightmap = texture(colortex2, texcoord).xy;

        PBRMaterial mat = getMaterial(texture(colortex3, texcoord));

        color = getLighting(
            albedo, N, viewPos, depth,
            lightmap, mat, rngState,
            reflWeight
        );
    }

    outColor = vec4(color, 1);
}
