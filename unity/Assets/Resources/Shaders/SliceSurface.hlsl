// HDRP's Lit surface with the slice's voxel colour rules. Lighting, shadows, GI and fog stay HDRP's.
// Building is scenes/building_baked.gdshader in merged-voxel mode, Cube and Fill are scenes/voxel_skin*.gdshader.
#define GetSurfaceAndBuiltinData Orig_GetSurfaceAndBuiltinData
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Lit/LitData.hlsl"
#undef GetSurfaceAndBuiltinData

float4 _SliceAmbient;
void SliceSetup() {}

#if defined(SLICE_BUILDING) || defined(SLICE_FACADE)
float4 _VoxelOrigin, _WinUnit, _WinAlign;
float _VoxelSize, _Salt, _Noise;
float _BubbleCut;
float _BubbleRadius;
float _BubbleCore;
float _VoxelAoStrength, _VoxelAoLightAffect, _WindowGlow, _ColorInside, _WinCount, _WinPaletteOn;
float4 _FinishRoughness, _WinGain;
float4 _WinColors[8];
float _WinEnds[8];

uint Rotl(uint x, uint k) { return (x << k) | (x >> (32u - k)); }

uint MurmurStep(uint k, uint h)
{
    k *= 0xcc9e2d51u;
    k = Rotl(k, 15u);
    k *= 0x1b873593u;
    h ^= k;
    h = Rotl(h, 13u);
    return h * 5u + 0xe6546b64u;
}

uint Fmix(uint h)
{
    h ^= h >> 16;
    h *= 0x85ebca6bu;
    h ^= h >> 13;
    h *= 0xc2b2ae35u;
    h ^= h >> 16;
    return h;
}

float JitterFactor(int3 c)
{
    uint h = 0x7F07C65u;
    h = MurmurStep((uint)c.x, h);
    h = MurmurStep((uint)c.y, h);
    h = MurmurStep((uint)c.z, h);
    h = MurmurStep((uint)_Salt, h);
    h = Fmix(h);
    float t = float(h % 1000u) / 1000.0 * 2.0 - 1.0;
    return 1.0 + t * _Noise;
}

uint WindowMix(uint x)
{
    x ^= x >> 16;
    x *= 2146121005u;
    x ^= x >> 15;
    x *= 2221713035u;
    x ^= x >> 16;
    return x;
}

uint WindowHash(float3 cellPoint, float3 n)
{
    float3 at = cellPoint - (1.0 - abs(n)) * _VoxelSize * 0.5;
    float2 u = at.y < 1.0 ? float2(1, 1) : _WinUnit.xy;
    float3 grid = float3((at.x - _WinAlign.x) / u.x, at.y / u.y, (at.z - _WinAlign.y) / u.x);
    int3 k = (int3)floor(grid);
    uint h = WindowMix((uint)k.x);
    h = WindowMix(h ^ (uint)k.y);
    return WindowMix(h ^ (uint)k.z);
}

float4 WindowPick(uint h)
{
    float u = float(h & 65535u) / 65536.0;
    int size = (int)_WinCount;
    int index = 0;
    for (int i = 0; i < 7; i++)
        if (i < size - 1 && u >= _WinEnds[i]) index = i + 1;
    float gain = lerp(_WinGain.x, _WinGain.y, float(h >> 16) / 65535.0);
    return float4(_WinColors[index].rgb, gain);
}
#endif

#if defined(SLICE_CUBE) || defined(SLICE_FILL)
#include "Assets/Resources/Shaders/SkinCommon.hlsl"
#endif

#if defined(SLICE_CUBE)
struct Cube
{
    float3 centre;
    float w0;
    float3 tint;
    float w1;
    uint bones;
    float3 cor;
    float corFlag;
};
StructuredBuffer<Cube> _Cubes;
float _CubeSize;
#define HAVE_MESH_MODIFICATION
AttributesMesh ApplyMeshModification(AttributesMesh input, float3 timeParameters)
{
#if UNITY_ANY_INSTANCING_ENABLED
    Cube c = _Cubes[input.instanceID];
#else
    Cube c = _Cubes[0];
#endif
    uint b0 = c.bones & 255u, b1 = (c.bones >> 8) & 255u, b2 = (c.bones >> 16) & 255u;
    float w0 = c.w0, w1 = c.w1, w2 = max(0.0, 1.0 - w0 - w1);
    float4x4 m0 = _Bones[b0], m1 = _Bones[b1], m2 = _Bones[b2];
    float4x4 blend = m0 * w0 + m1 * w1 + m2 * w2;
    float3 moved = mul(blend, float4(c.centre, 1)).xyz;
    float3x3 turn = Square(m0);
    if (c.corFlag > 0.5)
    {
        float4 q0 = ToQuat(turn);
        float4 q1 = ToQuat(Square(m1));
        float4 q2 = ToQuat(Square(m2));
        float4 q = normalize(q0 * w0 + q1 * (w1 * sign(dot(q0, q1) + 1e-6)) + q2 * (w2 * sign(dot(q0, q2) + 1e-6)));
        turn = FromQuat(q);
        moved = mul(turn, c.centre - c.cor) + mul(blend, float4(c.cor, 1)).xyz;
    }
    float3 local = input.positionOS * _CubeSize;
    float3 rest = c.centre + local;
    input.positionOS = Mirror(mul(_CrocWorld, float4(moved + mul(turn, local), 1)).xyz);
#ifdef ATTRIBUTES_NEED_NORMAL
    input.normalOS = normalize(Mirror(mul((float3x3)_CrocWorld, mul(turn, input.normalOS))));
#endif
#ifdef ATTRIBUTES_NEED_TANGENT
    input.tangentOS = float4(1, 0, 0, 1);
#endif
#ifdef ATTRIBUTES_NEED_COLOR
    input.color = float4(c.tint, 1);
#endif
#ifdef ATTRIBUTES_NEED_TEXCOORD0
    input.uv0 = rest.xy;
#endif
#ifdef ATTRIBUTES_NEED_TEXCOORD1
    input.uv1 = float2(rest.z, 0);
#endif
    return input;
}
#endif

#if defined(SLICE_FILL)
#define HAVE_MESH_MODIFICATION
AttributesMesh ApplyMeshModification(AttributesMesh input, float3 timeParameters)
{
#if defined(ATTRIBUTES_NEED_TEXCOORD0) && defined(ATTRIBUTES_NEED_TEXCOORD1) && defined(ATTRIBUTES_NEED_COLOR)
    float w0 = input.uv0.x, w1 = input.uv0.y, w2 = max(0.0, 1.0 - w0 - w1);
    uint b0 = (uint)round(input.uv1.x * 255.0), b1 = (uint)round(input.uv1.y * 255.0), b2 = (uint)round(input.color.a * 255.0);
#else
    // The depth and shadow passes get no streams from HDRP's defines: main bone only is not enough, so they get them too.
    float w0 = 1.0, w1 = 0.0, w2 = 0.0;
    uint b0 = 0u, b1 = 0u, b2 = 0u;
#endif
    float4x4 m0 = _Bones[b0], m1 = _Bones[b1], m2 = _Bones[b2];
    float4x4 blend = m0 * w0 + m1 * w1 + m2 * w2;
    float3 rest = input.positionOS;
    float3x3 turn = Square(m0);
    float3x3 world = (float3x3)_CrocWorld;
    input.positionOS = Mirror(mul(_CrocWorld, float4(mul(blend, float4(rest, 1)).xyz, 1)).xyz);
#ifdef ATTRIBUTES_NEED_NORMAL
    input.normalOS = normalize(Mirror(mul(world, float3(turn._m01, turn._m11, turn._m21))));
#endif
#ifdef ATTRIBUTES_NEED_TANGENT
    input.tangentOS = float4(normalize(Mirror(mul(world, float3(turn._m00, turn._m10, turn._m20)))), 1);
#endif
#ifdef ATTRIBUTES_NEED_TEXCOORD0
    input.uv0 = rest.xy;
#endif
#ifdef ATTRIBUTES_NEED_TEXCOORD1
    input.uv1 = float2(rest.z, 0);
#endif
    return input;
}

float3 FacetNormal(FragInputs input, float3 positionRWS)
{
    float3 n = normalize(cross(ddy(positionRWS), ddx(positionRWS)));
    if (dot(n, -positionRWS) < 0) n = -n;
    float3 axisX = input.tangentToWorld[0], axisY = input.tangentToWorld[2], axisZ = input.tangentToWorld[1];
    float dx = dot(n, axisX), dy = dot(n, axisY), dz = dot(n, axisZ);
    float ax = abs(dx), ay = abs(dy), az = abs(dz);
    if (ax >= ay && ax >= az) return normalize(axisX) * sign(dx);
    if (ay >= az) return normalize(axisY) * sign(dy);
    return normalize(axisZ) * sign(dz);
}
#endif

#if defined(SLICE_DEBRIS)
struct Particle
{
    float3 pos;
    uint color;
    float3 vel;
    uint seed;
};
StructuredBuffer<Particle> _Particles;
#define HAVE_MESH_MODIFICATION
AttributesMesh ApplyMeshModification(AttributesMesh input, float3 timeParameters)
{
#if UNITY_ANY_INSTANCING_ENABLED
    Particle p = _Particles[input.instanceID];
#else
    Particle p = _Particles[0];
#endif
    // Broken pieces, not gravel: mostly small, a few big lumps (scenes/debris_field.gd's mix of sizes).
    uint sized = (p.seed >> 16) & 255u;
    float grain = sized < 20u ? 2.6 : 0.6 + float(sized) / 255.0;
    input.positionOS = p.color == 0u ? float3(0, -1000, 0) : p.pos + input.positionOS * grain;
#ifdef ATTRIBUTES_NEED_TANGENT
    input.tangentOS = float4(1, 0, 0, 1);
#endif
#ifdef ATTRIBUTES_NEED_COLOR
    input.color = float4(float3(p.color & 255u, (p.color >> 8) & 255u, (p.color >> 16) & 255u) / 255.0, 1);
#endif
    return input;
}
#endif

#if defined(SLICE_GROUND)
#include "Assets/Resources/Shaders/CityGround.hlsl"
#endif

#if defined(SLICE_FACADE)
#include "Assets/Resources/Shaders/Facade.hlsl"
#endif

void GetSurfaceAndBuiltinData(FragInputs input, float3 V, inout PositionInputs posInput, out SurfaceData surfaceData, out BuiltinData builtinData)
{
    Orig_GetSurfaceAndBuiltinData(input, V, posInput, surfaceData, builtinData);
#if defined(SLICE_BUILDING) && SHADERPASS != SHADERPASS_SHADOWS
    // The camera bubble (D-283): cut in every view pass, never in the shadow's. Nothing is ever
    // drawn inside the core, a toppling piece swinging through the eye included.
    if (length(GetCameraRelativePositionWS(posInput.positionWS)) < max(_BubbleRadius * _BubbleCut, _BubbleCore))
        discard;
#endif
#if SHADERPASS == SHADERPASS_GBUFFER || SHADERPASS == SHADERPASS_FORWARD
    float3 n = input.tangentToWorld[2];
    float3 albedo = 1.0;
    float roughness = 0.9;
    float ao = 1.0;
    float3 emission = 0.0;

    #if defined(SLICE_BUILDING)
    float3 model = TransformWorldToObject(posInput.positionWS);
    float3 modelN = TransformWorldToObjectNormal(n);
    model.z = -model.z;
    modelN.z = -modelN.z;
    float3 windowPoint = model - modelN * (_VoxelSize * 0.5);
    int3 cell = (int3)round((windowPoint - _VoxelOrigin.xyz) / _VoxelSize);
    float3 srgb = round(saturate(input.color.rgb * JitterFactor(cell)) * 255.0) / 255.0;
    albedo = SRGBToLinear(srgb);
    if (!input.isFrontFace)
    {
        n = -n;
        albedo *= _ColorInside;
    }
    else
    {
        float lit = 1.0 - input.color.a;
        float a = input.color.a * 255.0;
        if (a > 0.5 && a < 1.5)
        {
            lit = 1.0;
            if (_WinPaletteOn > 0.5)
            {
                float4 w = WindowPick(WindowHash(windowPoint, modelN));
                albedo = w.rgb;
                lit = w.a;
            }
        }
        ao = lerp(1.0, input.texCoord0.x, _VoxelAoStrength);
        int finish = clamp((int)(input.texCoord0.y + 0.5), 0, 2);
        roughness = _FinishRoughness[finish];
        emission = albedo * _WindowGlow * lit;
        albedo *= lerp(1.0, ao, _VoxelAoLightAffect);
    }
    #elif defined(SLICE_CUBE)
    albedo = SRGBToLinear(input.color.rgb) * HideGrain(float3(input.texCoord0.xy, input.texCoord1.x));
    roughness = _KaijuRoughness;
    #elif defined(SLICE_FILL)
    n = FacetNormal(input, posInput.positionWS);
    albedo = SRGBToLinear(input.color.rgb) * HideGrain(float3(input.texCoord0.xy, input.texCoord1.x));
    roughness = _KaijuRoughness;
    #elif defined(SLICE_DEBRIS)
    albedo = SRGBToLinear(input.color.rgb);
    #elif defined(SLICE_FACADE)
    float3 facadeAt = TransformWorldToObject(posInput.positionWS);
    float3 facadeN = TransformWorldToObjectNormal(n);
    facadeAt.z = -facadeAt.z;
    facadeN.z = -facadeN.z;
    FacadeSurface(facadeAt, facadeN, input.color, input.texCoord0.xy, input.texCoord1.xy, albedo, emission);
    #elif defined(SLICE_GROUND)
    float3 groundAt = TransformWorldToObject(posInput.positionWS);
    float3 groundN = TransformWorldToObjectNormal(n);
    groundAt.z = -groundAt.z;
    groundN.z = -groundN.z;
    float groundDepth = -TransformWorldToView(posInput.positionWS).z;
    CityGroundSurface(input.texCoord0.xy, input.texCoord1.xy, groundAt, groundN, groundDepth, albedo, roughness, emission);
    #endif

    surfaceData.baseColor = albedo;
    surfaceData.normalWS = n;
    surfaceData.geomNormalWS = n;
    surfaceData.perceptualSmoothness = 1.0 - roughness;
    surfaceData.metallic = 0.0;
    surfaceData.ambientOcclusion = ao;
    surfaceData.specularOcclusion = 1.0;
    // Godot's flat ambient and emission, in display units: HDRP multiplies the exposure back in.
    builtinData.bakeDiffuseLighting = _SliceAmbient.rgb * albedo * ao * GetInverseCurrentExposureMultiplier();
    builtinData.backBakeDiffuseLighting = 0.0;
    builtinData.emissiveColor = emission * GetInverseCurrentExposureMultiplier();
#endif
}
