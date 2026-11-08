#ifndef SKIN_COMMON_INCLUDED
#define SKIN_COMMON_INCLUDED
// scenes/voxel_skin.gdshader's shared pieces: bone turns, QLERP, the hide grain.
StructuredBuffer<float4x4> _Bones;
float4x4 _CrocWorld;
float _HideCell, _HideSeed, _HideCrevice, _HideCreviceWidth, _HideFleck, _HideFleckDark, _HideTone, _KaijuRoughness;

float3x3 Columns(float3 a, float3 b, float3 c)
{
    return float3x3(a.x, b.x, c.x, a.y, b.y, c.y, a.z, b.z, c.z);
}

float3x3 Square(float4x4 m)
{
    float3 ax = normalize(float3(m._m00, m._m10, m._m20));
    float3 y = float3(m._m01, m._m11, m._m21);
    float3 ay = normalize(y - ax * dot(ax, y));
    return Columns(ax, ay, cross(ax, ay));
}

float4 ToQuat(float3x3 m)
{
    float tr = m._m00 + m._m11 + m._m22;
    float4 q;
    if (tr > 0.0)
    {
        float s = sqrt(tr + 1.0) * 2.0;
        q = float4((m._m21 - m._m12) / s, (m._m02 - m._m20) / s, (m._m10 - m._m01) / s, 0.25 * s);
    }
    else if (m._m00 > m._m11 && m._m00 > m._m22)
    {
        float s = sqrt(1.0 + m._m00 - m._m11 - m._m22) * 2.0;
        q = float4(0.25 * s, (m._m01 + m._m10) / s, (m._m02 + m._m20) / s, (m._m21 - m._m12) / s);
    }
    else if (m._m11 > m._m22)
    {
        float s = sqrt(1.0 + m._m11 - m._m00 - m._m22) * 2.0;
        q = float4((m._m01 + m._m10) / s, 0.25 * s, (m._m12 + m._m21) / s, (m._m02 - m._m20) / s);
    }
    else
    {
        float s = sqrt(1.0 + m._m22 - m._m00 - m._m11) * 2.0;
        q = float4((m._m02 + m._m20) / s, (m._m12 + m._m21) / s, 0.25 * s, (m._m10 - m._m01) / s);
    }
    return q;
}

float3x3 FromQuat(float4 q)
{
    float x = q.x, y = q.y, z = q.z, w = q.w;
    return float3x3(
        1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y),
        2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x),
        2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y));
}

float3 Mirror(float3 p) { return float3(p.x, p.y, -p.z); }

float3 HideHash3(float3 p)
{
    p = float3(dot(p, float3(127.1, 311.7, 74.7)), dot(p, float3(269.5, 183.3, 246.1)), dot(p, float3(113.5, 271.9, 124.6)));
    return frac(sin(p) * 43758.5453);
}

float HideGrain(float3 p)
{
    float3 q = p / _HideCell + _HideSeed;
    float3 i = floor(q);
    float3 f = q - i;
    float d1 = 8.0, d2 = 8.0;
    float3 best = i;
    for (int z = -1; z <= 1; z++)
        for (int y = -1; y <= 1; y++)
            for (int x = -1; x <= 1; x++)
            {
                float3 o = float3(x, y, z);
                float3 r = o + HideHash3(i + o) - f;
                float d = dot(r, r);
                if (d < d1)
                {
                    d2 = d1;
                    d1 = d;
                    best = i + o;
                }
                else if (d < d2)
                {
                    d2 = d;
                }
            }
    float edge = sqrt(d2) - sqrt(d1);
    float crevice = 1.0 - smoothstep(0.0, _HideCreviceWidth, edge);
    float3 h = HideHash3(best + 17.0);
    float tone = 1.0 + (h.x - 0.5) * 2.0 * _HideTone;
    float fleck = step(1.0 - _HideFleck, h.y) * (h.z > 0.5 ? 1.0 : -1.0);
    return tone * (1.0 - _HideCrevice * crevice) * (1.0 - _HideFleckDark * fleck);
}
#endif
