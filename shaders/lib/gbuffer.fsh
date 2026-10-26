uniform sampler2D gtexture;
uniform sampler2D specular;
uniform float alphaTestRef;


in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;

layout(location = 0) out vec4 outAlbedo;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outLight;
layout(location = 3) out vec4 outPBR;


void main() {
    vec4 c = texture(gtexture, texcoord) * glcolor;
    if (c.a < alphaTestRef) discard;

    outAlbedo = c;
    outNormal = vec4(normalize(normal) * 0.5 + 0.5, 1);
    outLight = vec4(lmcoord, 0, 1);

    vec4 s = texture(specular, texcoord);
    float roughness = pow(1.0 - s.r, 2.0);
    float f0 = s.g;
    outPBR = vec4(roughness, f0, 0, 1);
}
