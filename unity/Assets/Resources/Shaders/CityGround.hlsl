// The city's ground: scenes/surface_detail.gdshaderinc and scenes/ground_slab.gdshader, one surface family
// (every feature evaluated at the centre of a 0.125 m world block, seeded, in Godot's world axes).
struct CitySlab
{
    float4 color;   // sRGB base colour
    float4 data;    // kind + axis / 8, then the street's centre line (big, small) and half width
    float4 axes;    // the slab's own x axis (xz) and its centre (xz)
    float4 extent;  // the slab's half size (x, z)
};
StructuredBuffer<CitySlab> _Slabs;

float g_block, g_block_noise, g_patch_noise, g_speck_chance, g_speck_dark, g_seam, g_fade_near, g_fade_far;
float g_mottle, g_track, g_tar, g_patch_dark, g_stain, g_gutter, g_panel, g_damp, g_streak, g_soil, g_paving;
float g_band_h, g_night_floor, g_river_y, g_seed;
float g_wet_dark, g_wet_rough;
// The weather's wet streets (ground_slab.gdshader `wet` and `sheen_color`, set only by WeatherView, D-155): 0 dry,
// 1 soaked; the sky colour the wet road gives back (linear). The road paint and the beach's sand stay dry, as
// Godot's paint and sand materials are not in its wet group.
float g_wet;
float4 g_sheen;

static const float JUNCTION_BLEND = 1.5;
static const float BAND_DARKEN = 0.78;
static const float BAND_PATCHY = 0.4;
static const float BAND_DARKEST = 0.85;
static const float BAND_PORE = 0.4;
static const float3 BAND_ALGAE = float3(0.72, 0.9, 0.5);
static const float BAND_ALGAE_MIX = 0.7;
static const float BAND_TIDE_W = 0.07;
static const float BAND_TIDE_GAP = 0.1;
static const float BAND_TIDE_LIFT = 0.35;
static const float BAND_ROUGHNESS = 0.42;
static const float BAND_NIGHT_GLOW = 0.08;
static const float BAND_NIGHT_LOW = 0.3;
static const float BAND_NIGHT_GRAIN = -0.2;
static const float GRAIN_SHADE = 0.065;
static const float GRAIN_TILE = 64.0;
// ground_slab.gdshader: the wet look's identity (how wet each weather is, is data).
static const float WET_DARKEN = 0.62;
static const float WET_ROUGHNESS = 0.18;
static const float WET_PUDDLE_SCALE = 0.16;  // puddle patches per metre
static const float WET_PUDDLE_ROUGHNESS = 0.03;
static const float WET_SHEEN = 0.55;  // how much of the sky colour the glancing road gives back
static const float WET_NIGHT_KEEP = 0.5;  // the night glow a soaked road keeps

float sd_mod(float a, float b) { return a - b * floor(a / b); }

// ground_slab.gdshader wet_hash, wet_noise: the puddles' value noise.
float wet_hash(float2 p) { return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }

float wet_noise(float2 p)
{
    float2 i = floor(p);
    float2 f = frac(p);
    f = f * f * (3.0 - 2.0 * f);
    return lerp(lerp(wet_hash(i), wet_hash(i + float2(1.0, 0.0)), f.x),
        lerp(wet_hash(i + float2(0.0, 1.0)), wet_hash(i + float2(1.0, 1.0)), f.x), f.y);
}

float sd_h(float2 p)
{
    float3 q = frac((p.xyx + g_seed) * float3(0.1031, 0.1030, 0.0973));
    q += dot(q, q.yzx + 33.33);
    return frac((q.x + q.y) * q.z);
}

float sd_h3(float3 p)
{
    p = frac((p + g_seed) * float3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return frac((p.x + p.y) * p.z);
}

float sd_vn(float2 p)
{
    float2 i = floor(p);
    float2 f = frac(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return lerp(lerp(sd_h(i), sd_h(i + float2(1.0, 0.0)), u.x),
        lerp(sd_h(i + float2(0.0, 1.0)), sd_h(i + float2(1.0, 1.0)), u.x), u.y);
}

float sd_fbm(float2 p, float m)
{
    float2 q = p / m;
    return 0.55 * sd_vn(q) + 0.3 * sd_vn(q * 2.3 + 17.0) + 0.15 * sd_vn(q * 5.1 + 43.0);
}

float2 sd_plane(float3 q, float3 n)
{
    float3 a = abs(n);
    if (a.y > 0.5) return q.xz;
    if (a.x > a.z) return float2(q.z, q.y);
    return float2(q.x, q.y);
}

float2 sd_cell(float2 p) { return (floor(p / g_block) + 0.5) * g_block; }

float sd_grain(float3 q, float depth)
{
    float3 cell = floor(q / g_block);
    float h = sd_h3(cell) * 2.0 - 1.0;
    float patch_h = sd_h3(floor(q) + 17.0) * 2.0 - 1.0;
    float k = 1.0 + h * g_block_noise + patch_h * g_patch_noise;
    if (sd_h3(cell + 91.0) < g_speck_chance) k *= g_speck_dark;
    float3 f = frac(q / g_block);
    float3 edge = min(f, 1.0 - f);
    float e = min(min(edge.x, edge.y), edge.z);
    k *= 1.0 - g_seam * (1.0 - smoothstep(0.0, 0.06, e));
    return lerp(1.0, k, 1.0 - smoothstep(g_fade_near, g_fade_far, depth));
}

float3 sd_asphalt(float3 base, float2 pc, float along, float lat, float half_w, float road, out float polish)
{
    polish = 0.0;
    float tone = sd_fbm(pc, 5.0) - 0.5;
    float tone2 = sd_vn(pc / 1.3) - 0.5;
    float k = 1.0 + tone * 2.0 * g_mottle + tone2 * g_mottle * 0.8;
    float3 col = base * k;
    col *= lerp(float3(0.93, 0.98, 1.07), float3(1.08, 1.02, 0.92), smoothstep(-0.18, 0.18, tone));
    float lane_w = 2.0 + step(5.0, half_w * 2.0);
    float u = (lat + half_w) / lane_w;
    float li = floor(u);
    float lm = (frac(u) - 0.5) * lane_w;
    float cell_a = road > 0.5 ? along : pc.x;
    float cell_l = road > 0.5 ? lm : pc.y;
    float2 cc = road > 0.5 ? float2(floor(along / 11.0), li) : floor(pc / 9.0);
    float span = road > 0.5 ? 11.0 : 9.0;
    float lw = road > 0.5 ? lane_w : 9.0;
    if (g_patch_dark > 0.0 && sd_h(cc * float2(1.7, 3.1) + 5.0) < 0.42)
    {
        float a0 = road > 0.5 ? frac(along / 11.0) * 11.0 : frac(pc.x / 9.0) * 9.0;
        float l0 = road > 0.5 ? lm : (frac(pc.y / 9.0) - 0.5) * 9.0;
        float len = lerp(1.4, 4.5, sd_h(cc + 11.0));
        float st = lerp(0.4, span - len - 0.4, sd_h(cc + 23.0));
        float wid = lerp(0.8, lw * 0.85, sd_h(cc + 37.0));
        float lo = (sd_h(cc + 53.0) - 0.5) * max(lw - wid, 0.0);
        float2 d2 = abs(float2(a0 - (st + len * 0.5), l0 - lo)) - float2(len, wid) * 0.5;
        float dd = max(d2.x, d2.y);
        float inside = 1.0 - step(0.0, dd);
        float rim = inside * step(-0.13, dd);
        float3 fresh = base * float3(0.62, 0.66, 0.76) * (0.85 + 0.3 * sd_h(cc + 71.0));
        col = lerp(col, fresh, saturate(inside * g_patch_dark * 2.0));
        polish = max(polish, inside * 0.6);
        col *= 1.0 + rim * 0.32;
    }
    float oil = sd_vn(float2(cell_a * 1.6, cell_l * 2.2 + li * 5.0));
    float oil_m = smoothstep(0.64, 0.82, oil);
    if (road > 0.5) oil_m *= 1.0 - smoothstep(0.12, 0.6, abs(lm));
    else oil_m *= smoothstep(0.55, 0.8, sd_vn(pc / 7.0 + 31.0));
    col *= lerp(float3(1.0, 1.0, 1.0), float3(0.62, 0.68, 0.8), oil_m * g_stain * 1.6);
    polish = max(polish, saturate(oil_m * g_stain * 2.5));
    if (road < 0.5) return col;
    float drift = (sd_vn(float2(along / 4.0, li * 3.7)) - 0.5) * 0.22;
    float tr = 1.0 - smoothstep(0.08, 0.22, abs(abs(lm + drift) - 0.42));
    float tmod = smoothstep(0.52, 0.78, sd_vn(float2(along / 1.5, li * 7.3 + 3.0)) * 0.55 + sd_vn(float2(along / 6.0, li * 2.1 + 8.0)) * 0.5);
    tmod *= 0.65 + 0.35 * sd_h(float2(floor(along / g_block), li + 13.0));
    polish = max(polish, tr * (0.25 + 0.75 * tmod));
    col = col * (1.0 + g_track * 1.7 * tr * (0.1 + 0.9 * tmod)) + float3(0.012, 0.012, 0.013) * g_track * tr * tmod;
    float sid = floor(along / 9.0);
    float spos = (sid + 0.15 + 0.7 * sd_h(float2(sid, 9.0))) * 9.0;
    float wob = (sd_vn(float2(lat * 2.6, sid)) - 0.5) * 0.5;
    float seamline = 1.0 - smoothstep(0.05, 0.15, abs(along - spos + wob));
    seamline *= step(0.3, sd_vn(float2(lat * 1.1, sid * 3.3)));
    float je = min(frac(u), 1.0 - frac(u)) * lane_w;
    float joint = (1.0 - smoothstep(0.05, 0.14, je)) * step(0.4, u) * step(u, floor(half_w * 2.0 / lane_w + 0.5) - 0.4);
    joint *= step(0.55, sd_vn(float2(along / 1.3, 11.0)));
    col *= 1.0 - g_tar * 0.7 * saturate(seamline + joint * 0.8);
    float kd = half_w - abs(lat);
    float gut = (1.0 - smoothstep(0.12, 0.75, kd)) * step(road, 1.5);
    col *= 1.0 - g_gutter * gut * (0.7 + 0.5 * sd_vn(pc / 0.8));
    col *= 1.0 + 0.5 * g_gutter * gut * step(sd_h(pc * 8.0 + 3.0), 0.12);
    return col;
}

float3 sd_pavement(float3 base, float2 pc, float kerb_d)
{
    float row = floor(pc.y);
    float shift = sd_mod(row, 2.0) * 0.5;
    float len = 1.0;
    float2 fp = float2((pc.x + shift) / len, pc.y);
    float2 fc = float2(floor(fp.x), row);
    float flagstone = sd_h(fc * 1.3 + 7.0) * 2.0 - 1.0;
    float k = 1.0 + flagstone * g_paving * 1.3 + (sd_fbm(pc, 3.5) - 0.5) * 0.18;
    k *= 1.0 + (sd_vn(pc / 0.45 + fc) - 0.5) * 0.1;
    float2 f = float2(frac(fp.x) * len, frac(pc.y));
    float2 e = min(f, float2(len, 1.0) - f);
    float joint = 1.0 - step(0.075, min(e.x, e.y));
    float3 col = base * k;
    col *= 1.0 - 0.3 * joint;
    float grime = smoothstep(0.6, 0.8, sd_vn(pc / 2.2 + 13.0));
    col *= 1.0 - 0.28 * grime * g_stain * 1.6;
    if (sd_h(fc + 29.0) < 0.14)
    {
        float cr = abs(frac((pc.x + pc.y * 0.7) * 1.0) - 0.5);
        col *= 1.0 - 0.3 * (1.0 - step(0.045, cr)) * step(0.35, sd_vn(pc * 3.0));
    }
    col *= 1.0 - g_gutter * 0.9 * (1.0 - smoothstep(0.05, 0.5, kerb_d)) * (0.6 + 0.6 * sd_vn(pc / 0.7));
    return col;
}

float3 sd_lawn(float3 base, float2 pc)
{
    float tone = sd_fbm(pc, 3.5) - 0.5;
    float k = 1.0 + tone * 0.5 + (step(0.5, frac(pc.y / 2.2)) - 0.5) * 0.09;
    float3 col = base * k;
    col *= lerp(float3(0.92, 0.98, 0.88), float3(1.1, 1.04, 0.86), smoothstep(-0.12, 0.2, tone));
    float t = sd_h(floor(pc / 0.25) + 3.0);
    col *= 1.0 + 0.2 * step(t, 0.12) - 0.2 * step(0.88, t);
    float s = sd_fbm(pc + 71.0, 2.4);
    float soil_m = smoothstep(0.56, 0.66, s) * g_soil * 1.7;
    float crumb = 0.75 + 0.5 * sd_h(pc * 8.0);
    return lerp(col, float3(0.085, 0.057, 0.034) * crumb, clamp(soil_m, 0.0, 0.92));
}

float sd_band_edge(float2 uv) { return g_band_h + 0.1 * (sd_vn(float2(uv.x * 0.9, 4.0)) - 0.5) * 2.0; }

float sd_band_wet(float2 uv, float h)
{
    float edge = sd_band_edge(uv);
    return 1.0 - smoothstep(edge - 0.1, edge + 0.03, h);
}

float sd_concrete_wet(float2 uv, float wy, float3 n, float water_y)
{
    if (water_y <= -50.0 || n.y > 0.5 || n.y < -0.5) return 0.0;
    return sd_band_wet(uv, wy - water_y) * g_damp;
}

float sd_band_glow(float2 uv, float wy, float3 n, float water_y)
{
    float w = sd_concrete_wet(uv, wy, n, water_y);
    float low = 1.0 - saturate((wy - water_y) / sd_band_edge(uv));
    return w * (1.0 + BAND_NIGHT_LOW * low);
}

float3 sd_concrete(float3 base, float2 uv, float wy, float3 n, float water_y)
{
    bool top = n.y > 0.5;
    bool under = n.y < -0.5;
    float2 psz = (top || under) ? float2(3.0, 3.0) : float2(3.2, 1.5);
    float2 pg = uv / psz;
    float2 pcell = floor(pg);
    float ptone = sd_h(pcell * 1.9 + 3.0) * 2.0 - 1.0;
    float3 col = base * (1.0 + ptone * g_panel + (sd_fbm(uv, 4.0) - 0.5) * 0.3);
    col *= lerp(float3(0.95, 0.98, 1.04), float3(1.05, 1.02, 0.96), sd_vn(uv / 1.7 + 5.0));
    float2 pf = frac(pg) * psz;
    float2 pe = min(pf, psz - pf);
    float joint = 1.0 - step(0.08, pe.x);
    float lift = 1.0 - step(0.075, pe.y);
    col *= 1.0 - 0.34 * saturate(joint + lift * 0.8);
    if (!top && !under)
    {
        float2 tf = abs(pf - float2(0.6, 0.45));
        col *= 1.0 - 0.3 * (1.0 - step(0.07, max(tf.x, tf.y)));
    }
    float st = sd_vn(float2(uv.x * (top ? 1.4 : 2.4), uv.y * (top ? 1.4 : 0.1)));
    float sm = smoothstep(0.58, 0.85, st);
    col *= 1.0 - g_streak * 1.5 * sm * (top ? 0.6 : 1.0);
    col *= 1.0 + 0.6 * g_streak * (1.0 - smoothstep(0.3, 0.5, st)) * (top ? 0.0 : 1.0) * 0.4;
    if (top)
    {
        float g = smoothstep(0.55, 0.8, sd_vn(uv / 1.8 + 21.0));
        col *= 1.0 - 0.22 * g * g_stain * 1.6;
    }
    if (under) col *= 0.55 * (0.8 + 0.4 * sd_fbm(uv, 2.0));
    if (!top && !under && sd_h(pcell + 61.0) < 0.3)
    {
        float cx = abs(pf.x - 0.3);
        float below = pf.y;
        float rust = (1.0 - step(0.1, cx)) * (1.0 - smoothstep(0.0, 0.9, below)) * step(0.3, sd_vn(float2(uv.x * 7.0, uv.y * 1.2)));
        col = lerp(col, float3(0.2, 0.085, 0.04), rust * 0.7);
    }
    if (water_y > -50.0 && !top)
    {
        float h = wy - water_y;
        float edge = sd_band_edge(uv);
        float wet_band = sd_band_wet(uv, h);
        float patchy = 1.0 - BAND_PATCHY * (sd_fbm(uv + 37.0, 0.6) - 0.5) * 2.0 - BAND_PORE * (sd_h(uv * 3.7 + 11.0) - 0.5) * 2.0;
        col *= 1.0 - min(BAND_DARKEN * g_damp * wet_band * patchy, BAND_DARKEST);
        float drips = sd_vn(float2(uv.x * 3.1, uv.y * 0.35 + 9.0));
        float algae_top = edge * lerp(0.35, 0.8, drips);
        float slime = (1.0 - smoothstep(0.0, algae_top, h)) * (0.65 + 0.35 * sd_fbm(uv + 13.0, 0.9));
        col *= lerp(float3(1.0, 1.0, 1.0), BAND_ALGAE, clamp(slime * g_damp * BAND_ALGAE_MIX, 0.0, BAND_ALGAE_MIX));
        float tide = (1.0 - smoothstep(0.0, BAND_TIDE_W, abs(h - edge - BAND_TIDE_GAP))) * g_damp;
        tide *= 0.6 + 0.4 * sd_vn(float2(uv.x * 2.2, 31.0));
        col *= 1.0 + BAND_TIDE_LIFT * tide;
    }
    return col;
}

float3 sd_paint(float3 base, float2 pc)
{
    float k = 0.94 + 0.1 * (sd_h(floor(pc / g_block)) - 0.5);
    return base * k;
}

float sd_paint_chip(float2 pc, float edge_d) { return (1.0 - smoothstep(0.0, 0.2, edge_d)) * 0.45; }

float3 sd_junction(float3 base, float2 pc, float2 wc, float2 centre, float2 half_size, out float polish)
{
    float2 d = wc - centre;
    float px;
    float pz;
    float3 along_x = sd_asphalt(base, pc, wc.x, d.y, half_size.y, 2.0, px);
    float3 along_z = sd_asphalt(base, pc, wc.y, d.x, half_size.x, 2.0, pz);
    float2 reach = abs(d) / max(half_size, float2(0.001, 0.001));
    float w = saturate(0.5 + JUNCTION_BLEND * (reach.x - reach.y));
    polish = lerp(pz, px, w);
    return lerp(along_z, along_x, w);
}

// One pixel of the city's ground. world and normal in Godot's axes; local: where it is on its slab from the
// slab's centre (m); up01: a beach corner's metres up the sand over the wet strip (0..1); depth: view depth;
// ndv: the surface normal's dot with the direction to the eye (Godot's dot(NORMAL, VIEW)).
void CityGroundSurface(float2 uv0, float2 local, float3 world, float3 normal, float depth, float ndv,
    out float3 albedo, out float roughness, out float3 emission)
{
    CitySlab s = _Slabs[(uint)round(uv0.x)];
    float3 q = world - normal * 0.001;
    float2 pc = sd_cell(sd_plane(q, normal));
    float code = s.data.x;
    float kind = floor(code + 0.001);
    float axis = floor(frac(code + 0.001) * 8.0 + 0.5);
    float3 base = SRGBToLinear(s.color.rgb);
    bool up = normal.y > 0.5;
    float2 wc = sd_cell(q.xz);
    float centre_line = s.data.y + s.data.z;
    float along = axis < 0.5 ? wc.x : wc.y;
    float lat = (axis < 0.5 ? wc.y : wc.x) - centre_line;
    if (axis > 1.5)
    {
        float2 d = wc - s.axes.zw;
        along = dot(d, s.axes.xy) + s.axes.z * 0.37;
        lat = dot(d, float2(-s.axes.y, s.axes.x));
    }
    float3 col = base;
    float polish = 0.0;
    float band_wet = 0.0;
    float band_glow = 0.0;
    roughness = -1.0;
    if (kind < 0.5)
    {
        col = sd_asphalt(base, pc, 0.0, 0.0, 1.0, 0.0, polish);
    }
    else if (kind < 1.5)
    {
        col = sd_asphalt(base, pc, along, lat, abs(s.data.w), s.data.w < 0.0 ? 2.0 : 1.0, polish);
    }
    else if (kind < 2.5)
    {
        if (up) col = sd_pavement(base, pc, min(s.extent.x - abs(local.x), s.extent.y - abs(local.y)));
        else col = sd_concrete(base, pc, world.y, normal, -100.0);
    }
    else if (kind < 3.5)
    {
        col = up ? sd_lawn(base, pc) : base;
    }
    else if (kind < 4.5)
    {
        col = sd_concrete(base, pc, world.y, normal, s.data.y);
        band_wet = sd_concrete_wet(pc, world.y, normal, s.data.y);
        band_glow = sd_band_glow(pc, world.y, normal, s.data.y);
    }
    else if (kind < 5.5)
    {
        if (up)
        {
            col = sd_asphalt(base, pc, along, lat, s.data.w, 1.0, polish);
        }
        else
        {
            col = sd_concrete(base, pc, world.y, normal, g_river_y);
            band_wet = sd_concrete_wet(pc, world.y, normal, g_river_y);
            band_glow = sd_band_glow(pc, world.y, normal, g_river_y);
        }
    }
    else if (kind > 7.5)
    {
        // The beach's sand: grains a voxel each, wet along the waterline (scenes/sand.gdshader).
        float2 grain = sd_mod(floor(world.x / g_block), GRAIN_TILE) * float2(1.0, 0.0) + sd_mod(floor(world.z / g_block), GRAIN_TILE) * float2(0.0, 1.0);
        float shade = (sd_h(grain + 41.0) * 2.0 - 1.0) * GRAIN_SHADE * (1.0 - smoothstep(g_fade_near, g_fade_far, depth));
        float3 srgb = shade >= 0.0 ? s.color.rgb + (1.0 - s.color.rgb) * shade : s.color.rgb * (1.0 + shade);
        float wet = 1.0 - smoothstep(0.0, 1.0, uv0.y);
        wet *= wet;
        albedo = SRGBToLinear(srgb) * lerp(1.0, g_wet_dark, wet);
        roughness = lerp(1.0, g_wet_rough, wet);
        emission = 0.0;
        return;
    }
    else if (kind > 6.5)
    {
        col = sd_junction(base, pc, wc, s.axes.zw, s.extent.xy, polish);
    }
    else
    {
        float lx = s.extent.x - abs(local.x);
        float lz = s.extent.y - abs(local.y);
        float edge_d = s.extent.x > s.extent.y ? lx : lz;
        // A chip shows the road under the paint (carried in the slab: no discard, so no depth pass to match).
        if (sd_h(pc * 7.0 + 2.0) < sd_paint_chip(pc, edge_d)) base = SRGBToLinear(s.data.yzw);
        col = sd_paint(base, pc);
    }
    col *= sd_grain(q, depth);
    // Wet goes last (ground_slab.gdshader): the same darkening and gloss whatever the surface; the paint stays dry.
    float wet = (kind > 5.5 && kind < 6.5) ? 0.0 : g_wet;
    albedo = col * (1.0 - wet * WET_DARKEN);
    // Godot's SPECULAR (0.5 dry, 0.9 wet) has no match in HDRP's metallic Lit: its F0 stays at 4%.
    roughness = lerp(lerp(lerp(1.0, 0.45, polish), BAND_ROUGHNESS, band_wet), WET_ROUGHNESS, wet);
    float ratio = dot(col, float3(0.3, 0.55, 0.15)) / max(dot(base, float3(0.3, 0.55, 0.15)), 0.0001);
    float keep = 1.0 - wet * WET_NIGHT_KEEP;
    emission = base * g_night_floor * pow(max(ratio, 0.0), 0.3) * ((kind < 1.5 || (kind > 4.5 && (up || kind > 5.5))) ? 1.0 : 0.0) * keep;
    emission += base * g_night_floor * BAND_NIGHT_GLOW * band_glow * pow(max(ratio, 0.0001), BAND_NIGHT_GRAIN) * keep;
    // Wet only: puddle patches are mirror-smooth and give the sky back at a glancing angle (fresnel), the rest of
    // the road a faint sheen. Both are 0 when dry.
    float2 ground = world.xz;
    float puddle = smoothstep(0.45, 0.7, wet_noise(ground * WET_PUDDLE_SCALE) * 0.65 + wet_noise(ground * WET_PUDDLE_SCALE * 3.7) * 0.35);
    roughness = lerp(roughness, WET_PUDDLE_ROUGHNESS, wet * puddle);
    float glance = pow(1.0 - saturate(ndv), 2.5);
    emission += g_sheen.rgb * wet * WET_SHEEN * glance * (0.35 + 0.65 * puddle);
}
