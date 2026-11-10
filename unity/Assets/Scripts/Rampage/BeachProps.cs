using System.Collections.Generic;
using UnityEngine;
using S = Kaiju.Sim;

// The crowded sand's props (scenes/beach_props.gd plant, _umbrella, _lines and _net; city "harbour" "props", D-381):
// an umbrella with a lounger under it at every BeachLayout spot, and the volleyball courts' lines and nets.
public static class BeachProps
{
    static int Hex(S.GDict colors, string key) => System.Convert.ToInt32(S.Gd.Str(colors[key]), 16);

    static int Cells(S.Variant v) => (int)S.Num.I(v);

    // props: the umbrellas and nets, crushable; lines: the courts' flush lines, which nothing crushes.
    public static void Plant(S.GDict plan, S.GDict cfg, double view, PropTiles props, PropTiles lines)
    {
        S.GDict colors = cfg["colors"];
        float voxel = (float)S.Num.F(cfg["voxel"]);
        var umbrellas = new int[4];
        for (int paint = 0; paint < 4; paint++) umbrellas[paint] = props.AddShape(Umbrella(cfg, colors, paint));
        List<S.Vector2> spots = BeachLayout.Spots(plan, view);
        for (int n = 0; n < spots.Count; n++)
            props.Add(new Vector2((float)spots[n].x, (float)spots[n].y), umbrellas[n % 4]);
        S.GArray<S.Variant> court = cfg["court"];
        var half = new Vector2Int(Mathf.RoundToInt((float)S.Num.F(court[0]) * 0.5f / voxel), Mathf.RoundToInt((float)S.Num.F(court[1]) * 0.5f / voxel));
        int line = lines.AddShape(Lines(half, Hex(colors, "court_line")));
        int net = props.AddShape(Net(cfg, half, colors));
        foreach (S.Vector2 at in BeachLayout.Courts(plan))
        {
            if (System.Math.Abs(at.x) > view) continue;
            var p = new Vector2((float)at.x, (float)at.y);
            lines.Add(p, line);
            props.Add(p, net);
        }
    }

    // A pole, a two-layer canopy in one of four paints, and a lounger beside the pole under it.
    static Dictionary<Vector3Int, int> Umbrella(S.GDict cfg, S.GDict colors, int paint)
    {
        var cells = new Dictionary<Vector3Int, int>();
        S.GArray<S.Variant> umbrella = cfg["umbrella"];
        S.GArray<S.Variant> lounger = cfg["lounger"];
        int r = Cells(umbrella[0]), pole = Cells(umbrella[1]);
        int length = Cells(lounger[0]), width = Cells(lounger[1]);
        int back = length / 2;
        int bed = Hex(colors, "lounger"), canopy = Hex(colors, "umbrella" + paint);
        PropTiles.Box(cells, new Vector3Int(1, 1, -back), new Vector3Int(width, 1, length - 1 - back), bed);
        PropTiles.Box(cells, new Vector3Int(1, 2, length - 1 - back), new Vector3Int(width, 2, length - 1 - back), bed);
        PropTiles.Box(cells, new Vector3Int(0, 1, 0), new Vector3Int(0, pole, 0), Hex(colors, "pole"));
        PropTiles.Blob(cells, new Vector3(0, pole + 1, 0), new Vector3(r + 0.5f, 0.5f, r + 0.5f), canopy);
        PropTiles.Blob(cells, new Vector3(0, pole + 2, 0), new Vector3(r - 0.5f, 0.5f, r - 0.5f), canopy);
        return cells;
    }

    // A court's outline and centre line, one cell wide, lying in the sand.
    static Dictionary<Vector3Int, int> Lines(Vector2Int half, int color)
    {
        var cells = new Dictionary<Vector3Int, int>();
        for (int side = -1; side <= 1; side += 2)
            PropTiles.Box(cells, new Vector3Int(-half.x, 0, side * half.y), new Vector3Int(half.x, 0, side * half.y), color);
        for (int k = -1; k <= 1; k++)
            PropTiles.Box(cells, new Vector3Int(k * half.x, 0, -half.y), new Vector3Int(k * half.x, 0, half.y), color);
        return cells;
    }

    // The net across the court's middle between two posts.
    static Dictionary<Vector3Int, int> Net(S.GDict cfg, Vector2Int half, S.GDict colors)
    {
        var cells = new Dictionary<Vector3Int, int>();
        S.GArray<S.Variant> net = cfg["net"];
        int top = Cells(net[0]), depth = Cells(net[1]);
        PropTiles.Box(cells, new Vector3Int(0, top - depth + 1, -half.y), new Vector3Int(0, top, half.y), Hex(colors, "net"));
        for (int side = -1; side <= 1; side += 2)
            PropTiles.Box(cells, new Vector3Int(0, 1, side * (half.y + 1)), new Vector3Int(0, top, side * (half.y + 1)), Hex(colors, "post"));
        return cells;
    }
}
