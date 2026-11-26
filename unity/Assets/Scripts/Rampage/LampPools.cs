using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using S = Kaiju.Sim;

// scenes/lamp_pools.gd: the warm pools street lamps lay on the road and pavement at night (director 2026-10-25: real
// night streets are lit in pools under the lamps). One flat disc per lamp spot (city_decor.gd _lamp_spots), drawn
// additively a little over the ground (LampPool.shader), carrying the ground's own grain. The look's
// "ground_lamp_pool" is the strength: 0 by day, and then no discs at all. Built once, as Godot's MultiMesh is, so a
// trampled lamp's pool stays. Godot axes in, Unity's drawn. Presentation only.
public sealed class LampPools : IDisposable
{
    // scenes/lamp_pools.gd RADIUS, LIFT; lamp_pool.gdshader's tint.
    const float RADIUS = 4f, LIFT = 0.13f;
    static readonly Color TINT = new Color(1f, 0.72f, 0.42f);
    const int SEED_MOD = 997, CORNERS = 4;
    static readonly int[] QUAD = { 0, 1, 2, 0, 2, 3 };
    static readonly Vector2[] CORNER = { new Vector2(-1f, -1f), new Vector2(1f, -1f), new Vector2(1f, 1f), new Vector2(-1f, 1f) };

    public int Count { get; }
    readonly Mesh mesh;
    readonly Material mat;

    public LampPools(IReadOnlyList<S.Vector2> spots, float exposureUnit, Transform parent)
    {
        S.GDict look = S.Content.Look();
        float strength = (float)S.Num.F(look.Get("ground_lamp_pool", 0.0));
        if (strength <= 0f || spots.Count == 0) return;
        Count = spots.Count;
        var verts = new Vector3[Count * CORNERS];
        var centres = new Vector2[Count * CORNERS];
        var tris = new int[Count * QUAD.Length];
        for (int i = 0; i < Count; i++)
        {
            var c = new Vector2((float)spots[i].x, (float)spots[i].y);
            for (int k = 0; k < CORNERS; k++)
            {
                Vector2 p = c + CORNER[k] * RADIUS;
                verts[i * CORNERS + k] = new Vector3(p.x, LIFT, -p.y);
                centres[i * CORNERS + k] = c;
            }
            for (int k = 0; k < QUAD.Length; k++) tris[i * QUAD.Length + k] = i * CORNERS + QUAD[k];
        }
        mesh = new Mesh { name = "lamp pools", indexFormat = IndexFormat.UInt32 };
        mesh.SetVertices(verts);
        mesh.SetUVs(0, centres);
        mesh.SetTriangles(tris, 0, true);
        mesh.UploadMeshData(true);

        mat = new Material(Resources.Load<Shader>("Shaders/LampPool"));
        Color tint = TINT.linear;  // a source_color uniform: Godot hands it to the shader linear
        mat.SetVector("_PoolTint", new Vector4(tint.r, tint.g, tint.b, strength));
        mat.SetVector("_PoolShape", new Vector4(RADIUS, exposureUnit, 0f, 0f));
        // ground_kit.gd apply_look: the ground's block and seed, so the pools' grain is the ground's.
        mat.SetFloat("g_block", (float)S.Num.F(look["ground_block"]));
        mat.SetFloat("g_seed", S.Num.I(S.Content.Section("city")["map_seed"]) % SEED_MOD);

        var go = new GameObject("lamp pools");
        go.transform.SetParent(parent, false);
        go.AddComponent<MeshFilter>().sharedMesh = mesh;
        var mr = go.AddComponent<MeshRenderer>();
        mr.sharedMaterial = mat;
        mr.shadowCastingMode = ShadowCastingMode.Off;
        mr.receiveShadows = false;
        Debug.Log($"lamp pools: {Count} at {strength}");
    }

    public void Dispose()
    {
        if (mesh != null) UnityEngine.Object.Destroy(mesh);
        if (mat != null) UnityEngine.Object.Destroy(mat);
    }
}
