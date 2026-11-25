using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

// scenes/fx_decals.gd: the marks the powers leave on the city. A box drawn over the depth buffer, each pixel looked
// up by where the world behind it stands, so a mark lies on the street, on rubble heaps and on ruins alike, and
// never on the croc (Scorch.shader skips its body box). Soot darkens; the crack lines glow and cool over the first
// 60% of the mark's seconds, then the soot fades. WEDGE: the breath's scorch down its cone (BreathView); DISC: a
// heavy stomp's or a leap landing's molten cracks (StompCracks). Godot axes throughout.
public sealed class ScorchMarks : IDisposable
{
    public enum Shape { Disc, Wedge }

    // scenes/fx_decals.gd: SIZE, DEPTH, the centre's lift (a share of DEPTH), normal_fade, the cracks' default.
    const int SIZE = 192, CRACKS = 9, NOISE_OCTAVES = 5;
    const float DEPTH = 14f, CENTRE_LIFT = 0.2f, NORMAL_FADE = 0.35f, NOISE_FREQ = 0.03f;
    const float GLOW_SHARE = 0.6f, FADE_SHARE = 0.4f;
    static readonly Vector3 SOOT = new Vector3(0.03f, 0.027f, 0.024f);
    // A disc lies flat and unturned: its texture's top row toward Godot -z, as an unturned Godot Decal's.
    static readonly Vector3 DISC_DIR = new Vector3(0f, 0f, -1f);
    const float FAR_BOUNDS = 1e6f;

    // scenes/fx_decals.gd _pixel and _crack: the ragged rim, the wedge's sides and tip, the cracks' wander and width.
    const float RIM_IN = 0.55f, EDGE_RAG = 0.3f, SIDE_RAG = 0.3f, SIDE_IN = 0.8f, SIDE_OUT = 1.1f;
    const float TIP_IN = 0.02f, TIP_OUT = 0.12f, STREAK_SHARP = 40f, STREAK = 0.8f;
    const float SHADE_BASE = 0.6f, SHADE_NOISE = 0.8f, COVER_BASE = 0.65f, COVER_NOISE = 0.35f;
    const float WANDER_ALONG = 60f, WANDER_LANE = 17f, WANDER = 0.6f, WIDTH_BASE = 0.04f, WIDTH_OUT = 0.05f;
    const float WIDTH_SOFT = 0.4f, CRACK_FROM = 0.05f, CRACK_FULL = 0.18f, BYTE = 255f, KEY_STEPS = 1000f;
    // The fractal noise's fixed offsets (FastNoiseLite's seed 7 + shape is not in Unity); each shape shifts by one more.
    const float NOISE_X = 31.7f, NOISE_Y = 11.3f, SHAPE_SHIFT = 57.1f;

    public sealed class Mark
    {
        public readonly MaterialPropertyBlock block = new MaterialPropertyBlock();
        public float age, seconds, sootIn, glowIn, energy, soot = 1f;
    }

    readonly List<Mark> marks = new List<Mark>();
    readonly Mesh mesh;
    readonly Material mat;
    readonly Dictionary<(Shape, int, int), Texture2D> drawn = new Dictionary<(Shape, int, int), Texture2D>();

    public ScorchMarks(Shader shader)
    {
        mesh = SliceGame.CubeMesh(1f, false);
        mesh.bounds = new Bounds(Vector3.zero, Vector3.one * FAR_BOUNDS);
        mat = new Material(shader);
    }

    // The breath's wedge. feet: Godot axes, the wedge's apex; dir: flat Godot axes; size: the square it fills.
    public void Add(Vector3 feet, Vector3 dir, float size, float half, float seconds, float sootIn, float glowIn, float energy, Color tint)
    {
        Mark m = Place(Texture(Shape.Wedge, CRACKS, half), feet, dir, size, tint);
        m.seconds = seconds;
        m.sootIn = sootIn;
        m.glowIn = glowIn;
        m.energy = energy;
    }

    // fx_decals.gd spawn(DISC): `cracks` radial cracks glowing `tint` at `energy`, `size` across, centred on `at`
    // (Godot axes), the soot at `soot`; it lands at once and cools over `seconds`.
    public Mark Disc(Vector3 at, float size, int cracks, float seconds, float energy, float soot, Color tint)
    {
        Mark m = Place(Texture(Shape.Disc, cracks, 0f), at, DISC_DIR, size, tint);
        m.seconds = seconds;
        m.energy = energy;
        m.soot = soot;
        return m;
    }

    Mark Place(Texture2D tex, Vector3 at, Vector3 dir, float size, Color tint)
    {
        var m = new Mark();
        Vector3 centre = at + Vector3.up * (DEPTH * CENTRE_LIFT);
        m.block.SetTexture("_ScorchTex", tex);
        m.block.SetVector("_ScorchAt", new Vector4(centre.x, centre.y, -centre.z, size * 0.5f));
        m.block.SetVector("_ScorchDir", new Vector4(dir.x, dir.z, DEPTH * 0.5f, NORMAL_FADE));
        m.block.SetVector("_ScorchTint", tint);
        m.block.SetVector("_ScorchSoot", SOOT);
        marks.Add(m);
        return m;
    }

    public int Live => marks.Count;

    public void Step(float dt)
    {
        for (int i = marks.Count - 1; i >= 0; i--)
        {
            Mark m = marks[i];
            m.age += dt;
            float lastsGlow = m.glowIn + m.seconds * GLOW_SHARE;
            float lasts = lastsGlow + m.seconds * FADE_SHARE;
            if (m.age >= lasts)
            {
                marks.RemoveAt(i);
                continue;
            }
            float glow = m.age < m.glowIn ? m.age / m.glowIn : Mathf.Max(0f, 1f - (m.age - m.glowIn) / (m.seconds * GLOW_SHARE));
            float soot = m.sootIn > 0f ? Mathf.Min(1f, m.age / m.sootIn) : 1f;  // no soot_in: it lands at once
            if (m.age > lastsGlow) soot *= 1f - (m.age - lastsGlow) / (m.seconds * FADE_SHARE);
            m.block.SetFloat("_ScorchMix", soot * m.soot);
            m.block.SetFloat("_ScorchGlow", glow * m.energy);
            Graphics.DrawMesh(mesh, Matrix4x4.identity, mat, 0, null, 0, m.block, ShadowCastingMode.Off, false);
        }
    }

    // FastNoiseLite's default (fractal simplex) is not in Unity; this fractal Perlin fills the same role.
    static float Noise(float x, float y, float shift)
    {
        float sum = 0f, amp = 1f, total = 0f, f = NOISE_FREQ;
        for (int i = 0; i < NOISE_OCTAVES; i++)
        {
            sum += (Mathf.PerlinNoise(x * f + NOISE_X + shift, y * f + NOISE_Y) * 2f - 1f) * amp;
            total += amp;
            amp *= 0.5f;
            f *= 2f;
        }
        return sum / total * 2f;
    }

    static float Smooth(float a, float b, float x)
    {
        float k = Mathf.Clamp01((x - a) / (b - a));
        return k * k * (3f - 2f * k);
    }

    // R soot shade, G cover, B the crack line. One per shape, crack count and half angle, as fx_decals.gd caches.
    Texture2D Texture(Shape shape, int cracks, float half)
    {
        var key = (shape, cracks, Mathf.RoundToInt(half * KEY_STEPS));
        if (drawn.TryGetValue(key, out Texture2D made)) return made;
        float shift = (int)shape - (int)Shape.Wedge;  // the wedge keeps the noise it always had
        var tex = new Texture2D(SIZE, SIZE, TextureFormat.RGBA32, false, true) { wrapMode = TextureWrapMode.Clamp };
        var px = new Color32[SIZE * SIZE];
        for (int y = 0; y < SIZE; y++)
            for (int x = 0; x < SIZE; x++)
                px[y * SIZE + x] = Pixel(shape, cracks, half, x, y, shift * SHAPE_SHIFT);
        tex.SetPixels32(px);
        tex.Apply(false, true);
        drawn[key] = tex;
        return tex;
    }

    static Color32 Pixel(Shape shape, int cracks, float half, int x, int y, float shift)
    {
        float px0 = (float)x / (SIZE - 1) * 2f - 1f, py0 = (float)y / (SIZE - 1) * 2f - 1f;
        float r = Mathf.Sqrt(px0 * px0 + py0 * py0);
        float ang = Mathf.Atan2(px0, -py0);  // 0 points at the top row (local -z)
        float n = Mathf.Clamp01(Noise(x, y, shift) * 0.5f + 0.5f);
        float edge = (n - 0.5f) * EDGE_RAG;
        float mask = 1f - Smooth(RIM_IN, 1f, r + edge);
        float line = Crack(ang, r, cracks, shift);
        if (shape == Shape.Wedge)
        {
            mask *= 1f - Smooth(half * SIDE_IN, half * SIDE_OUT, Mathf.Abs(ang) + edge * SIDE_RAG);
            mask *= Smooth(TIP_IN, TIP_OUT, r);
            line = Mathf.Max(line, Mathf.Exp(-ang * ang * STREAK_SHARP) * (1f - r) * STREAK);  // where the beam ran
        }
        line = Mathf.Clamp01(line) * mask;
        float shade = SHADE_BASE + SHADE_NOISE * n;
        float alpha = Mathf.Clamp01(mask * (COVER_BASE + COVER_NOISE * n) + line * 0.5f);
        // Shade runs to 1.4: stored halved, the shader doubles it.
        return new Color32((byte)(shade * 0.5f * BYTE), (byte)(alpha * BYTE), (byte)(line * BYTE), byte.MaxValue);
    }

    // fx_decals.gd _crack: jagged radial cracks, wide enough to read from the gameplay camera.
    static float Crack(float ang, float r, int cracks, float shift)
    {
        float laneF = ang * cracks / (Mathf.PI * 2f);
        float wander = Noise(r * WANDER_ALONG, Mathf.Floor(laneF) * WANDER_LANE, shift) * WANDER;
        float lane = Mathf.Repeat(laneF + wander * r, 1f);
        float toCrack = 0.5f - Mathf.Abs(lane - 0.5f);
        float width = WIDTH_BASE + WIDTH_OUT * r;
        return (1f - Smooth(width * WIDTH_SOFT, width, toCrack)) * Smooth(CRACK_FROM, CRACK_FULL, r);
    }

    public void Dispose()
    {
        UnityEngine.Object.Destroy(mesh);
        UnityEngine.Object.Destroy(mat);
        foreach (Texture2D t in drawn.Values) UnityEngine.Object.Destroy(t);
    }
}
