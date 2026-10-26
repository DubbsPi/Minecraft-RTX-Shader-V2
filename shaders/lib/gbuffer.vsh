#include "taa.glsl"


out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 normal;


void main() {
    gl_Position = ftransform();
    gl_Position.xy += taaJitter() * gl_Position.w;
    
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = ((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy - 0.03125) * 1.06667;
    glcolor = gl_Color;
    normal = gl_NormalMatrix * gl_Normal;
}
