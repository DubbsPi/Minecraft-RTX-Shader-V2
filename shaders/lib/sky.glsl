#ifndef INCLUDE_SKY
#define INCLUDE_SKY

#include "settings.glsl"
#include "random.glsl"
#include "common.glsl"
#include "lut_uitl.glsl"


uniform int moonPhase;
uniform float moonPhaseMult;
uniform float nightFactor;
uniform vec3 sunDirW;
uniform vec3 moonDirW;

uniform float sunMuS;
uniform float moonMuS;
uniform float sunLightFade;
uniform float moonLightFade;
uniform float moonSkyIntensity;
uniform float moonWashFactor;
uniform float skyY0;
uniform vec2 moonSpin;


vec3 moonRelativeDirection(in vec3 rayDir) {
    const vec3 e1 = vec3(1, 0, 0);
    const vec3 e2 = cross(CELESTIAL_AXIS, e1);

    float x = dot(rayDir, e1);
    float y = dot(rayDir, e2);

    return vec3(moonSpin.x * x - moonSpin.y * y, moonSpin.y * x + moonSpin.x * y, dot(rayDir, CELESTIAL_AXIS));
}

float softElevation(in float y) {
    return 0.03 + 0.5 * (y + sqrt(y * y + HORIZON_SOFTNESS * HORIZON_SOFTNESS));
}


float flatRayleighPhase(in float mu) {
    return 3.0 / (16.0 * PI) * (1.0 + mu * mu);
}

float flatMiePhase(in float mu, in float g) {
    float g2 = g * g;
    float denom = max(1.0 + g2 - 2.0 * g * mu, 1e-4);
    return 3.0 / (8.0 * PI) * ((1.0 - g2) * (1.0 + mu * mu)) / ((2.0 + g2) * pow(denom, 1.5));
}

vec3 transmittance(in vec2 opticalDepth, in Atmosphere a) {
    return exp(-(a.betaRayleigh * opticalDepth.x) - vec3(a.betaMie * opticalDepth.y));
}

vec2 opticalDepthToTop(in float y, in float dirY, in Atmosphere a) {
    float top = a.atmosphereHeight;
    y = clamp(y, 0.0, top);
    float rh = max(a.rayleighHeight, 1e-4);
    float mh = max(a.mieHeight, 1e-4);
    float mu = max(dirY, 0.03);

    return vec2(rh * (exp(-y / rh) - exp(-top / rh)), mh * (exp(-y / mh) - exp(-top / mh))) / mu;
}

vec3 skyTransmittance(in vec3 dir, in float camY) {
    return transmittance(opticalDepthToTop(skyY0, softElevation(dir.y), EARTHLIKE), EARTHLIKE);
}



vec3 sunTransmittance(in vec3 sunDirW, in float camY) {
    return transmittance(opticalDepthToTop(skyY0, max(sunDirW.y, 0.05), EARTHLIKE), EARTHLIKE);
}

vec3 atmosphereSkyFast(in vec3 worldDir, in vec3 lightDir, in vec3 lightColor, in float intensity, in float lightFade, in float muS) {
    if (lightFade <= 0.0) return vec3(0);

    Atmosphere a = EARTHLIKE;
    float top = a.atmosphereHeight;
    float HR = max(a.rayleighHeight, 1e-4);
    float HM = max(a.mieHeight, 1e-4);

    vec3 d = normalize(vec3(worldDir.x, softElevation(worldDir.y), worldDir.z));
    // softElevation keeps this positive around the horizon, but normalization
    // can move it slightly below the optical-depth floor.
    float muV = max(d.y, 0.03);
    float yEnd = min(top, skyY0 + muV * MAX_SKY_DIST);

    float uR0 = exp(-skyY0 / HR), uRE = exp(-yEnd / HR), uRT = exp(-top / HR);
    float uM0 = exp(-skyY0 / HM), uME = exp(-yEnd / HM), uMT = exp(-top / HM);

    float deltaMu = muV - muS;

    // Rayleigh. The analytic expression divides by (muV - muS), but its
    // numerator also tends to zero there. Use the derivative limit instead
    // of perturbing muV, which can create a colored band near the horizon.
    vec3 bR = a.betaRayleigh * HR;
    vec3 tRStart = exp(-bR * ((uR0 - uRT) / muS));
    vec3 intR;
    if (abs(deltaMu) < 1e-3) {
        float yEndLimit = min(top, skyY0 + muS * MAX_SKY_DIST);
        float uRELimit = exp(-yEndLimit / HR);
        intR = tRStart * bR * ((uR0 - uRELimit) / muS);
    } else {
        vec3 tREnd = exp(-bR * ((uR0 - uRE) / muV + (uRE - uRT) / muS));
        intR = (tREnd - tRStart) * (muS / deltaMu);
    }

    // Mie, using the same stable limit as the Rayleigh integral.
    float bM = a.betaMie * HM;
    float tMStart = exp(-bM * ((uM0 - uMT) / muS));
    float intM;
    if (abs(deltaMu) < 1e-3) {
        float yEndLimit = min(top, skyY0 + muS * MAX_SKY_DIST);
        float uMELimit = exp(-yEndLimit / HM);
        intM = tMStart * bM * ((uM0 - uMELimit) / muS);
    } else {
        float tMEnd = exp(-bM * ((uM0 - uME) / muV + (uME - uMT) / muS));
        intM = (tMEnd - tMStart) * (muS / deltaMu);
    }

    // Attenuation
    float uMr = max(uM0 * 0.1353, uME);
    float odM = HM * ((uM0 - uMr) / muV + (uMr - uMT) / muS);
    float crossM = exp(-a.betaMie * odM);

    float uRm = max(uR0 * exp(-HM / HR), uRE);
    float odR = HR * ((uR0 - uRm) / muV + (uRm - uRT) / muS);
    vec3 crossR = exp(-a.betaRayleigh * odR);

    float mu = dot(d, lightDir);
    vec3 scatter = (intR * crossM * flatRayleighPhase(mu) + vec3(intM) * crossR * flatMiePhase(mu, a.mieG)) * lightColor * intensity * lightFade;
    return max(scatter, vec3(0));
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


vec3 minecraftStars(in vec3 starDir, in bool runAnyways) {
    if (nightFactor <= 0.0 && !runAnyways) return vec3(0);

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

vec3 realisticStars(in vec3 starDir, in bool runAnyways) {
    if (nightFactor <= 0.0 && !runAnyways) return vec3(0);

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

    return result;
}


vec3 nebula(in vec3 d, in bool runAnyways) {
    if (nightFactor <= 0.0 && !runAnyways) return vec3(0);

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

    return emission * NEBULA_INTENSITY;
}

vec3 galacticHaze(in vec3 d, in bool runAnyways) {
    if (nightFactor <= 0.0 && !runAnyways) return vec3(0);

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

    return tint * density * (0.65 + 0.7 * grain) * GALAXY_BRIGHTNESS;
}


void bodyFrame(in vec3 dir, out vec3 right, out vec3 up) {
    right = normalize(cross(dir, CELESTIAL_AXIS));
    up = cross(right, dir);
}

vec4 sunBody(in vec3 rd) {
    if (dot(rd, sunDirW) <= 0.0) return vec4(0);

    const float sinR = sin(radians(SUN_RADIUS_DEG));
    float x = length(cross(rd, sunDirW)) / sinR;
    if (x > 16.0) return vec4(0);

    float cover = 1.0 - smoothstep(0.88, 1.0, x);
    float mu = sqrt(max(1.0 - x * x, 0.0));
    float limb = 1.0 - 0.6 * (1.0 - mu);

    const float corona = SUN_CORONA * exp(-1.3 * x);

    vec3 col = vec3(1.0, 0.96, 0.88);
    return vec4(col * (limb * cover * SUN_DISC_SCALE + corona) * SPRITE_BOOST, cover);
}

vec4 moonBody(in vec3 rd) {
    if (dot(rd, moonDirW) <= 0.0) return vec4(0);

    const float sinR = sin(radians(MOON_RADIUS_DEG));
    vec3 right, up;
    bodyFrame(moonDirW, right, up);

    vec2 p = vec2(dot(rd, right), dot(rd, up)) / sinR;

    const float roll = radians(MOON_ROLL_DEG);
    const mat2 m2r = mat2(cos(roll), sin(roll), -sin(roll), cos(roll));

    p = m2r * p;
    float r2 = dot(p, p);
    if (r2 >= 1.0) return vec4(0);

    float h = sqrt(1.0 - r2);

    float alpha = float(moonPhase) * (PI * 0.25);
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


vec3 getSkyAtmosphere(in vec3 dir, in vec3 vanillaSky, in bool useVanillaSky, out vec3 trans, out float cover) {
    vec3 unusedA, unusedB;
    vec3 sky = atmosphereSkyFast(dir, sunDirW,  vec3(1.0, 0.98, 0.95), 10.0, sunLightFade, sunMuS);
    sky += atmosphereSkyFast(dir, moonDirW, vec3(0.45, 0.55, 0.9), moonSkyIntensity, moonLightFade, moonMuS);

    float belowHorizon = 1.0 - smoothstep(-0.25, 0.0, dir.y);
    sky *= mix(1.0, GROUND_DIM, belowHorizon);
    
    trans = skyTransmittance(dir, cameraPosition.y);

    vec3 bodies = vec3(0);
    cover = 0.0;

    if (useVanillaSky) {
        float spriteLum = max(vanillaSky.r, max(vanillaSky.g, vanillaSky.b));
        float spriteCore = smoothstep(0.25, 0.4, spriteLum);
        vec3 sprite = pow(vanillaSky, vec3(2.2)) * mix(spriteCore, 1.0, SPRITE_GLOW);
        bodies += sprite * SPRITE_BOOST;
        cover = spriteCore;
    }

    #ifndef VANILLA_SUN
        vec4 s = sunBody(dir);
        bodies += s.rgb;
        cover = 1.0 - (1.0 - cover) * (1.0 - s.a);
    #else
        if (!useVanillaSky) {
            vec4 s = sunBody(dir);
            bodies += s.rgb;
            cover = 1.0 - (1.0 - cover) * (1.0 - s.a);
        }
    #endif
    #ifndef VANILLA_MOON
        vec4 m = moonBody(dir);
        m.rgb *= 0.1;
        bodies += m.rgb;
        cover = 1.0 - (1.0 - cover) * (1.0 - m.a);
    #else
        if (!useVanillaSky) {
            vec4 m = moonBody(dir);
            m.rgb *= 0.1;
            bodies += m.rgb;
            cover = 1.0 - (1.0 - cover) * (1.0 - m.a);
        }
    #endif
    
    float horizonMask = smoothstep(-0.3, 0.06, dir.y);
    bodies *= horizonMask;
    cover *= horizonMask;

    return sky + bodies * trans;
}

vec3 getSkyLut(in vec3 dir) {
    vec3 space = vec3(0);
    #ifdef VANILLA_STARS
        space += minecraftStars(dir, true);
    #else
        space += realisticStars(dir, true);
    #endif
    #ifdef NEBULA
        space += nebula(dir, true) * NEBULA_BRIGHTNESS;
    #endif
    #ifdef GALATIC_HAZE
        space += galacticHaze(dir, true);
    #endif

    return space;
}


vec3 sampleSky(in vec3 rayDir, in vec3 spaceDir, in vec3 vanillaSky, in bool useVanillaSky) {
    vec3 trans;
    float cover;
    vec3 sky = getSkyAtmosphere(rayDir, vanillaSky, useVanillaSky, trans, cover);

    if (nightFactor <= 0.0) return sky;

    vec3 space = sampleSkyLut(spaceDir);
    vec3 spaceTrans = pow(trans, vec3(SPACE_EXTINCTION));
    float horizonMask = smoothstep(-0.3, 0.06, rayDir.y);
    return sky + space * nightFactor * moonWashFactor * (1.0 - cover) * spaceTrans * horizonMask;
}


#endif
