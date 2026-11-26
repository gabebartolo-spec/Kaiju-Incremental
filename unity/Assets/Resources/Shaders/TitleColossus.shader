// The title's colossus card (scenes/title_colossus.gd _card_sprite with scenes/title_colossus.gdshader) in the title
// city's 3D scene: a camera-facing card `_Card` metres wide and tall, its feet on `_Feet` (Unity axes), drawn among
// the transparents at Godot's render priority (FarFire.FLAME_PRIORITY - 1) and depth-tested, so the towers, the
// shore and the bay stand in front of it as in Godot. The baked black silhouette, a thin rim of fire light where its
// edge faces the inferno, a warm crown line along the skull and snout, and smog patches eating the legs and the
// tail; `_Amount` is how much of it shows (0 hidden in the smoke .. 1 plain against the fire). No fog (Godot's
// fog_disabled). One quad, drawn procedurally (TitleFxView). Colours arrive linear; display units straight out.
Shader "Hidden/Slice/TitleColossus"
{
    Properties
    {
        [HideInInspector] _Body("", 2D) = "black" {}
        [HideInInspector] _Noise("", 2D) = "gray" {}
        [HideInInspector] _Feet("", Vector) = (0, 0, 0, 0)
        [HideInInspector] _Card("", Vector) = (1, 1, 0, 0)
        [HideInInspector] _Amount("", Float) = 0
        [HideInInspector] _RimColour("", Vector) = (1, 0.45, 0.12, 1)
        [HideInInspector] _CrownColour("", Vector) = (1, 0.72, 0.4, 1)
        [HideInInspector] _BodyColour("", Vector) = (0.02, 0.012, 0.014, 1)
        [HideInInspector] _Rim("", Vector) = (0.012, 1.4, 0.1, 0)
        [HideInInspector] _RimLight("", Vector) = (-0.3, 0.95, 0, 0)
        [HideInInspector] _Crown("", Vector) = (2.5, 1, 0.34, 0)
        [HideInInspector] _Smog("", Vector) = (0.6, 0.5, 0, 0)
    }
    HLSLINCLUDE
    #pragma target 4.5
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"
    ENDHLSL

    SubShader
    {
        Tags { "RenderPipeline" = "HDRenderPipeline" "RenderType" = "Transparent" "Queue" = "Transparent" }
        Pass
        {
            Name "ForwardOnly"
            Tags { "LightMode" = "ForwardOnly" }
            Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
            ZWrite Off
            ZTest LEqual
            Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag

            TEXTURE2D(_Body);
            SAMPLER(sampler_Body);
            TEXTURE2D(_Noise);
            SAMPLER(sampler_Noise);
            float4 _Feet, _Card;
            float _Amount;
            float4 _RimColour, _CrownColour, _BodyColour;
            float4 _Rim;       // rim_width, rim_strength, rim_min
            float4 _RimLight;  // rim_light (x, y, normalised)
            float4 _Crown;     // crown_px, crown_strength, crown_extent
            float4 _Smog;      // smog, smog_tail
            float _TitleTime;

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            // Godot's billboard card: the camera's right and up through the feet, the quad's centre lifted half its
            // height (QuadMesh center_offset); uv as Godot's QuadMesh (v 0 at the top).
            Varyings Vert(uint vertexID : SV_VertexID)
            {
                uint corner = vertexID % 6u;
                float2 c = float2(corner == 1u || corner == 2u || corner == 4u ? 1.0 : 0.0, corner == 2u || corner >= 4u ? 1.0 : 0.0);
                float3 world = _Feet.xyz + UNITY_MATRIX_V[0].xyz * (c.x - 0.5) * _Card.x + UNITY_MATRIX_V[1].xyz * c.y * _Card.y;
                Varyings o;
                o.positionCS = TransformWorldToHClip(GetCameraRelativePositionWS(world));
                o.uv = float2(c.x, 1.0 - c.y);
                return o;
            }

            // The picture's alpha at Godot uv (y down; the loaded texture's rows run up).
            float Body(float2 uv) { return SAMPLE_TEXTURE2D(_Body, sampler_Body, float2(uv.x, 1.0 - uv.y)).a; }

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
                // Lit only where the body meets empty air AND the edge faces the fire's light; thinner along the top.
                float top = 1.0 - uv.y;
                float2 grad = float2(Body(uv + float2(width, 0.0)) - Body(uv - float2(width, 0.0)),
                    Body(uv + float2(0.0, width)) - Body(uv - float2(0.0, width)));
                float2 outward = -normalize(grad + 0.0001);
                float catches = saturate(dot(outward, _RimLight.xy));
                float aim = _Rim.z + (1.0 - _Rim.z) * pow(catches, 1.3);
                float rim = saturate(a - around) * _Rim.y * aim * lerp(0.55, 1.0, smoothstep(0.2, 0.9, top));
                // Smog: slow patches of smoke over the body, thickest low down and along the tail.
                float t = _TitleTime;
                float2 q = uv * float2(2.4, 1.0) * 1.6 + float2(t * 0.012, -t * 0.008);
                float patch = smoothstep(0.3, 0.7, SAMPLE_TEXTURE2D(_Noise, sampler_Noise, q).r * 0.65
                    + SAMPLE_TEXTURE2D(_Noise, sampler_Noise, q * 2.7 + 0.3).r * 0.35);
                float low = smoothstep(0.55, 0.1, top);
                float along = smoothstep(0.3, 0.95, uv.x);
                float eaten = clamp(_Smog.x * (0.35 * patch + 0.85 * low) + _Smog.y * along, 0.0, 0.92);
                // The crown: crown_px screen px thick at 2160 rows along the skull and snout's top edge.
                float2 reach = fwidth(uv) * _Crown.x * _ScreenSize.y / 2160.0;
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
                return float4(colour, a * _Amount * (1.0 - eaten * 0.9));
            }
            ENDHLSL
        }
    }
}
