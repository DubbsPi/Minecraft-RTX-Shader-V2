#version 430 compatibility

#include "lib/settings.glsl"
#include "lib/shadow_util.glsl"
#include "lib/vertex_util.glsl"
#include "lib/waves.glsl"

#define DONT_INLCUDE_READONLY_VERTS
#include "lib/bvh_util.glsl"


#ifdef RTX_FEATURES
    layout(rg32ui, binding = 0) uniform writeonly restrict uimage2D vertexPositions;
    layout(rg32ui, binding = 1) uniform writeonly restrict uimage2D vertexAttributes;
#endif


uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform int frameCounter;


in vec3 mc_Entity;
in vec4 at_midBlock;

out vec2 texcoord;
out vec4 glcolor;
flat out float vIsWater;


void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;

    vec4 rawShadowClipPos = ftransform();
    gl_Position = rawShadowClipPos;
    gl_Position.xyz = distortShadowClipPos(gl_Position.xyz);


    vIsWater = (mc_Entity.x == 10001.0)? 1.0 : 0.0;


    #ifdef RTX_FEATURES
        if (frameCounter < BVH_DELAY_FRAMES) return;
                
        #ifdef TRACE_WATER
            vec3 shadowViewPos = (shadowProjectionInverse * rawShadowClipPos).xyz;
            vec3 feetPos = (shadowModelViewInverse * vec4(shadowViewPos, 1)).xyz;
            vec3 world = feetPos + cameraPosition;

            if (vIsWater > 0.5) {
                float surface = step(0.05, fract(world.y + 0.01));

                vec3 displacement = evaluateWaterDisplacement(world.xz, frameTimeCounter);
                feetPos += displacement * surface;
            }
            
            #include "/lib/vertex_write.glsl"
        #else
            if (vIsWater > 0.5) return;
            #include "lib/vertex_write.glsl"
        #endif
    #endif
}
