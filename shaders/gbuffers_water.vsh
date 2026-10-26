#version 430 compatibility

#include "lib/taa.glsl"
#include "lib/settings.glsl"
#include "lib/waves.glsl"


uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;


out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 vNormal;
out vec3 vWorldPos;
in vec3 mc_Entity;
flat out float vIsWater;


void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = ((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy - 0.03125) * 1.06667;
    glcolor = gl_Color;
    vNormal = gl_NormalMatrix * gl_Normal;
    vIsWater = (mc_Entity.x == 10001.0)? 1.0 : 0.0;

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    vec3 feet = (gbufferModelViewInverse * viewPos).xyz;
    vec3 world = feet + cameraPosition;
    vWorldPos = world;

    if (vIsWater > 0.5) {
        float surface = step(0.05, fract(world.y + 0.01));

        vec3 displacement = evaluateWaterDisplacement(world.xz, frameTimeCounter);
        feet += displacement * surface;
        viewPos = gbufferModelView * vec4(feet, 1);
    }

    gl_Position = gl_ProjectionMatrix * viewPos;
    gl_Position.xy += taaJitter() * gl_Position.w;
}