#ifndef INCLUDE_SETTINGS
#define INCLUDE_SETTINGS

#include "common.glsl"


/*
const int colortex0Format = RGBA16F;  // Scene color
const int colortex1Format = RGBA16F;  // Opaque normals
const int colortex2Format = RG16F;    // Lightmap
const int colortex3Format = RG16F;    // PBR material
const int colortex4Format = RGBA16F;  // Reflections
const int colortex5Format = RGBA16F;  // Translucent tint
const int colortex6Format = RGBA16F;  // Translucent normals
const int colortex7Format = RG16F;    // Reflection depth
*/


// TAA
const int TAA_JITTER_FRAMES = 8;
const float VARIANCE_GAMMA = 1.25;
const float BASE_BLEND = 0.10;
const float TAA_ADAPTIVE_BLEND = 0.28;


// Shadows
#define SHADOW_MAP_RESOLUTION 2048 // [512 1024 2048 4096 8192]
const float shadowIntervalSize = 1.0;

#define SHADOW_SAMPLES 8 // [4 6 8 16 32]
#define PCSS_BLOCKER_SAMPLES 8 // [4 6 8 10]

const float PENUMBRA_SCALE = 0.08;
const float MIN_RADIUS_BLOCKS = 0.005;
const float MAX_RADIUS_BLOCKS = 2.0;
const float SEARCH_RADIUS_BLOCKS = 0.8;

//#define PIXELATED_SHADOWS
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
#define SUN_CORONA 0.15 // [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35]
#define MOON_PHASE_FLIP 1.0 
#define MOON_ROLL_DEG 90.0


// SSR
#define SSR_STEPS 48 // [16 32 48 64 96]
#define SSR_REFINE_STEPS 4 // [2 3 4 5 6]
#define SSR_MAX_DIST 64.0
#define SSR_THICKNESS 0.5 // [0.2 0.35 0.5 0.75]
#define SSR_MAX_ROUGHNESS 0.95


// Water
//#define WATER_PIXELATED
#define WAVE_HEIGHT 0.15
#define WAVE_DETAIL 0.1
#define WATER_DENSITY 0.15
#define WATER_ROUGHNESS 0.03
#define WATER_IOR 1.33
#define WATER_REFLECTION_STRENGTH 2.0 // [1.0 1.5 2.0 2.5 3.0 4.0]

#define WATER_DEBUG 0 // [0 1 2 3 4 5 6]

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
#define RTX_FEATURES
#define RTX_REFLECTIONS
#define RTX_SHADOWS

#define BVH_REUSE
#define RTX_REFRACTION
//#define SS_REFRACTION_FIRST
//#define SSR_FIRST

#define RTX_REFLECTION_SHADOWS
#define RTX_SHADOW_SAMPLES 1 // [1 2 3 4 6 8 10 12 16]
//#define RTX_SHADOW_CULLING
#define CULL_TAP_RADIUS 2

//#define USE_SUBGROUPS // Broken

#define MAX_QUADS 2359296 // [262144 589824 1048576 2359296 4194304]
#define MAX_CHUNK_DIST 8 // [2 4 6 8 10 12 14 16 18 20 22 24 26 28 30 32]
#define VIRT_MAX 2048.0

#define BVH_DELAY_FRAMES 96 // [0 64 96 128 256]
#define RT_ALPHA_CUTOFF 0.025

#define RT_OPAQUE_ALPHA 0.98
#define RT_TINT_EPS 0.002
#define RT_TINT_MIN_ENERGY 0.004
#define MAX_TINT_LAYERS 8


#if MAX_CHUNK_DIST == 2
    #define MAX_DIST 32.0
#elif MAX_CHUNK_DIST == 4
    #define MAX_DIST 64.0
#elif MAX_CHUNK_DIST == 6
    #define MAX_DIST 96.0
#elif MAX_CHUNK_DIST == 8
    #define MAX_DIST 128.0
#elif MAX_CHUNK_DIST == 10
    #define MAX_DIST 160.0
#elif MAX_CHUNK_DIST == 12
    #define MAX_DIST 192.0
#elif MAX_CHUNK_DIST == 14
    #define MAX_DIST 224.0
#elif MAX_CHUNK_DIST == 16
    #define MAX_DIST 256.0
#elif MAX_CHUNK_DIST == 18
    #define MAX_DIST 288.0
#elif MAX_CHUNK_DIST == 20
    #define MAX_DIST 320.0
#elif MAX_CHUNK_DIST == 22
    #define MAX_DIST 352.0
#elif MAX_CHUNK_DIST == 24
    #define MAX_DIST 384.0
#elif MAX_CHUNK_DIST == 26
    #define MAX_DIST 416.0
#elif MAX_CHUNK_DIST == 28
    #define MAX_DIST 448.0
#elif MAX_CHUNK_DIST == 30
    #define MAX_DIST 480.0
#elif MAX_CHUNK_DIST == 32
    #define MAX_DIST 512.0
#endif

uniform float far;
#define ACTUAL_MAX_DIST min(MAX_DIST, far)
const float shadowDistance = MAX_DIST;
const float shadowDistanceRenderMul = 1.0;

const float RAY_EPSILON = 1e-6;


#define TRACE_WATER
#define TRACE_ENTITIES

#define ENTITY_ATLAS_SLOT_SIZE 128
#define ENTITY_ATLAS_SIZE 4096


// We ignore me not renaming this
#if MAX_QUADS == 4194304
    #define MAX_VERTS_SQRT 4096
#elif MAX_QUADS == 2359296
    #define MAX_VERTS_SQRT 3072
#elif MAX_QUADS == 1048576
    #define MAX_VERTS_SQRT 2048
#elif MAX_QUADS == 589824
    #define MAX_VERTS_SQRT 1536
#elif MAX_QUADS == 262144
    #define MAX_VERTS_SQRT 1024
#endif

#if MAX_QUADS == 4194304
    #define MAX_QUADS_OVER_128 32768
#elif MAX_QUADS == 2359296
    #define MAX_QUADS_OVER_128 16384
#elif MAX_QUADS == 1048576
    #define MAX_QUADS_OVER_128 8192
#elif MAX_QUADS == 589824
    #define MAX_QUADS_OVER_128 4096
#elif MAX_QUADS == 262144
    #define MAX_QUADS_OVER_128 2048
#endif

#if MAX_QUADS == 4194304
    #define MAX_QUADS_OVER_64 65536
#elif MAX_QUADS == 2359296
    #define MAX_QUADS_OVER_64 32768
#elif MAX_QUADS == 1048576
    #define MAX_QUADS_OVER_64 16384
#elif MAX_QUADS == 589824
    #define MAX_QUADS_OVER_64 8192
#elif MAX_QUADS == 262144
    #define MAX_QUADS_OVER_64 4096
#endif

#if MAX_QUADS == 4194304
    #define MAX_QUADS_OVER_4096 1024
#elif MAX_QUADS == 2359296
    #define MAX_QUADS_OVER_4096 512
#elif MAX_QUADS == 1048576
    #define MAX_QUADS_OVER_4096 256
#elif MAX_QUADS == 589824
    #define MAX_QUADS_OVER_4096 128
#elif MAX_QUADS == 262144
    #define MAX_QUADS_OVER_4096 64
#endif


//#define VERTEX_COUNT_DEBUG
//#define RADIX_SORT_DEBUG
//#define BVH_DEBUG
#define TRACE_DEBUG 0 // [0 1 2]
//#define ENTITY_ATLAS_DEBUG
//#define VERTEX_HASH_DEBUG
//#define DEBUG_RT_CULL
//#define BVH_REUSE_DEBUG

#ifdef TRACE_WATER
#endif
#ifdef TRACE_ENTITIES
#endif
#ifdef RTX_REFLECTIONS
#endif
#ifdef RTX_SHADOWS
#endif
#ifdef RTX_SHADOW_SAMPLES
#endif
#ifdef USE_SUBGROUPS
#endif
#ifdef RTX_REFLECTION_SHADOWS
#endif

#if defined RTX_SHADOWS && defined RTX_SHADOW_CULLING
    const int shadowMapResolution = 2048;
#elif defined RTX_SHADOWS
    const int shadowMapResolution = 1;
#else
    const int shadowMapResolution = SHADOW_MAP_RESOLUTION;
#endif


#endif