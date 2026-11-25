using System.Collections.Generic;
using Kaiju.Game;
using UnityEngine;
using UnityEngine.Rendering;
using N = System.Numerics;
using S = Kaiju.Sim;

// A landmark's section bursts where it stands on its break frame (scenes/landmark_burst.gd, scenes/city_falls.gd
// start): its cells leave the fine view at once and make no falling piece; on that frame its samples (taken as
// Godot's carve job takes them) throw a spray of chunks in their own colours, a cloud covers the opening, a few real
// fragments go to the city's DebrisField and one dust puff marks it (GameLogic/LandmarkBurst.cs, checked against
// Godot by SimTests/LandmarkBurstCheck.cs). Everything runs on the game's clock, so it slows with the landmark slow-mo.
public sealed unsafe partial class CityDraw
{
    sealed class Burst
    {
        public LandmarkBurstPlan plan;
        public double t;
        // The chunks by colour: one instanced draw each.
        public List<(Mesh mesh, List<int> chunks)> groups;
        public Matrix4x4[] matrices;
    }

    // A colour's hex is read in base HEX (PoliceView's).
    const int HEX = 16;
    readonly List<Burst> bursts = new List<Burst>();
    readonly Dictionary<Color32, Mesh> chunkMeshes = new Dictionary<Color32, Mesh>();
    LandmarkBurstTuning burstTuning;
    Material burstMaterial;
    DebrisField cityDebris;

    // A landmark's fall_start: the section's cells at the break, sampled before they are cleared (a look's palette
    // colour, Godot axes). False for any other building's, which falls as a piece (FallStart).
    bool BurstStart(S.GDict e)
    {
        if (!e.Has("index")) return false;
        Site s = sites[(int)S.Num.I(e["building"])];
        if (s.b.landmark == "") return false;
        FineBody f = s.fine;
        var indexArray = (S.PackedInt32Array)e["index"];
        int n = (int)indexArray.Size();
        if (f == null || n == 0) return true;
        int[] raw = indexArray.Raw;
        var index = new List<int>(n);
        for (int k = 0; k < n; k++) index.Add(raw[k]);
        Unity.Collections.NativeArray<byte> palette = s.palette, looks = f.looks;
        List<BurstPart> parts = LandmarkBurst.Samples(index, f.w, f.d, new N.Vector3(f.origin.x, f.origin.y, f.origin.z), VOXEL,
            i => PaletteColor(palette, looks[i]));
        byte* drawn = f.Drawn, cells = f.Cells;
        for (int k = 0; k < n; k++)
        {
            int i = raw[k];
            drawn[i] = 0;
            cells[i] = 0;
            f.MarkCell(i);
        }
        if (parts.Count == 0) return true;
        if (burstMaterial == null) BurstSetup();
        LandmarkBurstPlan plan = LandmarkBurst.Plan(parts, new N.Vector2((float)(double)s.b.x, (float)(double)s.b.z), S.Num.I(e["id"]), burstTuning);
        foreach (BurstFragment frag in plan.fragments)
            cityDebris.Spawn(V(frag.pos), new Color(frag.color.X, frag.color.Y, frag.color.Z, frag.color.W), V(frag.away));
        if (crumbleFx != null)
        {
            crumbleFx.Dust(V(plan.dustAt), plan.dustSize);
            foreach (N.Vector3 at in plan.clouds)
                crumbleFx.LandmarkCloud(V(at), plan.cloudSize, (float)burstTuning.cloudLife, burstTuning.cloudAlpha);
        }
        bursts.Add(Spray(plan));
        return true;
    }

    void BurstSetup()
    {
        burstTuning = LandmarkBurstTuning.From(S.Content.Section("landmark_burst"));
        burstMaterial = ArmyView.PlainMaterial(shader, VOXEL);
        burstMaterial.enableInstancing = true;
        // city_view.gd: the city's own DebrisField, capped by the graphics preset (its own stream here: the director
        // accepted the fragments' scatter differing from Godot's shared city stream, 2026-11-25).
        DebrisField.Ground(root);
        cityDebris = new DebrisField(S.Seeds.Make("city_debris"), (int)GraphicsPreset.Cap("debris_pool"), 1f, true, burstMaterial, root, "city debris");
        HideStart();
    }

    // The chunks grouped by colour, each colour one glowing cube (vertex alpha 0: lit from within, as Godot's
    // unshaded chunk material), centred on its origin as Godot's BoxMesh.
    Burst Spray(LandmarkBurstPlan plan)
    {
        var byColor = new Dictionary<Color32, List<int>>();
        for (int i = 0; i < plan.chunks.Count; i++)
        {
            N.Vector4 c = plan.chunks[i].color;
            Color32 key = new Color(c.X, c.Y, c.Z, 1f);
            if (!byColor.TryGetValue(key, out List<int> list)) byColor[key] = list = new List<int>();
            list.Add(i);
        }
        var groups = new List<(Mesh, List<int>)>();
        foreach (KeyValuePair<Color32, List<int>> kv in byColor)
            groups.Add((ChunkMesh(kv.Key), kv.Value));
        return new Burst { plan = plan, groups = groups, matrices = new Matrix4x4[plan.chunks.Count] };
    }

    Mesh ChunkMesh(Color32 c)
    {
        if (chunkMeshes.TryGetValue(c, out Mesh mesh)) return mesh;
        var cell = new Dictionary<Vector3Int, int> { [Vector3Int.zero] = System.Convert.ToInt32(ColorUtility.ToHtmlStringRGB(c), HEX) };
        mesh = ArmyView.Faces(PropTiles.Model(cell), VOXEL, new Vector3(0f, 0.5f * VOXEL, 0f), new[] { true });
        chunkMeshes[c] = mesh;
        return mesh;
    }

    // landmark_burst.gd _process: the spray tumbles out and falls, shrinking away at the end of its life.
    void StepBursts(float dt)
    {
        cityDebris?.Tick(dt);
        for (int b = bursts.Count - 1; b >= 0; b--)
        {
            Burst burst = bursts[b];
            burst.t += dt;
            if (!LandmarkBurst.SprayAlive(burst.t, burstTuning))
            {
                bursts.RemoveAt(b);
                continue;
            }
            float shrink = LandmarkBurst.Shrink(burst.t, burstTuning);
            foreach ((Mesh mesh, List<int> chunks) in burst.groups)
            {
                int k = 0;
                foreach (int i in chunks)
                {
                    LandmarkBurst.SprayPose(burst.plan.chunks[i], i, burst.t, shrink, out N.Vector3 bx, out N.Vector3 by, out N.Vector3 bz, out N.Vector3 at);
                    burst.matrices[k++] = Mirrored(bx, by, bz, at);
                }
                Graphics.DrawMeshInstanced(mesh, 0, burstMaterial, burst.matrices, k, null, ShadowCastingMode.Off, false);
            }
        }
    }

    // A Godot transform seen through the z mirror: M' = F M F with F = diag(1, 1, -1).
    static Matrix4x4 Mirrored(N.Vector3 bx, N.Vector3 by, N.Vector3 bz, N.Vector3 at)
    {
        var m = new Matrix4x4(
            new Vector4(bx.X, bx.Y, -bx.Z, 0f),
            new Vector4(by.X, by.Y, -by.Z, 0f),
            new Vector4(-bz.X, -bz.Y, bz.Z, 0f),
            new Vector4(at.X, at.Y, -at.Z, 1f));
        return m;
    }

    static Vector3 V(N.Vector3 v) => new Vector3(v.X, v.Y, v.Z);

    // A site's palette entry `id` (RGBA bytes) as a colour; Godot's chunks and fragments are opaque.
    static N.Vector4 PaletteColor(Unity.Collections.NativeArray<byte> palette, byte id)
    {
        Color c = new Color32(palette[id * 4], palette[id * 4 + 1], palette[id * 4 + 2], byte.MaxValue);
        return new N.Vector4(c.r, c.g, c.b, 1f);
    }
}
