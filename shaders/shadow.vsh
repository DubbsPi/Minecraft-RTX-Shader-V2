#version 430 compatibility

#include "lib/settings.glsl"
#include "lib/shadow_util.glsl"
#include "lib/vertex_util.glsl"

uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelViewInverse;

in vec3 mc_Entity;
in vec4 at_midBlock;

out vec2 texcoord;
out vec4 glcolor;
flat out float vIsWater;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor  = gl_Color;

    vec4 rawShadowClipPos = ftransform();
    gl_Position = rawShadowClipPos;
    gl_Position.xyz = distortShadowClipPos(gl_Position.xyz);

    vIsWater = (mc_Entity.x == 10001.0)? 1.0 : 0.0;

    #ifdef RTX_FEATURES
        vec3 shadowViewPos = (shadowProjectionInverse * rawShadowClipPos).xyz;
        vec3 feetPos = (shadowModelViewInverse * vec4(shadowViewPos, 1.0)).xyz;

        const float inv64 = 1.0 / 64.0;
        vec3 blockCenter = feetPos + at_midBlock.xyz * inv64;
        if (any(greaterThan(abs(blockCenter), vec3(voxelDistance)))) return;

        uint vertexIndex = atomicAdd(TriCounter.vertexCount, 1u);
        uint quadID = vertexIndex >> 2u;
        uint corner = vertexIndex & 3u;

        if (quadID < uint(MAX_TRIS)) {
            ivec2 base   = ivec2(int(quadID % TRIS_PER_ROW), int(quadID / TRIS_PER_ROW)) * 2;
            ivec2 offset = ivec2(int(corner & 1u), int(corner >> 1u));

            imageStore(vertexPositions, base + offset, uvec4(packPos(feetPos), 0u, 0u));
            imageStore(vertexAttributes, base + offset, uvec4(packAttributes(texcoord, glcolor), 0u, 0u));

            if (corner == 3u) atomicAdd(TriCounter.quadCount, 1u);
        }
    #endif
}
