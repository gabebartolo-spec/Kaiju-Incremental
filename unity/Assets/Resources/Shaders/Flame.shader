// The game's fire in HDRP (D-470 U1): flames, embers and smoke, each copied from the Godot game
// (scenes/flame.gdshader, ember.gdshader, smoke.gdshader; emitters from scenes/fire.gd).
// Stateless particles: a particle's age and path come from its index and _FireTime, so a frame is
// the same at any frame rate and a fire needs no buffers. Fires.cs draws one call per system.
Shader "Hidden/Slice/Flame"
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
            #pragma multi_compile_local FIRE_FLAME FIRE_EMBER FIRE_SMOKE
            #define SHADERPASS SHADERPASS_FORWARD_UNLIT
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Material.hlsl"

            // Set for all fires.
            float _FireTime;
            float4 _SliceAmbient, _FireSunDir, _FireSunColor;
            float4 _SmokeRamp[4];
            float4 _SmokeRampAt;
            float4 _SmokeClear;  // near_clear, near_full, centre_keep, centre_radius
            float4 _SmokeFocus;  // focus_clear, focus_full, camera-to-kaiju depth, soft contact metres
            float4 _SmokeBody;   // softness
            float4 _EmberStart, _EmberEnd;
            float _FlameHeat, _EmberHeat;

            // Set per system.
            float4 _FireOrigin, _EmitBox, _FireGravity, _FireCurve, _FireLightPos, _FireLightColor;
            float4 _FireQuad;    // width, height, how far the foot sits above the particle
            float4 _FireFlame;   // base_y, flame_h, half_w
            float4 _FireXZ;
            float _FireSeed, _FireCount, _FireLife, _FireSpread;
            float _SpeedMin, _SpeedMax, _ScaleMin, _ScaleMax, _AlphaIn, _AlphaOut;

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionRWS : TEXCOORD0;
                float2 uv : TEXCOORD1;
                float4 color : TEXCOORD2;
                float tongue : TEXCOORD3;
            };

            float Hash(float2 p)
            {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
            }

            float Noise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                f = f * f * (3.0 - 2.0 * f);
                return lerp(lerp(Hash(i), Hash(i + float2(1.0, 0.0)), f.x),
                    lerp(Hash(i + float2(0.0, 1.0)), Hash(i + float2(1.0, 1.0)), f.x), f.y);
            }

            uint Pcg(uint v)
            {
                uint s = v * 747796405u + 2891336453u;
                uint w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u;
                return (w >> 22u) ^ w;
            }

            // A random in 0..1 for one life of one particle.
            float Rnd(uint k, uint life, uint stream)
            {
                return Pcg(Pcg(Pcg(k + (uint)(_FireSeed * 1000.0) * 7919u) + life) + stream) / 4294967295.0;
            }

            // Godot's Curve between its points: zero tangents, so a smoothstep. Points (0,x) (y,z) (1,w).
            float SizeOverLife(float age)
            {
                if (age < _FireCurve.y)
                    return lerp(_FireCurve.x, _FireCurve.z, smoothstep(0.0, _FireCurve.y, age));
                return lerp(_FireCurve.z, _FireCurve.w, smoothstep(_FireCurve.y, 1.0, age));
            }

            float4 SmokeColor(float age)
            {
                for (int i = 0; i < 3; i++)
                {
                    if (age <= _SmokeRampAt[i + 1])
                        return lerp(_SmokeRamp[i], _SmokeRamp[i + 1], (age - _SmokeRampAt[i]) / (_SmokeRampAt[i + 1] - _SmokeRampAt[i]));
                }
                return _SmokeRamp[3];
            }

            Varyings Vert(uint vertexID : SV_VertexID, uint instanceID : SV_InstanceID)
            {
                float phase = _FireTime / _FireLife + (float)instanceID / _FireCount;
                float age = frac(phase);
                uint life = (uint)floor(phase);
                float t = age * _FireLife;

                float3 box = float3(Rnd(instanceID, life, 1u), Rnd(instanceID, life, 2u), Rnd(instanceID, life, 3u)) * 2.0 - 1.0;
                float a1 = (Rnd(instanceID, life, 4u) * 2.0 - 1.0) * _FireSpread;
                float a2 = (Rnd(instanceID, life, 5u) * 2.0 - 1.0) * _FireSpread;
                float3 dir = float3(sin(a1) * cos(a2), cos(a1) * cos(a2), sin(a2));
                float speed = lerp(_SpeedMin, _SpeedMax, Rnd(instanceID, life, 6u));
                float3 at = _FireOrigin.xyz + box * _EmitBox.xyz + dir * speed * t + 0.5 * _FireGravity.xyz * t * t;
                float scale = lerp(_ScaleMin, _ScaleMax, Rnd(instanceID, life, 7u)) * SizeOverLife(age);

                Varyings o;
                float3 world;
                #if defined(FIRE_EMBER)
                    uint face = vertexID / 6u;
                    uint corner = vertexID % 6u;
                    float2 c = float2(corner == 1u || corner == 2u || corner == 4u ? 1.0 : 0.0, corner == 2u || corner >= 4u ? 1.0 : 0.0);
                    uint axis = face / 2u;
                    float3 n = float3(axis == 0u, axis == 1u, axis == 2u) * ((face & 1u) != 0u ? -1.0 : 1.0);
                    float3 u = float3(axis == 2u, axis == 0u, axis == 1u);
                    float3 v = float3(axis == 1u, axis == 2u, axis == 0u);
                    world = at + (n + u * (2.0 * c.x - 1.0) + v * (2.0 * c.y - 1.0)) * 0.5 * _FireQuad.x * scale;
                    o.uv = c;
                    o.color = float4(lerp(_EmberStart.rgb, _EmberEnd.rgb, age), 1.0);
                    o.tongue = 0.0;
                #else
                    uint corner = vertexID % 6u;
                    float2 c = float2(corner == 1u || corner == 2u || corner == 4u ? 1.0 : 0.0, corner == 2u || corner >= 4u ? 1.0 : 0.0);
                    float3 right = UNITY_MATRIX_V[0].xyz;
                    float3 up = UNITY_MATRIX_V[1].xyz;
                    world = at + right * (c.x - 0.5) * _FireQuad.x * scale + up * (c.y - 0.5 + _FireQuad.z) * _FireQuad.y * scale;
                    o.uv = float2(c.x, 1.0 - c.y);
                    #if defined(FIRE_FLAME)
                        float alpha = saturate(age / _AlphaIn) * (1.0 - saturate((age - _AlphaOut) / (1.0 - _AlphaOut)));
                        o.color = float4(1.0, 1.0, 1.0, alpha);
                        float index = (float)instanceID;
                        o.tongue = Hash(float2(index * 0.37 + _FireSeed, _FireSeed * 1.7 + 3.0));
                    #else
                        o.color = SmokeColor(age);
                        o.tongue = 0.0;
                    #endif
                #endif
                o.positionRWS = GetCameraRelativePositionWS(world);
                o.positionCS = TransformWorldToHClip(o.positionRWS);
                return o;
            }

            float3 Fogged(Varyings i, float3 color)
            {
                PositionInputs pos = GetPositionInput(i.positionCS.xy, _ScreenSize.zw, i.positionCS.z, i.positionCS.w, i.positionRWS, uint2(0, 0));
                float3 fogColor, fogOpacity;
                if (EvaluateAtmosphericScattering(pos, GetWorldSpaceNormalizeViewDir(i.positionRWS), fogColor, fogOpacity))
                    color = color * (1.0 - fogOpacity) + fogColor;
                return color;
            }

            float4 FlameColor(Varyings i)
            {
                float3 wp = GetAbsolutePositionWS(i.positionRWS);
                float baseY = _FireFlame.x, flameH = _FireFlame.y, halfW = _FireFlame.z;
                float hw = saturate((wp.y - baseY) / flameH);
                float seed = i.tongue;
                float tall = 0.78 + 0.44 * seed;
                float h = (1.0 - i.uv.y) / tall;
                float x = (i.uv.x - 0.5) * 2.0 - (seed - 0.5) * 0.5 * h;
                float foot = 0.03 + 0.08 * frac(seed * 7.3) + 0.04 * Noise(float2(i.uv.x * 11.0, seed * 31.0));
                float width = (1.0 - pow(saturate(h), 0.8)) * (0.35 + 0.65 * sin(clamp(h * 3.0, 0.0, 1.5708)));
                width *= lerp(0.4, 1.0, smoothstep(foot, foot + 0.25, h));
                float n = Noise(float2(i.uv.x * 6.0 + seed * 20.0, i.uv.y * 5.0 - _FireTime * 3.0));
                float d = abs(x) / max(width, 0.001) + (n - 0.5) * 0.7 * (0.4 + h);
                float mask = 1.0 - smoothstep(0.55, 1.0, d);
                mask *= 1.0 - smoothstep(0.92, 1.0, h);
                mask *= smoothstep(foot - 0.02, foot + 0.05, h);
                float3 orange = float3(1.0, 0.40, 0.06);
                float3 red = float3(0.94, 0.23, 0.05);
                float3 deep = float3(0.50, 0.11, 0.06);
                float3 c = lerp(float3(0.70, 0.20, 0.05), orange, smoothstep(0.02, 0.2, hw));
                c = lerp(c, red, smoothstep(0.3, 0.55, hw));
                c = lerp(c, deep, smoothstep(0.62, 0.95, hw));
                float2 off = float2(dot(wp.xz - _FireXZ.xy, UNITY_MATRIX_V[0].xz), (hw - 0.22) * flameH);
                float blob = 1.0 - smoothstep(0.05, 1.0, length(off / float2(0.62 * halfW, 0.24 * flameH)));
                float heart = blob * (0.75 + 0.25 * n);
                c = lerp(c, lerp(float3(1.0, 0.72, 0.22), float3(1.0, 0.96, 0.78), smoothstep(0.5, 0.85, heart)), smoothstep(0.15, 0.6, heart));
                float rim = smoothstep(0.35, 0.95, d);
                c *= (0.9 + 0.2 * frac(seed * 13.7)) * lerp(1.0, 0.62, rim);
                c = lerp(c, red * 0.6, rim * 0.4);
                return float4(c * _FlameHeat * (1.0 + 0.9 * smoothstep(0.35, 0.7, heart)), smoothstep(0.3, 0.62, mask) * i.color.a);
            }

            float4 SmokeOut(Varyings i)
            {
                float2 p = i.uv * 2.0 - 1.0;
                float n = Noise(i.uv * 5.0 + i.color.rg * 13.0) * 0.6 + Noise(i.uv * 11.0) * 0.4;
                float mask = 1.0 - smoothstep(_SmokeBody.x, 1.0, length(p) + (n - 0.5) * 0.5);
                float3 body = i.color.rgb * (0.75 + 0.35 * n);

                // Lit as Godot lights it: ambient, the sun on a camera-facing puff, this fire's light.
                float3 normal = UNITY_MATRIX_V[2].xyz;
                float3 light = _SliceAmbient.rgb + _FireSunColor.rgb * saturate(dot(normal, _FireSunDir.xyz));
                float3 toLight = _FireLightPos.xyz - GetAbsolutePositionWS(i.positionRWS);
                float dist = max(length(toLight), 0.0001);
                float window = saturate(1.0 - pow(dist / _FireLightPos.w, 4.0));
                light += _FireLightColor.rgb * window * window / dist * saturate(dot(normal, toLight / dist));

                float eye = i.positionCS.w;
                float near = smoothstep(_SmokeClear.x, _SmokeClear.y, eye);
                float2 screen = i.positionCS.xy * _ScreenSize.zw;
                float2 off = (screen - 0.5) * float2(_ScreenSize.x / _ScreenSize.y, 1.0);
                float centre = lerp(_SmokeClear.z, 1.0, smoothstep(_SmokeClear.w * 0.4, _SmokeClear.w, length(off)));
                float front = smoothstep(_SmokeFocus.z * _SmokeFocus.x, _SmokeFocus.z * _SmokeFocus.y, eye);
                float behind = LinearEyeDepth(LoadCameraDepth(i.positionCS.xy), _ZBufferParams);
                float soft = smoothstep(0.0, _SmokeFocus.w, behind - eye);
                return float4(Fogged(i, body * light), i.color.a * mask * near * centre * front * soft);
            }

            float4 Frag(Varyings i) : SV_Target
            {
                #if defined(FIRE_FLAME)
                    return FlameColor(i);
                #elif defined(FIRE_EMBER)
                    return float4(Fogged(i, i.color.rgb * _EmberHeat), 1.0);
                #else
                    return SmokeOut(i);
                #endif
            }
            ENDHLSL
        }
    }
}
