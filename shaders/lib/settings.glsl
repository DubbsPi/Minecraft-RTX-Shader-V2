#ifndef INCLUDE_SETTINGS
#define INCLUDE_SETTINGS

#include "common.glsl"


/*
const int colortex0Format = RGBA16F;  // Scene color
const int colortex6Format = RGBA16F;  // Water normals
const int colortex7Format = RGBA16F;  // TAA
*/


// TAA
const bool colortex7Clear = false;
const int TAA_JITTER_FRAMES = 8;
const float VARIANCE_GAMMA = 1.25;
const float BASE_BLEND = 0.15;


// Shadows
#define SHADOW_MAP_RESOLUTION 2048 // [512 1024 2048 4096 8192]
const int shadowMapResolution = SHADOW_MAP_RESOLUTION;
const float shadowDistanceRenderMul = 1.0;

#define SHADOW_SAMPLES 16 // [4 8 16 32 64]

const float PENUMBRA_SCALE = 0.08;
const float MIN_RADIUS_BLOCKS = 0.005;
const float MAX_RADIUS_BLOCKS = 2.0;
const float SEARCH_RADIUS_BLOCKS = 0.8;

#define PIXELATED_SHADOWS
#define SHADOW_PIXELS_PER_BLOCK 16 // [8 16 32 64]

#define VARIABLE_PENUMBRA_SHADOWS
#define FIXED_SHADOW_RADIUS 0.001 // [0.0005 0.001 0.0015 0.002 0.0025 0.003 0.004 0.005 0.0075 0.01]


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


const float SEA_LEVEL = 63.0;
const float MAX_SKY_DIST = 200000.0;
#define SKY_VIEW_STEPS 16 // [8 12 16 24 32]
#define SKY_LIGHT_STEPS 8 // [4 6 8 10 12]

const float SPRITE_BOOST = 6.0;


// Stars
#define STAR_SLAB 0.5
#define STAR_SPIN_RATE 0.7 // [0.1 0.3 0.5 0.7 0.9 1.1]

const int MC_STAR_GRID_X = 256;
const int MC_STAR_GRID_Y = 128;
const float MC_STAR_DENSITY = 0.1;
const float MC_STAR_STAR_RADIUS = 0.1;

const int REAL_STAR_GRID_X = 512;
const int REAL_STAR_GRID_Y = 256;
const float REAL_STAR_DENSITY = 0.18;
const float REAL_STAR_RADIUS = 0.075;

#define GALAXY_WIDTH 0.2 // [0.1 0.15 0.2 0.25 0.3]
#define GALAXY_BRIGHTNESS 0.05 // [0.025 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5]
#define NEBULA_BRIGHTNESS 0.25 // [0.025 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5]
#define NEBULA_BAND_BIAS 0.15 // [0.05 0.1 0.15 0.2 0.25 0.3]
#define STAR_DENSITY_MIN_MULT 0.2
#define STAR_DENSITY_MAX_MULT 2.5

const vec3 GALAXY_NORMAL = normalize(vec3(0.1, 0.9, 0.3));
const vec3 GALAXY_CENTER = normalize(vec3(0.9, -0.1, 0.1));


// Celestials
#define VANILLA_CLOUDS 2 // [0 1 2]
//#define VANILLA_SUN
//#define VANILLA_MOON
//#define VANILLA_STARS

#define SUN_PATH_ROTATION 15.0 // [0.0 5.0 10.0 15.0 20.0 25.0 30.0 35.0 40.0 45.0]
const float sunPathRotation = SUN_PATH_ROTATION;
const vec3 CELESTIAL_AXIS = normalize(vec3(0, sin(radians(SUN_PATH_ROTATION)), cos(radians(SUN_PATH_ROTATION))));

#define SPRITE_GLOW 0.5
#define SPACE_EXTINCTION 0.5
#define MOON_WASH 0.7

#define SUN_RADIUS_DEG 2.0
#define MOON_RADIUS_DEG 1.5
#define SUN_DISC_SCALE 1.0
#define MOON_DISC_SCALE 1.0
#define SUN_CORONA 0.25 // [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5]
#define MOON_PHASE_FLIP 1.0 
#define MOON_ROLL_DEG 90.0


// SSR
#define SSR_STEPS 32 // [16 32 64]
#define SSR_REFINE_STEPS 6 // [2 3 4 5 6 7 8]
#define SSR_MAX_DIST 64.0
#define SSR_THICKNESS 0.75
#define SSR_MAX_ROUGHNESS 0.6


// Water
//#define WATER_PIXELATED
#define WAVE_HEIGHT 0.15
#define WAVE_DETAIL 0.1
#define WATER_DENSITY 0.35
#define WATER_ROUGHNESS 0.05
#define WATER_IOR 1.33


#endif