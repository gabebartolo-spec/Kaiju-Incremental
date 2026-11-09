using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

// The look of one kind of burst: scenes/fx_particle_mats.gd and blast_parts.gd, Godot axes.
public sealed class BurstStyle
{
    public bool glow;
    public Vector3 gravity;
    // Godot axes: where the spread points; zero is straight up.
    public Vector3 aim;
    public float vmin, vmax, spread, dmin, dmax, smin, smax, unit = 1f, heat = 1f, selfLit = 1f, clear = 1f;
    public readonly float[] sizeAt = new float[8], size = new float[8];
    public readonly Vector4[] colors = new Vector4[4];
    public Vector4 colorAt;
    public readonly Vector4[] shades = { Vector4.one, Vector4.one, Vector4.one };

    // Curve points as (life share, scale), the last repeated to the end of the array.
    public BurstStyle Size(params float[] points)
    {
        int n = points.Length / 2;
        for (int i = 0; i < size.Length; i++)
        {
            int k = Mathf.Min(i, n - 1);
            sizeAt[i] = points[k * 2];
            size[i] = points[k * 2 + 1];
        }
        return this;
    }

    // Gradient stops: up to four colours, the last repeated.
    public BurstStyle Colors(float[] at, params Color[] c)
    {
        var stops = new Vector4(1, 1, 1, 1);
        for (int i = 0; i < colors.Length; i++)
        {
            int k = Mathf.Min(i, c.Length - 1);
            colors[i] = c[k];
            stops[i] = at[k];
        }
        colorAt = stops;
        return this;
    }
}

// Every live one-shot: one draw a burst with its own pooled property block, and nothing simulated.
public sealed class Bursts : IDisposable
{
    const int QUAD_VERTS = 6, CUBE_VERTS = 36;
    // How far past its life a burst's bounds reach: quads and cubes are never bigger than this.
    const float BOUNDS_PAD = 20f;
    // scenes/fx.gd draws with the smoke's own queue, and glow over it (fire.json's ember and smoke queues).
    const int QUEUE_DUST = 3002, QUEUE_GLOW = 3001, QUEUE_RING = 3000;

    sealed class Live
    {
        public MaterialPropertyBlock block = new MaterialPropertyBlock();
        public Material mat;
        public Bounds bounds;
        public int verts, count;
        public float end;
    }

    readonly Material dustMat, glowMat, ringMat;
    readonly List<Live> live = new List<Live>();
    readonly Stack<Live> free = new Stack<Live>();

    static readonly int TIME = Shader.PropertyToID("_BurstTime");
    static readonly int ORIGIN = Shader.PropertyToID("_BOrigin"), BOX = Shader.PropertyToID("_BBox");
    static readonly int GRAVITY = Shader.PropertyToID("_BGravity"), VEL = Shader.PropertyToID("_BVel");
    static readonly int DAMP = Shader.PropertyToID("_BDamp"), SCALE = Shader.PropertyToID("_BScale");
    static readonly int CLEAR = Shader.PropertyToID("_BClear"), SIZE_T = Shader.PropertyToID("_BSizeT");
    static readonly int SIZE_V = Shader.PropertyToID("_BSizeV"), COLOR = Shader.PropertyToID("_BColor");
    static readonly int COLOR_AT = Shader.PropertyToID("_BColorAt"), SHADE = Shader.PropertyToID("_BShade");
    static readonly int R_CENTRE = Shader.PropertyToID("_RCentre"), R_TIME = Shader.PropertyToID("_RTime");
    static readonly int R_TINT = Shader.PropertyToID("_RTint");

    public int Count => live.Count;

    public Bursts(Shader shader)
    {
        dustMat = Make(shader, "BURST_DUST", QUEUE_DUST);
        glowMat = Make(shader, "BURST_GLOW", QUEUE_GLOW);
        ringMat = Make(shader, "BURST_RING", QUEUE_RING);
    }

    static Material Make(Shader shader, string keyword, int queue)
    {
        var mat = new Material(shader) { renderQueue = queue };
        mat.EnableKeyword(keyword);
        return mat;
    }

    Live Take() => free.Count > 0 ? free.Pop() : new Live();

    static Vector3 Flip(Vector3 v) => new Vector3(v.x, v.y, -v.z);

    // at and box in Godot axes; window: seconds over which its particles start (1 - explosiveness of life).
    public void Spawn(BurstStyle s, Vector3 at, Vector3 box, int count, float life, float window, float time, float seed)
    {
        if (count <= 0) return;
        Live b = Take();
        b.mat = s.glow ? glowMat : dustMat;
        b.verts = s.glow ? CUBE_VERTS : QUAD_VERTS;
        b.count = count;
        b.end = time + life + window;
        Vector3 o = Flip(at), g = Flip(s.gravity);
        MaterialPropertyBlock m = b.block;
        m.SetVector(ORIGIN, new Vector4(o.x, o.y, o.z, time));
        m.SetVector(BOX, new Vector4(box.x, box.y, box.z, life));
        m.SetVector(GRAVITY, new Vector4(g.x, g.y, g.z, window));
        m.SetVector(VEL, new Vector4(s.vmin, s.vmax, s.spread * Mathf.Deg2Rad, count));
        m.SetVector(DAMP, new Vector4(s.dmin, s.dmax, seed, s.heat));
        m.SetVector(SCALE, new Vector4(s.smin, s.smax, s.unit, s.selfLit));
        Vector3 aim = Flip(s.aim);
        m.SetVector(CLEAR, new Vector4(s.clear, aim.x, aim.y, aim.z));
        m.SetFloatArray(SIZE_T, s.sizeAt);
        m.SetFloatArray(SIZE_V, s.size);
        m.SetVectorArray(COLOR, s.colors);
        m.SetVector(COLOR_AT, s.colorAt);
        m.SetVectorArray(SHADE, s.shades);
        float reach = s.vmax * life + 0.5f * g.magnitude * life * life + s.smax * s.unit * 2f + BOUNDS_PAD;
        b.bounds = new Bounds(o, (box + Vector3.one * reach) * 2f);
        live.Add(b);
    }

    // scenes/fx.gd ring_of: a flat band on the street from `start` of its radius out. at in Godot axes.
    public void Ring(Vector3 at, float halfWidth, float start, float seconds, Color tint, float peak, float soft, float time)
    {
        Live b = Take();
        b.mat = ringMat;
        b.verts = QUAD_VERTS;
        b.count = 1;
        float lasts = seconds * (1f - start);
        b.end = time + lasts;
        Vector3 o = Flip(at);
        MaterialPropertyBlock m = b.block;
        m.SetVector(ORIGIN, new Vector4(o.x, o.y, o.z, time));
        m.SetVector(R_CENTRE, new Vector4(o.x, o.y, o.z, halfWidth));
        m.SetVector(R_TIME, new Vector4(start, lasts, 0, soft));
        m.SetVector(R_TINT, new Vector4(tint.r, tint.g, tint.b, peak));
        b.bounds = new Bounds(o, new Vector3(halfWidth * 2f, BOUNDS_PAD, halfWidth * 2f));
        live.Add(b);
    }

    public void Draw(float time)
    {
        Shader.SetGlobalFloat(TIME, time);
        for (int i = live.Count - 1; i >= 0; i--)
        {
            Live b = live[i];
            if (time > b.end)
            {
                live[i] = live[live.Count - 1];
                live.RemoveAt(live.Count - 1);
                free.Push(b);
                continue;
            }
            Graphics.DrawProcedural(b.mat, b.bounds, MeshTopology.Triangles, b.verts, b.count, null, b.block, ShadowCastingMode.Off, false, 0);
        }
    }

    public void Dispose()
    {
        UnityEngine.Object.Destroy(dustMat);
        UnityEngine.Object.Destroy(glowMat);
        UnityEngine.Object.Destroy(ringMat);
    }
}
