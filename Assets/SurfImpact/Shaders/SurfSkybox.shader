Shader "Surf/Skybox"
{
    Properties
    {
        _TopColor ("Top", Color) = (0.25, 0.55, 0.85, 1)
        _HorizonColor ("Horizon", Color) = (0.72, 0.88, 0.95, 1)
        _BottomColor ("Bottom", Color) = (0.15, 0.4, 0.55, 1)
        _SunColor ("Sun", Color) = (1, 0.95, 0.8, 1)
        _SunDir ("Sun Direction", Vector) = (0, 1, 0, 0)
        _SunIntensity ("Sun Intensity", Range(0, 2)) = 1
        _SunSize ("Sun Size", Range(0.0001, 0.01)) = 0.0006
        _StarAmount ("Stars", Range(0, 1)) = 0
    }
    SubShader
    {
        Tags { "Queue"="Background" "RenderType"="Background" "PreviewType"="Skybox" }
        Cull Off
        ZWrite Off
        Fog { Mode Off }
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata { float4 vertex : POSITION; };
            struct v2f { float4 pos : SV_POSITION; float3 dir : TEXCOORD0; };

            fixed4 _TopColor, _HorizonColor, _BottomColor, _SunColor;
            float4 _SunDir;
            float _SunIntensity, _SunSize, _StarAmount;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.dir = v.vertex.xyz;
                return o;
            }

            float hash31(float3 p)
            {
                return frac(sin(dot(p, float3(12.9898, 78.233, 37.719))) * 43758.5453);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 dir = normalize(i.dir);
                float up = saturate(dir.y);
                float3 col = lerp(_HorizonColor.rgb, _TopColor.rgb, pow(up, 0.62));
                float down = saturate(-dir.y);
                col = lerp(col, _BottomColor.rgb, smoothstep(0.0, 0.7, down));

                float sunDot = saturate(dot(dir, normalize(_SunDir.xyz)));
                float disc = smoothstep(1.0 - _SunSize, 1.0 - _SunSize * 0.35, sunDot);
                float glow = pow(sunDot, 28.0) * 0.35 + pow(sunDot, 6.0) * 0.10;
                col += _SunColor.rgb * (disc * 1.4 + glow) * _SunIntensity;

                if (_StarAmount > 0.001)
                {
                    float3 p = dir * 260.0;
                    float star = smoothstep(0.9965, 0.9997, hash31(floor(p)));
                    float mask = smoothstep(0.02, 0.32, dir.y);
                    col += float3(0.85, 0.92, 1.0) * star * mask * _StarAmount * 0.9;
                }

                return fixed4(col, 1.0);
            }
            ENDCG
        }
    }
}
