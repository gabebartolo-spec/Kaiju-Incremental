using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using S = Kaiju.Sim;

// Draws the wildlife (scenes/wildlife_view.gd): each flock one instanced draw of its bird mesh (Godot's MultiMesh, no
// shadow), the whale a scaled sphere, both with bird.gdshader (SliceLit SLICE_BIRD); the whale's spout is its
// CPUParticles3D burst (CityFx's Bursts). Wildlife poses everything in Godot axes; the shader flips z.
public sealed class WildlifeView
{
    const float BOUNDS = 8000f;
    const int POSE_FLOATS = 4, POSE_BYTES = 64;
    // Godot's SphereMesh defaults (radius 0.5, height 1): 64 segments round, 32 rings.
    const int SEGMENTS = 64, RINGS = 32;
    // Wing shape, as shares of the half span (wildlife_view.gd _bird_mesh).
    const float NOSE = 0.6f, TAIL = 0.4f, WAIST = 0.08f, ROOT_FRONT = 0.15f, ROOT_BACK = 0.2f, TIP_BACK = 0.25f;
    const float SPOUT_AHEAD = 0.3f, SPOUT_LOW = 0.7f, SPOUT_EXPLOSIVE = 0.6f;

    public readonly Wildlife wild;
    readonly CityFx fx;
    readonly List<(Mesh mesh, Material mat, GraphicsBuffer buffer, Vector4[] data)> flocks = new List<(Mesh, Material, GraphicsBuffer, Vector4[])>();
    readonly Mesh whaleMesh;
    readonly Material whaleMat;
    readonly GraphicsBuffer whaleBuffer;
    readonly Vector4[] whaleData = new Vector4[POSE_FLOATS];
    readonly BurstStyle spout;
    readonly S.GDict whale;
    int spouted;

    static float F(S.GDict d, string key) => (float)(double)S.Num.F(d[key]);

    static Color Linear(S.Variant hex)
    {
        ColorUtility.TryParseHtmlString("#" + S.Gd.Str(hex), out Color c);
        return c.linear;
    }

    public WildlifeView(S.RampageSim sim, Shader lit, CityFx fx)
    {
        this.fx = fx;
        wild = new Wildlife(sim);
        S.GDict cfg = S.Content.Section("wildlife");
        foreach (Wildlife.Flock flock in wild.flocks)
        {
            S.GDict look = cfg[flock.kind];
            Material mat = Material(lit, look["color"], 1f);
            mat.SetFloat("_FlapRate", F(look, "flap_rate"));
            mat.SetFloat("_FlapLift", F(cfg, "flap_lift"));
            int n = Mathf.Max(1, flock.birds.Count);
            var buffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, n, POSE_BYTES);
            mat.SetBuffer("_Birds", buffer);
            flocks.Add((BirdMesh(F(look, "span")), mat, buffer, new Vector4[n * POSE_FLOATS]));
        }
        whale = cfg["whale"];
        whaleMesh = Sphere();
        whaleMat = Material(lit, whale["color"], F(whale, "roughness"));
        whaleBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, 1, POSE_BYTES);
        whaleMat.SetBuffer("_Birds", whaleBuffer);
        spout = SpoutStyle(whale["spout"]);
    }

    static Material Material(Shader lit, S.Variant color, float roughness)
    {
        var m = new Material(lit) { enableInstancing = true };
        m.EnableKeyword("SLICE_BIRD");
        m.SetFloat("_CullMode", 0);
        m.SetFloat("_CullModeForward", 0);
        for (int i = 0; i < DeathView.GRAIN_KEYS.Length; i++) m.SetFloat(DeathView.GRAIN_KEYS[i], DeathView.GRAIN_VALUES[i]);
        m.SetColor("_BirdColor", Linear(color));
        m.SetFloat("_BirdRoughness", roughness);
        return m;
    }

    BurstStyle SpoutStyle(S.GDict s)
    {
        Color c = Linear(s["color"]);
        return new BurstStyle
        {
            gravity = new Vector3(0f, -F(s, "gravity"), 0f), vmin = F(s, "speed") * SPOUT_LOW, vmax = F(s, "speed"), spread = F(s, "spread"),
            smin = 1f, smax = 1f, unit = F(s, "size"), clear = 0f,
        }.Size(0f, 1f).Colors(new[] { 0f, 1f }, c, c);
    }

    // A bird `span` metres wingtip to wingtip (Godot axes): a slim body along -z and two swept wings; uv0.x the share
    // of the way out along the wing.
    static Mesh BirdMesh(float span)
    {
        float h = span * 0.5f;
        var v = new List<Vector3>();
        var uv = new List<Vector2>();
        foreach (float side in new[] { -1f, 1f })
        {
            v.Add(new Vector3(0f, 0f, -h * ROOT_FRONT));
            v.Add(new Vector3(0f, 0f, h * ROOT_BACK));
            v.Add(new Vector3(side * h, 0f, h * TIP_BACK));
            uv.Add(Vector2.zero);
            uv.Add(Vector2.zero);
            uv.Add(Vector2.right);
        }
        v.Add(new Vector3(0f, 0f, -h * NOSE));
        v.Add(new Vector3(h * WAIST, 0f, h * TAIL));
        v.Add(new Vector3(-h * WAIST, 0f, h * TAIL));
        for (int i = 0; i < 3; i++) uv.Add(Vector2.zero);
        var mesh = new Mesh();
        mesh.SetVertices(v);
        mesh.SetUVs(0, uv);
        var normals = new Vector3[v.Count];
        var tris = new int[v.Count];
        for (int i = 0; i < v.Count; i++)
        {
            normals[i] = Vector3.up;
            tris[i] = i;
        }
        mesh.normals = normals;
        mesh.triangles = tris;
        return mesh;
    }

    // Godot's SphereMesh (radius 0.5, height 1), its vertex and index order, Godot axes.
    static Mesh Sphere()
    {
        var v = new List<Vector3>();
        var normals = new List<Vector3>();
        var tris = new List<int>();
        int thisRow = 0, prevRow = 0, point = 0;
        for (int j = 0; j <= RINGS + 1; j++)
        {
            float a = Mathf.PI * j / (RINGS + 1), w = Mathf.Sin(a), y = 0.5f * Mathf.Cos(a);
            for (int i = 0; i <= SEGMENTS; i++)
            {
                float u = Mathf.PI * 2f * i / SEGMENTS, x = Mathf.Sin(u), z = Mathf.Cos(u);
                v.Add(new Vector3(x * 0.5f * w, y, z * 0.5f * w));
                normals.Add(new Vector3(x * w * 0.5f, 0.5f * (y / 0.5f), z * w * 0.5f).normalized);
                point++;
                if (i > 0 && j > 0)
                    tris.AddRange(new[] { prevRow + i - 1, prevRow + i, thisRow + i - 1, prevRow + i, thisRow + i, thisRow + i - 1 });
            }
            prevRow = thisRow;
            thisRow = point;
        }
        var mesh = new Mesh { indexFormat = IndexFormat.UInt32 };
        mesh.SetVertices(v);
        mesh.SetNormals(normals);
        mesh.SetUVs(0, new Vector2[v.Count]);
        mesh.SetTriangles(tris, 0);
        return mesh;
    }

    // rampage.gd _on_event: WildlifeView.feed (birds scatter, the whale dives). feet: the kaiju, Godot axes.
    public void OnEvent(S.GDict e, Vector3 feet) => wild.OnEvent(e, new S.Vector3(feet.x, feet.y, feet.z));

    public void Step(float dt)
    {
        wild.Step(dt);
        if (wild.spouts > spouted) Spout();
        var bounds = new Bounds(Vector3.zero, Vector3.one * BOUNDS);
        for (int f = 0; f < flocks.Count; f++)
        {
            List<Wildlife.Bird> birds = wild.flocks[f].birds;
            if (birds.Count == 0) continue;
            (Mesh mesh, Material mat, GraphicsBuffer buffer, Vector4[] data) = flocks[f];
            for (int i = 0; i < birds.Count; i++)
            {
                Wildlife.Bird b = birds[i];
                Pose(data, i, b.x, b.y, b.z, b.pos, new Vector4((float)b.phase, b.perched ? 0f : 1f, 0f, 0f));
            }
            buffer.SetData(data);
            Graphics.DrawMeshInstancedProcedural(mesh, 0, mat, bounds, birds.Count, null, ShadowCastingMode.Off, true);
        }
        if (!wild.whaleVisible) return;
        float yaw = wild.whaleYaw, c = Mathf.Cos(yaw), s = Mathf.Sin(yaw);
        var x = new S.Vector3(c * F(whale, "width"), 0f, -s * F(whale, "width"));
        var y = new S.Vector3(0f, F(whale, "hump") * 2f, 0f);
        var z = new S.Vector3(s * F(whale, "length"), 0f, c * F(whale, "length"));
        Pose(whaleData, 0, x, y, z, wild.whaleAt, Vector4.zero);
        whaleBuffer.SetData(whaleData);
        Graphics.DrawMeshInstancedProcedural(whaleMesh, 0, whaleMat, bounds, 1, null, ShadowCastingMode.On, true);
    }

    static void Pose(Vector4[] data, int i, S.Vector3 x, S.Vector3 y, S.Vector3 z, S.Vector3 at, Vector4 custom)
    {
        int o = i * POSE_FLOATS;
        data[o] = new Vector4((float)x.x, (float)x.y, (float)x.z, (float)at.x);
        data[o + 1] = new Vector4((float)y.x, (float)y.y, (float)y.z, (float)at.y);
        data[o + 2] = new Vector4((float)z.x, (float)z.y, (float)z.z, (float)at.z);
        data[o + 3] = custom;
    }

    // The spout's burst at its node: (0, hump, -length * 0.3) on the whale (Godot axes), world-space particles.
    void Spout()
    {
        spouted = wild.spouts;
        S.GDict s = whale["spout"];
        float yaw = wild.whaleYaw, back = -F(whale, "length") * SPOUT_AHEAD;
        var at = new Vector3((float)wild.whaleAt.x + Mathf.Sin(yaw) * back, (float)wild.whaleAt.y + F(whale, "hump"), (float)wild.whaleAt.z + Mathf.Cos(yaw) * back);
        float life = F(s, "life");
        fx.Spray(spout, at, Vector3.zero, (int)S.Num.I(s["amount"]), life, life * (1f - SPOUT_EXPLOSIVE));
    }

    // Counts for the load line.
    public string Built()
    {
        S.GArray<S.Variant> times = whale["surfacings"];
        return $"{wild.flocks[0].birds.Count} gulls, {wild.flocks[1].birds.Count} pigeons, whale {S.Num.I(times[0])}-{S.Num.I(times[1])} surfacings";
    }

    // What the run did to them, for the end line.
    public string Ended()
    {
        int up = 0;
        foreach (Wildlife.Bird b in wild.flocks[1].birds) up += b.perched ? 0 : 1;
        return $"{wild.scattered} birds scattered, {up} of {wild.flocks[1].birds.Count} pigeons off their roofs, whale surfaced {wild.surfacings} dived {wild.dives} spouted {wild.spouts} ({wild.whaleState})";
    }

    public void Dispose()
    {
        foreach ((Mesh mesh, Material mat, GraphicsBuffer buffer, Vector4[] _) in flocks)
        {
            Object.Destroy(mesh);
            Object.Destroy(mat);
            buffer.Release();
        }
        Object.Destroy(whaleMesh);
        Object.Destroy(whaleMat);
        whaleBuffer.Release();
    }
}
