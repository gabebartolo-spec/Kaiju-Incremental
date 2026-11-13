// The far rampage across the bay (SkylineRampage, D-484): its fires and the warm wash they throw on the haze
// (scenes/horizon_fire.gdshader), its smoke columns and collapse dust (horizon_smoke.gdshaderinc, in the same air
// as the far towers: the engine's fog on top), and the far city's window light on the bay
// (bay_glow.gdshader). Camera-facing quads placed here from the elapsed time (_FarNow); a quad's data sits in
// _FarQuads (Godot axes), three float4 each: (centre or base xyz, size x), Godot's INSTANCE_CUSTOM, (size y).
// Display units straight out: HDRP's colour buffer is pre-exposed.
Shader "Hidden/Slice/HorizonFx"
{
    Properties
    {
        [HideInInspector] _SrcBlend("", Float) = 5
        [HideInInspector] _DstBlend("", Float) = 10
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
        Tags { "RenderPipeline" = "HDRenderPipeline" "RenderType" = "Transparent" "Queue" = "Transparent+1" }
        Pass
        {
            Name "ForwardOnly"
            Tags { "LightMode" = "ForwardOnly" }
            Blend [_SrcBlend] [_DstBlend], One OneMinusSrcAlpha
            ZWrite Off
            ZTest [_ZTest]
            Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile_local FAR_FIRE FAR_SMOKE BAY_GLOW
            #define SHADERPASS SHADERPASS_FORWARD_UNLIT
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Material.hlsl"
            #include "Assets/Resources/Shaders/CityGround.hlsl"

            float4 _SliceAmbient, _FireSunDir, _FireSunColor;
            StructuredBuffer<float4> _FarQuads;
            float _FarNow;
            float4 _FarColor;      // fire: the tint (raw, as Godot's instance colour); glow: glow_color x energy
            float4 _FarHazeShape;  // haze per metre, haze start
            float4 _FarHazeTint;   // the smoke's haze colour (linear)
            float4 _SmokeShape;    // rise_s, height, drift, dust_s
            float4 _SmokeColor, _DustColor, _EmberColor;  // linear; ember's w its energy
            float4 _GlowRect;      // bay glow: x0, z0, x1, z1 (Godot axes)
            float4 _GlowShape;     // y, far shore z, reach, strength
            // The glow lies on the bay's waves as Godot's pass on the same mesh does: drawn without the depth test,
            // it gives way only where the scene is this share of its depth nearer (the croc, the near city).
            #define GLOW_SLACK 0.15

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionRWS : TEXCOORD0;
                float2 uv : TEXCOORD1;
                float4 data : TEXCOORD2;  // fire: kind, power, seed; smoke: alpha, age, haze, kind; glow: from shore
                float seed : TEXCOORD3;
            };

            float3 Mirror(float3 p) { return float3(p.x, p.y, -p.z); }

            float FarHaze(float3 godot)
            {
                float dist = length(GetCameraRelativePositionWS(Mirror(godot)));
                return clamp(1.0 - exp(-max(dist - _FarHazeShape.y, 0.0) * _FarHazeShape.x), 0.0, 0.94);
            }

            // A camera-facing quad `size` big round `centre` (Godot axes); uv as Godot's QuadMesh (v 0 at the top).
            void Billboard(float3 centre, float2 size, uint vertexID, inout Varyings o)
            {
                uint corner = vertexID % 6u;
                float2 c = float2(corner == 1u || corner == 2u || corner == 4u ? 1.0 : 0.0, corner == 2u || corner >= 4u ? 1.0 : 0.0);
                float3 world = Mirror(centre) + UNITY_MATRIX_V[0].xyz * (c.x - 0.5) * size.x + UNITY_MATRIX_V[1].xyz * (c.y - 0.5) * size.y;
                o.uv = float2(c.x, 1.0 - c.y);
                o.positionRWS = GetCameraRelativePositionWS(world);
                o.positionCS = TransformWorldToHClip(o.positionRWS);
            }

            Varyings Vert(uint vertexID : SV_VertexID, uint instanceID : SV_InstanceID)
            {
                Varyings o = (Varyings)0;
            #if defined(BAY_GLOW)
                uint corner = vertexID % 6u;
                float2 c = float2(corner == 1u || corner == 2u || corner == 4u ? 1.0 : 0.0, corner == 2u || corner >= 4u ? 1.0 : 0.0);
                float3 godot = float3(lerp(_GlowRect.x, _GlowRect.z, c.x), _GlowShape.x, lerp(_GlowRect.y, _GlowRect.w, c.y));
                o.data.x = godot.z - _GlowShape.y;
                o.positionRWS = GetCameraRelativePositionWS(Mirror(godot));
                o.positionCS = TransformWorldToHClip(o.positionRWS);
                return o;
            #else
                float4 a = _FarQuads[instanceID * 3u], custom = _FarQuads[instanceID * 3u + 1u], extra = _FarQuads[instanceID * 3u + 2u];
                float now = _FarNow;
                o.seed = custom.w;
                #if defined(FAR_FIRE)
                    // horizon_fire.gdshader vertex: a = (centre, width), custom = (seed, start, kind, strength), extra.x height.
                    float kind = custom.z;
                    float2 size = float2(a.w, extra.x);
                    float seed = custom.x;
                    float lit = smoothstep(0.0, 1.5, now - custom.y);
                    float flicker = 0.75 + 0.15 * sin(now * 11.0 + seed * 31.0) + 0.1 * sin(now * 23.0 + seed * 7.0);
                    if (kind > 0.5) flicker = 0.9 + 0.1 * sin(now * 1.7 + seed * 13.0);
                    float3 centre = a.xyz;
                    float f = FarHaze(centre);
                    o.data = float4(kind, custom.w * lit * flicker * (1.0 - f * 0.6), seed, 0);
                    if (kind < 0.5)
                    {
                        size *= 0.9 + 0.2 * flicker;
                        centre.y += size.y * 0.4;  // flames stand on their fire, not round it
                    }
                    Billboard(centre, size, vertexID, o);
                #else
                    // horizon_smoke.gdshaderinc vertex: a = (base, size); custom = (slot, start, kind, seed).
                    float3 base = a.xyz;
                    float size = a.w;
                    float since = now - custom.y;
                    float slot = custom.x, puff = custom.w;
                    float kind = custom.z;
                    float3 centre;
                    float age, alpha;
                    if (kind < 0.5)
                    {
                        float trip = since / _SmokeShape.x;
                        age = frac(trip + slot);
                        float grown = step(age, trip);
                        centre = base + float3(_SmokeShape.z * _SmokeShape.y * age * age + sin(puff * 40.0 + age * 6.0) * size * 0.3, _SmokeShape.y * age, 0.0);
                        size *= 1.0 + 3.0 * age;
                        alpha = grown * sin(3.14159 * sqrt(age)) * smoothstep(0.0, 2.0, since);
                    }
                    else
                    {
                        age = clamp(since / _SmokeShape.w, 0.0, 1.0);
                        float turn = puff * 6.2832;
                        float spread = size * (0.6 + 2.2 * sqrt(age)) * (0.5 + slot);
                        centre = base + float3(cos(turn) * spread, size * (0.3 + 1.2 * age) * (0.4 + slot), sin(turn) * spread * 0.4);
                        size *= 1.0 + 1.5 * age;
                        alpha = step(0.0, since) * (1.0 - age) * smoothstep(0.0, 0.08, age + 0.01);
                    }
                    o.data = float4(alpha, age, FarHaze(centre), kind);
                    Billboard(centre, float2(size, size), vertexID, o);
                #endif
                return o;
            #endif
            }

            float3 Fogged(Varyings i, float3 color)
            {
                PositionInputs pos = GetPositionInput(i.positionCS.xy, _ScreenSize.zw, i.positionCS.z, i.positionCS.w, i.positionRWS, uint2(0, 0));
                float3 fogColor, fogOpacity;
                if (EvaluateAtmosphericScattering(pos, GetWorldSpaceNormalizeViewDir(i.positionRWS), fogColor, fogOpacity))
                    color = color * (1.0 - fogOpacity) + fogColor;
                return color;
            }

            float4 Frag(Varyings i) : SV_Target
            {
            #if defined(BAY_GLOW)
                float scene = LinearEyeDepth(LoadCameraDepth(uint2(i.positionCS.xy)), _ZBufferParams);
                if (scene < i.positionCS.w * (1.0 - GLOW_SLACK)) discard;
                float alpha = _GlowShape.w * (1.0 - smoothstep(0.0, _GlowShape.z, max(i.data.x, 0.0)));
                return float4(Fogged(i, _FarColor.rgb), alpha);
            #elif defined(FAR_FIRE)
                float2 p = i.uv * 2.0 - 1.0;
                float r = length(p);
                float kind = i.data.x, seed = i.data.z;
                float shape;
                if (kind > 0.5)
                {
                    shape = exp(-r * r * 3.0) * 0.5;  // the wash: broad and soft
                }
                else
                {
                    // A flame: a soft tongue of light, widest low down, wavering.
                    float up = saturate(1.0 - i.uv.y);
                    float sway = 0.12 * sin(up * 7.0 + _FarNow * 8.0 + seed * 11.0) * up;
                    shape = exp(-pow((p.x - sway) / lerp(0.55, 0.2, up), 2.0) - pow((up - 0.3) / 0.35, 2.0));
                }
                shape *= 0.8 + 0.4 * sd_fbm(i.uv * float2(5.0, 9.0) + float2(seed * 13.0, _FarNow * 0.9 * (1.0 - step(0.5, kind))), 1.0);
                float3 hot = lerp(_FarColor.rgb, float3(1.0, 0.92, 0.7), exp(-r * r * 8.0) * 0.3);
                return float4(hot * shape * i.data.y, 1.0);
            #else
                float alpha = i.data.x, age = i.data.y, haze = i.data.z, kind = i.data.w;
                float2 p = i.uv * 2.0 - 1.0;
                float n = sd_fbm(i.uv * 4.0 + i.seed * 17.0, 1.0);
                float mask = 1.0 - smoothstep(0.25, 1.0, length(p) + (n - 0.5) * 0.6);
                float3 col = (kind < 0.5 ? _SmokeColor.rgb : _DustColor.rgb) * (0.8 + 0.35 * n);
                float3 emit = kind < 0.5 ? _EmberColor.rgb * _EmberColor.w * pow(1.0 - age, 6.0) : 0.0;
                // Lit as Godot lights a camera-facing puff: ambient and the sun.
                float3 normal = UNITY_MATRIX_V[2].xyz;
                float3 light = _SliceAmbient.rgb + _FireSunColor.rgb * saturate(dot(normal, _FireSunDir.xyz));
                float3 color = col * (1.0 - haze) * light + emit * (1.0 - haze * 0.6) + _FarHazeTint.rgb * haze;
                return float4(Fogged(i, color), saturate(mask * alpha * (1.0 - haze * 0.5)));
            #endif
            }
            ENDHLSL
        }
    }
}
