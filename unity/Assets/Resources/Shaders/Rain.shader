// The rain of WeatherView (scenes/rain.gdshader, rain_splash.gdshader, view_clear.gdshaderinc), drawn
// procedurally: a drop's whole life is a function of its index and the view's clock, as Burst.shader's, in place of
// Godot's GPUParticles3D (D-476 first version). Each drop sits at a world-anchored place inside its volume, which
// wraps round the camera, so drops already falling stay put as the camera moves (Godot: local_coords false).
// RAIN_STREAK: one depth layer of streaks, a thin quad as long and thick on screen as its share of the viewport
// height, at the one screen angle the fall has. RAIN_SPLASH: a soft puff of mist on upward-facing ground.
Shader "Hidden/Slice/Rain"
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
            Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
            ZWrite Off
            ZTest LEqual
            Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile_local RAIN_STREAK RAIN_SPLASH
            #define SHADERPASS SHADERPASS_FORWARD_UNLIT
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Material.hlsl"

            // Fires.cs sets it every frame: focus_clear, focus_full, camera-to-kaiju depth (z), soft contact.
            float4 _SmokeFocus;

            float _RainTime;
            float _RainSeed;
            float4 _RainVol;     // volume x, y, z (Unity axes), drop count
            float4 _RainCentre;  // volume centre xz and emitter (streaks) or plane (splashes) y, Unity world; lifetime
            float4 _RainVel;     // streaks: base velocity (Unity axes), speed jitter share
            float4 _RainLook;    // streaks: len, width (viewport-height shares), fade_in, fade_out
            float4 _RainSplash;  // splashes: quad size, scale min, scale max, lifetime spread
            float4 _RainFade;    // near_clear, near_full, far_begin, far_end
            float4 _RainClear;   // centre_keep, centre_radius, focus_clear, focus_full
            float4 _RainTint;    // rgb (linear, exposure-scaled), alpha

            // rain_splash.gdshader rest_tolerance: metres a surface may sit off the puff's plane.
            #define REST_TOLERANCE 0.3

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionRWS : TEXCOORD0;
                float2 uv : TEXCOORD1;
                float life : TEXCOORD2;
                float depth : TEXCOORD3;
                float seed : TEXCOORD4;
            };

            uint Pcg(uint v)
            {
                uint s = v * 747796405u + 2891336453u;
                uint w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u;
                return (w >> 22u) ^ w;
            }

            // 0..1 for drop `id` in its `cycle`th fall, one stream per use.
            float Rnd(uint id, uint cycle, uint stream)
            {
                return Pcg(Pcg(Pcg(id + (uint)_RainSeed * 7919u) + cycle * 2654435761u) + stream) / 4294967295.0;
            }

            // A world-anchored coordinate `u` (0..size) placed inside the window of `size` centred on `centre`.
            float Wrap(float u, float centre, float size)
            {
                float lo = centre - 0.5 * size;
                return lo + frac((u - lo) / size) * size;
            }

            // view_clear.gdshaderinc: near, screen centre and in front of the kaiju.
            float ViewClear(float depth, float2 screenUv, float nClear, float nFull, float keep, float radius, float fClear, float fFull)
            {
                float near = smoothstep(nClear, nFull, depth);
                float2 off = (screenUv - 0.5) * float2(_ScreenSize.x / _ScreenSize.y, 1.0);
                float centre = lerp(keep, 1.0, smoothstep(radius * 0.4, radius, length(off)));
                float focus = _SmokeFocus.z;
                float front = focus > 0.0 ? smoothstep(focus * fClear, focus * fFull, depth) : 1.0;
                return near * centre * front;
            }

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
                Varyings o = (Varyings)0;
                uint id = instanceID;
                #if defined(RAIN_STREAK)
                    float life = _RainCentre.w;
                    float run = _RainTime / life + Rnd(id, 0u, 1u);
                    float cycle = floor(run);
                    float age = run - cycle;
                    uint cy = (uint)cycle;
                    float3 vel = _RainVel.xyz * lerp(1.0 - _RainVel.w, 1.0 + _RainVel.w, Rnd(id, cy, 4u));
                    float x = Wrap(Rnd(id, cy, 2u) * _RainVol.x, _RainCentre.x, _RainVol.x);
                    float z = Wrap(Rnd(id, cy, 5u) * _RainVol.z, _RainCentre.z, _RainVol.z);
                    float y = _RainCentre.y + (Rnd(id, cy, 3u) * 2.0 - 1.0) * 0.5;
                    float3 at = float3(x, y, z) + vel * (age * life);
                    float3 rws = GetCameraRelativePositionWS(at);
                    float3 centreV = TransformWorldToView(rws);
                    // One screen angle everywhere: the fall direction as the camera sees it, in the screen plane.
                    float2 lean = mul((float3x3)UNITY_MATRIX_V, normalize(_RainVel.xyz)).xy;
                    lean = length(lean) > 0.01 ? normalize(lean) : float2(0.0, -1.0);
                    float2 side = float2(-lean.y, lean.x);
                    float dist = max(-centreV.z, 0.001);
                    // px per metre at this depth: viewport height / (2 d tan(fov/2)).
                    float pxPerM = _ScreenSize.y * 0.5 * abs(UNITY_MATRIX_P[1][1]) / dist;
                    float w = max(_RainLook.y * _ScreenSize.y, 1.0) / pxPerM;
                    float l = _RainLook.x * _ScreenSize.y / pxPerM;
                    float3 v = centreV + float3(side * (c.x - 0.5) * w + lean * (c.y - 0.5) * l, 0.0);
                    o.positionCS = TransformWViewToHClip(v);
                    o.positionRWS = rws;
                    o.life = age;
                    o.depth = dist;
                #else
                    float life = _RainCentre.w * (1.0 - _RainSplash.w * Rnd(id, 0u, 7u));
                    float run = _RainTime / life + Rnd(id, 0u, 1u);
                    float cycle = floor(run);
                    float age = run - cycle;
                    uint cy = (uint)cycle;
                    float x = Wrap(Rnd(id, cy, 2u) * _RainVol.x, _RainCentre.x, _RainVol.x);
                    float z = Wrap(Rnd(id, cy, 5u) * _RainVol.z, _RainCentre.z, _RainVol.z);
                    float scale = _RainSplash.x * lerp(_RainSplash.y, _RainSplash.z, Rnd(id, cy, 4u));
                    float3 at = float3(x, _RainCentre.y, z) + float3(c.x - 0.5, 0.0, c.y - 0.5) * scale;
                    o.positionRWS = GetCameraRelativePositionWS(at);
                    o.positionCS = TransformWorldToHClip(o.positionRWS);
                    o.life = age;
                    o.depth = o.positionCS.w;
                    o.seed = Rnd(id, 0u, 6u);
                #endif
                o.uv = c;
                return o;
            }

            float4 Frag(Varyings i) : SV_Target
            {
                float2 screenUv = i.positionCS.xy * _ScreenSize.zw;
                #if defined(RAIN_STREAK)
                    // Soft across the width, brightest along the middle, tapering at both ends.
                    float across = 1.0 - abs(i.uv.x * 2.0 - 1.0);
                    float along = smoothstep(0.0, 0.35, i.uv.y) * smoothstep(1.0, 0.65, i.uv.y);
                    float life = smoothstep(0.0, _RainLook.z, i.life) * (1.0 - smoothstep(1.0 - _RainLook.w, 1.0, i.life));
                    float far = 1.0 - smoothstep(_RainFade.z, _RainFade.w, i.depth);
                    float clear = ViewClear(i.depth, screenUv, _RainFade.x, _RainFade.y, _RainClear.x, _RainClear.y, _RainClear.z, _RainClear.w);
                    return float4(Fogged(i.positionCS, i.positionRWS, _RainTint.rgb), _RainTint.a * across * along * life * far * clear);
                #else
                    float2 p = i.uv * 2.0 - 1.0;
                    float life = saturate(i.life * lerp(0.8, 1.25, i.seed));
                    // A soft lumpy puff: wisps off the middle so it reads as mist, not a disc.
                    float a = atan2(p.y, p.x) + i.seed * 6.2832;
                    float lump = 0.92 + 0.08 * sin(a * 2.0 + i.seed * 9.0);
                    float r = length(p) / lerp(0.5, 1.0, sqrt(life)) / lump;
                    float puff = exp(-r * r * 3.0) * smoothstep(1.0, 0.7, r);
                    float fade = smoothstep(0.0, 0.08, life) * pow(1.0 - life, 1.5);
                    float clear = ViewClear(i.depth, screenUv, _RainFade.x, _RainFade.y, _RainClear.x, _RainClear.y, _RainClear.z, _RainClear.w);
                    // Only on upward-facing ground at the puff's own height: the scene under the pixel, back to world.
                    float deviceDepth = LoadCameraDepth(i.positionCS.xy);
                    PositionInputs under = GetPositionInput(i.positionCS.xy, _ScreenSize.zw, deviceDepth, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);
                    float underY = GetAbsolutePositionWS(under.positionWS).y;
                    float rests = 1.0 - smoothstep(REST_TOLERANCE * 0.5, REST_TOLERANCE, abs(underY - _RainCentre.y));
                    return float4(Fogged(i.positionCS, i.positionRWS, _RainTint.rgb), _RainTint.a * puff * fade * clear * rests);
                #endif
            }
            ENDHLSL
        }
    }
}
