// The dish's genome and lightning in 3D (scenes/creation_genome.gd _blocks and its light): one block per cell, the
// helix in the picked genome's glow charring to its scales, the bolt white-hot, flickering violet; the blocks show
// as a prefix of each list (the helix settling from the middle out, the bolt reaching out step by step), and the
// dish's light grows and flickers with the takeover. What each block is comes from CreationGenome.
using System.Collections.Generic;
using Kaiju.Game;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;
using S = Kaiju.Sim;

public sealed class CreationGenomeView
{
    const int CUBE_VERTS = 24, CUBE_INDICES = 36, QUAD = 4;
    const byte GLOWS = 0, SOLID = 255;
    // creation_genome.gd _ready: the dish light's place over the agar and its range.
    static readonly Vector3 LIGHT_AT = new Vector3(0f, 0.45f, 0f);
    const float LIGHT_RANGE = 1.6f;

    static readonly Vector3Int[] WAYS = { Vector3Int.right, Vector3Int.left, Vector3Int.up, Vector3Int.down, new Vector3Int(0, 0, 1), new Vector3Int(0, 0, -1) };

    readonly Mesh helix, bolt;
    readonly Color32[] helixColours, boltColours;
    readonly Light light;
    readonly float candela;
    readonly List<Object> owned = new List<Object>();
    int helixShown = -1, boltShown = -1;

    public CreationGenomeView(Transform parent, CreationGenome g)
    {
        S.GDict cfg = CreationLab.Cfg();
        float voxel = (float)S.Num.F(cfg["voxel"]);
        Tuning tuning = SliceData.LoadTuning();
        float unit = SliceGame.ExposureUnit(tuning);
        Shader lit = Resources.Load<Shader>("Shaders/SliceLit");
        S.GDict b = cfg["bolt"];
        helix = Blocks("genome", g.Helix, voxel, (float)S.Num.F(cfg["glow"]), lit, parent);
        bolt = Blocks("bolt", g.Bolt, voxel, (float)S.Num.F(b["glow"]), lit, parent);
        helixColours = new Color32[helix.vertexCount];
        boltColours = new Color32[bolt.vertexCount];
        var go = new GameObject("dish_light");
        go.transform.SetParent(parent, false);
        go.transform.localPosition = LIGHT_AT;
        owned.Add(go);
        light = go.AddComponent<Light>();
        light.type = LightType.Point;
        light.shadows = LightShadows.None;
        light.lightUnit = LightUnit.Candela;
        go.AddComponent<HDAdditionalLightData>();
        light.color = Hex("bolt");
        light.range = LIGHT_RANGE;
        light.intensity = 0f;
        // Godot energy as HDRP candela, matched to Godot at the agar under it (tuning.json lab_bolt_match_m).
        candela = Mathf.PI * unit * tuning.LabMatch("bolt");
    }

    static Color Hex(string key)
    {
        S.GDict colors = CreationLab.Cfg()["colors"];
        return CreationPaint.Rgb(CreationPaint.Hex(S.Gd.Str(colors[key])));
    }

    // _blocks: a cube per cell (none merged, so any prefix can show), all hidden until Draw.
    Mesh Blocks(string name, List<S.Vector3i> cells, float voxel, float glow, Shader lit, Transform parent)
    {
        Mesh mesh = Cubes(name, cells, voxel);
        owned.Add(mesh);
        Material m = ArmyView.PlainMaterial(lit, voxel);
        m.SetFloat("_WindowGlow", glow);
        owned.Add(m);
        var go = new GameObject(name);
        go.transform.SetParent(parent, false);
        owned.Add(go);
        go.AddComponent<MeshFilter>().sharedMesh = mesh;
        MeshRenderer r = go.AddComponent<MeshRenderer>();
        r.sharedMaterial = m;
        r.shadowCastingMode = ShadowCastingMode.Off;
        return mesh;
    }

    static Mesh Cubes(string name, List<S.Vector3i> cells, float voxel)
    {
        var verts = new List<Vector3>(cells.Count * CUBE_VERTS);
        var normals = new List<Vector3>(cells.Count * CUBE_VERTS);
        var tris = new List<int>(cells.Count * CUBE_INDICES);
        float half = voxel * 0.5f;
        foreach (S.Vector3i c in cells)
        {
            // Godot's axes to Unity's: z mirrored.
            var centre = new Vector3((c.x + 0.5f) * voxel, (c.y + 0.5f) * voxel, -(c.z + 0.5f) * voxel);
            foreach (Vector3Int way in WAYS)
            {
                Vector3 n = way;
                Vector3 u = Mathf.Abs(n.y) > 0.5f ? Vector3.right : Vector3.up;
                Vector3 v = Vector3.Cross(u, n);
                int at = verts.Count;
                verts.Add(centre + (n - u - v) * half);
                verts.Add(centre + (n - u + v) * half);
                verts.Add(centre + (n + u + v) * half);
                verts.Add(centre + (n + u - v) * half);
                for (int k = 0; k < QUAD; k++) normals.Add(n);
                tris.AddRange(new[] { at, at + 1, at + 2, at, at + 2, at + 3 });
            }
        }
        var mesh = new Mesh { name = name, indexFormat = IndexFormat.UInt32 };
        mesh.MarkDynamic();
        mesh.SetVertices(verts);
        mesh.SetNormals(normals);
        var uv = new Vector2[verts.Count];
        for (int i = 0; i < uv.Length; i++) uv[i] = Vector2.right;
        mesh.uv = uv;
        mesh.colors32 = new Color32[verts.Count];
        mesh.SetIndices(tris, MeshTopology.Triangles, 0);
        mesh.SetSubMesh(0, new SubMeshDescriptor(0, 0), MeshUpdateFlags.DontRecalculateBounds);
        return mesh;
    }

    // Shows the dish as `g` stands this tick; `genome` is the picked titan's colour (Color.white before a pick).
    public void Draw(CreationGenome g, Color genome)
    {
        S.GDict cfg = CreationLab.Cfg();
        S.GDict b = cfg["bolt"];
        Color32 own = genome, hot = Hex("bolt"), dim = Hex("bolt_flicker"), juice = Hex("special_k");
        own.a = hot.a = dim.a = juice.a = GLOWS;
        float darken = 1f - (float)S.Num.F(b["char"]);
        // Color.darkened keeps the genome's own (opaque) alpha: the scales do not glow.
        Color32 scales = new Color(genome.r * darken, genome.g * darken, genome.b * darken, 1f);
        scales.a = SOLID;
        for (int i = 0; i < g.HelixState.Length; i++)
            Fill(helixColours, i, g.HelixState[i] == CreationGenome.HOT ? hot : g.HelixState[i] == CreationGenome.SCALES ? scales : own);
        for (int i = 0; i < g.BoltState.Length; i++)
            Fill(boltColours, i, g.BoltState[i] == CreationGenome.BOLT_DIM ? dim : g.BoltState[i] == CreationGenome.BOLT_JUICE ? juice : hot);
        helix.colors32 = helixColours;
        bolt.colors32 = boltColours;
        Show(helix, g.HelixShown, ref helixShown);
        Show(bolt, g.BoltShown, ref boltShown);
        light.intensity = (float)g.Light * candela;
    }

    static void Fill(Color32[] colours, int block, Color32 c)
    {
        for (int k = 0; k < CUBE_VERTS; k++) colours[block * CUBE_VERTS + k] = c;
    }

    static void Show(Mesh mesh, int blocks, ref int shown)
    {
        if (blocks == shown) return;
        shown = blocks;
        mesh.SetSubMesh(0, new SubMeshDescriptor(0, blocks * CUBE_INDICES), MeshUpdateFlags.DontRecalculateBounds);
    }

    public void Close()
    {
        foreach (Object o in owned)
            if (o != null) Object.Destroy(o);
        owned.Clear();
    }
}
