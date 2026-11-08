// The city's water (D-244, D-245, D-325), scenes/water.gdshader on HDRP's Lit forward pass: sun, shadows, fog and
// reflections stay HDRP's; this holds the surface. All coordinates in here are Godot's (x, z = -Unity z), so the
// maths and every wave's direction read as the source's. Comments on what each part is for are in the source.
#define GetSurfaceAndBuiltinData Orig_GetSurfaceAndBuiltinData
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Lit/LitData.hlsl"
#undef GetSurfaceAndBuiltinData

float4 _SliceAmbient;
float4 _WaterDeep, _WaterShallow, _WaterFoam, _WaterSky;
float _WaterAbsorb, _WaterMurk, _WaterFoamDepth, _WaterFoamShare;
float _WaveLength, _WaveSlope, _RippleLength, _RippleSlope, _SwellLength, _SwellSlope;
float4 _WaterWind, _SwellDir, _WaterFlow;
float _RoughNear, _RoughFar, _WaterSpec, _CrestLight, _MottleLength, _MottleAmp, _DayGlow, _NightGlow, _WaterNight, _WaterSeed;
float _LapHeight, _LapLength, _LapPeriod;
float4 _LapDir;
TEXTURE2D(_SimHeight);
float4 _SimOrigin, _SimSize, _SimTexels;
float _SimOn, _WhitecapSlope, _WhitecapLift;
float _OceanOn, _OceanMapSize;
float _OceanCount;
TEXTURE2D_ARRAY(_OceanDisp);
TEXTURE2D_ARRAY(_OceanNormals);
float4 _OceanScales[8];
float4 _OceanFade;
SamplerState water_linear_repeat_sampler;
SamplerState water_linear_clamp_sampler;

static const float OCEAN_NEAR = 150.0;
static const float OCEAN_FALLOFF = 0.007;
static const float WATER_GRAVITY = 9.81;
static const float WATER_TAU = 6.28318530717958647692;
static const int WATER_WAVES = 6;
static const int WATER_SWELLS = 3;
static const float WAVE_STEP = 0.71;
static const float SLOPE_STEP = 0.9;
static const float WAVE_SPREAD = 1.2;
static const float RIPPLE_STEP = 0.43;
static const float WATER_F0 = 0.16;
static const float CREST_MEAN = 0.4658;
static const float LAP_BEND = 1.4;
static const float LAP_BEND_LONG = 23.0;
static const float LAP_BEND_SHORT = 9.0;
static const float SWELL_SHALLOW = 0.3;
static const float SWELL_DEEP = 1.8;

float4 WaterCubicWeights(float a)
{
    float a2 = a * a;
    float a3 = a2 * a;
    float w0 = -a3 + a2 * 3.0 - a * 3.0 + 1.0;
    float w1 = a3 * 3.0 - a2 * 6.0 + 4.0;
    float w2 = -a3 * 3.0 + a2 * 3.0 + a * 3.0 + 1.0;
    float w3 = a3;
    return float4(w0, w1, w2, w3) / 6.0;
}

float4 WaterOceanNormal(float2 uv, float layer)
{
    return SAMPLE_TEXTURE2D_ARRAY_LOD(_OceanNormals, water_linear_repeat_sampler, uv, layer, 0.0);
}

float4 WaterOceanBicubic(float2 uv, float layer)
{
    float dims_inv = 1.0 / _OceanMapSize;
    uv = uv * _OceanMapSize + 0.5;
    float2 fuv = frac(uv);
    float4 wx = WaterCubicWeights(fuv.x);
    float4 wy = WaterCubicWeights(fuv.y);
    float4 g = float4(wx.xz + wx.yw, wy.xz + wy.yw);
    float4 h = (float4(wx.yw, wy.yw) / g + float2(-1.5, 0.5).xyxy + floor(uv).xxyy) * dims_inv;
    float2 w = g.xz / (g.xz + g.yw);
    return lerp(
        lerp(WaterOceanNormal(h.yw, layer), WaterOceanNormal(h.xw, layer), w.x),
        lerp(WaterOceanNormal(h.yz, layer), WaterOceanNormal(h.xz, layer), w.x), w.y);
}

float3 WaterOceanShift(float2 p)
{
    float3 sum = 0.0;
    for (int i = 0; i < (int)_OceanCount; i++)
    {
        float4 sc = _OceanScales[i];
        sum += SAMPLE_TEXTURE2D_ARRAY_LOD(_OceanDisp, water_linear_repeat_sampler, p * sc.xy, (float)i, 0.0).xyz * sc.z;
    }
    return sum;
}

// No derivatives in a loop: the pixel's footprint comes in, as metres per pixel along screen x and y.
float3 WaterOceanGradient(float2 p, float2 dpx, float2 dpy)
{
    float3 sum = 0.0;
    for (int i = 0; i < (int)_OceanCount; i++)
    {
        float4 sc = _OceanScales[i];
        float2 uv = p * sc.xy;
        float ppm = _OceanMapSize * min(sc.x, sc.y);
        float footprint = max(length(dpx * sc.xy), length(dpy * sc.xy)) * _OceanMapSize;
        float shown = 1.0 - smoothstep(_OceanFade.x, _OceanFade.y, footprint);
        sum += lerp(WaterOceanBicubic(uv, (float)i), WaterOceanNormal(uv, (float)i), min(1.0, ppm * 0.1)).xyw
            * float3(sc.ww, 1.0) * shown;
    }
    return sum;
}

float WaterWh(float n)
{
    return frac(sin(n * 91.3458 + _WaterSeed * 1.37) * 47453.5453);
}

float WaterH2(float2 p)
{
    float3 q = frac(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973) + _WaterSeed * 0.013);
    q += dot(q, q.yzx + 33.33);
    return frac((q.x + q.y) * q.z);
}

float2 WaterGrad2(float2 i)
{
    float a = WATER_TAU * WaterH2(i);
    return float2(cos(a), sin(a));
}

float3 WaterNoise(float2 p)
{
    float2 i = floor(p);
    float2 f = p - i;
    float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    float2 du = 30.0 * f * f * (f * (f - 2.0) + 1.0);
    float2 ga = WaterGrad2(i);
    float2 gb = WaterGrad2(i + float2(1.0, 0.0));
    float2 gc = WaterGrad2(i + float2(0.0, 1.0));
    float2 gd = WaterGrad2(i + float2(1.0, 1.0));
    float va = dot(ga, f);
    float vb = dot(gb, f - float2(1.0, 0.0));
    float vc = dot(gc, f - float2(0.0, 1.0));
    float vd = dot(gd, f - float2(1.0, 1.0));
    float k = va - vb - vc + vd;
    float n = va + u.x * (vb - va) + u.y * (vc - va) + u.x * u.y * k;
    float2 g = ga + u.x * (gb - ga) + u.y * (gc - ga) + u.x * u.y * (ga - gb - gc + gd)
        + du * (u.yx * k + float2(vb, vc) - va);
    return float3(n, g);
}

float2 WaterTurn(float2 d, float a)
{
    float c = cos(a);
    float s = sin(a);
    return float2(d.x * c - d.y * s, d.x * s + d.y * c);
}

float3 WaterWaveSet(float2 p, float t, float fp, float2 dir, float len0, float slope0, int count, float spread, float salt, inout float lost)
{
    float3 sum = 0.0;
    float len = len0;
    float s = slope0;
    for (int i = 0; i < count; i++)
    {
        float fi = (float)i + salt;
        float2 d = WaterTurn(dir, (WaterWh(fi) - 0.5) * spread);
        float k = WATER_TAU / len;
        float ph = k * dot(d, p) - sqrt(WATER_GRAVITY * k) * t + WATER_TAU * WaterWh(fi + 17.0);
        float e = exp(sin(ph) - 1.0);
        float keep = 1.0 - smoothstep(len * 0.12, len * 0.4, fp);
        sum += keep * float3(s / k * (e - CREST_MEAN), s * e * cos(ph) * d);
        lost += (1.0 - keep) * s * s;
        len *= WAVE_STEP;
        s *= SLOPE_STEP;
    }
    return sum;
}

float3 WaterRipples(float2 p, float t, float fp, inout float lost)
{
    float3 sum = 0.0;
    float len = _RippleLength;
    float s = _RippleSlope;
    for (int i = 0; i < 2; i++)
    {
        float a = 0.6 + (float)i * 1.9;
        float2 drift = WaterTurn(_WaterWind.xy, (float)i * 2.2 - 0.7) * (0.35 - 0.12 * (float)i);
        float2 q = WaterTurn(p - drift * t, a) / len;
        float3 n = WaterNoise(q + float2(_WaterSeed * 0.37, (float)i * 31.7));
        float keep = 1.0 - smoothstep(len * 0.25, len * 0.9, fp);
        sum += keep * s * float3(n.x * len, WaterTurn(n.yz, -a));
        lost += (1.0 - keep) * s * s;
        len *= RIPPLE_STEP;
        s *= 0.8;
    }
    return sum;
}

float WaterLap(float2 p, float t)
{
    float2 side = float2(-_LapDir.y, _LapDir.x);
    float u = dot(side, p);
    float bend = LAP_BEND * sin(u / LAP_BEND_LONG + _WaterSeed) + LAP_BEND * 0.6 * sin(u / LAP_BEND_SHORT - _WaterSeed * 0.7);
    float ph = WATER_TAU * ((dot(_LapDir.xy, p) + bend) / _LapLength - t / _LapPeriod);
    return _LapHeight * (exp(sin(ph) - 1.0) - CREST_MEAN) / (1.0 - CREST_MEAN);
}

float WaterSimSmooth(float2 uv, float2 du, float2 dv)
{
    float sum = 0.0;
    for (int i = -1; i <= 1; i++)
    {
        for (int j = -1; j <= 1; j++)
        {
            float w = (float)((2 - abs(i)) * (2 - abs(j)));
            sum += w * SAMPLE_TEXTURE2D_LOD(_SimHeight, water_linear_clamp_sampler, uv + (float)i * du + (float)j * dv, 0.0).r;
        }
    }
    return sum / 16.0;
}

bool WaterOffSim(float2 uv)
{
    return _SimOn <= 0.0 || uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0;
}

float WaterSimLift(float2 p)
{
    float2 uv = (p - _SimOrigin.xy) / _SimSize.xy;
    if (WaterOffSim(uv)) return 0.0;
    return WaterSimSmooth(uv, float2(_SimTexels.x, 0.0), float2(0.0, _SimTexels.y));
}

float3 WaterSimAt(float2 p)
{
    float2 uv = (p - _SimOrigin.xy) / _SimSize.xy;
    if (WaterOffSim(uv)) return 0.0;
    float2 du = float2(_SimTexels.x, 0.0);
    float2 dv = float2(0.0, _SimTexels.y);
    float2 cell = _SimSize.xy * _SimTexels.xy;
    float h = WaterSimSmooth(uv, du, dv);
    float hx = WaterSimSmooth(uv + du, du, dv) - WaterSimSmooth(uv - du, du, dv);
    float hz = WaterSimSmooth(uv + dv, du, dv) - WaterSimSmooth(uv - dv, du, dv);
    return float3(h, hx / (2.0 * cell.x), hz / (2.0 * cell.y));
}

float WaterSwellKeep(float2 p)
{
    float2 uv = (p - _SimOrigin.xy) / _SimSize.xy;
    if (WaterOffSim(uv)) return 1.0;
    return smoothstep(SWELL_SHALLOW, SWELL_DEEP, -SAMPLE_TEXTURE2D_LOD(_SimHeight, water_linear_clamp_sampler, uv, 0.0).g);
}

#define HAVE_MESH_MODIFICATION
AttributesMesh ApplyMeshModification(AttributesMesh input, float3 timeParameters)
{
    // The sheet's object space is Unity's world.
    float2 p = float2(input.positionOS.x, -input.positionOS.z);
    float t = timeParameters.x;
    float3 move = 0.0;
#ifdef ATTRIBUTES_NEED_COLOR
    if (_LapHeight > 0.0) move.y += WaterLap(p, t) * input.color.r;
#endif
    if (_OceanOn > 0.0)
    {
        float3 eye = GetAbsolutePositionWS(float3(0.0, 0.0, 0.0));
        float near = min(exp(-(length(p - float2(eye.x, -eye.z)) - OCEAN_NEAR) * OCEAN_FALLOFF), 1.0);
        move += WaterOceanShift(p) * near * WaterSwellKeep(p);
    }
    else if (_SwellLength > 0.0)
    {
        float none = 0.0;
        move.y += WaterWaveSet(p, t, 0.0, _SwellDir.xy, _SwellLength, _SwellSlope, WATER_SWELLS, WAVE_SPREAD * 0.08, 40.0, none).x * WaterSwellKeep(p);
    }
    move.y += WaterSimLift(p);
    input.positionOS += float3(move.x, move.y, -move.z);
    return input;
}

void GetSurfaceAndBuiltinData(FragInputs input, float3 V, inout PositionInputs posInput, out SurfaceData surfaceData, out BuiltinData builtinData)
{
    Orig_GetSurfaceAndBuiltinData(input, V, posInput, surfaceData, builtinData);
    float3 world = GetAbsolutePositionWS(posInput.positionWS);
    float2 rest = input.texCoord0.xy;
    float2 p = float2(world.x, -world.z);
    float t = _TimeParameters.x;
    float2 dpx = ddx(p), dpy = ddy(p);
    float2 restX = ddx(rest), restY = ddy(rest);
    float fp = max(length(dpx), length(dpy));
    float2 carried = p - _WaterFlow.xy * t;
    float lost = 0.0;
    float3 h = WaterWaveSet(carried, t, fp, _WaterWind.xy, _WaveLength, _WaveSlope, WATER_WAVES, WAVE_SPREAD, 0.0, lost);
    h += WaterRipples(carried, t, fp, lost);
    float crest = clamp(h.x / max(0.001, _WaveSlope * _WaveLength / WATER_TAU), -1.0, 1.0);
    float sea_foam = 0.0;
    float dist = length(TransformWorldToView(posInput.positionWS).xz);
    if (_OceanOn > 0.0)
    {
        float keep = WaterSwellKeep(rest);
        float3 g = WaterOceanGradient(rest, restX, restY);
        sea_foam = smoothstep(0.0, 1.0, g.z * 0.75) * exp(-dist * 0.0075) * keep;
        g.xy *= lerp(0.015, 1.0, exp(-dist * 0.0175));
        h = h * (1.0 - keep) + float3(0.0, g.xy * keep);
        lost *= 1.0 - keep;
        crest *= 0.15 * (1.0 - keep);
    }
    else if (_SwellLength > 0.0)
    {
        float3 s = WaterWaveSet(p, t, fp, _SwellDir.xy, _SwellLength, _SwellSlope, WATER_SWELLS, WAVE_SPREAD * 0.08, 40.0, lost) * WaterSwellKeep(p);
        h += s;
        crest = clamp(0.15 * crest + s.x / max(0.001, _SwellSlope * _SwellLength / WATER_TAU), -1.0, 1.0);
    }
    float3 liquid = WaterSimAt(p);
    h.yz += clamp(liquid.yz, -2.0, 2.0);
    // Godot's (-dh/dx, 1, -dh/dz), z negated into Unity.
    float3 n = normalize(float3(-h.y, 1.0, h.z));
    float alpha0 = _RoughNear * _RoughNear;
    float roughness = clamp(sqrt(sqrt(alpha0 * alpha0 + lost)), _RoughNear, _RoughFar);

    // How much water lies in front of what is under it: the view path, and how deep it sits.
    float behind = LoadCameraDepth((uint2)input.positionSS.xy);
    float3 under = ComputeWorldSpacePosition(posInput.positionNDC, behind, UNITY_MATRIX_I_VP);
    float path = max(0.0, length(under) - length(posInput.positionWS));
    float below = max(0.0, posInput.positionWS.y - under.y);
    float clear = exp(-_WaterAbsorb * path) * (1.0 - smoothstep(_WaterMurk * 0.5, _WaterMurk, below));

    float f0 = WATER_F0 * _WaterSpec * _WaterSpec;
    float fres = f0 + (1.0 - f0) * pow(1.0 - saturate(dot(n, V)), 5.0);

    float3 body = lerp(_WaterShallow.rgb, _WaterDeep.rgb, smoothstep(0.0, _WaterMurk, below));
    body *= 1.0 + _CrestLight * crest;
    float mottle = WaterNoise(carried / _MottleLength + float2(t * 0.03, _WaterSeed * 0.11)).x
        + 0.5 * WaterNoise(carried / (_MottleLength * 0.37) - float2(0.0, t * 0.05)).x;
    body *= 1.0 + _MottleAmp * mottle;

    float band = 1.0 - smoothstep(0.0, _WaterFoamDepth, below);
    float lace = WaterNoise(carried * 1.7 + float2(t * 0.11, _WaterSeed)).x + 0.5 * WaterNoise(carried * 4.3 - float2(0.0, t * 0.17)).x;
    float froth = smoothstep(0.4, 0.75, band * (0.75 + lace)) * _WaterFoamShare;
    float cap = max(length(liquid.yz) / _WhitecapSlope, liquid.x / _WhitecapLift);
    froth = max(froth, smoothstep(0.7, 1.2, cap * (0.75 + lace)) * _SimOn);
    froth = max(froth, sea_foam);

    float seen = clear * (1.0 - fres);
    float3 albedo = lerp(body * (1.0 - clear) * (1.0 - fres), _WaterFoam.rgb, froth);
    float glow = 0.5 * (1.0 + _MottleAmp * mottle) * (1.0 + _CrestLight * crest);
    float3 emission = _WaterSky.rgb * (_NightGlow * _WaterNight + _DayGlow) * glow * (1.0 - froth);
    float spec = _WaterSpec * (1.0 - froth);
    roughness = lerp(roughness, 0.7, froth);

    surfaceData.baseColor = albedo;
    surfaceData.normalWS = n;
    surfaceData.geomNormalWS = n;
    surfaceData.perceptualSmoothness = 1.0 - roughness;
    surfaceData.metallic = 0.0;
    surfaceData.ambientOcclusion = 1.0;
    surfaceData.specularOcclusion = 1.0;
    // Godot's F0 is 0.16 * spec^2; HDRP takes it as a specular colour.
    surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_SPECULAR_COLOR;
    surfaceData.specularColor = WATER_F0 * spec * spec;
    builtinData.opacity = lerp(1.0 - seen, 1.0, froth);
    builtinData.bakeDiffuseLighting = _SliceAmbient.rgb * albedo * GetInverseCurrentExposureMultiplier();
    builtinData.backBakeDiffuseLighting = 0.0;
    builtinData.emissiveColor = emission * GetInverseCurrentExposureMultiplier();
}
