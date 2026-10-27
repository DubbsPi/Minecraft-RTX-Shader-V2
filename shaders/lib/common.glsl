#ifndef INCLUDE_COMMON
#define INCLUDE_COMMON


const float PI = 3.14159265359;
const float TAU = 6.28318530718;
const float INV_PI = 0.31830988618;
const float TWO_INV_PI = 0.636619772;


struct Atmosphere {
    vec3 betaRayleigh;
    float betaMie;
    float mieG;
    float rayleighHeight;
    float mieHeight;
    float atmosphereHeight;
};


float luma(in vec3 c) {return dot(c, vec3(0.2126, 0.7152, 0.0722));}

vec3 projectAndDivide(in mat4 projectionMatrix, in vec3 position){
    vec4 homPos = projectionMatrix * vec4(position, 1);
    return homPos.xyz / homPos.w;
}


#endif