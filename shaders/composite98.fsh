#version 430 compatibility


uniform sampler2D colortex0;
uniform sampler2D colortex4;
uniform sampler2D colortex6;


in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;


void main() {
    vec3 scene = texture(colortex0, texcoord).rgb;
    vec3 layer = texture(colortex4, texcoord).rgb;
    vec3 translucentNormal = texture(colortex6, texcoord).xyz;
    bool hasTranslucentLayer = dot(translucentNormal, translucentNormal) >= 0.25;
    vec3 color = hasTranslucentLayer ? layer : scene + layer;

    outColor = vec4(color, 1);
}