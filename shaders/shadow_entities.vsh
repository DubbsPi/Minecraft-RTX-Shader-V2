#version 430 compatibility

#extension GL_KHR_shader_subgroup_basic : enable
#extension GL_KHR_shader_subgroup_ballot : enable
#extension GL_KHR_shader_subgroup_shuffle : enable

#include "lib/settings.glsl"
#include "lib/shadow_util.glsl"
#include "lib/vertex_util.glsl"

#define DONT_INLCUDE_READONLY_VERTS
#include "lib/bvh_util.glsl"


#if defined(GL_KHR_shader_subgroup_basic) && defined(GL_KHR_shader_subgroup_ballot) && defined(GL_KHR_shader_subgroup_shuffle) && !defined(FORCE_NO_SUBGROUPS)
    #define USE_SUBGROUPS
#endif


#ifdef RTX_FEATURES
    layout(rg32ui, binding = 0) uniform writeonly restrict uimage2D vertexPositions;
    layout(rg32ui, binding = 1) uniform writeonly restrict uimage2D vertexAttributes;
    #ifdef TRACE_ENTITIES
        layout(rgba8, binding = 3) uniform writeonly restrict image2D entityAtlas;
    #endif
#endif


uniform sampler2D gtexture;

uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelViewInverse;


in vec3 mc_Entity;
in vec4 at_midBlock;

out vec2 texcoord;
out vec4 glcolor;
flat out float vIsWater;


#if defined RTX_FEATURES && defined TRACE_ENTITIES
    uint getTextureHash() {
        const vec2 taps[4] = vec2[4](vec2(0.15, 0.15), vec2(0.85, 0.15), vec2(0.15, 0.85), vec2(0.85, 0.85));
        uint h = 2166136261u;
        for (int i = 0; i < 4; i++) {
            uint c = packUnorm4x8(textureLod(gtexture, taps[i], 4.0));
            h = (h ^ c) * 16777619u;
        }
        return (h == 0u)? 1u : h;
    }

    void bakeTexture(in int slot) {
        const int slotsPerRow = int(ENTITY_ATLAS_SIZE / ENTITY_ATLAS_SLOT_SIZE);
        ivec2 pos = ivec2(slot % slotsPerRow, slot / slotsPerRow) * ENTITY_ATLAS_SLOT_SIZE;
        ivec2 texSize = min(textureSize(gtexture, 0), ivec2(ENTITY_ATLAS_SLOT_SIZE));

        TriCounter.texSize[slot] = texSize;
        for (int x = 0; x < texSize.x; x++) {
            for (int y = 0; y < texSize.y; y++) {
                imageStore(entityAtlas, pos + ivec2(x, y), texelFetch(gtexture, ivec2(x, y), 0));
            }
        }
    }
#endif


void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor  = gl_Color;

    #if defined RTX_FEATURES && defined TRACE_ENTITIES
        uint texHash = getTextureHash();
        uint assignedSlot = 0xffffffffu;
        uint initialPos = texHash % 1024u;

        for (uint i = 0u; i < 4u; i++) {
            uint checkSlot = (initialPos + i) % 1024u;
            
            uint existingHash = atomicCompSwap(TriCounter.textureHashes[checkSlot], 0u, texHash);
            
            if (existingHash == 0u) {
                bakeTexture(int(checkSlot));
                assignedSlot = checkSlot;
                break;
            } 
            else if (existingHash == texHash) {
                assignedSlot = checkSlot;
                break;
            }
        }

        if (assignedSlot == 0xffffffffu) assignedSlot = 0u;
    #endif


    vec4 rawShadowClipPos = ftransform();
    gl_Position = rawShadowClipPos;
    gl_Position.xyz = distortShadowClipPos(gl_Position.xyz);

    #if defined RTX_FEATURES && defined TRACE_ENTITIES
        bool valid = frameCounter >= BVH_DELAY_FRAMES;

        vec3 feetPos = vec3(0);
        if (valid) {
            vec3 shadowViewPos = (shadowProjectionInverse * rawShadowClipPos).xyz;
            feetPos = (shadowModelViewInverse * vec4(shadowViewPos, 1)).xyz;

            // Not yet for this...
            //atomicAdd(TriCounter.vertexHash[gl_VertexID & 63], hashVertex(feetPos));
        }

        #define ENTITY_WRITE
        #include "lib/vertex_write.glsl"
    #endif
}
