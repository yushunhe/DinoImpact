Shader "Surf/Sprite"
{
    // Unlit sprite shader with the global time-of-day tint (docs/lighting-plan.md 第 1 步).
    // Blend and premultiply match Sprites/Default, so with _DinoTint = 1 and
    // _DinoLift = 0 the art looks exactly as before. _DinoTint / _DinoLift are
    // globals set by DinoLighting.Apply, deliberately not in Properties.
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Tint", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "IgnoreProjector" = "True"
            "RenderType" = "Transparent"
            "PreviewType" = "Plane"
            "CanUseSpriteAtlas" = "True"
        }
        Cull Off
        Lighting Off
        ZWrite Off
        Blend One OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                fixed4 color : COLOR;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float2 wp : TEXCOORD1;      // world-space XY, for the point lights
                fixed4 color : COLOR;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _Color;
            fixed4 _DinoTint;
            fixed4 _DinoLift;
            // Local lights, set by DinoLighting.SetLight / CommitLights.
            // Array length must match DinoLighting.MaxLights (8).
            float4 _DinoLightPR[8];     // xy = world pos, z = radius
            float4 _DinoLightCI[8];     // rgb = colour, a = intensity
            float _DinoLightCount;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.wp = mul(unity_ObjectToWorld, v.vertex).xy;
                o.color = v.color;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 c = tex2D(_MainTex, i.uv) * _Color * i.color;

                // Additive light scaled by albedo, so lights brighten the art
                // rather than washing it out. Quadratic falloff to zero at radius.
                float3 add = 0;
                int n = (int)_DinoLightCount;
                for (int k = 0; k < 8; k++)
                {
                    if (k >= n) break;
                    float d = distance(i.wp, _DinoLightPR[k].xy);
                    float f = saturate(1 - d / _DinoLightPR[k].z);
                    add += _DinoLightCI[k].rgb * _DinoLightCI[k].a * (f * f);
                }

                c.rgb = saturate(c.rgb * _DinoTint.rgb + _DinoLift.rgb + c.rgb * add) * c.a;
                return c;
            }
            ENDCG
        }
    }
    FallBack "Sprites/Default"
}
