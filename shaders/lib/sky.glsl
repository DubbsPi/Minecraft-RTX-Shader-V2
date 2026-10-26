#ifndef INCLUDE_SKY
#define INCLUDE_SKY

#include "settings.glsl"
#include "random.glsl"
#include "common.glsl"


float nightFactor(in vec3 sunDir) {
    float sunHeight = normalize(sunDir).y;
    return 1.0 - smoothstep(-0.12, 0.04, sunHeight);
}

vec3 moonRelativeDirection(in vec3 rayDir, in vec3 moonDir) {
    moonDir = mix(moonDir, vec3(0, 1, 0), 0.5);
    moonDir = normalize(moonDir);

    vec3 forward = normalize(moonDir);
    vec3 referenceUp = vec3(0, 1, 0);

    if (abs(dot(forward, referenceUp)) > 0.999) referenceUp = vec3(0, 0, 1);

    vec3 right = normalize(cross(referenceUp, forward));
    vec3 up = cross(forward, right);

    return vec3(dot(rayDir, right), dot(rayDir, up), dot(rayDir, forward));
}


float flatRayleighPhase(in float mu) {
    return 3.0 / (16.0 * PI) * (1.0 + mu * mu);
}

float flatMiePhase(in float mu, in float g) {
    float g2 = g * g;
    float denom = max(1.0 + g2 - 2.0 * g * mu, 1e-4);
    return 3.0 / (8.0 * PI) * ((1.0 - g2) * (1.0 + mu * mu)) / ((2.0 + g2) * pow(denom, 1.5));
}

float flatRayleighDensity(in float y, in Atmosphere a) {
    return exp(-max(y, 0.0) / max(a.rayleighHeight, 1e-4));
}

float flatMieDensity(in float y, in Atmosphere a) {
    return exp(-max(y, 0.0) / max(a.mieHeight, 1e-4));
}

vec2 opticalDepth(in vec3 origin, in vec3 direction, in float dist, in Atmosphere a, in int steps) {
    if (dist <= 0.0 || steps <= 0 || a.atmosphereHeight <= 0.0) return vec2(0);

    float ds = dist / float(steps);
    vec2 depth = vec2(0.0);

    for (int i = 0; i < steps; ++i) {
        float t = (float(i) + 0.5) * ds;
        float y = origin.y + direction.y * t;

        if (y >= 0.0 && y <= a.atmosphereHeight) {
            depth.x += flatRayleighDensity(y, a) * ds;
            depth.y += flatMieDensity(y, a) * ds;
        }
    }

    return depth;
}

vec3 transmittance(in vec2 opticalDepth, in Atmosphere a) {
    return exp(-(a.betaRayleigh * opticalDepth.x) - vec3(a.betaMie * opticalDepth.y));
}


vec3 sunTransmittance(in vec3 sunDirW, in float camY) {
    float y0 = max(camY - SEA_LEVEL, 0.0) + 1.0;
    float dist = (EARTHLIKE.atmosphereHeight - y0) / max(sunDirW.y, 0.05);
    vec2 od = opticalDepth(vec3(0.0, y0, 0.0), sunDirW, dist, EARTHLIKE, 16);
    return transmittance(od, EARTHLIKE);
}

vec3 scatterAtmosphere(
    in vec3 rayOrigin,
    in vec3 viewDir,
    in float viewDistance,
    in vec3 sunDir,
    in vec3 sunColor,
    in float sunIntensity,
    in Atmosphere a,
    in int viewSteps,
    in int lightSteps,
    out vec3 viewTransmittance
 ) {
    viewTransmittance = vec3(1);

    if (viewDistance <= 0.0 || viewSteps <= 0 ||
        a.atmosphereHeight <= 0.0) {
        return vec3(0.0);
    }

    float ds = viewDistance / float(viewSteps);
    vec2 viewOD = vec2(0);
    vec3 scatter = vec3(0);
    float mu = dot(viewDir, sunDir);
    float phaseR = flatRayleighPhase(mu);
    float phaseM = flatMiePhase(mu, a.mieG);

    for (int i = 0; i < viewSteps; ++i) {
        float t = (float(i) + 0.5) * ds;
        vec3 samplePos = rayOrigin + viewDir * t;
        float y = samplePos.y;

        if (y < 0.0 || y > a.atmosphereHeight) continue;

        float densR = flatRayleighDensity(y, a);
        float densM = flatMieDensity(y, a);

        viewOD += vec2(densR, densM) * ds;

        if (sunDir.y <= 0.0) continue;

        float lightDistance = (a.atmosphereHeight - y) / max(sunDir.y, 1e-5);
        vec2 sunOD = opticalDepth(samplePos, sunDir, lightDistance, a, lightSteps);

        vec3 transSun = transmittance(sunOD, a);
        vec3 transView = transmittance(viewOD, a);

        vec3 extinctionR = a.betaRayleigh * densR;
        vec3 extinctionM = vec3(a.betaMie * densM);

        scatter += transView * transSun * sunColor * sunIntensity * (extinctionR * phaseR + extinctionM * phaseM) * ds;
    }

    viewTransmittance = transmittance(viewOD, a);
    return max(scatter, vec3(0));
}

vec3 atmosphereSky(in vec3 worldDir, in vec3 lightDir, in vec3 lightColor, in float intensity, in float camY, out vec3 viewTrans) {
    vec3 d = worldDir;
    d.y = smoothstep(0.001, 1.0, d.y);
    d = normalize(d);

    vec3 origin = vec3(0, max(camY - SEA_LEVEL, 0.0) + 1.0, 0);
    float dist = min((EARTHLIKE.atmosphereHeight - origin.y) / d.y, MAX_SKY_DIST);

    return scatterAtmosphere(origin, d, dist, lightDir, lightColor, intensity, EARTHLIKE, SKY_VIEW_STEPS, SKY_LIGHT_STEPS, viewTrans);
}


float starScale(in int gx, in int gy) {
    return sqrt(float(gx * gy) / (4.0 * PI));
}

void starFrame(in vec3 n, in float angle, out vec3 a, out vec3 b) {
    vec3 ref = abs(n.y) < 0.99? vec3(0, 1, 0) : vec3(1, 0, 0);
    vec3 t = normalize(cross(ref, n));
    vec3 s = cross(n, t);
    float c = cos(angle), sn = sin(angle);
    a = t * c + s * sn;
    b = s * c - t * sn;
}


vec3 minecraftStars(in vec3 rayDir, in vec3 moonDirW, in float nightFactor) {
    if (nightFactor <= 0.0) return vec3(0);

    vec3 starDir = moonRelativeDirection(rayDir, moonDirW);
    vec3 p = starDir * starScale(MC_STAR_GRID_X, MC_STAR_GRID_Y);
    ivec3 base = ivec3(floor(p));

    float starBrightness = 0.0;

    for (int z = -1; z <= 1; ++z)
    for (int y = -1; y <= 1; ++y)
    for (int x = -1; x <= 1; ++x) {
        ivec3 cell = base + ivec3(x, y, z);

        uint seed = hash3(cell);
        float spawn = rand(seed);
        if (spawn > MC_STAR_DENSITY) continue;

        float ox = rand(seed);
        float oy = rand(seed);
        float oz = rand(seed);
        vec3 starPos = vec3(cell) + vec3(ox, oy, oz);

        vec3 n = normalize(starPos);
        vec3 delta = starPos - p;

        if (abs(dot(delta, n)) > STAR_SLAB) continue;

        float rot = rand(seed) * 6.2831853;
        float brightnessRandom = rand(seed);

        vec3 a, b;
        starFrame(n, rot, a, b);
        vec2 q = vec2(dot(delta, a), dot(delta, b));

        float dist = max(abs(q.x), abs(q.y));
        float star = 1.0 - smoothstep(MC_STAR_STAR_RADIUS * 0.75, MC_STAR_STAR_RADIUS, dist);

        float brightness = 0.15 + 0.85 * pow(brightnessRandom, 2.5);
        starBrightness = max(starBrightness, star * brightness);
    }

    return vec3(starBrightness * nightFactor);
}

vec3 realisticStars(in vec3 rayDir, in vec3 moonDirW, in float nightFactor) {
    if (nightFactor <= 0.0) return vec3(0);

    vec3 starDir = moonRelativeDirection(rayDir, moonDirW);
    vec3 p = starDir * starScale(REAL_STAR_GRID_X, REAL_STAR_GRID_Y);
    ivec3 base = ivec3(floor(p));

    vec3 result = vec3(0);

    for (int z = -1; z <= 1; ++z)
    for (int y = -1; y <= 1; ++y)
    for (int x = -1; x <= 1; ++x) {
        ivec3 cell = base + ivec3(x, y, z);

        uint seed = hash3(cell);
        float spawn = rand(seed);
        if (spawn > REAL_STAR_DENSITY) continue;

        float ox = rand(seed);
        float oy = rand(seed);
        float oz = rand(seed);
        vec3 starPos = vec3(cell) + vec3(ox, oy, oz);

        vec3 n = normalize(starPos);
        vec3 delta = starPos - p;

        float radial = dot(delta, n);
        if (abs(radial) > STAR_SLAB) continue;

        vec3 tang = delta - n * radial;
        float dist = length(tang);

        float brightnessRandom = rand(seed);
        float brightness = 0.15 + 0.85 * pow(brightnessRandom, 2.5);

        float colorRandom = rand(seed);
        vec3 starColor = mix(vec3(0.70, 0.82, 1.00), vec3(1.00, 0.88, 0.70), colorRandom);

        float core = 1.0 - smoothstep(REAL_STAR_RADIUS * 0.55, REAL_STAR_RADIUS, dist);

        float haloRadius = REAL_STAR_RADIUS * 3.0;
        float halo = exp(-dist * dist / max(haloRadius * haloRadius, 1e-6));
        halo *= smoothstep(0.65, 0.95, brightnessRandom);

        result += starColor * (brightness * core + halo * 0.08);
    }

    return result * nightFactor;
}


#endif
