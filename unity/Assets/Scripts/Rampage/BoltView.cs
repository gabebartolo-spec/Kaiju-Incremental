using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using S = Kaiju.Sim;

// The geometry of a bolt (scenes/bolt_shape.gd): a jagged channel by midpoint displacement, placed
// between two world points. Pure maths from a seeded stream. Godot axes.
public static class BoltShape
{
    const float SLIDE = 0.2f, PUSH_FALLOFF = 0.55f;

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
}

// One set of bolt lines drawn as capsules (scenes/bolt_view.gd's arc surface): every segment its own quad.
public sealed class BoltView
{
    const int QUEUE_BOLT = 3003;

    readonly Mesh mesh = new Mesh { name = "bolt" };
    readonly Material mat;
    readonly float tip;
    readonly List<Vector3> verts = new List<Vector3>(), other = new List<Vector3>(), info = new List<Vector3>();
    readonly List<Vector2> ends = new List<Vector2>();
    readonly List<int> tris = new List<int>();
    bool shown;

    static Color Hex(S.Variant v)
    {
        ColorUtility.TryParseHtmlString("#" + S.Gd.Str(v), out Color c);
        return c.linear;
    }

    static float F(S.GDict d, string key) => (float)(double)S.Num.F(d[key]);

    // width: full width in world units; minPx: the least width on screen at 1080p. cfg: tuning fx.bolt.
    public BoltView(Shader shader, float width, float minPx, float alpha, S.GDict cfg)
    {
        S.GDict modes = cfg["halo_modes"];
        S.GDict row = modes[S.Gd.Str(cfg["halo_mode"])];
        tip = F(cfg, "branch_tip");
        mesh.MarkDynamic();
        mat = new Material(shader) { renderQueue = QUEUE_BOLT };
        mat.SetColor("_BoltTint", Hex(row["inner"]));
        mat.SetColor("_BoltFringe", Hex(row["fringe"]));
        mat.SetColor("_BoltCore", Hex(row["core"]));
        mat.SetFloat("_BoltWidth", width);
        mat.SetFloat("_BoltLevel", 1f);
        mat.SetFloat("_BoltBoost", F(cfg, "boost_core"));
        mat.SetFloat("_BoltFringeBoost", F(cfg, "fringe_boost"));
        mat.SetFloat("_BoltWhiteTo", F(cfg, "white_to"));
        mat.SetFloat("_BoltTintTo", F(cfg, "tint_to"));
        mat.SetFloat("_BoltWobble", F(cfg, "wobble"));
        mat.SetFloat("_BoltWobbleHz", F(cfg, "wobble_hz"));
        mat.SetFloat("_BoltMinPx", minPx);
        mat.SetFloat("_BoltAlpha", alpha);
    }

    public void Hide() => shown = false;

    // Each line in Godot axes, fading to its tip in width and brightness.
    public void Rebuild(List<List<Vector3>> lines)
    {
        verts.Clear();
        other.Clear();
        info.Clear();
        ends.Clear();
        tris.Clear();
        foreach (List<Vector3> line in lines)
        {
            float last = line.Count - 1;
            for (int i = 0; i < line.Count - 1; i++)
            {
                float t0 = i / last, t1 = (i + 1) / last;
                float share = Mathf.Lerp(1f, tip, (t0 + t1) * 0.5f);
                int at = verts.Count;
                for (int end = 0; end < 2; end++)
                {
                    Vector3 here = line[i + end], there = line[i + 1 - end];
                    float t = end == 1 ? t1 : t0;
                    for (int side = -1; side <= 1; side += 2)
                    {
                        verts.Add(new Vector3(here.x, here.y, -here.z));
                        other.Add(new Vector3(there.x, there.y, -there.z));
                        info.Add(new Vector3(share, Mathf.Lerp(1f, tip, t), t));
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
        if (shown) Graphics.DrawMesh(mesh, Matrix4x4.identity, mat, 0, null, 0, null, ShadowCastingMode.Off, false);
    }
}
