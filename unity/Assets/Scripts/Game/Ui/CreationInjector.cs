// The injector's blocks (scenes/creation_injector.gd _ready): its model split into the static post (its column
// carried on up, its foot clear of the cradle), the carriage (the boom and the head, the needle lengthened in
// steel) and the head's glass barrel, which fills as it draws (CreationLiquid). Cells relative to the pivot.
using System.Collections.Generic;
using Kaiju.Game;
using UnityEngine;
using S = Kaiju.Sim;

public static class CreationInjector
{
    // _lengthen: the needle's last cells are a single block, not a cross.
    const int POINT = 3;

    static readonly Vector3Int[] SIDES = { Vector3Int.left, Vector3Int.right, new Vector3Int(0, 0, -1), new Vector3Int(0, 0, 1) };

    static int I(S.Variant v) => (int)S.Num.I(v);

    // steel: the needle's colour (0xRRGGBB).
    public static void Split(CreationLab lab, ModelColors.Model model, float voxel, int steel,
        out Dictionary<Vector3Int, int> post, out Dictionary<Vector3Int, int> head, out Dictionary<Vector3Int, int> glass)
    {
        S.GDict cfg = CreationLab.Cfg()["injector"];
        S.GArray<S.Variant> pv = cfg["pivot"];
        var pivot = new Vector3Int(I(pv[0]), 0, I(pv[1]));
        int splitX = I(cfg["split_x"]), splitY = I(cfg["split_y"]);
        post = new Dictionary<Vector3Int, int>();
        head = new Dictionary<Vector3Int, int>();
        glass = new Dictionary<Vector3Int, int>();
        int[] raw = model.xyz.Raw;
        for (int i = 0; i < model.rgb.Length; i++)
        {
            var cell = new Vector3Int(raw[i * 3], raw[i * 3 + 1], raw[i * 3 + 2]);
            bool onCarriage = cell.x >= splitX || cell.y >= splitY;
            (!onCarriage ? post : InBarrel(cell, model.rgb[i], cfg) ? glass : head)[cell - pivot] = model.rgb[i];
        }
        Extend(post, I(cfg["profile_y"]), splitY, I(cfg["post_extend"]));
        Seat(post, lab, voxel, S.Num.F(cfg["post_seat"]));
        S.GArray<S.Variant> tc = cfg["tip"];
        Lengthen(head, new Vector3Int(I(tc[0]), I(tc[1]), I(tc[2])) - pivot, I(cfg["needle"]), steel);
    }

    // _in_barrel: the head's glass, the bright cells inside the barrel's ring and height.
    static bool InBarrel(Vector3Int cell, int rgb, S.GDict cfg)
    {
        S.GDict b = cfg["barrel"];
        S.GArray<S.Variant> c = b["centre"], ys = b["y"];
        CreationPaint.Hsv(rgb, out _, out _, out float value);
        if (cell.y < S.Num.I(ys[0]) || cell.y > S.Num.I(ys[1]) || value < S.Num.F(b["min_light"])) return false;
        return new Vector2(cell.x - (float)S.Num.F(c[0]), cell.z - (float)S.Num.F(c[1])).magnitude <= S.Num.F(b["radius"]);
    }

    // _extend_post: the post's cross-section at `profile` repeated from `from` for `cells` up, for the carriage to ride.
    static void Extend(Dictionary<Vector3Int, int> post, int profile, int from, int cells)
    {
        var ring = new List<KeyValuePair<Vector3Int, int>>();
        foreach (KeyValuePair<Vector3Int, int> cell in post)
            if (cell.Key.y == profile) ring.Add(cell);
        for (int y = from; y < from + cells; y++)
            foreach (KeyValuePair<Vector3Int, int> cell in ring)
                post[new Vector3Int(cell.Key.x, y, cell.Key.z)] = cell.Value;
    }

    // _seat: the foot's blocks inside the cradle's rim go.
    static void Seat(Dictionary<Vector3Int, int> post, CreationLab lab, float voxel, double seat)
    {
        double turn = lab.PostYaw();
        foreach (Vector3Int cell in new List<Vector3Int>(post.Keys))
        {
            CreationVec w = new CreationVec(cell.x, 0.0, cell.z).Turned(turn) * voxel;
            if ((lab.Post + w).FlatLength() < seat) post.Remove(cell);
        }
    }

    // _lengthen: a cross, then one block at the point.
    static void Lengthen(Dictionary<Vector3Int, int> head, Vector3Int tip, int needle, int steel)
    {
        for (int i = 1; i <= needle; i++)
        {
            Vector3Int at = tip - new Vector3Int(0, i, 0);
            head[at] = steel;
            if (i > needle - POINT) continue;
            foreach (Vector3Int d in SIDES) head[at + d] = steel;
        }
    }
}
