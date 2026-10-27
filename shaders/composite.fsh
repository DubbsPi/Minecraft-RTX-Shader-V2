#version 430 compatibility

#include "lib/settings.glsl"
#include "lib/shadow_util.glsl"
#include "lib/random.glsl"
#include "lib/taa.glsl"
#include "lib/sky.glsl"
#include "lib/pbr.glsl"


uniform sampler2D colortex0;  // albedo
uniform sampler2D colortex1;  // view space normal
uniform sampler2D colortex2;  // lightmap (x = block, y = sky)
uniform sampler2D colortex3;  // pbr

uniform sampler2D depthtex0;


uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;

uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int moonPhase;

uniform vec3 upPosition;
uniform vec3 fogColor;
uniform float far;


in vec2 texcoord;

/* RENDERTARGETS: 0,4 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 reflWeight;


vec3 toView(in vec2 uv, in float depth) {
    vec4 p = gbufferProjectionInverse * vec4(vec3(uv, depth) * 2.0 - 1.0, 1);
    return p.xyz / p.w;
}

float moonPhaseMult(in int moonPhase) {
    if (moonPhase == 0)
        return 1.0;
    else if (moonPhase == 1 || moonPhase == 7)
        return 0.75;
    else if (moonPhase == 2 || moonPhase == 6)
        return 0.5;
    else if (moonPhase == 3 || moonPhase == 5)
        return 0.25;
    else
        return 0.025;
}


void main() {
    uint rngState = randInt(ivec2(gl_FragCoord.xy), ivec2(viewWidth, viewHeight), frameCounter);

    vec4 src = texture(colortex0, texcoord);
    float depth = texture(depthtex0, texcoord).r;
    vec3 color;
    reflWeight = vec4(0);

    vec3 NDCPos = vec3(texcoord.xy, depth) * 2.0 - 1.0;
    NDCPos.xy -= taaJitter();
    vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);
    vec3 rayDirView = normalize(viewPos.xyz);
    vec3 rayDirWorld = normalize((gbufferModelViewInverse * vec4(rayDirView, 0)).xyz);
    
    vec3 sunDirW = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    vec3 moonDirW = normalize(mat3(gbufferModelViewInverse) * moonPosition);
    float nightFactor = nightFactor(sunDirW);


    // Sky
    bool isSky = depth >= 1.0;
        if (isSky) {
        vec3 dir = rayDirWorld;
        float phase = moonPhaseMult(moonPhase);
        
        vec3 trans, trans2;
        vec3 sky = atmosphereSky(dir, sunDirW, vec3(1.0, 0.98, 0.95), 20.0, cameraPosition.y, trans);
        sky += atmosphereSky(dir, moonDirW, vec3(0.45, 0.55, 0.9), 0.3 * mix(0.1, 1.0, phase), cameraPosition.y, trans2);

        float moonWash = 1.0 - MOON_WASH * phase * smoothstep(0.0, 0.4, moonDirW.y);
        vec3 space = vec3(0);
        #ifdef VANILLA_STARS
            space += minecraftStars(dir, moonDirW, nightFactor);
        #else
            space += realisticStars(dir, moonDirW, nightFactor)
                   + (nebula(dir, moonDirW, nightFactor) * NEBULA_BRIGHTNESS
                   + galacticHaze(dir, moonDirW, nightFactor)) * moonWash;
        #endif


        vec3 bodies = vec3(0);
        float cover = 0.0;

        float spriteLum = max(src.r, max(src.g, src.b));
        float spriteCore = smoothstep(0.25, 0.4, spriteLum);
        vec3 sprite = pow(src.rgb, vec3(2.2)) * mix(spriteCore, 1.0, SPRITE_GLOW);
        bodies += sprite * SPRITE_BOOST;
        cover = spriteCore;
        

        #ifndef VANILLA_SUN
            vec4 s = sunBody(dir, sunDirW);
            bodies += s.rgb;
            cover = 1.0 - (1.0 - cover) * (1.0 - s.a);
        #endif
        #ifndef VANILLA_MOON
            vec4 m = moonBody(dir, moonDirW, moonPhase) * 0.1;
            bodies += m.rgb;
            cover = 1.0 - (1.0 - cover) * (1.0 - m.a);
        #endif

        vec3 spaceTrans = pow(trans, vec3(SPACE_EXTINCTION));
        color = sky + space * (1.0 - cover) * spaceTrans + bodies * trans;
    }
    
    // Regular geometry
    else {
        vec3 albedo = pow(src.rgb, vec3(2.2));
        vec3 viewNormal = normalize(texture(colortex1, texcoord).xyz * 2.0 - 1.0);
        vec2 lm = texture(colortex2, texcoord).xy;
        vec3 pos = toView(texcoord, depth);

        // Day vs night
        float sunUp = dot(normalize(sunPosition), normalize(upPosition));
        float day = smoothstep(-0.1, 0.25, sunUp);

        // Lights
        vec3 L = normalize(shadowLightPosition);
        float rawNdotL = dot(viewNormal, L);
        float NdotL = max(rawNdotL, 0.0);
        vec3 sunlightColor = sunTransmittance(day > 0.0? sunDirW : moonDirW, cameraPosition.y);
        vec3 ambColor = mix(vec3(0.02, 0.03, 0.06), vec3(0.35, 0.45, 0.65), day);

        // Material
        vec3 worldPos = (gbufferModelViewInverse * vec4(pos, 1.0)).xyz + cameraPosition;
        PBRMaterial mat = getMaterial(texture(colortex3, texcoord));

        vec3 V = normalize(-pos);
        float NdotV = max(dot(viewNormal, V), 1e-4);
        vec3 F0 = mix(vec3(mat.f0), albedo, mat.metallic);

        // Shadow
        vec3 shadow = vec3(1);

        vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);

        #ifdef PIXELATED_SHADOWS
            vec3 worldNormal = mat3(gbufferModelViewInverse) * viewNormal;
            vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1)).xyz;
            bool isHand = depth < 0.56;
            if (!isHand) feetPlayerPos = snapToShadowGrid(feetPlayerPos, worldNormal);
            vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1)).xyz;
        #else
            vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1)).xyz;
            vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1)).xyz;
        #endif

        vec3 shadowClipPos = projectAndDivide(shadowProjection, shadowViewPos);
        bool inMap = all(lessThan(abs(shadowClipPos.xy), vec2(0.95)));

        if (rawNdotL > 0.0) {
            shadowClipPos.z -= 0.001;  // Bias
            #ifdef VARIABLE_PENUMBRA_SHADOWS
                shadow = getPCSSShadow(shadowClipPos, rand(rngState));
            #else
                shadow = getSoftShadow(shadowClipPos, FIXED_SHADOW_RADIUS, rand(rngState));
            #endif
        }


        float sky = lm.y * lm.y;
        float block = pow(lm.x, 3.0);

        // Direct sun
        Lobes lb = evalLobes(viewNormal, V, L, mat, albedo, F0);
        vec3 sunE = sunlightColor * PI * sky * max(day, 0.1) * (day < 0.0? moonPhaseMult(moonPhase) : 1.0);

        vec3 directDiffuse = lb.diffuse * sunE * NdotL * shadow;
        vec3 directSpec = lb.spec * sunE * NdotL * shadow;

        // Ambient
        vec3 envW = envBRDFApprox(F0, mat.roughness, NdotV);
        vec3 envColor = ambColor;

        vec3 ambDiffuse = albedo * (1.0 - mat.metallic) * (vec3(1) - envW) * ambColor * sky;
        vec3 blockLight = albedo * mix(1.0, 0.35, mat.metallic) * vec3(1.0, 0.6, 0.3) * block * 2.0;

        vec3 base = ambDiffuse + directDiffuse + blockLight + albedo * 0.01;
        color = base + directSpec;

        // Fog
        float f = smoothstep(0.75, 1.0, length(pos) / far);
        color = mix(color, pow(fogColor, vec3(2.2)), f);

        reflWeight = vec4(clamp(envW * (1.0 - f), 0.0, 1.0), mat.roughness);
    }

    outColor = vec4(color, 1);
}
