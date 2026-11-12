using System.Collections.Generic;
using UnityEngine;
using S = Kaiju.Sim;

// scenes/voxel_person.gd: a voxel person built from cells. Here the rooftop rifleman only (pose AIM with a
// rifle), in the five ROOFTOP_OUTFITS. Each cell is shaded by VoxelJitter (salt 97 + outfit).
public static class PersonMesh
{
    // scenes/voxel_person.gd ROOFTOP_OUTFITS: shirt, pants, hair, skin.
    static readonly int[][] ROOFTOP_OUTFITS =
    {
        new[] { 0x8a3a32, 0x2f3440, 0x2a1f18, 0xe0b48e },
        new[] { 0xc9c2b0, 0x3b3a36, 0x1a1714, 0x8d5a3b },
        new[] { 0x4a5233, 0x3d4230, 0x39402a, 0xc58c5f },
        new[] { 0x3f5f7a, 0x57503f, 0x6a4a2a, 0xf0caa8 },
        new[] { 0x4a5233, 0x3d4230, 0x39402a, 0xe0b48e },
    };
    // scenes/voxel_person.gd _bake
    const int SHOE = 0x1a1a1a, GUN = 0x161616;
    // scenes/voxel_person.gd rifleman: v.salt = 97 + outfit.
    const int SALT = 97;

    static double Noise => S.Num.F(S.Content.Look().Get("color_noise", 0.0));

    public static int RooftopOutfits => ROOFTOP_OUTFITS.Length;

    // voxel_person.gd rifleman(outfit, voxel): feet on the origin, facing Godot -z (Faces mirrors it for Unity).
    public static Mesh Rifleman(int outfit, float voxel)
    {
        int[] o = ROOFTOP_OUTFITS[outfit];
        int shirt = o[0], pants = o[1], hair = o[2], skin = o[3];
        var cells = new Dictionary<Vector3Int, int>();
        var order = new List<Vector3Int>();
        // _body(AIM): the left foot one cell back, the right one forward (-z is forward).
        foreach (Vector2Int leg in new[] { new Vector2Int(-2, 1), new Vector2Int(1, -1) })
        {
            int x = leg.x, f = leg.y;
            Put(cells, order, x, 0, f, SHOE);
            Put(cells, order, x, 0, f - 1, SHOE);
            Put(cells, order, x, 1, f, pants);
            Put(cells, order, x, 2, 0, pants);
            Box(cells, order, x, 3, 0, x, 4, 0, pants);
        }
        Box(cells, order, -2, 5, -1, 1, 5, 0, pants);
        Box(cells, order, -2, 6, -1, 1, 8, 0, shirt);
        Box(cells, order, -1, 9, -1, 0, 9, -1, skin);
        Box(cells, order, -1, 9, 0, 0, 9, 0, hair);
        Box(cells, order, -1, 10, -1, 0, 10, 0, hair);
        foreach (Vector2Int side in new[] { new Vector2Int(-3, 1), new Vector2Int(2, -1) })
        {
            Put(cells, order, side.x, 8, -1, shirt);
            Put(cells, order, side.x + side.y, 8, -2, shirt);
            Put(cells, order, side.x + side.y * 2, 8, -3, skin);
        }
        Box(cells, order, -1, 8, -4, 0, 8, -4, GUN);
        Put(cells, order, -1, 9, -4, GUN);
        // rifleman: the barrel, and the receiver against the hands.
        Box(cells, order, -1, 8, -7, 0, 8, -4, GUN);
        Box(cells, order, -1, 9, -4, 0, 9, -3, GUN);

        var model = new ModelColors.Model { xyz = new S.PackedInt32Array(), rgb = new int[order.Count] };
        for (int i = 0; i < order.Count; i++)
        {
            Vector3Int c = order[i];
            model.xyz.Append(c.x);
            model.xyz.Append(c.y);
            model.xyz.Append(c.z);
            model.rgb[i] = VoxelJitter.Shade(cells[c], c.x, c.y, c.z, SALT + outfit, Noise);
        }
        // The body is symmetric about cell x = -0.5 and z = -0.5: centre it on the origin (_bake).
        Mesh mesh = ArmyView.Faces(model, voxel, new Vector3(-voxel * 0.5f, 0f, -voxel * 0.5f));
        mesh.name = "rifleman " + outfit;
        return mesh;
    }

    // A later put at the same cell replaces the earlier one, as VoxelBuilder.put does.
    static void Put(Dictionary<Vector3Int, int> cells, List<Vector3Int> order, int x, int y, int z, int rgb)
    {
        var c = new Vector3Int(x, y, z);
        if (!cells.ContainsKey(c)) order.Add(c);
        cells[c] = rgb;
    }

    static void Box(Dictionary<Vector3Int, int> cells, List<Vector3Int> order, int x0, int y0, int z0, int x1, int y1, int z1, int rgb)
    {
        for (int x = x0; x <= x1; x++)
            for (int y = y0; y <= y1; y++)
                for (int z = z0; z <= z1; z++)
                    Put(cells, order, x, y, z, rgb);
    }
}
