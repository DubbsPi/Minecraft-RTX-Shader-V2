#ifndef INCLUDE_SSR
#define INCLUDE_SSR


uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform vec3 cameraPosition;


vec3 toView(in vec2 uv, in float depth) {
    vec4 p = gbufferProjectionInverse * vec4(vec3(uv, depth) * 2.0 - 1.0, 1.0);
    return p.xyz / p.w;
}

vec3 viewToScreen(in vec3 v) {
    vec4 c = gbufferProjection * vec4(v, 1.0);
    return c.xyz / c.w * 0.5 + 0.5;
}

float viewZ(in float d) {
    float n  = d * 2.0 - 1.0;
    float zz = gbufferProjectionInverse[2][2] * n + gbufferProjectionInverse[3][2];
    float ww = gbufferProjectionInverse[2][3] * n + gbufferProjectionInverse[3][3];
    return zz / ww;
}

bool traceSSR(in vec3 P, in vec3 R, in float dither, out vec2 hitUV) {
    hitUV = vec2(0.0);

    float len = SSR_MAX_DIST;
    if (P.z + R.z * len > -0.1) len = (-0.1 - P.z) / R.z;   // don't march behind the camera
    if (len <= 0.0) return false;

    vec3 s0 = viewToScreen(P);
    vec3 s1 = viewToScreen(P + R * len);
    vec3 stepS = (s1 - s0) / float(SSR_STEPS);

    vec3 prev = s0;
    vec3 s = s0 + stepS * dither;

    for (int i = 0; i < SSR_STEPS; i++) {
        s += stepS;
        if (s.x < 0.0 || s.x > 1.0 || s.y < 0.0 || s.y > 1.0 || s.z < 0.0 || s.z >= 1.0) return false;

        float sceneD = texture(depthtex0, s.xy).r;
        if (sceneD < 1.0) {
            float diff = viewZ(sceneD) - viewZ(s.z);
            if (diff > 0.0 && diff < SSR_THICKNESS) {
                vec3 lo = prev, hi = s;
                for (int j = 0; j < SSR_REFINE_STEPS; j++) {
                    vec3 m = 0.5 * (lo + hi);
                    float df = viewZ(texture(depthtex0, m.xy).r) - viewZ(m.z);
                    if (df > 0.0) hi = m; else lo = m;
                }
                hitUV = hi.xy;
                return true;
            }
        }
        prev = s;
    }
    return false;
}

vec3 skyReflection(in vec3 dirW, in vec3 sunDirW, in vec3 moonDirW) {
    vec3 t1, t2;
    vec3 sky = atmosphereSky(dirW, sunDirW,  vec3(1.0, 0.98, 0.95), 20.0, cameraPosition.y, t1);
    sky += atmosphereSky(dirW, moonDirW, vec3(0.45, 0.55, 0.90), 0.3,  cameraPosition.y, t2);
    sky += vec3(0.001, 0.0015, 0.003);
    return sky * mix(1.0, 0.25, clamp(-dirW.y * 4.0, 0.0, 1.0));
}


#endif