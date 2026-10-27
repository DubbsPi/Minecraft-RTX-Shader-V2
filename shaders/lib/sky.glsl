#ifndef INCLUDE_SKY
#define INCLUDE_SKY

#include "settings.glsl"
#include "random.glsl"
#include "common.glsl"


#define NEBULA_SCALE 1.6
#define NEBULA_WARP 1.2
#define NEBULA_THRESHOLD 0.48 
#define NEBULA_INTENSITY 0.35


float nightFactor(in vec3 sunDir) {
    float sunHeight = normalize(sunDir).y;
    return 1.0 - smoothstep(-0.12, 0.04, sunHeight);
}

vec3 moonRelativeDirection(in vec3 rayDir, in vec3 moonDir) {
    vec3 axis = CELESTIAL_AXIS;
    vec3 e1 = vec3(1, 0, 0);
    vec3 e2 = cross(axis, e1);

    float theta = atan(dot(moonDir, e2), dot(moonDir, e1));

    float a = -theta * STAR_SPIN_RATE;
    float c = cos(a), s = sin(a);
    float x = dot(rayDir, e1);
    float y = dot(rayDir, e2);

    return vec3(c * x - s * y, s * x + c * y, dot(rayDir, axis));
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


float galaxyLatitude(in vec3 d) {
    vec3 w = vec3(valueNoise(d * 2.0),
                  valueNoise(d * 2.0 + 7.3),
                  valueNoise(d * 2.0 + 13.1)) - 0.5;
    return dot(normalize(d + w * 0.35), GALAXY_NORMAL);
}

float galaxyBand(in float lat) {
    return exp(-lat * lat / (2.0 * GALAXY_WIDTH * GALAXY_WIDTH));
}

float galaxyBulge(in vec3 d) {
    return pow(max(dot(d, GALAXY_CENTER), 0.0), 3.0);
}


float nebulaCloud(in vec3 d, in float band, out vec3 pw) {
    vec3 p = d * NEBULA_SCALE;

    vec3 warp = vec3(
        fbm(p, 3),
        fbm(p + vec3(5.2, 1.3, 8.1), 3),
        fbm(p + vec3(2.7, 9.4, 3.3), 3)
    ) - 0.5;
    p += warp * NEBULA_WARP * 2.0;
    pw = p;

    float shape = fbm(p, 5) + (band - 0.35) * NEBULA_BAND_BIAS;
    return smoothstep(NEBULA_THRESHOLD, NEBULA_THRESHOLD + 0.3, shape);
}


float starClusterFactor(in vec3 n) {
    float band = galaxyBand(galaxyLatitude(n));
    vec3 pw;
    float gas = nebulaCloud(n, band, pw);
    float t = clamp(band * 0.6 + gas * 0.8, 0.0, 1.0);
    return mix(STAR_DENSITY_MIN_MULT, STAR_DENSITY_MAX_MULT, t);
}

vec3 realisticStars(in vec3 rayDir, in vec3 moonDirW, in float nightFactor) {
    if (nightFactor <= 0.0) return vec3(0);

    vec3 starDir = moonRelativeDirection(rayDir, moonDirW);
    vec3 p = starDir * starScale(REAL_STAR_GRID_X, REAL_STAR_GRID_Y);
    ivec3 base = ivec3(floor(p));

    float maxDensity = min(REAL_STAR_DENSITY * STAR_DENSITY_MAX_MULT, 1.0);
    float haloRadius = REAL_STAR_RADIUS * 5.0;
    float cutoff = haloRadius * 2.0;

    vec3 result = vec3(0);

    for (int z = -1; z <= 1; ++z)
    for (int y = -1; y <= 1; ++y)
    for (int x = -1; x <= 1; ++x) {
        ivec3 cell = base + ivec3(x, y, z);

        uint seed = hash3(cell);
        float spawn = rand(seed);
        float ox = rand(seed);
        float oy = rand(seed);
        float oz = rand(seed);
        float brightnessRandom = rand(seed);
        float colorRandom = rand(seed);
        float keepRandom = rand(seed);

        if (spawn > maxDensity) continue;

        vec3 starPos = vec3(cell) + vec3(ox, oy, oz);
        vec3 n = normalize(starPos);
        vec3 delta = starPos - p;

        float radial = dot(delta, n);
        if (abs(radial) > STAR_SLAB) continue;

        vec3 tang = delta - n * radial;
        float dist = length(tang);
        if (dist > cutoff) continue;

        float keep = REAL_STAR_DENSITY * starClusterFactor(n) / maxDensity;
        if (keepRandom > keep) continue;

        float brightness = 0.15 + 0.85 * pow(brightnessRandom, 2.5);
        vec3 starColor = mix(vec3(0.70, 0.82, 1.00), vec3(1.00, 0.88, 0.70), colorRandom);

        float core = 1.0 - smoothstep(REAL_STAR_RADIUS * 0.55, REAL_STAR_RADIUS, dist);
        float halo = exp(-dist * dist / max(haloRadius * haloRadius, 1e-6));
        halo *= smoothstep(0.65, 0.95, brightnessRandom);

        result += starColor * (brightness * core + halo * 0.08);
    }

    return result * nightFactor;
}


vec3 nebula(in vec3 rayDir, in vec3 moonDirW, in float nightFactor) {
    if (nightFactor <= 0.0) return vec3(0);

    vec3 d = moonRelativeDirection(rayDir, moonDirW);
    float band = galaxyBand(galaxyLatitude(d));

    vec3 p;
    float cloud = nebulaCloud(d, band, p);
    if (cloud <= 0.0) return vec3(0);

    float hue = fbm(p * 0.6 + 13.7, 3);
    vec3 colA = vec3(0.90, 0.25, 0.45);
    vec3 colB = vec3(0.25, 0.35, 0.95);
    vec3 colC = vec3(0.15, 0.80, 0.75);
    vec3 col = mix(colA, colB, smoothstep(0.30, 0.65, hue));
    col = mix(col, colC, smoothstep(0.60, 0.80, fbm(p * 0.8 + 31.1, 3)) * 0.6);

    float dust = fbm(p * 2.2 + 41.0, 4);
    float lanes = 1.0 - 0.85 * smoothstep(0.50, 0.68, dust);

    float core = cloud * cloud * cloud;
    vec3 emission = col * (cloud * 0.35 + core * 0.9) * lanes;

    return emission * NEBULA_INTENSITY * nightFactor;
}

vec3 galacticHaze(in vec3 rayDir, in vec3 moonDirW, in float nightFactor) {
    if (nightFactor <= 0.0) return vec3(0);

    vec3 d = moonRelativeDirection(rayDir, moonDirW);
    float lat = galaxyLatitude(d);
    float band = galaxyBand(lat);
    if (band < 0.04) return vec3(0);

    float bulge = galaxyBulge(d);
    float clumps = fbm(d * 5.0 + 3.1, 4);
    float grain = valueNoise(d * 140.0) * 0.6 + valueNoise(d * 310.0) * 0.4;

    float riftMask = exp(-lat * lat / (2.0 * 0.05 * 0.05));
    float rift = 1.0 - 0.75 * riftMask * smoothstep(0.35, 0.70, fbm(d * 4.0 + 21.0, 3));

    float density = band * (0.45 + 0.9 * bulge) * mix(0.5, 1.2, clumps) * rift;

    vec3 tint = mix(vec3(0.75, 0.85, 1.00), vec3(1.00, 0.85, 0.65), bulge);

    return tint * density * (0.65 + 0.7 * grain) * GALAXY_BRIGHTNESS * nightFactor;
}


void bodyFrame(in vec3 dir, out vec3 right, out vec3 up) {
    right = normalize(cross(dir, CELESTIAL_AXIS));
    up = cross(right, dir);
}

vec4 sunBody(in vec3 rd, in vec3 sunDir) {
    if (dot(rd, sunDir) <= 0.0) return vec4(0);

    const float sinR = sin(radians(SUN_RADIUS_DEG));
    float x = length(cross(rd, sunDir)) / sinR;
    if (x > 16.0) return vec4(0);

    float cover = 1.0 - smoothstep(0.88, 1.0, x);
    float mu = sqrt(max(1.0 - x * x, 0.0));
    float limb = 1.0 - 0.6 * (1.0 - mu);

    const float corona = SUN_CORONA * exp(-1.3 * x);

    vec3 col = vec3(1.0, 0.96, 0.88);
    return vec4(col * (limb * cover * SUN_DISC_SCALE + corona) * SPRITE_BOOST, cover);
}

vec4 moonBody(in vec3 rd, in vec3 moonDir, in int phase) {
    if (dot(rd, moonDir) <= 0.0) return vec4(0);

    const float sinR = sin(radians(MOON_RADIUS_DEG));
    vec3 right, up;
    bodyFrame(moonDir, right, up);

    vec2 p = vec2(dot(rd, right), dot(rd, up)) / sinR;

    const float roll = radians(MOON_ROLL_DEG);
    const mat2 m2r = mat2(cos(roll), sin(roll), -sin(roll), cos(roll));

    p = m2r * p;
    float r2 = dot(p, p);
    if (r2 >= 1.0) return vec4(0);

    float h = sqrt(1.0 - r2);

    float alpha = float(phase) * (PI * 0.25);
    float ndl = -p.x * sin(alpha) * MOON_PHASE_FLIP + h * cos(alpha);
    float lit = smoothstep(-0.03, 0.10, ndl);

    vec3 sp = vec3(p, h) * 2.2 + 17.0;
    float maria = smoothstep(0.48, 0.62, fbm(sp, 4));
    float grit = fbm(sp * 5.0, 3);
    float albedo = mix(0.95, 0.5, maria) * (0.8 + 0.4 * grit);

    vec3 col = vec3(0.90, 0.94, 1) * albedo * (lit + 0.02);

    float cover = 1.0 - smoothstep(0.90, 1.0, sqrt(r2));
    return vec4(col * cover * SPRITE_BOOST * MOON_DISC_SCALE, cover);
}


#endif
