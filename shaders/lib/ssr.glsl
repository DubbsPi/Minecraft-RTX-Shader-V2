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
    if (R.z > 1e-5 && P.z + R.z * len > -0.1) len = (-0.1 - P.z) / R.z;
    if (len <= 0.0) return false;

    vec3 endP = P + R * len;
    vec4 clip0 = gbufferProjection * vec4(P, 1.0);
    vec4 clip1 = gbufferProjection * vec4(endP, 1.0);
    if (clip0.w <= 0.0 || clip1.w <= 0.0) return false;

    vec2 uv0 = clip0.xy / clip0.w * 0.5 + 0.5;
    vec2 uv1 = clip1.xy / clip1.w * 0.5 + 0.5;
    if (any(lessThan(uv0, vec2(0.0))) || any(greaterThan(uv0, vec2(1.0)))) return false;

    vec2 pixelDelta = (uv1 - uv0) * vec2(textureSize(depthtex0, 0));
    float pixelSpan = max(abs(pixelDelta.x), abs(pixelDelta.y));
    float stepCount = min(max(ceil(pixelSpan), 1.0), float(SSR_STEPS));
    float invW0 = 1.0 / clip0.w;
    float invW1 = 1.0 / clip1.w;
    float viewZOverW0 = P.z * invW0;
    float viewZOverW1 = endP.z * invW1;

    float prevT = 0.0;
    float prevDiff = -SSR_THICKNESS;
    dither = clamp(dither, 0.0, 1.0);

    for (int i = 0; i < SSR_STEPS; i++) {
        if (float(i) >= stepCount) break;
        float t = min((float(i) + dither) / stepCount, 1.0);
        if (t <= prevT) continue;

        vec2 uv = mix(uv0, uv1, t);
        if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return false;

        float invW = mix(invW0, invW1, t);
        float rayZ = mix(viewZOverW0, viewZOverW1, t) / invW;
        float sceneD = texture(depthtex0, uv).r;
        float diff = -SSR_THICKNESS;
        if (sceneD < 1.0) {
            diff = viewZ(sceneD) - rayZ;
            if (diff > 0.0 && (prevDiff <= 0.0 || diff < SSR_THICKNESS)) {
                float hi = t;
                if (prevDiff <= 0.0) {
                    float lo = prevT;
                    for (int j = 0; j < SSR_REFINE_STEPS; j++) {
                        float mid = 0.5 * (lo + hi);
                        vec2 midUV = mix(uv0, uv1, mid);
                        float midInvW = mix(invW0, invW1, mid);
                        float midRayZ = mix(viewZOverW0, viewZOverW1, mid) / midInvW;
                        float midSceneD = texture(depthtex0, midUV).r;
                        float midDiff = midSceneD < 1.0 ? viewZ(midSceneD) - midRayZ : -SSR_THICKNESS;
                        if (midDiff > 0.0) hi = mid; else lo = mid;
                    }
                }
                hitUV = mix(uv0, uv1, hi);
                return true;
            }
        }
        prevDiff = diff;
        prevT = t;
    }
    return false;
}


#endif