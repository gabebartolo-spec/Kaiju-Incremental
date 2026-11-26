// The title's colossus card (scenes/title_colossus.gdshader) on the menu canvas (TitleBackdrop): the baked black
// silhouette, a thin rim of fire light where its edge faces the inferno, a warm crown line along the skull and
// snout, and smog patches eating the legs and the tail. The vertex colour's alpha is how much of it shows (Godot's
// `amount`, already under the city's fade). Colours arrive linear.
Shader "Hidden/Slice/TitleColossus"
{
    Properties
    {
        [PerRendererData] _MainTex("", 2D) = "white" {}
        _Noise("", 2D) = "gray" {}
    }
    SubShader
    {
        Tags { "Queue" = "Transparent" "RenderType" = "Transparent" "IgnoreProjector" = "True" "PreviewType" = "Plane" }
        Cull Off
        ZWrite Off
        ZTest [unity_GUIZTestMode]
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma target 4.5
            #include "UnityCG.cginc"

            sampler2D _MainTex, _Noise;
            float4 _MainTex_TexelSize;
            float4 _RimColour, _CrownColour, _BodyColour;
            float4 _Rim;    // rim_width, rim_strength, rim_min
            float4 _RimLight;  // rim_light (x, y, normalised)
            float4 _Crown;  // crown_px, crown_strength, crown_extent
            float4 _Smog;   // smog, smog_tail

            struct Attributes { float4 vertex : POSITION; float4 color : COLOR; float2 uv : TEXCOORD0; };
            struct Varyings { float4 pos : SV_POSITION; float4 color : COLOR; float2 uv : TEXCOORD0; };

            Varyings Vert(Attributes v)
            {
                Varyings o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.color = v.color;
                // Godot's uv runs y down.
                o.uv = float2(v.uv.x, 1.0 - v.uv.y);
                return o;
            }

            float Body(float2 uv) { return tex2D(_MainTex, float2(uv.x, 1.0 - uv.y)).a; }

            float4 Frag(Varyings i) : SV_Target
            {
                float2 uv = i.uv;
                float width = _Rim.x;
                float a = Body(uv);
                float around = 0.0;
                for (int k = 0; k < 8; k++)
                {
                    float ang = k * 0.7853982;
                    around += Body(uv + float2(cos(ang), sin(ang)) * width);
                }
                around *= 0.125;
                float top = 1.0 - uv.y;
                float2 grad = float2(Body(uv + float2(width, 0.0)) - Body(uv - float2(width, 0.0)),
                    Body(uv + float2(0.0, width)) - Body(uv - float2(0.0, width)));
                float2 outward = -normalize(grad + 0.0001);
                float catches = saturate(dot(outward, _RimLight.xy));
                float aim = _Rim.z + (1.0 - _Rim.z) * pow(catches, 1.3);
                float rim = saturate(a - around) * _Rim.y * aim * lerp(0.55, 1.0, smoothstep(0.2, 0.9, top));
                float t = _Time.y;
                float2 q = uv * float2(2.4, 1.0) * 1.6 + float2(t * 0.012, -t * 0.008);
                float patch = smoothstep(0.3, 0.7, tex2D(_Noise, q).r * 0.65 + tex2D(_Noise, q * 2.7 + 0.3).r * 0.35);
                float low = smoothstep(0.55, 0.1, top);
                float along = smoothstep(0.3, 0.95, uv.x);
                float eaten = clamp(_Smog.x * (0.35 * patch + 0.85 * low) + _Smog.y * along, 0.0, 0.92);
                float2 reach = fwidth(uv) * _Crown.x * _ScreenParams.y / 2160.0;
                float open = 0.0;
                for (int j = 0; j < 5; j++)
                {
                    float ang = radians(30.0 + j * 30.0);
                    open += 1.0 - Body(uv + float2(cos(ang), -sin(ang)) * reach);
                }
                float head = smoothstep(_Crown.z, _Crown.z - 0.05, uv.x);
                float crown = saturate(smoothstep(0.5, 0.9, a) * smoothstep(0.2, 0.6, open * 0.2) * head * _Crown.y);
                float3 colour = lerp(_BodyColour.rgb, _RimColour.rgb, saturate(rim * (1.0 - 0.85 * patch)));
                colour = lerp(colour, _CrownColour.rgb, crown * (1.0 - 0.5 * patch));
                return float4(colour, a * i.color.a * (1.0 - eaten * 0.9));
            }
            ENDHLSL
        }
    }
}
