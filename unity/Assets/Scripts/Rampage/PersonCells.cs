using System;
using System.Collections.Generic;
using UnityEngine;

// scenes/voxel_person.gd: a voxel person's cells, for the street's civilians and officers (StreetView) and the
// stadium's players and fans (StadiumView). An outfit is { shirt, pants, hair, skin } as 0xRRGGBB. Feet (or, seated,
// hips) on y = 0, facing Godot -z.
public static class PersonCells
{
    // voxel_person.gd _bake's shoe, and COP's belt and pistol.
    const int SHOE = 0x1a1a1a, BELT = 0x0e0e0e, GUN = 0x161616;
    // voxel_person.gd _body: each pose's stride (WALK_A, WALK_B, RUN_A, RUN_B, AIM).
    static readonly int[] STRIDE = { 1, -1, 2, -2, 1 };
    // voxel_person.gd: a running figure's hands, flung up over its head.
    const int HANDS_UP = 11;
    // voxel_person.gd dressed and seated: v.salt.
    public const int DRESSED_SALT = 53, SEATED_SALT = 61;
    const int HEX = 16;

    public static int[] Outfit(string shirt, string pants, string hair, string skin) =>
        new[] { Convert.ToInt32(shirt, HEX), Convert.ToInt32(pants, HEX), Convert.ToInt32(hair, HEX), Convert.ToInt32(skin, HEX) };

    // voxel_person.gd _bake: the mesh of `cells`, each a touch lighter or darker by `salt` (VoxelBuilder.salt), the
    // body centred on its origin.
    public static Mesh Mesh(Dictionary<Vector3Int, int> cells, int salt, float voxel, double noise)
    {
        var shaded = new Dictionary<Vector3Int, int>(cells.Count);
        foreach (KeyValuePair<Vector3Int, int> cell in cells)
            shaded[cell.Key] = VoxelJitter.Shade(cell.Value, cell.Key.x, cell.Key.y, cell.Key.z, salt, noise);
        return ArmyView.Faces(PropTiles.Model(shaded), voxel, new Vector3(-0.5f * voxel, 0f, -0.5f * voxel));
    }

    // voxel_person.gd _body: a figure standing in a pose.
    public static Dictionary<Vector3Int, int> Body(int[] o, int pose, bool cop)
    {
        int shirt = o[0], pants = o[1], hair = o[2], skin = o[3];
        var cells = new Dictionary<Vector3Int, int>();
        int stride = STRIDE[pose];
        for (int leg = 0; leg < 2; leg++)
        {
            int x = leg == 0 ? -2 : 1, f = leg == 0 ? stride : -stride;
            cells[new Vector3Int(x, 0, f)] = SHOE;
            cells[new Vector3Int(x, 0, f - 1)] = SHOE;
            cells[new Vector3Int(x, 1, f)] = pants;
            cells[new Vector3Int(x, 2, Math.Abs(f) > 1 ? Math.Sign(f) : 0)] = pants;
            PropTiles.Box(cells, new Vector3Int(x, 3, 0), new Vector3Int(x, 4, 0), pants);
        }
        PropTiles.Box(cells, new Vector3Int(-2, 5, -1), new Vector3Int(1, 5, 0), cop ? BELT : pants);
        PropTiles.Box(cells, new Vector3Int(-2, 6, -1), new Vector3Int(1, 8, 0), shirt);
        PropTiles.Box(cells, new Vector3Int(-1, 9, -1), new Vector3Int(0, 9, -1), skin);
        PropTiles.Box(cells, new Vector3Int(-1, 9, 0), new Vector3Int(0, 9, 0), hair);
        PropTiles.Box(cells, new Vector3Int(-1, 10, -1), new Vector3Int(0, 10, 0), hair);
        if (cop) PropTiles.Box(cells, new Vector3Int(-1, 10, -2), new Vector3Int(0, 10, -2), hair);  // cap brim
        if (pose == StreetPeople.AIM) Aim(cells, shirt, skin);
        else Arms(cells, pose, stride, shirt, skin);
        return cells;
    }

    // voxel_person.gd _body, Pose.AIM: both hands forward on a pistol.
    static void Aim(Dictionary<Vector3Int, int> cells, int shirt, int skin)
    {
        for (int side = 0; side < 2; side++)
        {
            int x = side == 0 ? -3 : 2, step = side == 0 ? 1 : -1;
            cells[new Vector3Int(x, 8, -1)] = shirt;
            cells[new Vector3Int(x + step, 8, -2)] = shirt;
            cells[new Vector3Int(x + step * 2, 8, -3)] = skin;
        }
        PropTiles.Box(cells, new Vector3Int(-1, 8, -4), new Vector3Int(0, 8, -4), GUN);
        cells[new Vector3Int(-1, 9, -4)] = GUN;
    }

    // voxel_person.gd _body: arms flung up in panic (running), else swinging against the legs.
    static void Arms(Dictionary<Vector3Int, int> cells, int pose, int stride, int shirt, int skin)
    {
        if (pose == StreetPeople.RUN_A || pose == StreetPeople.RUN_A + 1)
        {
            for (int side = 0; side < 2; side++)
            {
                int x = side == 0 ? -3 : 2;
                PropTiles.Box(cells, new Vector3Int(x, 8, 0), new Vector3Int(x, 10, 0), shirt);
                cells[new Vector3Int(x, HANDS_UP, 0)] = skin;
            }
            return;
        }
        for (int side = 0; side < 2; side++)
        {
            int ax = side == 0 ? -3 : 2, ay = side == 0 ? -Math.Sign(stride) : Math.Sign(stride);
            PropTiles.Box(cells, new Vector3Int(ax, 7, 0), new Vector3Int(ax, 8, 0), shirt);
            cells[new Vector3Int(ax, 6, ay)] = shirt;
            cells[new Vector3Int(ax, 5, ay)] = skin;
        }
    }

    // voxel_person.gd seated: a stadium spectator, hips on y = 0 and shins down the seat's front to the row below,
    // hands on the knees; 9 cells tall in all.
    public static Dictionary<Vector3Int, int> Seated(int[] o)
    {
        int shirt = o[0], pants = o[1], hair = o[2], skin = o[3];
        var cells = new Dictionary<Vector3Int, int>();
        for (int leg = 0; leg < 2; leg++)
        {
            int x = leg == 0 ? -2 : 1;
            PropTiles.Box(cells, new Vector3Int(x, -2, -3), new Vector3Int(x, -1, -3), pants);  // shins
            cells[new Vector3Int(x, -3, -3)] = SHOE;
            cells[new Vector3Int(x, -3, -4)] = SHOE;
        }
        PropTiles.Box(cells, new Vector3Int(-2, 0, -3), new Vector3Int(1, 0, 0), pants);  // thighs and seat
        PropTiles.Box(cells, new Vector3Int(-2, 1, -1), new Vector3Int(1, 3, 0), shirt);  // torso
        PropTiles.Box(cells, new Vector3Int(-1, 4, -1), new Vector3Int(0, 4, -1), skin);  // face
        PropTiles.Box(cells, new Vector3Int(-1, 4, 0), new Vector3Int(0, 4, 0), hair);
        PropTiles.Box(cells, new Vector3Int(-1, 5, -1), new Vector3Int(0, 5, 0), hair);
        for (int side = 0; side < 2; side++)
        {
            int x = side == 0 ? -3 : 2;
            PropTiles.Box(cells, new Vector3Int(x, 2, 0), new Vector3Int(x, 3, 0), shirt);  // upper arms
            cells[new Vector3Int(x, 1, -1)] = shirt;
            cells[new Vector3Int(x, 1, -2)] = skin;
        }
        return cells;
    }
}
