using System.Collections.Generic;
using UnityEngine;
using Kaiju.Game;
using S = Kaiju.Sim;

// scenes/arena_edge.gd: the row of small orange bollards just past the arena's edge (GameLogic/ArenaEdge.cs says
// where), clear of Unity's own kerb trees (CityTrees.KerbTrunks). One box mesh drawn instanced; no collider.
// Godot lights it Look.plain_detail_material(color, glow): EMISSION = tint * self_light. SliceLit's city surface
// lights a voxel albedo * _WindowGlow * (1 - vertex alpha), so the box's voxel is marked lit (alpha 0) and the
// material's _WindowGlow is the glow: the same 0.5 x colour (as StadiumView's ball_glow). Presentation only.
public sealed class ArenaEdgeView
{
    // Graphics.DrawMeshInstanced's most per call.
    const int BATCH = 1023;
    const int HEX = 16;

    readonly Mesh box;
    readonly Material material;
    readonly List<Matrix4x4[]> batches = new List<Matrix4x4[]>();
    readonly int count;

    public int Count => count;

    public ArenaEdgeView(S.RampageSim sim, IReadOnlyList<S.Vector2> trunks, Shader shader)
    {
        S.GDict cfg = S.Content.Tuning()["arena_edge"];
        S.GArray<S.Variant> size = cfg["size"];
        var scale = new Vector3((float)S.Num.F(size[0]), (float)S.Num.F(size[1]), (float)S.Num.F(size[0]));
        int rgb = System.Convert.ToInt32(S.Gd.Str(cfg["color"]), HEX);
        var model = new ModelColors.Model { xyz = new S.PackedInt32Array(), rgb = new[] { rgb } };
        model.xyz.Resize(3);
        // A unit cube about its centre, scaled per bollard to the box (Godot's BoxMesh of "size").
        box = ArmyView.Faces(model, 1f, new Vector3(0f, 0.5f, 0f), new[] { true });
        material = ArmyView.PlainMaterial(shader, 1f);
        material.SetFloat("_WindowGlow", (float)S.Num.F(cfg["glow"]));
        material.enableInstancing = true;
        List<S.Vector3> spots = ArenaEdge.Spots(sim, trunks);
        count = spots.Count;
        for (int from = 0; from < count; from += BATCH)
        {
            var batch = new Matrix4x4[Mathf.Min(BATCH, count - from)];
            for (int i = 0; i < batch.Length; i++)
            {
                S.Vector3 p = spots[from + i];
                // arena_edge.gd: posts[n] + Vector3(0, box.y * 0.5, 0); z mirrored into Unity's axes.
                var at = new Vector3((float)p.x, (float)p.y + scale.y * 0.5f, -(float)p.z);
                batch[i] = Matrix4x4.TRS(at, Quaternion.identity, scale);
            }
            batches.Add(batch);
        }
    }

    public void Draw()
    {
        foreach (Matrix4x4[] batch in batches) Graphics.DrawMeshInstanced(box, 0, material, batch, batch.Length);
    }
}
