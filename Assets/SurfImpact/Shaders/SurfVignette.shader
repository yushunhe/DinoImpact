Shader "Surf/Vignette"
{
    // Full-screen edge darkening used by DinoVignette (docs/lighting-plan.md 第 3 步).
    // _Strength 0 leaves the image unchanged; 1 darkens the corners fully.
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Strength ("Strength", Float) = 0
    }
    SubShader
    {
        Cull Off
        ZWrite Off
        ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float _Strength;
            float4 _CloudView;
            float4 _MainTex_TexelSize;
            #include "DinoClouds.cginc"

            fixed4 frag (v2f_img i) : SV_Target
            {
                fixed4 c = tex2D(_MainTex, i.uv);
                if (_DinoSun.z * _DinoCloud.w > .001)
                {
                    float2 viewUV = i.uv;
                    #if UNITY_UV_STARTS_AT_TOP
                    if (_MainTex_TexelSize.y < 0) viewUV.y = 1.0 - viewUV.y;
                    #endif
                    float2 world = _CloudView.xy + (2.0 * viewUV - 1.0) * _CloudView.zw;
                    float2 uv = cloudUV(world);
                    // Approximate in-scattered sunlight at five heights in the air column.
                    // A narrow break in the cloud projects a soft shaft along the sun direction.
                    float2 ray = _DinoSun.xy * _DinoCloud.z * 3.0;
                    float scatter = 0;
                    [unroll] for (int j = 0; j < 5; ++j)
                        scatter += smoothstep(.66, .97, cloudOpening(uv + ray * j));
                    // Smaller gaps break the haze into intermittent shafts. Their footprint
                    // stretches along the light direction but travels with the same cloud bank.
                    float2 across = float2(-_DinoSun.y, _DinoSun.x);
                    float2 apertureUV = across * dot(uv, across) * 4.5
                                      + _DinoSun.xy * dot(uv, _DinoSun.xy) * .52;
                    float aperture = smoothstep(.53, .91, cloudOpening(apertureUV));
                    float haze = scatter * .2 * (.20 + 1.35 * aperture) * _DinoSun.z * _DinoCloud.w;
                    c.rgb += float3(1.0, .74, .39) * haze;
                }
                // Distance from the centre: 0 at the middle, ~1 at the corners.
                float d = length(i.uv - 0.5) * 1.4;
                float v = smoothstep(0.35, 0.85, d);
                c.rgb *= 1.0 - v * _Strength;
                return c;
            }
            ENDCG
        }
    }
    FallBack Off
}
