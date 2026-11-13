// The campaign globe's two spheres (D-418), line for line from Godot: GLOBE_SHELL is scenes/globe_hologram.gdshader
// (a fresnel rim, scanlines scrolling up the sphere and a faint lat/long grid), GLOBE_LAND is scenes/globe_land.gdshader
// (the Tellus Nova mask: sea draws nothing; land a fill per campaign state, a bright coastline, the hovered continent
// brighter, an available one breathing). Both additive and unshaded, so they only ever brighten the near-black
// background. The mesh is Godot's SphereMesh in Unity's axes (z mirrored); model_pos is turned back to Godot's so the
// scanlines and the grid fall where they do there. Colours arrive linear; the camera runs no exposure
// or tonemap (Godot's linear tonemapper), so what is written is what shows.
Shader "Hidden/Slice/Globe"
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
            Cull Back

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile_local GLOBE_SHELL GLOBE_LAND
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"

            float4 _GlobeTint;      // the shell, and an available continent
            float4 _GlobeLocked;    // a locked continent's coastline
            float4 _GlobeConquered;
            float _GlobeTime;       // seconds, Godot's TIME
            // globe_hologram.gdshader uniforms
            float _RimPower, _RimStrength, _BaseGlow, _ScanCount, _ScanSpeed, _ShellScan, _GridLines, _GridWidth, _GridStrength;
            // globe_land.gdshader uniforms
            float _States[8];       // per mask value, Campaign.State: 0 locked, 1 available, 2 conquered
            float _HoverId;         // the continent under the pointer, 0 = none
            float _PulseHz, _PulseDepth, _Fill, _AvailableFill, _HoverFill, _Coast, _CoastTexels, _LandScan;
            Texture2D _GlobeMask;   // R8, linear, row 0 the north
            float4 _GlobeMask_TexelSize;
            SamplerState point_repeat_sampler;

            struct Attributes
            {
                float3 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionRWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 modelPos : TEXCOORD2;
                float2 uv : TEXCOORD3;
            };

            Varyings Vert(Attributes v)
            {
                Varyings o;
                o.positionRWS = TransformObjectToWorld(v.positionOS);
                o.positionCS = TransformWorldToHClip(o.positionRWS);
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                o.modelPos = float3(v.positionOS.x, v.positionOS.y, -v.positionOS.z);
                o.uv = v.uv;
                return o;
            }

            float Facing(Varyings i)
            {
                return saturate(dot(normalize(i.normalWS), GetWorldSpaceNormalizeViewDir(i.positionRWS)));
            }

            float Scan(float y, float strength)
            {
                float h = y * 0.5 + 0.5;
                return smoothstep(0.35, 0.5, frac(h * _ScanCount - _GlobeTime * _ScanSpeed * _ScanCount)) * strength;
            }

            int IdAt(float2 uv)
            {
                return (int)round(_GlobeMask.SampleLevel(point_repeat_sampler, uv, 0).r * 255.0);
            }

            float4 Shell(Varyings i)
            {
                float facing = Facing(i);
                float rim = pow(1.0 - facing, _RimPower) * _RimStrength;
                float scan = Scan(i.modelPos.y, _ShellScan);
                float3 p = normalize(i.modelPos);
                float lon = atan2(p.z, p.x) / 3.14159265 * _GridLines;
                float lat = acos(clamp(p.y, -1.0, 1.0)) / 3.14159265 * _GridLines;
                // distance to the nearest grid line, in grid cells
                float d = min(abs(frac(lon + 0.5) - 0.5), abs(frac(lat + 0.5) - 0.5));
                float grid = (1.0 - smoothstep(0.0, _GridWidth, d)) * _GridStrength * facing;
                return float4(_GlobeTint.rgb * (_BaseGlow + rim + scan * (0.3 + rim) + grid), 1.0);
            }

            float4 Land(Varyings i)
            {
                int id = IdAt(i.uv);
                if (id == 0) discard;
                float2 t = _CoastTexels * _GlobeMask_TexelSize.xy;
                bool edge = IdAt(i.uv + float2(t.x, 0.0)) != id || IdAt(i.uv - float2(t.x, 0.0)) != id
                    || IdAt(i.uv + float2(0.0, t.y)) != id || IdAt(i.uv - float2(0.0, t.y)) != id;
                int state = (int)_States[id];
                if (state == 0 && !edge) discard;
                float3 col = state == 0 ? _GlobeLocked.rgb : (state == 2 ? _GlobeConquered.rgb : _GlobeTint.rgb);
                float scan = Scan(i.modelPos.y, _LandScan);
                float facing = Facing(i);
                float body = (id == (int)_HoverId ? _HoverFill : (state == 1 ? _AvailableFill : _Fill)) + scan;
                if (state == 1) body *= 1.0 - _PulseDepth * (0.5 - 0.5 * cos(_GlobeTime * _PulseHz * 6.28318531));
                return float4(col * (edge ? _Coast : body) * (0.4 + 0.6 * facing), 1.0);
            }

            float4 Frag(Varyings i) : SV_Target
            {
            #if defined(GLOBE_LAND)
                return Land(i);
            #else
                return Shell(i);
            #endif
            }
            ENDHLSL
        }
    }
}
