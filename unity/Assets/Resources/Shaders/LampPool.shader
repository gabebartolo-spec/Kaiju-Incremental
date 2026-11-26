// The warm pool a street lamp lays on the ground at night (scenes/lamp_pool.gdshader; LampPools): a flat disc a
// little over the street, added light that falls off from the lamp's foot and carries the ground's own block grain
// (CityGround.hlsl's sd_cell, sd_fbm and sd_h, seeded as the ground is). Each disc's centre (Godot axes, x and z)
// rides in its vertices' first uv. Unshaded and added, under Godot's fog.
Shader "Hidden/Slice/LampPool"
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
            #include "Assets/Resources/Shaders/CityGround.hlsl"

            float4 _PoolTint;   // rgb: the tint (linear); a: the look's ground_lamp_pool
            float _PoolRadius;  // m

            struct Attributes
            {
                float3 positionOS : POSITION;
                float2 centre : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionRWS : TEXCOORD0;
                float2 centre : TEXCOORD1;
            };

            Varyings Vert(Attributes v)
            {
                Varyings o;
                o.positionRWS = TransformObjectToWorld(v.positionOS);  // HDRP: already camera-relative
                o.positionCS = TransformWorldToHClip(o.positionRWS);
                o.centre = v.centre;
                return o;
            }

            float4 Frag(Varyings i) : SV_Target
            {
                float3 world = GetAbsolutePositionWS(i.positionRWS);
                float2 xz = float2(world.x, -world.z);  // Godot axes
                float d = length(xz - i.centre) / _PoolRadius;
                float fall = pow(saturate(1.0 - d), 1.5);
                float2 pc = sd_cell(xz);
                float grain = 0.6 + 0.8 * sd_fbm(pc, 1.3) + (sd_h(floor(pc / g_block)) - 0.5) * 0.35;
                // Written straight into HDRP's colour buffer, which is already pre-exposed (in Godot's radiance units): no
                // exposure unit here, unlike a light's intensity or a lit surface's emission.
                float3 glow = _PoolTint.rgb * _PoolTint.a * fall * grain;
                PositionInputs pos = GetPositionInput(i.positionCS.xy, _ScreenSize.zw, i.positionCS.z, i.positionCS.w, i.positionRWS, uint2(0, 0));
                float3 fogColor, fogOpacity;
                if (EvaluateAtmosphericScattering(pos, GetWorldSpaceNormalizeViewDir(i.positionRWS), fogColor, fogOpacity))
                    glow = glow * (1.0 - fogOpacity);  // added light: the fog hides it, the fog's own colour is already there
                return float4(glow, 1.0);
            }
            ENDHLSL
        }
    }
}
