// The title's soft lights and smoke (Resources/Shaders/TitleFx), all camera-facing quads in Godot's axes:
//   glows     the promenade's lamp heads (title_shore.gd _glow_quad), each district fire's flickering glow
//             (far_fire.gd _glow_sprite), the colossus's great fire glow (title_colossus.gd _glow_sprite) and
//             the flashes (far_flash.gd: shots, booms, their white cores, additive; the booms' smoke, mixed);
//   smoke     the sky's smoke banks (title_sky_smoke.gd), one draw per layer at its own priority;
//   panes     the burning windows (title_burning_windows.gd), one draw per group.
// The district fires' own flames and embers (far_fire.gd's zoomed Fire) are not drawn here.
using System;
using System.Collections.Generic;
using Kaiju.Game;
using UnityEngine;
using UnityEngine.Rendering;
using S = Kaiju.Sim;

public sealed class TitleFxView : IDisposable
{
    const int QUAD_VERTS = 6, STRIDE = 3;
    const float BOUNDS = 4000f;
    // The sky glow draws after every other transparent (HDRP sorts within Transparent +-50 priority).
    const int SKY_LAST = 50;
    // far_fire.gd: a fire's glow is GLOW_SHAPE of its size wide and tall, GLOW_LIFT of it up, at GLOW_ALPHA.
    const float GLOW_ALPHA = 0.15f, GLOW_WIDE = 0.55f, GLOW_TALL = 1.5f, GLOW_LIFT = 0.45f;
    const float GLOW_BEAT = 0.2f, GLOW_HELD = 0.8f, BEAT_HZ = 2.3f;
    // title_sky_smoke.gdshader's morph default; title_sky_smoke.gd noise_texture: FastNoiseLite's numbers.
    const float SMOKE_MORPH = 0.03f;
    const int NOISE_SIDE = 256, NOISE_OCTAVES = 4, NOISE_SEED = 7;
    const float FLAT = 1e-6f;
    const float NOISE_FREQ = 0.012f, NOISE_GAIN = 0.5f, NOISE_LACUNARITY = 2f, NOISE_SHIFT = 97.3f;
    // title_burning_windows.gdshader's flicker_hz default (the gd never sets it).
    const float PANE_FLICKER_HZ = 7f;

    // A flash in flight (far_flash.gd).
    sealed class Flash
    {
        public Vector3 at;
        public Color color;
        public float size, life, rise, grow = 1f, age, bright = 1f;
        public bool additive = true, sky;
    }

    readonly Shader shader;
    readonly List<Material> mats = new List<Material>();
    readonly List<ComputeBuffer> buffers = new List<ComputeBuffer>();
    readonly List<Flash> flashes = new List<Flash>();
    readonly List<Vector4> quads = new List<Vector4>(), mixed = new List<Vector4>(), sky = new List<Vector4>();
    readonly Material glowMat, mixMat, skyMat;
    readonly List<(Material mat, int count)> smoke = new List<(Material mat, int count)>(), panes = new List<(Material mat, int count)>();
    readonly List<TitleShoreView.Head> lamps;
    readonly Color lampColor;
    readonly List<TitleCity.Fire> fires;
    readonly Texture2D noise;
    ComputeBuffer glowBuf, mixBuf, skyBuf;
    float time;

    // The colossus's glow this frame (title_colossus.gd _show): where (Godot axes), how big, its colour and alpha.
    public Vector3 colossusAt;
    public float colossusSize;
    public Color colossusColor;

    public TitleFxView(Shader shader, TitleShoreView shore, TitleCity.District district, S.GDict title, float smokeStrength)
    {
        this.shader = shader;
        lamps = shore.heads;
        lampColor = shore.lampColor.linear;
        fires = district.fires;
        glowMat = Make("TITLE_GLOW", BlendMode.SrcAlpha, BlendMode.One, (int)RenderQueue.Transparent);
        mixMat = Make("TITLE_GLOW", BlendMode.SrcAlpha, BlendMode.OneMinusSrcAlpha, (int)RenderQueue.Transparent);
        // title_backdrop.gd _light_sky: a glow over the picture, so nothing in the city hides it.
        skyMat = Make("TITLE_GLOW", BlendMode.SrcAlpha, BlendMode.One, (int)RenderQueue.Transparent + SKY_LAST);
        skyMat.SetFloat("_ZTest", (float)CompareFunction.Always);
        noise = Noise();
        Smoke(title["sky_smoke"], smokeStrength);
        S.GDict fireCfg = title["fires"], windows = fireCfg["windows"];
        S.GDict heroCfg = fireCfg["hero"], hero = windows.Duplicate();
        hero["cells"] = heroCfg["cells"];
        Panes(district.windowPanes, windows);
        Panes(district.heroPanes, hero);
    }

    Material Make(string keyword, BlendMode src, BlendMode dst, int queue)
    {
        var mat = new Material(shader) { renderQueue = queue };
        mat.EnableKeyword(keyword);
        mat.SetFloat("_SrcBlend", (float)src);
        mat.SetFloat("_DstBlend", (float)dst);
        mats.Add(mat);
        return mat;
    }

    ComputeBuffer Buffer(List<Vector4> data)
    {
        var buf = new ComputeBuffer(Mathf.Max(1, data.Count), sizeof(float) * 4);
        if (data.Count > 0) buf.SetData(data);
        buffers.Add(buf);
        return buf;
    }

    static void Quad(List<Vector4> into, Vector3 at, float width, float height, Vector4 b)
    {
        into.Add(new Vector4(at.x, at.y, at.z, width));
        into.Add(b);
        into.Add(new Vector4(height, 0f, 0f, 0f));
    }

    // One material per bank, drawn at the layer's priority (Godot render_priority) among the transparents.
    void Smoke(S.GArray<S.Variant> layers, float strength)
    {
        List<TitleCity.Puff> puffs = TitleCity.Smoke(layers);
        for (int n = 0; n < layers.Size(); n++)
        {
            S.GDict layer = layers[n];
            var data = new List<Vector4>();
            foreach (TitleCity.Puff p in puffs)
                if (p.layer == n) Quad(data, new Vector3((float)p.at.x, (float)p.at.y, (float)p.at.z), (float)p.size, (float)p.size, Vector4.zero);
            var mat = Make("TITLE_SMOKE", BlendMode.SrcAlpha, BlendMode.OneMinusSrcAlpha, (int)RenderQueue.Transparent + (int)S.Num.I(layer["priority"]));
            Color tint = SliceData.Hex(S.Gd.Str(layer["colour"])).linear;
            mat.SetVector("_Tint", new Vector4(tint.r, tint.g, tint.b, (float)S.Num.F(layer["alpha"]) * strength));
            Color under = SliceData.Hex(S.Gd.Str(layer["under_colour"])).linear;
            mat.SetVector("_Under", new Vector4(under.r, under.g, under.b, (float)S.Num.F(layer["under"])));
            mat.SetVector("_Drift", new Vector4((float)S.Num.F(layer["drift"]), SMOKE_MORPH, 0f, 0f));
            mat.SetTexture("_Noise", noise);
            mat.SetBuffer("_TitleQuads", Buffer(data));
            smoke.Add((mat, data.Count / STRIDE));
        }
    }

    void Panes(List<TitleCity.Pane> list, S.GDict cfg)
    {
        if (list == null || list.Count == 0) return;
        var data = new List<Vector4>();
        foreach (TitleCity.Pane p in list)
            Quad(data, new Vector3((float)p.at.x, (float)p.at.y, (float)p.at.z), (float)p.width, (float)(p.width * TitleCity.PANE_ROWS), new Vector4((float)p.shade, 0f, 0f, 0f));
        var mat = Make("TITLE_PANE", BlendMode.One, BlendMode.Zero, (int)RenderQueue.Transparent);
        mat.SetFloat("_ZWrite", 1f);
        Color colour = SliceData.Hex(S.Gd.Str(cfg["colour"])).linear * (float)S.Num.F(cfg["glow"]);
        mat.SetVector("_Pane", new Vector4(colour.r, colour.g, colour.b, PANE_FLICKER_HZ));
        mat.SetBuffer("_TitleQuads", Buffer(data));
        panes.Add((mat, data.Count / STRIDE));
    }

    // A flash at `at` (Godot axes): far_flash.gd with its spec; an additive one takes the player's flash scale.
    public void Add(Vector3 at, Color color, float size, float life, float grow = 1f, float rise = 0f, bool additive = true)
    {
        flashes.Add(new Flash
        {
            at = at, color = color.linear, size = size, life = life, grow = grow, rise = rise, additive = additive,
            bright = additive ? (float)PlayerSettings.FlashScale() : 1f,
        });
    }

    // title_backdrop.gd _light_sky: an explosion's light over the picture, `size` across where `at` is seen,
    // its alpha going to nothing over `life` (a tween, so linear, and no flash scale).
    public void Sky(Vector3 at, Color color, float size, float life)
    {
        flashes.Add(new Flash { at = at, color = color.linear, size = size, life = life, sky = true });
    }

    public void Step(float dt)
    {
        time += dt;
        Shader.SetGlobalFloat("_TitleTime", time);
        quads.Clear();
        mixed.Clear();
        sky.Clear();
        foreach (TitleShoreView.Head h in lamps) Quad(quads, h.at, h.size, h.size, lampColor);
        FireGlows();
        if (colossusSize > 0f) Quad(quads, colossusAt, colossusSize, colossusSize, colossusColor);
        StepFlashes(dt);
        var bounds = new Bounds(Vector3.zero, Vector3.one * BOUNDS);
        foreach ((Material mat, int count) in smoke)
            Graphics.DrawProcedural(mat, bounds, MeshTopology.Triangles, QUAD_VERTS, count, null, null, ShadowCastingMode.Off, false, 0);
        foreach ((Material mat, int count) in panes)
            Graphics.DrawProcedural(mat, bounds, MeshTopology.Triangles, QUAD_VERTS, count, null, null, ShadowCastingMode.Off, false, 0);
        Draw(glowMat, ref glowBuf, quads, bounds);
        Draw(mixMat, ref mixBuf, mixed, bounds);
        Draw(skyMat, ref skyBuf, sky, bounds);
    }

    // far_fire.gd _process: each fire's glow breathes with its own beat.
    void FireGlows()
    {
        foreach (TitleCity.Fire f in fires)
        {
            float size = (float)S.Num.F(f.spec["glow_size"]), seed = (float)f.seed;
            float beat = Mathf.Sin(time * (float)S.Num.F(f.spec["flicker_hz"]) + seed) * Mathf.Sin(time * BEAT_HZ + seed * 3f);
            float k = GLOW_HELD + GLOW_BEAT * beat;
            Color c = SliceData.Hex(S.Gd.Str(f.spec["glow_color"])).linear;
            var at = new Vector3((float)f.at.x, (float)f.at.y + size * GLOW_LIFT, (float)f.at.z);
            Quad(quads, at, size * GLOW_WIDE * k, size * GLOW_TALL * k, new Vector4(c.r, c.g, c.b, GLOW_ALPHA));
        }
    }

    // far_flash.gd _process: holds its light then dies, grows, smoke rises.
    void StepFlashes(float dt)
    {
        for (int i = flashes.Count - 1; i >= 0; i--)
        {
            Flash f = flashes[i];
            f.age += dt;
            float t = f.age / f.life;
            if (t >= 1f)
            {
                flashes.RemoveAt(i);
                continue;
            }
            if (f.sky)
            {
                Quad(sky, f.at, f.size, f.size, new Vector4(f.color.r, f.color.g, f.color.b, f.color.a * (1f - t)));
                continue;
            }
            f.at.y += f.rise / f.life * dt;
            float size = f.size * Mathf.Lerp(1f, f.grow, t);
            var colour = new Vector4(f.color.r, f.color.g, f.color.b, f.color.a * (1f - t * t) * f.bright);
            Quad(f.additive ? quads : mixed, f.at, size, size, colour);
        }
    }

    void Draw(Material mat, ref ComputeBuffer buf, List<Vector4> data, Bounds bounds)
    {
        if (data.Count == 0) return;
        if (buf == null || buf.count < data.Count)
        {
            if (buf != null) buffers.Remove(buf);
            buf?.Release();
            buf = new ComputeBuffer(Mathf.NextPowerOfTwo(data.Count), sizeof(float) * 4);
            buffers.Add(buf);
            mat.SetBuffer("_TitleQuads", buf);
        }
        buf.SetData(data);
        Graphics.DrawProcedural(mat, bounds, MeshTopology.Triangles, QUAD_VERTS, data.Count / STRIDE, null, null, ShadowCastingMode.Off, false, 0);
    }

    // title_sky_smoke.gd noise_texture: FastNoiseLite (simplex, 0.012, 4 octaves, seed 7) is not in Unity; this
    // fractal Perlin (BreathView's stand-in) in its place, made seamless by blending across the tile.
    static Texture2D Noise()
    {
        var tex = new Texture2D(NOISE_SIDE, NOISE_SIDE, TextureFormat.R8, false, true) { wrapMode = TextureWrapMode.Repeat };
        var raw = new float[NOISE_SIDE * NOISE_SIDE];
        float low = float.MaxValue, high = float.MinValue;
        for (int y = 0; y < NOISE_SIDE; y++)
            for (int x = 0; x < NOISE_SIDE; x++)
            {
                float u = (float)x / NOISE_SIDE, v = (float)y / NOISE_SIDE;
                float n = Fractal(x, y) * (1f - u) * (1f - v) + Fractal(x - NOISE_SIDE, y) * u * (1f - v)
                    + Fractal(x, y - NOISE_SIDE) * (1f - u) * v + Fractal(x - NOISE_SIDE, y - NOISE_SIDE) * u * v;
                raw[y * NOISE_SIDE + x] = n;
                low = Mathf.Min(low, n);
                high = Mathf.Max(high, n);
            }
        var px = new Color[raw.Length];
        for (int i = 0; i < raw.Length; i++)
        {
            float g = (raw[i] - low) / Mathf.Max(high - low, FLAT);
            px[i] = new Color(g, g, g, 1f);
        }
        tex.SetPixels(px);
        tex.Apply(false, true);
        return tex;
    }

    static float Fractal(float x, float y)
    {
        float sum = 0f, amp = 1f, f = NOISE_FREQ;
        for (int i = 0; i < NOISE_OCTAVES; i++)
        {
            sum += Mathf.PerlinNoise(x * f + NOISE_SEED * NOISE_SHIFT, y * f + NOISE_SEED) * amp;
            amp *= NOISE_GAIN;
            f *= NOISE_LACUNARITY;
        }
        return sum;
    }

    public void Dispose()
    {
        foreach (ComputeBuffer b in buffers) b.Release();
        foreach (Material m in mats) UnityEngine.Object.Destroy(m);
        if (noise != null) UnityEngine.Object.Destroy(noise);
    }
}
