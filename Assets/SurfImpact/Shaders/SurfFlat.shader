Shader "Surf/Flat"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _EmissionColor ("Emission", Color) = (0,0,0,1)
        _RimColor ("Rim Color", Color) = (1,1,1,0.16)
        _RimPower ("Rim Power", Range(0.5, 8)) = 3.5
        _Ambient ("Ambient", Range(0, 2)) = 0.5
        _SunBoost ("Sun Boost", Range(0, 2)) = 0.85
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 150
        Pass
        {
            Tags { "LightMode"="ForwardBase" }
            Cull Back
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 color : COLOR;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 wnormal : TEXCOORD0;
                float3 wpos : TEXCOORD1;
                float4 color : COLOR;
                UNITY_FOG_COORDS(2)
            };

            fixed4 _Color;
            fixed4 _EmissionColor;
            fixed4 _RimColor;
            float _RimPower;
            float _Ambient;
            float _SunBoost;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.wnormal = UnityObjectToWorldNormal(v.normal);
                o.wpos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.color = v.color;
                UNITY_TRANSFER_FOG(o, o.pos);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 n = normalize(i.wnormal);
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.wpos);
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                float ndl = saturate(dot(n, lightDir));
                float halfLambert = pow(ndl * 0.5 + 0.5, 1.5);

                float3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb * _Ambient;
                float3 lit = _LightColor0.rgb * halfLambert * _SunBoost;
                float3 base = i.color.rgb * _Color.rgb;
                float3 col = base * (ambient + lit);

                float rim = pow(1.0 - saturate(dot(n, viewDir)), _RimPower) * _RimColor.a;
                col += _RimColor.rgb * rim + _EmissionColor.rgb;

                fixed4 result = fixed4(col, 1.0);
                UNITY_APPLY_FOG(i.fogCoord, result);
                return result;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
