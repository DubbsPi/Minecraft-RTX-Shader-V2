#ifndef INCLUDE_LUT_UTIL
#define INCLUDE_LUT_UTIL


uniform sampler2D skyLutSampler;


vec3 equirectToDir(in vec2 uv) {
    float longitude = (uv.x * 2.0 - 1.0) * PI;
    float latitude = (uv.y - 0.5) * PI;
    float cosLatitude = cos(latitude);

    return vec3(cosLatitude * cos(longitude), sin(latitude), cosLatitude * sin(longitude));
}

vec2 dirToEquirect(in vec3 direction) {
    vec3 dir = normalize(direction);
    float longitude = atan(dir.z, dir.x);
    float latitude = asin(clamp(dir.y, -1.0, 1.0));

    return vec2(longitude / (2.0 * PI) + 0.5, latitude / PI + 0.5);
}

vec3 sampleSkyLut(in vec3 direction) {
    ivec2 size = textureSize(skyLutSampler, 0);
    vec2 pixel = dirToEquirect(direction) * vec2(size) - 0.5;
    ivec2 base = ivec2(floor(pixel));
    vec2 blend = fract(pixel);

    int x0 = (base.x % size.x + size.x) % size.x;
    int x1 = (x0 + 1) % size.x;
    int y0 = clamp(base.y, 0, size.y - 1);
    int y1 = clamp(base.y + 1, 0, size.y - 1);

    vec3 lower = mix(
        texelFetch(skyLutSampler, ivec2(x0, y0), 0).rgb,
        texelFetch(skyLutSampler, ivec2(x1, y0), 0).rgb,
        blend.x
    );
    vec3 upper = mix(
        texelFetch(skyLutSampler, ivec2(x0, y1), 0).rgb,
        texelFetch(skyLutSampler, ivec2(x1, y1), 0).rgb,
        blend.x
    );

    return mix(lower, upper, blend.y);
}


#endif
