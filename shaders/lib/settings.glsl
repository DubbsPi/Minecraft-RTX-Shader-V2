#ifndef INCLUDE_SETTINGS
#define INCLUDE_SETTINGS

#include "common.glsl"


/*
const int colortex0Format = RGBA16F;  // Scene color
const int colortex4Format = RGBA16F;  // Reflections
const int colortex6Format = RGBA16F;  // Water normals
*/


// TAA
const int TAA_JITTER_FRAMES = 8;
const float VARIANCE_GAMMA = 1.25;
const float BASE_BLEND = 0.15;


// Shadows
#define SHADOW_MAP_RESOLUTION 2048 // [512 1024 2048 4096 8192]
const int shadowMapResolution = SHADOW_MAP_RESOLUTION;
const float shadowDistanceRenderMul = 1.0;

#define SHADOW_SAMPLES 8 // [4 6 8 16 32]
#define PCSS_BLOCKER_SAMPLES 8 // [4 6 8 10]

const float PENUMBRA_SCALE = 0.08;
const float MIN_RADIUS_BLOCKS = 0.005;
const float MAX_RADIUS_BLOCKS = 2.0;
const float SEARCH_RADIUS_BLOCKS = 0.8;

#define PIXELATED_SHADOWS
#define SHADOW_PIXELS_PER_BLOCK 16 // [4 8 16 32]

#define VARIABLE_PENUMBRA_SHADOWS
#define FIXED_SHADOW_RADIUS 0.001 // [0.0005 0.001 0.0015 0.002 0.0025 0.003 0.004 0.005 0.0075 0.01]

#define SSS_STRENGTH 0.75 // [0.35 0.5 0.75 1.0 1.25 1.5 1.75]

const bool shadowtex0Nearest = false;
const bool shadowtex1Nearest = false; 
const bool shadowcolor0Nearest = false;


// Sky
const Atmosphere EARTHLIKE = Atmosphere(
    vec3(5.8e-6, 13.5e-6, 33.1e-6),
    21e-6, 0.76,
    8000.0, 1200.0,
    40000.0
);


#define SEA_LEVEL 63.0
#define MAX_SKY_DIST 200000.0
#define SKY_VIEW_STEPS 16 // [8 12 16 24 32]
#define SKY_LIGHT_STEPS 8 // [4 6 8 10 12]
#define HORIZON_SOFTNESS 0.04
#define GROUND_DIM 0.35

const float SPRITE_BOOST = 6.0;


// Stars
#define STAR_SLAB 0.5

const int MC_STAR_GRID_X = 256;
const int MC_STAR_GRID_Y = 128;
const float MC_STAR_DENSITY = 0.1;
const float MC_STAR_STAR_RADIUS = 0.1;

const int REAL_STAR_GRID_X = 512;
const int REAL_STAR_GRID_Y = 256;
const float REAL_STAR_DENSITY = 0.18;
const float REAL_STAR_RADIUS = 0.075;

#define GALAXY_WIDTH 0.2 // [0.1 0.15 0.2 0.25 0.3]
#define GALAXY_BRIGHTNESS 0.05 // [0.01 0.025 0.05 0.075 0.1 0.15]
#define NEBULA_BRIGHTNESS 0.25 // [0.025 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5]
#define NEBULA_BAND_BIAS 0.15 // [0.05 0.1 0.15 0.2 0.25 0.3]
#define STAR_DENSITY_MIN_MULT 0.2
#define STAR_DENSITY_MAX_MULT 2.5

#define GALATIC_HAZE
#define NEBULA
#define NEBULA_SCALE 1.4 // [0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5]
#define NEBULA_WARP 1.2 // [0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5]
#define NEBULA_THRESHOLD 0.4 // [0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75]
#define NEBULA_INTENSITY 0.4

const vec3 GALAXY_NORMAL = normalize(vec3(0.1, 0.9, 0.3));
const vec3 GALAXY_CENTER = normalize(vec3(0.9, -0.1, 0.1));


// Celestials
#define VANILLA_CLOUDS 2 // [0 1 2]
//#define VANILLA_SUN
//#define VANILLA_MOON
//#define VANILLA_STARS

#define SUN_PATH_ROTATION 15.0 // [0.0 5.0 10.0 15.0 20.0 25.0 30.0 35.0 40.0 45.0]
const float sunPathRotation = SUN_PATH_ROTATION;
#define CELESTIAL_AXIS normalize(vec3(0, sin(radians(SUN_PATH_ROTATION)), cos(radians(SUN_PATH_ROTATION))))

#ifdef CELESTIAL_AXIS
#endif

#define SPRITE_GLOW 0.5
#define SPACE_EXTINCTION 0.25

#define SUN_RADIUS_DEG 2.0
#define MOON_RADIUS_DEG 1.5
#define SUN_DISC_SCALE 1.0
#define MOON_DISC_SCALE 1.0
#define SUN_CORONA 0.25 // [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5]
#define MOON_PHASE_FLIP 1.0 
#define MOON_ROLL_DEG 90.0


// SSR
#define SSR_STEPS 48 // [16 32 48 64 96]
#define SSR_REFINE_STEPS 4 // [2 3 4 5 6]
#define SSR_MAX_DIST 64.0
#define SSR_THICKNESS 0.2 // [0.1 0.2 0.35 0.5]
#define SSR_MAX_ROUGHNESS 0.6


// Water
//#define WATER_PIXELATED
#define WAVE_HEIGHT 0.15
#define WAVE_DETAIL 0.1
#define WATER_DENSITY 0.15
#define WATER_ROUGHNESS 0.03
#define WATER_IOR 1.33
#define WATER_REFLECTION_STRENGTH 3.0 // [1.0 1.5 2.0 2.5 3.0 4.0]

// Waves
const int WATER_SWELL_WAVES = 6;
const int WATER_DETAIL_WAVES = 6;
const int WATER_TOTAL_WAVES = WATER_SWELL_WAVES + WATER_DETAIL_WAVES;

const float WATER_WAVE_LENGTH_0 = 18.0;
const float WATER_WAVE_LENGTH_RATIO = 0.78;

const float WATER_SWELL_AMP_0 = 0.36;
const float WATER_SWELL_AMP_RATIO = 0.70;
const float WATER_DETAIL_AMP_0 = 0.45;
const float WATER_DETAIL_AMP_RATIO = 0.72;

const float WATER_STEEPNESS = 0.7;

// Wind
const float WATER_WIND_ANGLE = 0.9;
const float WATER_SWELL_SPREAD = 1.6;
const float WATER_TIME_SCALE = 0.25;
const float WATER_GRAVITY = 9.81;

// Gust patches
const float WATER_SWELL_GUST  = 0.35;
const float WATER_DETAIL_GUST = 0.8;

// Coarse domain warp
const float WATER_COARSE_SCALE = 0.045;
const float WATER_COARSE_STRENGTH = 2.6;
const float WATER_COARSE_ROTATION = 0.6;
const vec2 WATER_COARSE_SCROLL = vec2(0.012, -0.017);

// Fine domain warp
const float WATER_FINE_SCALE = 0.7;
const float WATER_FINE_STRENGTH = 0.22;
const float WATER_FINE_ROTATION = 1.1;
const vec2 WATER_FINE_SCROLL = vec2(0.22, -0.30);


// RTX features
#define RTX_FEATURES  // with this off 425fps in sky noon
#define MAX_VERTS 16777216 // [1048576 2097152 4194304 8388608 16777216]
#define MAX_DIST 256.0 // [32.0 64.0 128.0 196.0 256.0 384.0]
#define POS_BIAS 1 << 20

//#define VERTEX_COUNT_DEBUG


#endif