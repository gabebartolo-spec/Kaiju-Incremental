using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using S = Kaiju.Sim;

// The geometry of a bolt (scenes/bolt_shape.gd): a jagged channel by midpoint displacement, placed
// between two world points. Pure maths from a seeded stream. Godot axes.
public static class BoltShape
{
    const float SLIDE = 0.2f, PUSH_FALLOFF = 0.55f;

    // Points nearer the cone's apex than this are left alone; ends stay inside its edge; where a fan end
    // may land, and how far it may wander from its slot.
    const float APEX_FREE = 1.5f, EDGE_MARGIN = 0.97f, FAN_NEAR = 0.5f, FAN_FAR = 0.97f, SLOT_WANDER = 0.8f;

    static float R(S.RandomNumberGenerator rng) => (float)rng.Randf();

    // (right, up, t): sideways offsets are in lengths of the line, so one shape fits any span.
    public static List<Vector3> Channel(S.RandomNumberGenerator rng, int depth, float amp)
    {
        var pts = new List<Vector3> { Vector3.zero, new Vector3(0f, 0f, 1f) };
        float push = amp;
        for (int round = 0; round < depth; round++)
        {
            var next = new List<Vector3>(pts.Count * 2);
            for (int i = 0; i < pts.Count - 1; i++)
            {
                Vector3 a = pts[i], b = pts[i + 1];
                next.Add(a);
                float t = Mathf.Lerp(a.z, b.z, 0.5f + Mathf.Lerp(-SLIDE, SLIDE, R(rng)) * 0.5f);
                float angle = R(rng) * Mathf.PI * 2f;
                float kick = push * R(rng);
                next.Add(new Vector3((a.x + b.x) * 0.5f + Mathf.Cos(angle) * kick, (a.y + b.y) * 0.5f + Mathf.Sin(angle) * kick, t));
            }
            next.Add(pts[pts.Count - 1]);
            pts = next;
            push *= PUSH_FALLOFF;
        }
        return pts;
    }

    public static List<Vector3> Place(List<Vector3> shape, Vector3 a, Vector3 b)
    {
        Vector3 axis = b - a;
        float length = axis.magnitude;
        var line = new List<Vector3>(shape.Count);
        if (length < 0.001f)
        {
            line.Add(a);
            return line;
        }
        Vector3 dir = axis / length;
        Vector3 right = Vector3.Cross(dir, Vector3.up);
        if (right.magnitude < 0.05f) right = Vector3.Cross(dir, Vector3.right);
        right.Normalize();
        Vector3 up = Vector3.Cross(right, dir).normalized;
        foreach (Vector3 p in shape)
            line.Add(a + axis * p.z + (right * p.x + up * p.y) * length);
        return line;
    }

    public static Vector3 AtT(List<Vector3> line, float t)
    {
        if (line.Count < 2) return line.Count == 1 ? line[0] : Vector3.zero;
        float f = Mathf.Clamp01(t) * (line.Count - 1);
        int i = Mathf.Min(Mathf.FloorToInt(f), line.Count - 2);
        return Vector3.Lerp(line[i], line[i + 1], f - i);
    }

    // The first `share` of a line, its last point part-way along its segment.
    public static List<Vector3> Cut(List<Vector3> line, float share)
    {
        if (line.Count < 2 || share >= 1f) return line;
        float f = Mathf.Clamp01(share) * (line.Count - 1);
        int i = Mathf.Min(Mathf.FloorToInt(f), line.Count - 2);
        List<Vector3> o = line.GetRange(0, i + 1);
        o.Add(Vector3.Lerp(line[i], line[i + 1], f - i));
        return o;
    }

    // p pulled inside the cone; only the ground position moves.
    public static Vector3 ClampToCone(Vector3 p, BoltCone c)
    {
        var rel = new Vector2(p.x - c.origin.x, p.z - c.origin.z);
        float length = rel.magnitude;
        if (length < APEX_FREE) return p;
        // The throat sits behind the sim's snout on this croc: what is behind the apex is not yet in the cone.
        if (c.dir.x * rel.x + c.dir.z * rel.y <= 0f) return p;
        float half = c.half * EDGE_MARGIN;
        float ang = Mathf.Clamp(Mathf.Atan2(c.dir.x * rel.y - c.dir.z * rel.x, c.dir.x * rel.x + c.dir.z * rel.y), -half, half);
        float cos = Mathf.Cos(ang), sin = Mathf.Sin(ang);
        var o = new Vector2(c.dir.x * cos - c.dir.z * sin, c.dir.x * sin + c.dir.z * cos) * Mathf.Min(length, c.reach);
        return new Vector3(c.origin.x + o.x, p.y, c.origin.z + o.y);
    }

    // count ground points across the cone, one per equal slice of its width, shuffled.
    public static List<Vector3> FanEnds(S.RandomNumberGenerator rng, BoltCone c, int count, float spread = 1f, float near = FAN_NEAR)
    {
        float half = c.half * EDGE_MARGIN * spread;
        var o = new List<Vector3>(count);
        for (int i = 0; i < count; i++)
        {
            float slot = (i + 0.5f) / count * 2f - 1f;
            float wander = (float)rng.RandfRange(-1.0, 1.0) * SLOT_WANDER / count;
            float ang = Mathf.Clamp((slot + wander) * half, -half, half);
            float d = c.reach * (float)rng.RandfRange(near, FAN_FAR);
            float cos = Mathf.Cos(ang), sin = Mathf.Sin(ang);
            o.Add(new Vector3(c.origin.x + (c.dir.x * cos - c.dir.z * sin) * d, c.y, c.origin.z + (c.dir.x * sin + c.dir.z * cos) * d));
        }
        for (int i = count - 1; i > 0; i--)
        {
            int j = (int)rng.RandiRange(0, i);
            (o[i], o[j]) = (o[j], o[i]);
        }
        return o;
    }
}

// The sim's hit cone as bolt_shape.gd reads it. Godot axes.
public sealed class BoltCone
{
    public Vector3 origin, dir;
    public float reach, half, y;
}

// One set of bolt lines drawn as capsules (scenes/bolt_view.gd's arc surface): every segment its own quad.
public sealed class BoltView
{
    public const int QUEUE_BOLT = 3003;

    readonly Mesh mesh = new Mesh { name = "bolt" };
    readonly Material mat;
    readonly float tip;
    // Uniforms outside UnityPerMaterial leak between materials under the SRP Batcher; a block opts out.
    readonly MaterialPropertyBlock block = new MaterialPropertyBlock();
    readonly List<Vector3> verts = new List<Vector3>(), other = new List<Vector3>(), info = new List<Vector3>();
    readonly List<Vector2> ends = new List<Vector2>();
    readonly List<int> tris = new List<int>();
    bool shown;

    static Vector4 Hex(S.Variant v)
    {
        ColorUtility.TryParseHtmlString("#" + S.Gd.Str(v), out Color c);
        return c.linear;
    }

    static float F(S.GDict d, string key) => (float)(double)S.Num.F(d[key]);

    // width: full width in world units; minPx: the least width on screen at 1080p. cfg: tuning fx.bolt.
    public BoltView(Shader shader, float width, float minPx, float alpha, S.GDict cfg, int queue = QUEUE_BOLT, float soft = 0f)
    {
        S.GDict modes = cfg["halo_modes"];
        S.GDict row = modes[S.Gd.Str(cfg["halo_mode"])];
        tip = F(cfg, "branch_tip");
        mesh.MarkDynamic();
        mat = new Material(shader) { renderQueue = queue };
        block.SetVector("_BoltTint", Hex(row["inner"]));
        block.SetVector("_BoltFringe", Hex(row["fringe"]));
        block.SetVector("_BoltCore", Hex(row["core"]));
        block.SetFloat("_BoltWidth", width);
        block.SetFloat("_BoltLevel", 1f);
        block.SetFloat("_BoltBoost", F(cfg, "boost_core"));
        block.SetFloat("_BoltFringeBoost", F(cfg, "fringe_boost"));
        block.SetFloat("_BoltWhiteTo", F(cfg, "white_to"));
        block.SetFloat("_BoltTintTo", F(cfg, "tint_to"));
        block.SetFloat("_BoltWobble", F(cfg, "wobble"));
        block.SetFloat("_BoltWobbleHz", F(cfg, "wobble_hz"));
        block.SetFloat("_BoltMinPx", minPx);
        block.SetFloat("_BoltAlpha", alpha);
        block.SetFloat("_BoltSoft", soft);
    }

    public void Hide() => shown = false;

    public void SetLevel(float level) => block.SetFloat("_BoltLevel", level);

    // The signature's power brightens the bolt: the white-hot axis and the tinted fringe.
    public void SetPower(float core, float fringe)
    {
        block.SetFloat("_BoltBoost", core);
        block.SetFloat("_BoltFringeBoost", fringe);
    }

    // Each line in Godot axes, fading to its tip in width and brightness.
    public void Rebuild(List<List<Vector3>> lines) => Rebuild(lines, 1f, tip, 1f, tip);

    // taper: the width share at a line's start and end; bright: the brightness share there.
    public void Rebuild(List<List<Vector3>> lines, float taperA, float taperB, float brightA, float brightB)
    {
        verts.Clear();
        other.Clear();
        info.Clear();
        ends.Clear();
        tris.Clear();
        foreach (List<Vector3> line in lines)
        {
            if (line.Count < 2) continue;
            float last = line.Count - 1;
            for (int i = 0; i < line.Count - 1; i++)
            {
                float t0 = i / last, t1 = (i + 1) / last;
                float share = Mathf.Lerp(taperA, taperB, (t0 + t1) * 0.5f);
                int at = verts.Count;
                for (int end = 0; end < 2; end++)
                {
                    Vector3 here = line[i + end], there = line[i + 1 - end];
                    float t = end == 1 ? t1 : t0;
                    for (int side = -1; side <= 1; side += 2)
                    {
                        verts.Add(new Vector3(here.x, here.y, -here.z));
                        other.Add(new Vector3(there.x, there.y, -there.z));
                        info.Add(new Vector3(share, Mathf.Lerp(brightA, brightB, t), t));
                        ends.Add(new Vector2(end, side));
                    }
                }
                tris.Add(at); tris.Add(at + 1); tris.Add(at + 2);
                tris.Add(at + 1); tris.Add(at + 3); tris.Add(at + 2);
            }
        }
        shown = verts.Count > 0;
        mesh.Clear();
        if (!shown) return;
        mesh.SetVertices(verts);
        mesh.SetUVs(0, ends);
        mesh.SetUVs(1, other);
        mesh.SetUVs(2, info);
        mesh.SetTriangles(tris, 0, false);
        mesh.bounds = new Bounds(Vector3.zero, Vector3.one * 1e6f);
    }

    public void Draw()
    {
        if (shown) Graphics.DrawMesh(mesh, Matrix4x4.identity, mat, 0, null, 0, block, ShadowCastingMode.Off, false);
    }
}
