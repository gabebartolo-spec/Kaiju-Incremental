// The game's one beam shader (scenes/bolt.gdshader): a bolt drawn as capsules. Every segment is its own
// camera-facing quad; the vertex stage stretches it half a width past both ends and the fragment stage
// measures the distance to the segment's axis, so joints and caps are round and a bolt seen end-on never
// folds. Glow is not geometry: white-hot at the axis, a thin tinted fringe, HDR for the bloom to catch.
Shader "Hidden/Slice/Bolt"
{
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
            #pragma target 4.5
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"

            float4 _BoltTint, _BoltFringe, _BoltCore;
            float _BoltWidth, _BoltLevel, _BoltBoost, _BoltFringeBoost, _BoltWhiteTo, _BoltTintTo;
            float _BoltWobble, _BoltWobbleHz, _BoltMinPx, _BoltAlpha;

            struct Attributes
            {
                float3 here : POSITION;
                float2 end : TEXCOORD0;    // 0 start / 1 far end, side -1 / +1
                float3 there : TEXCOORD1;  // the segment's other end
                float3 info : TEXCOORD2;   // width share, brightness share, how far along
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 q : TEXCOORD0;
                float lw : TEXCOORD1;
                float wpx : TEXCOORD2;
                float2 shade : TEXCOORD3;
            };

            Varyings Vert(Attributes v)
            {
                float3 p = TransformWorldToView(GetCameraRelativePositionWS(v.here));
                float3 o = TransformWorldToView(GetCameraRelativePositionWS(v.there));
                p.z = min(p.z, -0.05);
                o.z = min(o.z, -0.05);
                float depth = max(-(p.z + o.z) * 0.5, 0.1);  // one radius for both ends
                float perPx = depth * 2.0 / (abs(UNITY_MATRIX_P[1][1]) * _ScreenSize.y);
                float share = v.info.x;
                float least = _BoltMinPx * _ScreenSize.y / 1080.0 * perPx * (0.7 + 0.3 * min(share, 1.0));
                float w = max(_BoltWidth * share, least) * 0.5;
                float2 d = p.xy - o.xy;
                float len = length(d);
                float2 outward = len > 0.0001 ? d / len : float2(v.end.x > 0.5 ? 1.0 : -1.0, 0.0);
                float2 perp = float2(-outward.y, outward.x);
                float3 at = p;
                at.xy += outward * w + perp * v.end.y * w;
                Varyings o2;
                o2.q = float2(v.end.x > 0.5 ? len / w + 1.0 : -1.0, v.end.y);
                o2.lw = len / w;
                o2.wpx = w / perPx;
                o2.shade = v.info.yz;
                o2.positionCS = TransformWViewToHClip(at);
                return o2;
            }

            float4 Frag(Varyings i) : SV_Target
            {
                float x = clamp(i.q.x, 0.0, i.lw);
                float d = length(float2(i.q.x - x, i.q.y));
                float cover = saturate((1.0 - d) / (1.5 / max(i.wpx, 1.0)));
                float hot = saturate((_BoltLevel - 0.25) / 0.5);
                float white = (1.0 - smoothstep(_BoltWhiteTo * 0.6, _BoltWhiteTo, d)) * hot;
                float3 edge = lerp(_BoltTint.rgb, _BoltFringe.rgb, smoothstep(_BoltTintTo, 1.0, d)) * _BoltFringeBoost;
                float3 color = lerp(edge, _BoltCore.rgb * _BoltBoost, white);
                float flick = 1.0 - _BoltWobble * 0.5 * (1.0 + sin(_Time.y * _BoltWobbleHz * 6.2832 + i.shade.y * 37.0));
                color *= i.shade.x * flick * lerp(0.6, 1.0, saturate(_BoltLevel));
                return float4(color, cover * smoothstep(0.0, 0.12, _BoltLevel) * _BoltAlpha);
            }
            ENDHLSL
        }
    }
}
