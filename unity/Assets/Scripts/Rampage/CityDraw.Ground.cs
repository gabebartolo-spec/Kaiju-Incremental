using System.Collections.Generic;
using Unity.Collections;
using UnityEngine;

// A landmark's pitch is also laid flat on the ground and drawn always (scenes/landmark_voxels.gd `ground`,
// scenes/building_view.gd _dress), so the ground under it keeps its colour once its cells are broken.
public sealed unsafe partial class CityDraw
{
    const int RED_SHIFT = 16, GREEN_SHIFT = 8;

    sealed partial class Site
    {
        // A landmark's pitch laid flat on the ground, made on the main thread with the shell.
        public Dictionary<Vector3Int, int> ground;
    }

    // The look each cell is drawn in, for the shell (Bake), the fine view (Promote) and the ground: its own,
    // or its tint, lit window or lit shop.
    void Tint(Site s, NativeArray<byte> looks)
    {
        for (int k = 0; k < s.tinted.Length; k++) looks[s.tinted[k]] = s.tintIds[k];
        foreach (int i in s.lit) looks[i] = LIT;
        foreach (int i in s.shopLit) looks[i] = SHOP_LIT;
    }

    // Every cell in the shape's "ground" colours (LandmarkCells' landmark_pitch) at the bottom row of its column, in
    // the colour it is drawn in. Pure data: runs on a bake worker.
    Dictionary<Vector3Int, int> GroundCells(Site s, byte[] mats, NativeArray<byte> looks, int w, int h, int d)
    {
        if (s.b.landmark == "" || !materialIds.TryGetValue("landmark_pitch", out int pitch)) return null;
        var cells = new Dictionary<Vector3Int, int>();
        for (int i = 0; i < w * h * d; i++)
        {
            if (mats[i] != pitch) continue;
            int id = looks[i];
            cells[new Vector3Int(i % w, 0, (i / w) % d)] = (s.palette[id * 4] << RED_SHIFT) | (s.palette[id * 4 + 1] << GREEN_SHIFT) | s.palette[id * 4 + 2];
        }
        return cells.Count == 0 ? null : cells;
    }

    // The ground cells' mesh at the landmark's base, in the building's own material (its colour noise), never cut.
    void MakeGround(Site s)
    {
        if (s.ground == null) return;
        Mesh mesh = ArmyView.Faces(PropTiles.Model(s.ground), VOXEL, Vector3.zero);
        mesh.name = "landmark ground";
        var go = new GameObject("landmark ground");
        go.transform.SetParent(root, false);
        go.transform.localPosition = new Vector3(s.origin.x, s.origin.y - (s.oy + 0.5f) * VOXEL, -s.origin.z);
        go.AddComponent<MeshFilter>().sharedMesh = mesh;
        go.AddComponent<MeshRenderer>().sharedMaterial = new Material(s.mat);
        s.ground = null;
    }
}
