// scenes/rooftop_view.gd _draw_tracers: a rifle round's short glowing streak, head to tail in three pieces,
// each dimmer than the last. One camera-facing strip per round, depth-tested so it vanishes into the hide.
Shader "Hidden/Slice/Tracer"
{
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
            #pragma target 4.5
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"

            float4 _TracerHead;   // world xyz, width w
            float4 _TracerTail;   // world xyz
            float4 _TracerTint;
            float4 _TracerTrail;  // brightness of the three pieces, head first

            struct Attributes
            {
                float3 corner : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float along : TEXCOORD0;
            };

            Varyings Vert(Attributes v)
            {
                float3 a = TransformWorldToView(GetCameraRelativePositionWS(_TracerHead.xyz));
                float3 b = TransformWorldToView(GetCameraRelativePositionWS(_TracerTail.xyz));
                float2 run = b.xy - a.xy;
                float len = length(run);
                float2 dir = len > 1e-5 ? run / len : float2(0.0, 1.0);
                float t = v.corner.y * 0.5 + 0.5;
                float3 at = lerp(a, b, t);
                at.xy += float2(-dir.y, dir.x) * (v.corner.x * _TracerHead.w * 0.5);
                Varyings o;
                o.along = t;
                o.positionCS = TransformWViewToHClip(at);
                return o;
            }

            float4 Frag(Varyings i) : SV_Target
            {
                float k = i.along < 1.0 / 3.0 ? _TracerTrail.x : (i.along < 2.0 / 3.0 ? _TracerTrail.y : _TracerTrail.z);
                return float4(_TracerTint.rgb * k, 0.0);
            }
            ENDHLSL
        }
    }
}
