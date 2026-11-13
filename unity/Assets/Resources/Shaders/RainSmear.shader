// A light's reflection on a wet street (scenes/rain_smear.gdshader; WeatherView, no screen-space reflections:
// director 2026-10-23 "a wet sheen"): a soft glowing smear on the ground under a lamp or in front of a lit building,
// drawn long toward the camera the way a light's reflection stretches on wet asphalt, brightest at its foot and
// breaking up with ripples. One procedural quad per smear (Godot: a MultiMesh); _Smears holds, per smear, its foot
// (Godot axes) and width, its colour and how much of it is on, and its length. Added light; Godot's fog over it.
Shader "Hidden/Slice/RainSmear"
{
    HLSLINCLUDE
    #pragma target 4.5
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/ShaderPass/FragInputs.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/ShaderPass/ShaderPass.cs.hlsl"
    ENDHLSL

    SubShader
    {
        Tags { "RenderPipeline" = "HDRenderPipeline" "RenderType" = "Transparent" "Queue" = "Transparent" }
        Pass
        {
            Name "ForwardOnly"
            Tags { "LightMode" = "ForwardOnly" }
            Blend One One
            ZWrite Off
            ZTest LEqual
            Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #define SHADERPASS SHADERPASS_FORWARD_UNLIT
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Material.hlsl"

            // Three per smear: foot x, y, z (Godot axes) and width; colour rgb (Godot's numbers) and how much is on;
            // length, unused.
            StructuredBuffer<float4> _Smears;
            float4 _SmearToward;  // xy: toward the camera, flat, unit (Godot axes); z: rain_smear alpha; w: exposure unit

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionRWS : TEXCOORD0;
                float2 uv : TEXCOORD1;
                float4 color : TEXCOORD2;
            };

            float3 Fogged(float4 positionCS, float3 positionRWS, float3 color)
            {
                PositionInputs pos = GetPositionInput(positionCS.xy, _ScreenSize.zw, positionCS.z, positionCS.w, positionRWS, uint2(0, 0));
                float3 fogColor, fogOpacity;
                if (EvaluateAtmosphericScattering(pos, GetWorldSpaceNormalizeViewDir(positionRWS), fogColor, fogOpacity))
                    color = color * (1.0 - fogOpacity) + fogColor;
                return color;
            }

            Varyings Vert(uint vertexID : SV_VertexID, uint instanceID : SV_InstanceID)
            {
                uint corner = vertexID % 6u;
                float2 c = float2(corner == 1u || corner == 2u || corner == 4u ? 1.0 : 0.0, corner == 2u || corner >= 4u ? 1.0 : 0.0);
                float4 foot = _Smears[instanceID * 3u];
                float4 color = _Smears[instanceID * 3u + 1u];
                float4 size = _Smears[instanceID * 3u + 2u];
                float2 along = _SmearToward.xy;
                float2 across = float2(-along.y, along.x);
                // The quad (1 x 1, in x and z) runs from the light's foot (z = -0.5) out toward the camera.
                float2 off = across * (c.x - 0.5) * foot.w + along * c.y * size.x;
                float3 at = float3(foot.x + off.x, foot.y, -(foot.z + off.y));
                Varyings o = (Varyings)0;
                o.positionRWS = GetCameraRelativePositionWS(at);
                o.positionCS = TransformWorldToHClip(o.positionRWS);
                o.uv = c;
                o.color = color;
                return o;
            }

            float4 Frag(Varyings i) : SV_Target
            {
                // v runs 0 at the light's foot to 1 at the tip: bright and narrow at the foot, widening and fading
                // toward the camera, with ripples that break it up.
                float t = saturate(i.uv.y);
                float across = abs(i.uv.x * 2.0 - 1.0);
                float body = smoothstep(1.0, 0.0, across / (0.35 + 0.65 * t));
                float tail = pow(1.0 - t, 1.5);
                float ripple = 0.7 + 0.3 * sin(t * 30.0 + i.uv.x * 4.0);
                // Added light: a light can never add more than its own colour.
                float3 glow = i.color.rgb * i.color.a * _SmearToward.z * body * tail * ripple * _SmearToward.w;
                return float4(Fogged(i.positionCS, i.positionRWS, glow), 1.0);
            }
            ENDHLSL
        }
    }
}
