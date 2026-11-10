using System;
using System.Collections.Generic;
using S = Kaiju.Sim;

// Where the beach's umbrellas and volleyball courts stand (scenes/beach_props.gd spots, courts and floor_y, line for
// line; city "harbour" "props"). No RNG and no UnityEngine: unity/SimTests compiles this file.
public static class BeachLayout
{
    // Each volleyball court's centre (x, z): at its x, court_shift landward of the sand's middle.
    public static List<S.Vector2> Courts(S.GDict plan)
    {
        var o = new List<S.Vector2>();
        if (!plan.Has("harbour")) return o;
        S.GDict b = plan["harbour"];
        S.GDict h = b["h"];
        S.GDict cfg = h["props"];
        S.GArray<S.Variant> xs = cfg["courts"];
        double shift = S.Num.F(cfg["court_shift"]);
        foreach (S.Variant v in xs)
        {
            double x = S.Num.F(v);
            S.PackedFloat32Array band = S.CityHarbour.Bands(h, x);
            o.Add(new S.Vector2(x, (band[0] + band[1]) * 0.5 + shift));
        }
        return o;
    }

    // Each umbrella's pole (x, z) within `view` of the centre (|x|): a grid every spacing along and across the sand,
    // kept court_clear off the courts.
    public static List<S.Vector2> Spots(S.GDict plan, double view)
    {
        var o = new List<S.Vector2>();
        if (!plan.Has("harbour")) return o;
        S.GDict b = plan["harbour"];
        S.GDict h = b["h"];
        S.GDict cfg = h["props"];
        S.Rect2 rect = b["rect"];
        double step = S.Num.F(cfg["spacing"]);
        List<S.Vector2> near = Courts(plan);
        S.GArray<S.Variant> clear = cfg["court_clear"];
        double keepX = S.Num.F(clear[0]), keepZ = S.Num.F(clear[1]);
        double fromWater = S.Num.F(cfg["from_water"]), fromEdge = S.Num.F(cfg["from_edge"]);
        double x = S.Num.F(b["beach_east"]) - S.Num.F(cfg["from_east"]);
        if (step <= 0.0) return o;
        while (x > rect.position.x)
        {
            S.PackedFloat32Array band = S.CityHarbour.Bands(h, x);
            double z = band[0] + fromWater;
            while (z < band[1] - fromEdge)
            {
                var at = new S.Vector2(x, z);
                bool busy = false;
                foreach (S.Vector2 c in near)
                    if (Math.Abs(at.x - c.x) < keepX && Math.Abs(at.y - c.y) < keepZ) busy = true;
                if (!busy && Math.Abs(x) <= view) o.Add(at);
                z += step;
            }
            x -= step;
        }
        return o;
    }

    // The props' height: their first cells lie in the sand, line_proud above it.
    public static double FloorY(S.GDict plan)
    {
        S.GDict b = plan["harbour"];
        S.GDict h = b["h"];
        S.GDict cfg = h["props"];
        return S.Num.F(h["sand_top"]) - S.Num.F(cfg["voxel"]) + S.Num.F(cfg["line_proud"]);
    }
}
