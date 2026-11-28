#version 430 compatibility

#include "/lib/denoise.glsl"
#include "/lib/settings.glsl"


layout(rgba16f) uniform image2D reflAccum0;
layout(rgba16f) uniform image2D reflAccum1;
layout(rgba16f) uniform image2D reflAux0;
layout(rgba16f) uniform image2D reflAux1;


in vec2 texcoord;

/* RENDERTARGETS: 4 */
layout(location = 0) out vec4 outRefl;


bool odd() {
    return (frameCounter & 1) == 1;
}

vec4 loadAccum(in ivec2 p) {
    return odd()? imageLoad(reflAccum1, p) : imageLoad(reflAccum0, p);
}

vec4 loadAux(in ivec2 p) {
    return odd()? imageLoad(reflAux1, p)   : imageLoad(reflAux0, p);
}


void storeBoth(in ivec2 p, vec4 acc, vec4 aux) {
    if (odd()) { imageStore(reflAccum0, p, acc); imageStore(reflAux0, p, aux); }
    else { imageStore(reflAccum1, p, acc); imageStore(reflAux1, p, aux); }
}

vec2 projectPrev(in vec3 pv) {
    vec4 c = gbufferPreviousProjection * vec4(pv, 1.0);
    return c.xy / c.w * 0.5 + 0.5;
}

bool validTap(in vec4 aux, in ivec2 q, in vec3 nW, in vec3 prevTrackView, in bool virtualTrack) {
    if (virtualTrack) {
        float expectedDepth = -prevTrackView.z;
        return expectedDepth > 0.0 && abs(aux.r - expectedDepth) < 0.03 * expectedDepth + 0.05;
    }

    if (dot(octDecode(aux.gb), nW) < 0.9) return false;

    vec3 nPV = mat3(gbufferPreviousModelView) * nW;
    vec3 rd = normalize(getViewPos((vec2(q) + 0.5) / viewSize, 0.5));

    float denom = dot(nPV, rd);
    if (abs(denom) < 1e-3) return false;

    float t = dot(nPV, prevTrackView) / denom;
    return t > 0.0 && abs(aux.r - t) < 0.03 * t + 0.05;
}


void main() {
    ivec2 px = ivec2(gl_FragCoord.xy);
    vec4 raw = texelFetch(colortex4, px, 0);
    float depth = getDenoiseDepth(px);
    vec4 info = texelFetch(colortex7, px, 0);

    float rough = getDenoiseRoughness(px);

    if (depth >= 1.0 || rough < 0.01) {
        outRefl = vec4(raw.rgb, 0.0);
        storeBoth(px, vec4(raw.rgb, 1), vec4(0));
        return;
    }

    vec3 vp = getViewPos(texcoord, depth);
    float dist = length(vp);
    vec3 nW = mat3(gbufferModelViewInverse) * getDenoiseNormal(px);
    bool virtualTrack = info.g > 0.5;
    float virtualDist = max(info.r * VIRT_MAX, dist);
    vec3 virtualPos = normalize(vp) * virtualDist;
    vec3 trackPos = virtualTrack
        ? mix(virtualPos, vp, smoothstep(0.1, 0.4, rough))
        : vp;
    vec3 trackRel = (gbufferModelViewInverse * vec4(trackPos, 1.0)).xyz;
    vec3 camDelta = cameraPosition - previousCameraPosition;

    vec3 prevTrackView = (gbufferPreviousModelView * vec4(trackRel + camDelta, 1.0)).xyz;
    vec2 prevUV = projectPrev(prevTrackView);

    vec3 m1 = vec3(0), m2 = vec3(0);
    float sl = 0.0, sl2 = 0.0;
    for (int y = -1; y <= 1; y++)
    for (int x = -1; x <= 1; x++) {
        ivec2 q = clamp(px + ivec2(x, y), ivec2(0), ivec2(viewSize) - 1);
        vec3 c = texelFetch(colortex4, q, 0).rgb;
        float l = luma(c);
        m1 += c; m2 += c * c; sl += l; sl2 += l * l;
    }
    const float oneOverNine = 1.0 / 9.0;
    m1 *= oneOverNine; m2 /= oneOverNine;
    vec3 sigma = sqrt(max(m2 - m1 * m1, 0.0));
    float varSpatial = max(sl2 * oneOverNine - (sl * oneOverNine) * (sl * oneOverNine), 0.0);

    vec2 pf = prevUV * viewSize - 0.5;
    ivec2 p0 = ivec2(floor(pf));
    vec2 f = fract(pf);
    vec4 hist = vec4(0);
    float histM2 = 0.0, wsum = 0.0;
    for (int i = 0; i < 4; i++) {
        ivec2 q = p0 + ivec2(i & 1, i >> 1);
        if (any(lessThan(q, ivec2(0))) || any(greaterThanEqual(q, ivec2(viewSize)))) continue;
        float bw = ((i & 1) == 1? f.x : 1.0 - f.x) * ((i >> 1) == 1? f.y : 1.0 - f.y);
        vec4 aux = loadAux(q);

        if (!validTap(aux, q, nW, prevTrackView, virtualTrack)) continue;
        hist += loadAccum(q) * bw;
        histM2 += aux.a * bw;
        wsum += bw;
    }

    float len = 1.0;
    vec3 result = raw.rgb;
    float m2New = dot(raw.rgb, vec3(0.2126, 0.7152, 0.0722));
    m2New *= m2New;

    if (wsum > 1e-3) {
        hist /= wsum; histM2 /= wsum;
        float maxLen = mix(1.0, 128.0, smoothstep(0.05, 0.5, rough));
        len = min(hist.a + 1.0, maxLen);
        float alpha = 1.0 / len;

        float gamma = mix(1.0, 2.0, rough);
        vec3 histC = clamp(hist.rgb, m1 - gamma * sigma, m1 + gamma * sigma);

        result = mix(histC, raw.rgb, alpha);
        float lr = luma(raw.rgb);
        m2New = mix(histM2, lr * lr, alpha);
    }

    float mean = luma(result);
    float varTemporal = max(m2New - mean * mean, 0.0);
    float variance = mix(varSpatial, varTemporal, clamp((len - 1.0) * 0.333333, 0.0, 1.0));

    float trackDepth = virtualTrack? -trackPos.z : dist;
    storeBoth(px, vec4(result, len), vec4(trackDepth, octEncode(nW), m2New));
    outRefl = vec4(result, variance);
}