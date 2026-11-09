// scenes/flare.gdshader: an additive camera-facing flare, white at the core, a tinted halo, an uneven rim,
// fading where it meets what stands behind it.
Shader "Hidden/Slice/Flare"
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

            float4 _FlarePos;   // world xyz, full size w
            float4 _FlareTint;
            float _FlareFade, _FlareEdge, _FlareSoft;

            static const float CORE_WIDTH = 18.0, CORE_GAIN = 4.0, HALO_FALL = 4.0, HALO_GAIN = 0.5, EDGE_LOBES = 3.0;

            struct Attributes
            {
                float3 corner : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 p : TEXCOORD0;
                float eye : TEXCOORD1;
            };

            Varyings Vert(Attributes v)
            {
                float3 at = TransformWorldToView(GetCameraRelativePositionWS(_FlarePos.xyz));
                at.xy += v.corner.xy * _FlarePos.w * 0.5;
                Varyings o;
                o.p = v.corner.xy;
                o.eye = -at.z;
                o.positionCS = TransformWViewToHClip(at);
                return o;
            }

            float Hash1(float x)
            {
                return frac(sin(x * 127.1) * 43758.5453);
            }

            float4 Frag(Varyings i) : SV_Target
            {
                float r = length(i.p);
                float core = exp(-r * r * CORE_WIDTH);
                float halo = exp(-r * HALO_FALL) * HALO_GAIN;
                float3 hot = lerp(_FlareTint.rgb, float3(1, 1, 1), core);
                float k = _FlareFade;
                if (_FlareEdge > 0.0)
                {
                    float a = atan2(i.p.y, i.p.x) * EDGE_LOBES;
                    float n = lerp(Hash1(floor(a)), Hash1(floor(a) + 1.0), smoothstep(0.0, 1.0, frac(a)));
                    float lim = 1.0 - _FlareEdge * n;
                    k *= 1.0 - smoothstep(lim - 0.4, lim, r);
                }
                if (_FlareSoft > 0.0)
                    k *= saturate((LinearEyeDepth(LoadCameraDepth(i.positionCS.xy), _ZBufferParams) - i.eye) / _FlareSoft);
                return float4(hot * (core * CORE_GAIN + halo) * k, 0.0);
            }
            ENDHLSL
        }
    }
}
