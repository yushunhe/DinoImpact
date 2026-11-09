Shader "Surf/Water"
{
    Properties
    {
        _DeepColor ("Deep Color", Color) = (0.03, 0.28, 0.38, 1)
        _ShallowColor ("Shallow Color", Color) = (0.2, 0.8, 0.78, 1)
        _FoamColor ("Foam Color", Color) = (1, 1, 1, 1)
        _SkyColor ("Sky Color", Color) = (0.6, 0.85, 0.95, 1)
        _SunColor ("Sun Color", Color) = (1, 1, 1, 1)
        _SunDir ("Sun Direction", Vector) = (0, 1, 0, 0)
        _WaveTime ("Wave Time", Float) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 200
        Pass
        {
            Tags { "LightMode"="ForwardBase" }
            Cull Off
            ZWrite On
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 wpos : TEXCOORD0;
                UNITY_FOG_COORDS(1)
            };

            fixed4 _DeepColor, _ShallowColor, _FoamColor, _SkyColor, _SunColor;
            float4 _SunDir;
            float _WaveTime;

            float WaveHeight(float2 p, float t)
            {
                return 0.50 * sin(dot(float2( 0.800,  0.600), p) * 0.209440 + t * 1.10)
                     + 0.28 * sin(dot(float2(-0.500,  0.866), p) * 0.330693 + t * 1.65)
                     + 0.34 * sin(dot(float2( 0.949, -0.316), p) * 0.149600 + t * 0.72);
            }

            float2 WaveSlope(float2 p, float t)
            {
                float2 s = float2(0, 0);
                s += 0.50 * 0.209440 * cos(dot(float2( 0.800,  0.600), p) * 0.209440 + t * 1.10) * float2( 0.800,  0.600);
                s += 0.28 * 0.330693 * cos(dot(float2(-0.500,  0.866), p) * 0.330693 + t * 1.65) * float2(-0.500,  0.866);
                s += 0.34 * 0.149600 * cos(dot(float2( 0.949, -0.316), p) * 0.149600 + t * 0.72) * float2( 0.949, -0.316);
                return s;
            }

            v2f vert (appdata v)
            {
                v2f o;
                float3 wp = mul(unity_ObjectToWorld, v.vertex).xyz;
                wp.y += WaveHeight(wp.xz, _WaveTime);
                o.wpos = wp;
                o.pos = mul(UNITY_MATRIX_VP, float4(wp, 1.0));
                UNITY_TRANSFER_FOG(o, o.pos);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float2 p = i.wpos.xz;
                float2 slope = WaveSlope(p, _WaveTime);
                float2 ripple = float2(
                    cos(p.x * 1.9 + _WaveTime * 2.4) + cos(p.y * 2.3 - _WaveTime * 1.7),
                    cos(p.y * 1.7 - _WaveTime * 2.1) + cos(p.x * 2.7 + _WaveTime * 1.3)) * 0.035;
                float3 N = normalize(float3(-(slope.x + ripple.x), 1.0, -(slope.y + ripple.y)));

                float3 V = normalize(_WorldSpaceCameraPos.xyz - i.wpos);
                float3 L = normalize(_SunDir.xyz);
                float height = i.wpos.y;

                float3 base = lerp(_DeepColor.rgb, _ShallowColor.rgb, saturate(height * 0.55 + 0.5));
                float fresnel = pow(1.0 - saturate(dot(N, V)), 4.0);
                base = lerp(base, _SkyColor.rgb, fresnel * 0.6);

                float diff = saturate(dot(N, L));
                float3 col = base * (0.58 + 0.42 * diff);
                col += base * _SunColor.rgb * 0.06;

                float3 H = normalize(L + V);
                float spec = pow(saturate(dot(N, H)), 140.0) * 1.1;
                col += _SunColor.rgb * spec;

                float crest = smoothstep(0.55, 1.02, height);
                float pattern = sin(p.x * 0.55 + p.y * 0.33 - _WaveTime * 1.8) * 0.5 + 0.5;
                pattern = smoothstep(0.58, 0.95, pattern);
                float foam = crest * pattern * 0.7 + smoothstep(0.32, 0.72, length(slope)) * 0.18;
                col = lerp(col, _FoamColor.rgb, saturate(foam));

                fixed4 result = fixed4(col, 1.0);
                UNITY_APPLY_FOG(i.fogCoord, result);
                return result;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
