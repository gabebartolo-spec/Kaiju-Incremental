// The stand-in buildings past the playable edge (scenes/facade.gdshaderinc): one box per building,
// its facade painted in world space at the voxels' grid: slab line, two window rows, lintel. Vertex
// colour = wall (sRGB), alpha = grain / 32; uv0 = (style, share of windows lit), uv1 = (roof height, seed).
// Style -1 is a plain box (concrete), -2 a blinking roof beacon. Godot axes throughout.
float4 _FacadeRoof, _FacadeWindow;
float _FacadeFilterStart, _FacadeFilterCells;

float FacadeHash(float3 p)
{
    p = frac(p * float3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return frac((p.x + p.y) * p.z);
}

void FacadeWall(float2 at, float top, float3 wall, float seed, float share, int style, float grain, out float3 albedo, out float3 emit)
{
    albedo = wall;
    emit = 0.0;
    float cell = floor(at.x * grain);
    float y4 = floor(at.y * grain);
    float row = fmod(y4, 4.0);
    float p = fmod(cell + floor(seed * 13.0), 64.0);
    bool window = false;
    bool trim = false;
    if (at.y * grain < 4.0)
    {
        window = fmod(p, 5.0) > 0.5 && row < 2.5;
        trim = row > 2.5;
    }
    else if (style == 0)
    {
        trim = row < 0.5;
        window = row > 0.5 && row < 2.5 && fmod(p, 4.0) > 0.5;
    }
    else if (style == 1)
    {
        window = row > 0.5 && row < 2.5 && fmod(p, 3.0) > 0.5;
    }
    else if (style == 2)
    {
        window = !(fmod(p, 4.0) < 0.5 || row < 0.5);
    }
    else
    {
        trim = fmod(y4, 20.0) < 0.5;
        window = row > 0.5 && row < 2.5 && fmod(p, 4.0) > 0.5 && fmod(p, 4.0) < 2.5;
    }
    if ((top - at.y) * grain < 2.0)
    {
        trim = true;
        window = false;
    }
    float jitter = 0.92 + 0.16 * FacadeHash(float3(cell, y4, seed));
    if (trim)
    {
        albedo = wall * 1.25 * jitter;
    }
    else if (window)
    {
        float3 pane = _FacadeWindow.rgb;
        if (style == 2) pane = lerp(pane, wall, 0.3) * 1.1;
        albedo = pane * jitter;
        if (FacadeHash(float3(floor(cell / 2.0), floor(y4 / 4.0), seed * 31.0)) < share)
        {
            uint h = WindowMix(uint(int(seed * 65536.0)) ^ 40503u);
            h = WindowMix(h ^ uint(int(floor(cell / 2.0))));
            float4 w = WindowPick(WindowMix(h ^ uint(int(floor(y4 / 4.0)))));
            albedo = w.rgb;
            emit = w.rgb * _WindowGlow * w.a;
        }
    }
    else
    {
        albedo = wall * jitter;
    }
}

// The box-filtered seam: the share of a pixel `w` cells wide at `x` lying within 0.04 of a cell edge.
float FacadeSeam(float x, float w)
{
    float a = x - 0.5 * w, b = x + 0.5 * w;
    float ia = floor(a) * 0.08 + min(frac(a), 0.04) + max(frac(a) - 0.96, 0.0);
    float ib = floor(b) * 0.08 + min(frac(b), 0.04) + max(frac(b) - 0.96, 0.0);
    return saturate((ib - ia) / w);
}

void FacadeSurface(float3 world, float3 n, float4 color, float2 data, float2 box, out float3 albedo, out float3 emit)
{
    float3 wall = SRGBToLinear(color.rgb);
    float grain = color.a * 255.0 / 32.0;
    albedo = wall;
    emit = 0.0;
    // Seed quantised: interpolated, it wobbles by a rounding error and the hashes re-roll per pixel row.
    float seed = floor(box.y * 1024.0 + 0.5) / 1024.0;
    float2 at = float2(abs(n.x) > 0.5 ? world.z : world.x, world.y);
    float2 foot = max(fwidth(at) * grain, 1e-5);
    if (data.x < -1.5)
    {
        float blink = step(0.5, frac(_Time.y * 0.6 + seed * 7.0));
        albedo = float3(0.4, 0.05, 0.03);
        emit = float3(1.0, 0.12, 0.08) * 6.0 * blink;
    }
    else if (data.x < -0.5)
    {
        albedo = wall * (n.y > 0.5 ? 1.08 : 1.0);
    }
    else if (n.y > 0.5)
    {
        albedo = _FacadeRoof.rgb * (0.85 + 0.3 * FacadeHash(floor(world * 4.0)));
    }
    else
    {
        int style = (int)(data.x + 0.5);
        if (max(foot.x, foot.y) > _FacadeFilterStart)
        {
            // Past a window's width one sample per pixel pops as the camera moves: take every cell under the pixel.
            float2 w = min(foot, _FacadeFilterCells);
            float2 lo = at * grain - 0.5 * w;
            float2 hi = lo + w;
            int nx = (int)(floor(hi.x) - floor(lo.x)) + 1;
            int ny = (int)(floor(hi.y) - floor(lo.y)) + 1;
            float3 sumA = 0.0, sumE = 0.0;
            for (int i = 0; i < nx; i++)
            {
                float cx = floor(lo.x) + i;
                float x0 = max(lo.x, cx), x1 = min(hi.x, cx + 1.0);
                for (int j = 0; j < ny; j++)
                {
                    float cy = floor(lo.y) + j;
                    float y0 = max(lo.y, cy), y1 = min(hi.y, cy + 1.0);
                    float3 a, e;
                    FacadeWall(float2(x0 + x1, y0 + y1) * (0.5 / grain), box.x, wall, seed, data.y, style, grain, a, e);
                    float k = max(x1 - x0, 0.0) * max(y1 - y0, 0.0);
                    sumA += a * k;
                    sumE += e * k;
                }
            }
            albedo = sumA / (w.x * w.y);
            emit = sumE / (w.x * w.y);
            float2 c = float2(FacadeSeam(lo.x + 0.5 * w.x, w.x), FacadeSeam(lo.y + 0.5 * w.y, w.y));
            albedo *= 1.0 - 0.2 * (c.x + c.y - c.x * c.y);
        }
        else
        {
            FacadeWall(at, box.x, wall, seed, data.y, style, grain, albedo, emit);
            float2 v = frac(at * grain);
            if (min(min(v.x, v.y), min(1.0 - v.x, 1.0 - v.y)) < 0.04) albedo *= 0.8;
        }
    }
}
