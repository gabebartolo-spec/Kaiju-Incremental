// scenes/fx_decals.gd's wedge as a decal: a box drawn over the depth buffer, each pixel looked up by where
// the world behind it stands. Soot darkens; the crack lines glow and cool. Never on the kaiju: what stands
// in the croc's body box, above its feet, is skipped (Croc.Draw sets the box).
Shader "Hidden/Slice/Scorch"
{
    SubShader
    {
        Tags { "RenderPipeline" = "HDRenderPipeline" "RenderType" = "Transparent" "Queue" = "Transparent-50" }
        Pass
        {
            Name "ForwardOnly"
            Tags { "LightMode" = "ForwardOnly" }
            Blend One OneMinusSrcAlpha
            ZWrite Off
            ZTest Always
            Cull Front
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"

            Texture2D _ScorchTex;
            SamplerState sampler_ScorchTex;
            float4 _ScorchAt;    // the box's centre (world), half its width
            float4 _ScorchDir;   // flat direction (Godot x, z), half its depth, normal fade
            float4 _ScorchTint;
            float4 _ScorchSoot;
            float _ScorchMix, _ScorchGlow;
            float4x4 _CrocBodyInv;
            float4 _CrocBodyMin, _CrocBodyMax;

            struct Attributes
            {
                float3 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

            Varyings Vert(Attributes v)
            {
                Varyings o;
                float3 world = _ScorchAt.xyz + v.positionOS * float3(_ScorchAt.w, _ScorchDir.z, _ScorchAt.w) * 2.0;
                o.positionCS = TransformWorldToHClip(GetCameraRelativePositionWS(world));
                return o;
            }

            float4 Frag(Varyings i) : SV_Target
            {
                float depth = LoadCameraDepth(i.positionCS.xy);
                PositionInputs pos = GetPositionInput(i.positionCS.xy, _ScreenSize.zw, depth, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);
                float3 ws = GetAbsolutePositionWS(pos.positionWS);
                float3 body = mul(_CrocBodyInv, float4(ws.x, ws.y, -ws.z, 1.0)).xyz;
                if (all(body > _CrocBodyMin.xwz) && all(body < _CrocBodyMax.xyz))
                    discard;
                float3 rel = ws - _ScorchAt.xyz;
                rel.z = -rel.z;  // Godot axes from here
                float y = rel.y / _ScorchDir.z;
                float along = dot(rel.xz, _ScorchDir.xy);
                float side = dot(rel.xz, float2(-_ScorchDir.y, _ScorchDir.x));
                float2 p = float2(side, -along) / _ScorchAt.w;
                if (abs(y) >= 1.0 || abs(p.x) >= 1.0 || abs(p.y) >= 1.0)
                    discard;
                float3 n = normalize(cross(ddy(pos.positionWS), ddx(pos.positionWS)));
                if (dot(n, -pos.positionWS) < 0.0)
                    n = -n;
                float fade = pow(1.0 - abs(y), 0.3) * smoothstep(_ScorchDir.w, 1.0, n.y * 0.5 + 0.5);
                float4 t = _ScorchTex.SampleLevel(sampler_ScorchTex, p * 0.5 + 0.5, 0.0);
                float cover = t.g * _ScorchMix * fade;
                float3 soot = _ScorchSoot.rgb * t.r * 2.0;
                float glow = pow(t.b, 2.2) * _ScorchGlow * fade;
                return float4(soot * cover + _ScorchTint.rgb * glow, cover);
            }
            ENDHLSL
        }
    }
}
