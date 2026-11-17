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

            fixed4 frag (v2f_img i) : SV_Target
            {
                fixed4 c = tex2D(_MainTex, i.uv);
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
