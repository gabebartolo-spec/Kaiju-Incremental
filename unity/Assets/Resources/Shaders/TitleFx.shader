// The title's burning city (Game/Title/TitleCityView.cs), Godot's title shaders line for line:
//   TITLE_GLOW     far_flash.gd / title_shore.gd _glow_quad / title_colossus.gd glow: a soft disc facing the camera
//                  (FarFire.soft_disc), additive or mixed by the material's blend, no fog.
//   TITLE_SMOKE    title_sky_smoke.gdshader: a smoke bank's puffs, swaying, noise-edged, lit from below.
//   TITLE_PANE     title_burning_windows.gdshader: a burning window pane, flickering.
//   TITLE_REFLECT  title_shore.gdshader: the far shore's windows and fires on the bay.
//   TITLE_SAND     title_sand.gdshader: the near beach, wet at the tide line, foam lace, the fires' wash.
//   TITLE_SOLID    the sea wall, cap, promenade, lamp posts and shallows (StandardMaterial3D: albedo, ambient
//                  and sun, emission, the engine's fog).
// Quads come from _TitleQuads (Godot axes), three float4 each: (centre, width), (colour) or (shade, ...), (height).
// Display units straight out: HDRP's colour buffer is pre-exposed.
Shader "Hidden/Slice/TitleFx"
{
    Properties
    {
        [HideInInspector] _SrcBlend("", Float) = 5
        [HideInInspector] _DstBlend("", Float) = 10
        [HideInInspector] _ZWrite("", Float) = 0
        [HideInInspector] _Cull("", Float) = 0
        [HideInInspector] _ZTest("", Float) = 4
    }
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
            Blend [_SrcBlend] [_DstBlend], One OneMinusSrcAlpha
            ZWrite [_ZWrite]
            ZTest [_ZTest]
            Cull [_Cull]

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile_local TITLE_GLOW TITLE_SMOKE TITLE_PANE TITLE_REFLECT TITLE_SAND TITLE_SOLID
            #define SHADERPASS SHADERPASS_FORWARD_UNLIT
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Material.hlsl"

            #define MAX_FIRES 12
            StructuredBuffer<float4> _TitleQuads;
            float _TitleTime;
            float4 _SliceAmbient, _FireSunDir, _FireSunColor;
            // TITLE_SMOKE: the bank's tint (alpha x strength), the glow under it (rgb, amount), drift, morph.
            float4 _Tint, _Under, _Drift;
            TEXTURE2D(_Noise);
            SAMPLER(sampler_Noise);
            // TITLE_PANE: colour (rgb, glow), flicker_hz.
            float4 _Pane;
            // TITLE_REFLECT: the sheet (x half span, y, z near, z far), window and fire colours, shore and camera.
            float4 _Sheet, _WindowColour, _FireColour, _ShoreCam;  // shore_z, cam x, cam z, sheet_length
            float4 _Lengths;   // window_length, fire_length, window_strength, fire_strength
            float4 _Ripple;    // fire_radius, cell, ripple_amp, ripple_glow
            float4 _Shiver;    // shiver, fire_count
            float4 _FireX[3];  // fire_x[12]
            // TITLE_SAND
            TEXTURE2D(_Grains);
            SAMPLER(sampler_Grains);
            float4 _SandWet;   // wet_width, wet_dark, night, grade
            float4 _SandTide;  // tide_y, foam_width, foam, fire_x
            float4 _SandFire;  // fire_colour rgb, fire_strength
            float4 _SandReach; // fire_width, fire_reach
            float4 _FoamColor;
            // TITLE_SOLID
            float4 _SolidColor, _SolidEmit;

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
                float2 uv : TEXCOORD1;
                float4 data : TEXCOORD2;
                float3 godot : TEXCOORD3;  // the point in Godot's world axes
                float3 normal : TEXCOORD4;
            };

            float3 Mirror(float3 p) { return float3(p.x, p.y, -p.z); }

            float3 Fogged(Varyings i, float3 color)
            {
                PositionInputs pos = GetPositionInput(i.positionCS.xy, _ScreenSize.zw, i.positionCS.z, i.positionCS.w, i.positionRWS, uint2(0, 0));
                float3 fogColor, fogOpacity;
                if (EvaluateAtmosphericScattering(pos, GetWorldSpaceNormalizeViewDir(i.positionRWS), fogColor, fogOpacity))
                    color = color * (1.0 - fogOpacity) + fogColor;
                return color;
            }

            void Place(float3 world, inout Varyings o)
            {
                o.godot = Mirror(world);
                o.positionRWS = GetCameraRelativePositionWS(world);
                o.positionCS = TransformWorldToHClip(o.positionRWS);
            }

            // Corner (0..1, 0..1) of quad vertex `vertexID`; uv as Godot's QuadMesh (v 0 at the top).
            float2 Corner(uint vertexID)
            {
                uint corner = vertexID % 6u;
                return float2(corner == 1u || corner == 2u || corner == 4u ? 1.0 : 0.0, corner == 2u || corner >= 4u ? 1.0 : 0.0);
            }

            // A camera-facing quad `size` big round `centre` (Unity axes).
            void Billboard(float3 centre, float2 size, uint vertexID, inout Varyings o)
            {
                float2 c = Corner(vertexID);
                o.uv = float2(c.x, 1.0 - c.y);
                Place(centre + UNITY_MATRIX_V[0].xyz * (c.x - 0.5) * size.x + UNITY_MATRIX_V[1].xyz * (c.y - 0.5) * size.y, o);
            }

            float Seed(float3 godot)
            {
                return frac(sin(dot(godot, float3(12.9898, 78.233, 37.719))) * 43758.5453);
            }

            Varyings VertQuad(uint vertexID, uint instanceID)
            {
                Varyings o = (Varyings)0;
                float4 a = _TitleQuads[instanceID * 3u], b = _TitleQuads[instanceID * 3u + 1u], c3 = _TitleQuads[instanceID * 3u + 2u];
                o.data = b;
            #if defined(TITLE_GLOW)
                Billboard(Mirror(a.xyz), float2(a.w, c3.x), vertexID, o);
            #elif defined(TITLE_SMOKE)
                float seed = Seed(a.xyz) * 30.0;
                float t = _TitleTime;
                float3 sway = float3(sin(t * 0.05 + seed) * _Drift.x, cos(t * 0.04 + seed * 1.7) * _Drift.x * 0.25, 0.0);
                o.data.x = seed;
                Billboard(Mirror(a.xyz + sway), a.ww, vertexID, o);
            #elif defined(TITLE_PANE)
                // Facing the bay (Godot +z), one cell wide and c3.x tall.
                float2 c = Corner(vertexID);
                o.uv = float2(c.x, 1.0 - c.y);
                o.data.y = Seed(a.xyz) * 6.2831;
                Place(Mirror(a.xyz + float3((c.x - 0.5) * a.w, (c.y - 0.5) * c3.x, 0.0)), o);
            #endif
                return o;
            }

            Varyings Vert(Attributes v, uint vertexID : SV_VertexID, uint instanceID : SV_InstanceID)
            {
            #if defined(TITLE_GLOW) || defined(TITLE_SMOKE) || defined(TITLE_PANE)
                return VertQuad(vertexID, instanceID);
            #elif defined(TITLE_REFLECT)
                Varyings o = (Varyings)0;
                float2 c = Corner(vertexID);
                Place(Mirror(float3(lerp(-_Sheet.x, _Sheet.x, c.x), _Sheet.y, lerp(_Sheet.z, _Sheet.w, c.y))), o);
                return o;
            #else
                Varyings o = (Varyings)0;
                float3 world = TransformObjectToWorld(v.positionOS);
                o.uv = v.uv;
                o.normal = TransformObjectToWorldNormal(v.normalOS);
                Place(world, o);
                return o;
            #endif
            }

            float H11(float p)
            {
                p = frac(p * 0.1031);
                p *= p + 33.33;
                p *= p + p;
                return frac(p);
            }

            float N1(float p)
            {
                float i = floor(p);
                float f = frac(p);
                f = f * f * (3.0 - 2.0 * f);
                return lerp(H11(i), H11(i + 1.0), f);
            }

            float Hash2(float2 p) { return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }

            float VNoise(float2 p)
            {
                float2 i = floor(p);
                float2 f = p - i;
                float2 u = f * f * (3.0 - 2.0 * f);
                float a = Hash2(i), b = Hash2(i + float2(1.0, 0.0)), c = Hash2(i + float2(0.0, 1.0)), d = Hash2(i + float2(1.0, 1.0));
                return lerp(lerp(a, b, u.x), lerp(c, d, u.x), u.y) - 0.5;
            }

            // FarFire.soft_disc: white, alpha 1 at the middle, 0.4 at 0.3 of the radius, 0 at the rim.
            float SoftDisc(float2 uv)
            {
                float r = length(uv - 0.5) / 0.5;
                return r < 0.3 ? lerp(1.0, 0.4, r / 0.3) : lerp(0.4, 0.0, saturate((r - 0.3) / 0.7));
            }

            float4 Smoke(Varyings i)
            {
                float seed = i.data.x, t = _TitleTime, morph = _Drift.y;
                float2 p = i.uv * 2.0 - 1.0;
                float2 q = i.uv * 0.9 + seed * 0.37 + float2(t * morph, -t * morph * 0.6) * 0.3;
                float n = SAMPLE_TEXTURE2D(_Noise, sampler_Noise, q).r * 0.6 + SAMPLE_TEXTURE2D(_Noise, sampler_Noise, q * 2.3 - seed).r * 0.3
                    + SAMPLE_TEXTURE2D(_Noise, sampler_Noise, q * 5.1).r * 0.1;
                float edge = length(p) + (n - 0.5) * 0.9;
                float mass = 1.0 - smoothstep(0.2, 1.0, edge);
                mass *= 1.0 - smoothstep(0.72, 1.0, length(p));
                float low = clamp((1.0 - i.uv.y) * 1.4 - 0.2, 0.0, 1.0);
                float3 col = lerp(_Tint.rgb, _Under.rgb, low * low * _Under.w);
                return float4(col * (0.75 + 0.5 * n), _Tint.a * mass * (0.6 + 0.8 * n));
            }

            float FireX(int k) { return _FireX[k >> 2][k & 3]; }

            float3 Reflect(Varyings i)
            {
                float t = _TitleTime, shiver = _Shiver.x;
                float3 w = i.godot;
                float shoreZ = _ShoreCam.x, camX = _ShoreCam.y, camZ = _ShoreCam.z, sheet = _ShoreCam.w;
                float dz = w.z - shoreZ;
                float k = (camZ - shoreZ) / max(camZ - w.z, 0.001);
                float xs = camX + (w.x - camX) * k;
                float sway = sin(dz * 0.3 + t * 0.5 + xs * 0.04) * 0.04;
                float shake = shiver * _Ripple.z * sin(dz * 0.85 - t * 9.0 + xs * 0.07) * (0.6 + 0.4 * sin(dz * 0.23 + t * 3.0));
                float x = xs + sway + shake;
                float u = x / _Ripple.y;
                float streak = 0.3 + 0.7 * smoothstep(0.2, 0.85, N1(u * 0.8 + 3.0) * 0.65 + N1(u * 2.3 + 11.0) * 0.35);
                float warm = 0.4 + 0.6 * N1(u * 0.5 + 40.0);
                float shimmer = 1.0 - (0.14 + 0.4 * shiver) * (0.5 + 0.5 * sin(dz * 0.55 + N1(u * 0.7) * 20.0 + t * 0.9));
                float3 col = _WindowColour.rgb * streak * warm * shimmer * exp(-dz / _Lengths.x) * _Lengths.z;
                for (int f = 0; f < MAX_FIRES; f++)
                {
                    if (f >= (int)_Shiver.y) break;
                    float dx = (x - FireX(f)) / _Ripple.x;
                    float flick = 0.7 + 0.3 * sin(dz * 0.5 + t * 1.8 + float(f) * 2.0);
                    float stripe = 0.55 + 0.45 * N1(u * 0.9 + float(f) * 7.0);
                    col += _FireColour.rgb * exp(-dx * dx) * stripe * flick * shimmer * exp(-dz / _Lengths.y) * _Lengths.w;
                }
                col *= 1.0 - shiver * 0.6 * (0.5 + 0.5 * sin(dz * 1.1 - t * 11.0));
                col *= smoothstep(0.0, 6.0, dz) * (1.0 - smoothstep(sheet * 0.55, sheet * 0.97, dz));
                float crest = pow(0.5 + 0.5 * sin(dz * 0.55 - t * 7.0 + xs * 0.03), 4.0);
                col += float3(0.5, 0.65, 1.0) * _Ripple.w * shiver * crest * exp(-dz / 120.0);
                return col;
            }

            float3 Sand(Varyings i)
            {
                float3 w = i.godot;
                float up = max(w.y - _SandTide.x, 0.0) / _SandWet.w;
                float wet = 1.0 - smoothstep(0.0, _SandWet.x, up);
                wet *= wet;
                float3 col = SAMPLE_TEXTURE2D(_Grains, sampler_Grains, i.uv).rgb * _SandWet.z * lerp(1.0, _SandWet.y, wet);
                float along = exp(-pow((w.x - _SandTide.w) / _SandReach.x, 2.0));
                float wash = exp(-up / _SandReach.y) * (0.35 + 0.65 * along) * lerp(1.0, _SandWet.y, wet);
                col += _SandFire.rgb * wash * _SandFire.w;
                float band = 1.0 - smoothstep(0.0, _SandTide.y, up);
                float lace = VNoise(w.xz * 0.6) + 0.5 * VNoise(w.xz * 1.7);
                float froth = smoothstep(0.4, 0.75, band * (0.75 + lace)) * _SandTide.z;
                return lerp(col, _FoamColor.rgb, froth);
            }

            float4 Frag(Varyings i) : SV_Target
            {
            #if defined(TITLE_GLOW)
                return float4(i.data.rgb, SoftDisc(i.uv) * i.data.a);
            #elif defined(TITLE_SMOKE)
                return Smoke(i);
            #elif defined(TITLE_PANE)
                float t = _TitleTime, phase = i.data.y;
                float beat = sin(t * _Pane.w + phase) * sin(t * 2.3 + phase * 3.0);
                float middle = 1.0 - 0.45 * length((i.uv - 0.5) * 2.0);
                return float4(_Pane.rgb * (0.75 + 0.25 * beat) * clamp(middle, 0.4, 1.0) * i.data.x, 1.0);
            #elif defined(TITLE_REFLECT)
                return float4(Reflect(i), 1.0);
            #elif defined(TITLE_SAND)
                return float4(Sand(i), 1.0);
            #else
                float3 n = normalize(i.normal);
                float3 light = _SliceAmbient.rgb + _FireSunColor.rgb * saturate(dot(n, _FireSunDir.xyz));
                return float4(Fogged(i, _SolidColor.rgb * light + _SolidEmit.rgb), 1.0);
            #endif
            }
            ENDHLSL
        }
    }
}
