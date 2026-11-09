// One-shot effects in HDRP (D-474): dust puffs, glowing voxels and the ground ring, copied from the
// Godot game (scenes/smoke.gdshader, ember.gdshader, shockwave.gdshader; emitters scenes/fx.gd, blast_parts.gd).
// A particle's whole life is a function of its index and the clock, as Flame.shader's: Bursts.cs fills
// one property block per burst and draws it until its last particle is gone.
Shader "Hidden/Slice/Burst"
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
            #pragma multi_compile_local BURST_DUST BURST_GLOW BURST_RING
            #define SHADERPASS SHADERPASS_FORWARD_UNLIT
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Material.hlsl"

            // Set for everything (Fires.cs sets the smoke's clearing; dust shares it).
            float _BurstTime;
            float4 _SliceAmbient, _FireSunDir, _FireSunColor;
            float4 _SmokeClear;  // near_clear, near_full, centre_keep, centre_radius
            float4 _SmokeFocus;  // focus_clear, focus_full, camera-to-kaiju depth, soft contact metres
            float4 _SmokeBody;   // softness

            // Set per burst.
            float4 _BOrigin;   // xyz, start time
            float4 _BBox;      // xyz half extents, life
            float4 _BGravity;  // xyz, seconds it takes to emit them all
            float4 _BVel;      // speed min, max, spread (radians), count
            float4 _BDamp;     // damping min, max, seed, heat
            float4 _BScale;    // scale min, max, unit size, self-lit
            float4 _BClear;    // 1: the smoke's centre and focus clearing, 0: off (at the kaiju's foot)
            float _BSizeT[8], _BSizeV[8];
            float4 _BColor[4];
            float4 _BColorAt;
            float4 _BShade[3];
            float4 _RCentre;   // xyz, half width
            float4 _RTime;     // start progress, seconds, tint alpha unused, soft
            float4 _RTint;     // rgb, peak

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionRWS : TEXCOORD0;
                float2 uv : TEXCOORD1;
                float4 color : TEXCOORD2;
                float progress : TEXCOORD3;
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

            float Rnd(uint k, uint stream)
            {
                return Pcg(Pcg(k + (uint)(_BDamp.z * 1000.0) * 7919u) + stream) / 4294967295.0;
            }

            // Godot's Curve between its points: zero tangents, so a smoothstep. A repeated last point ends it.
            float SizeOverLife(float age)
            {
                for (int i = 0; i < 7; i++)
                {
                    if (age <= _BSizeT[i + 1])
                        return lerp(_BSizeV[i], _BSizeV[i + 1], smoothstep(_BSizeT[i], max(_BSizeT[i + 1], _BSizeT[i] + 1e-4), age));
                }
                return _BSizeV[7];
            }

            // A Gradient: straight lines between its four stops.
            float4 ColorOverLife(float age)
            {
                for (int i = 0; i < 3; i++)
                {
                    if (age <= _BColorAt[i + 1])
                        return lerp(_BColor[i], _BColor[i + 1], saturate((age - _BColorAt[i]) / max(_BColorAt[i + 1] - _BColorAt[i], 1e-4)));
                }
                return _BColor[3];
            }

            Varyings Hidden()
            {
                Varyings o = (Varyings)0;
                return o;
            }

            Varyings Vert(uint vertexID : SV_VertexID, uint instanceID : SV_InstanceID)
            {
                uint corner = vertexID % 6u;
                float2 c = float2(corner == 1u || corner == 2u || corner == 4u ? 1.0 : 0.0, corner == 2u || corner >= 4u ? 1.0 : 0.0);
                Varyings o;
                float3 world;
                #if defined(BURST_RING)
                    world = _RCentre.xyz + float3(c.x * 2.0 - 1.0, 0.0, c.y * 2.0 - 1.0) * _RCentre.w;
                    o.uv = c;
                    o.color = _RTint;
                    o.progress = lerp(_RTime.x, 1.0, saturate((_BurstTime - _BOrigin.w) / _RTime.y));
                #else
                    float count = _BVel.w;
                    float birth = _BGravity.w * (float)instanceID / count;
                    float t = _BurstTime - _BOrigin.w - birth;
                    float life = _BBox.w;
                    if (t < 0.0 || t > life) return Hidden();
                    float age = t / life;

                    float3 box = float3(Rnd(instanceID, 1u), Rnd(instanceID, 2u), Rnd(instanceID, 3u)) * 2.0 - 1.0;
                    float a1 = (Rnd(instanceID, 4u) * 2.0 - 1.0) * _BVel.z;
                    float a2 = (Rnd(instanceID, 5u) * 2.0 - 1.0) * _BVel.z;
                    float3 dir = float3(sin(a1) * cos(a2), cos(a1) * cos(a2), sin(a2));
                    if (dot(_BClear.yzw, _BClear.yzw) > 0.0)
                    {
                        float3 ay = normalize(_BClear.yzw);
                        float3 ax = normalize(cross(ay, abs(ay.y) > 0.9 ? float3(1, 0, 0) : float3(0, 1, 0)));
                        dir = ax * dir.x + ay * dir.y + cross(ax, ay) * dir.z;
                    }
                    float speed = lerp(_BVel.x, _BVel.y, Rnd(instanceID, 6u));
                    float damp = lerp(_BDamp.x, _BDamp.y, Rnd(instanceID, 7u));
                    // Godot takes damping off the speed each step: a straight line down to a stop. Once
                    // it beats gravity, gravity stops counting as well.
                    float stop = damp > 0.0 ? speed / damp : life;
                    float moving = min(t, stop);
                    float dist = speed * moving - 0.5 * damp * moving * moving;
                    float falling = damp > length(_BGravity.xyz) ? moving : t;
                    float3 at = _BOrigin.xyz + box * _BBox.xyz + dir * dist + 0.5 * _BGravity.xyz * falling * falling;
                    float scale = lerp(_BScale.x, _BScale.y, Rnd(instanceID, 8u)) * SizeOverLife(age) * _BScale.z;
                    float4 shade = _BShade[(uint)(Rnd(instanceID, 9u) * 2.999)];
                    o.color = ColorOverLife(age) * shade;
                    o.progress = 0.0;
                    #if defined(BURST_GLOW)
                        uint face = vertexID / 6u;
                        uint axis = face / 2u;
                        float3 n = float3(axis == 0u, axis == 1u, axis == 2u) * ((face & 1u) != 0u ? -1.0 : 1.0);
                        float3 u = float3(axis == 2u, axis == 0u, axis == 1u);
                        float3 v = float3(axis == 1u, axis == 2u, axis == 0u);
                        world = at + (n + u * (2.0 * c.x - 1.0) + v * (2.0 * c.y - 1.0)) * 0.5 * scale;
                        o.uv = c;
                    #else
                        float3 right = UNITY_MATRIX_V[0].xyz;
                        float3 up = UNITY_MATRIX_V[1].xyz;
                        world = at + (right * (c.x - 0.5) + up * (c.y - 0.5)) * scale;
                        o.uv = float2(c.x, 1.0 - c.y);
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

            // scenes/smoke.gdshader. Street dust is its own colour (self-lit); the gas is lit like smoke.
            float4 DustOut(Varyings i)
            {
                float2 p = i.uv * 2.0 - 1.0;
                float n = Noise(i.uv * 5.0 + i.color.rg * 13.0) * 0.6 + Noise(i.uv * 11.0) * 0.4;
                float mask = 1.0 - smoothstep(_SmokeBody.x, 1.0, length(p) + (n - 0.5) * 0.5);
                float3 body = i.color.rgb * (0.75 + 0.35 * n);
                float selfLit = _BScale.w;
                float3 normal = UNITY_MATRIX_V[2].xyz;
                float3 light = _SliceAmbient.rgb + _FireSunColor.rgb * saturate(dot(normal, _FireSunDir.xyz));
                float3 color = body * lerp(light, float3(1.0, 1.0, 1.0), selfLit);
                mask *= lerp(1.0, 1.0 - smoothstep(0.55, 1.0, length(p)), selfLit);

                float eye = i.positionCS.w;
                float near = smoothstep(_SmokeClear.x, _SmokeClear.y, eye);
                float2 screen = i.positionCS.xy * _ScreenSize.zw;
                float2 off = (screen - 0.5) * float2(_ScreenSize.x / _ScreenSize.y, 1.0);
                float centre = lerp(_SmokeClear.z, 1.0, smoothstep(_SmokeClear.w * 0.4, _SmokeClear.w, length(off)));
                float front = smoothstep(_SmokeFocus.z * _SmokeFocus.x, _SmokeFocus.z * _SmokeFocus.y, eye);
                float clear = lerp(1.0, centre * front, _BClear.x);
                float behind = LinearEyeDepth(LoadCameraDepth(i.positionCS.xy), _ZBufferParams);
                float soft = smoothstep(0.0, _SmokeFocus.w, behind - eye);
                return float4(Fogged(i, color), i.color.a * mask * near * clear * soft);
            }

            // scenes/shockwave.gdshader.
            float4 RingOut(Varyings i)
            {
                float progress = i.progress;
                float soft = _RTime.w;
                const float rimWidth = 0.11, moundRadius = 0.14;
                float2 p = i.uv * 2.0 - 1.0;
                float r = length(p);
                float2 dir = p / max(r, 0.001);
                float lump = Noise(dir * 2.2 + 7.0);
                float grain = Noise(p * 6.0 + progress * 2.0);
                float front = progress + (lump - 0.5) * 0.08;
                float rim = smoothstep(front - rimWidth, front - rimWidth * 0.4, r) * (1.0 - smoothstep(front - 0.01, front + 0.03, r));
                float fill = smoothstep(front - soft, front - rimWidth, r) * (1.0 - smoothstep(front - rimWidth, front, r)) * 0.3;
                float mound = (1.0 - smoothstep(0.0, moundRadius * (1.0 + progress), r)) * (1.0 - smoothstep(0.0, 0.6, progress));
                float rimEdge = 1.0 - smoothstep(0.85, 1.0, r);
                float body = max(max(rim, fill), mound * 0.7) * rimEdge;
                float fade = 1.0 - progress * progress;
                float3 tint = i.color.rgb;
                float3 dust = lerp(dot(tint, float3(0.333, 0.333, 0.333)).xxx, tint, 0.6);
                return float4(dust * lerp(0.8, 1.25, rim) * (0.88 + 0.24 * grain), body * fade * i.color.a * (0.85 + 0.3 * grain));
            }

            float4 Frag(Varyings i) : SV_Target
            {
                #if defined(BURST_RING)
                    return RingOut(i);
                #elif defined(BURST_GLOW)
                    return float4(Fogged(i, i.color.rgb * _BDamp.w), i.color.a);
                #else
                    return DustOut(i);
                #endif
            }
            ENDHLSL
        }
    }
}
