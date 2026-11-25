#ifndef DINO_CLOUDS_INCLUDED
#define DINO_CLOUDS_INCLUDED

sampler2D _DinoCloudDensity;
float4 _DinoCloud; // wind displacement (world XY), inverse tile width, scattering strength
float4 _DinoSun;   // direction towards the sun (world XY), daylight strength

float2 cloudUV(float2 world)
{
    return (world - _DinoCloud.xy) * _DinoCloud.z + float2(.23, .61);
}

float cloudOpening(float2 uv)
{
    return 1.0 - smoothstep(.32, .66, tex2D(_DinoCloudDensity, uv).r);
}
#endif
