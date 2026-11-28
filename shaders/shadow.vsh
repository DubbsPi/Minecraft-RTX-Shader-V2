#version 430 compatibility

#extension GL_KHR_shader_subgroup_basic : enable
#extension GL_KHR_shader_subgroup_ballot : enable
#extension GL_KHR_shader_subgroup_shuffle : enable

#include "lib/settings.glsl"
#include "lib/shadow_util.glsl"
#include "lib/vertex_util.glsl"
#include "lib/waves.glsl"

#define DONT_INLCUDE_READONLY_VERTS
#include "lib/bvh_util.glsl"


#if defined(GL_KHR_shader_subgroup_basic) && defined(GL_KHR_shader_subgroup_ballot) && defined(GL_KHR_shader_subgroup_shuffle) && !defined(FORCE_NO_SUBGROUPS)
    #define USE_SUBGROUPS
#endif


#ifdef RTX_FEATURES
    layout(rg32ui, binding = 0) uniform writeonly restrict uimage2D vertexPositions;
    layout(rg32ui, binding = 1) uniform writeonly restrict uimage2D vertexAttributes;
    layout(rg32ui, binding = 5) uniform writeonly restrict uimage2D dynamicVertexPositions;
    layout(rg32ui, binding = 6) uniform writeonly restrict uimage2D dynamicVertexAttributes;
#endif


uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelViewInverse;

uniform float frameTimeCounter;

in vec3 mc_Entity;

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
        bool valid = frameCounter >= BVH_DELAY_FRAMES;
        bool dynamicWrite = vIsWater > 0.5;

        vec2 lm = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
        vec2 lightmap = clamp((lm - 1.0 * 0.03125) * 1.06666666667, 0.0, 1.0);
        
        bool isOpaque = true;

        vec3 feetPos = vec3(0);
        if (valid) {
            vec3 shadowViewPos = (shadowProjectionInverse * rawShadowClipPos).xyz;
            feetPos = (shadowModelViewInverse * vec4(shadowViewPos, 1)).xyz;
            vec3 world = feetPos + cameraPosition;

            #ifdef TRACE_WATER
                if (dynamicWrite) {
                    float surface = step(0.05, fract(world.y + 0.01));
                    feetPos += evaluateWaterDisplacement(world.xz, frameTimeCounter) * surface;
                }
            #else
                if (dynamicWrite) valid = false;
            #endif
        }

        uint assignedSlot = 0xffffffffu;
        #include "lib/vertex_write.glsl"
    #endif
}
