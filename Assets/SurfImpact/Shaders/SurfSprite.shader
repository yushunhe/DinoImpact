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
            #pragma multi_compile_local __ DINO_UPRIGHT DINO_CAST_SHADOW
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
            #include "DinoClouds.cginc"

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.wp = mul(unity_ObjectToWorld, v.vertex).xy;
                o.color = v.color;
                return o;
            }

            // Coordinates run from the roots (y=0) to the farthest projected crown (y=1).
            float shadowLobe(float2 uv, float2 center, float2 radii, float softness)
            {
                float d = length((uv - center) / radii);
                return 1.0 - smoothstep(1.0 - softness, 1.0 + softness, d);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float opening = cloudOpening(cloudUV(i.wp));
                #if defined(DINO_CAST_SHADOW)
                    float2 uv = i.uv;
                    float softness = lerp(.16, .56, smoothstep(.12, .92, uv.y));
                    float crown = max(shadowLobe(uv, float2(.43,.67), float2(.28,.19), softness),
                                      shadowLobe(uv, float2(.64,.63), float2(.19,.15), softness));
                    float distanceFromTrunk = abs(uv.x - .50 + .035 * uv.y);
                    float trunk = (1.0 - smoothstep(.016, .026 + .105 * uv.y, distanceFromTrunk))
                                * smoothstep(0.0,.035,uv.y) * (1.0 - smoothstep(.44,.68,uv.y));
                    float contact = shadowLobe(uv, float2(.50,.095), float2(.14,.075), .36);
                    float opacity = max(.60 * contact, max(.46 * trunk, .44 * crown)) * _DinoSun.z * lerp(.38, 1.0, opening);
                    return fixed4(float3(.008,.016,.025) * opacity, opacity);
                #endif
                fixed4 c = tex2D(_MainTex, i.uv) * _Color * i.color;
                float3 albedo = c.rgb;
                // Passing clouds shade the scenery, pickups and rider together.
                float3 daylight = lerp(float3(.50,.66,.85), float3(2.16,1.66,1.05), opening);
                c.rgb *= lerp(1.0, daylight, _DinoSun.z);
                #if defined(DINO_UPRIGHT)
                    // Derivatives keep the lit edge on the sunward side of mirrored sprites.
                    float2 offset = ddx(i.uv) * _DinoSun.x + ddy(i.uv) * _DinoSun.y * sign(ddy(i.wp.y));
                    float edge = saturate(c.a - tex2D(_MainTex, i.uv + offset * 1.8).a);
                    float side = (i.uv.x - .5) * sign(ddx(i.uv.x)) * _DinoSun.x;
                    float sunlit = saturate(.26 + .76 * side + .44 * i.uv.y);
                    float3 model = lerp(float3(.68,.77,.88), float3(1.46,1.22,.91), sunlit);
                    c.rgb = c.rgb * lerp(1.0, model, _DinoSun.z)
                          + float3(.12,.085,.028) * edge * _DinoSun.z * opening;
                #endif
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

                c.rgb = saturate(c.rgb * _DinoTint.rgb + _DinoLift.rgb + albedo * add) * c.a;
                return c;
            }
            ENDCG
        }
    }
    FallBack "Sprites/Default"
}
