using System;
using System.Collections.Generic;
using S = Kaiju.Sim;

// One sport's markings and posts on the stadium's pitch (scenes/pitch_props.gd, D-078, data/sports.json), as cells
// at the buildings' scale (RES to a sim unit): lines one cell proud of the grass, posts one cell thick. Cell
// (0, 0, 0) sits on the grass at the pitch's centre; +x runs to the ends (the posts), z across.
// No UnityEngine here: unity/SimTests compiles this file (StadiumCheck). Presentation only.
public static class PitchProps
{
    public const int RES = 8;
    // What a cell is painted with: the sport's line, post_color and strip.
    public const int LINE = 0, POST = 1, STRIP = 2;
    // A rectangular field's share of the pitch's half size (it fits inside the oval stands).
    const double RECT = 0.82;
    const int MIN_STEPS = 24;
    const double PER_RADIUS = 4.0;
    static readonly int[] Ends = { -1, 1 };
    // Posts and lines, in cells (pitch_props.gd's own numbers).
    const int AFL_RING = 3, AFL_GOAL_Z = 3, AFL_GOAL = 13, AFL_BEHIND_Z = 8, AFL_BEHIND = 8;
    const int YARD_LINES = 10, UPRIGHT_BAR = 5, UPRIGHT_Z = 3, UPRIGHT_TOP = 14;
    const int GOAL_RING = 4, GOAL_BOX = 7, GOAL_BOX_Z = 9, GOAL_Z = 3, GOAL_BAR = 3;
    const int STRIP_X = 10, CREASE_X = 8, CREASE_Z = 2, STUMP_X = 9, STUMP_TOP = 3;

    // The field's half size in cells: the whole pitch for an oval sport, else the rectangle.
    public static S.Vector2i Field(S.GDict sport, S.Vector2 half)
    {
        double share = S.Gd.Str(sport["shape"]) == "oval" ? 1.0 : RECT;
        return new S.Vector2i(S.Gd.Roundi(half.x * RES * share), S.Gd.Roundi(half.y * RES * share));
    }

    public static Dictionary<S.Vector3i, int> Cells(S.GDict sport, S.Vector2 half)
    {
        var v = new Dictionary<S.Vector3i, int>();
        S.Vector2i f = Field(sport, half);
        int fx = (int)f.x, fz = (int)f.y;
        if (S.Gd.Str(sport["shape"]) == "oval") Ellipse(v, fx, fz);
        else
        {
            Rect(v, -fx, -fz, fx, fz);
            LineZ(v, 0, fz);  // halfway
        }
        switch (S.Gd.Str(sport["posts"]))
        {
            case "afl": AflPosts(v, fx); break;
            case "uprights": Uprights(v, fx, fz); break;
            case "goals": Goals(v, fx); break;
            case "stumps": Stumps(v); break;
        }
        return v;
    }

    static void AflPosts(Dictionary<S.Vector3i, int> v, int fx)
    {
        Ellipse(v, AFL_RING, AFL_RING);  // centre circle
        foreach (int end in Ends)
            foreach (int side in Ends)
            {
                Post(v, end * fx, side * AFL_GOAL_Z, AFL_GOAL);
                Post(v, end * fx, side * AFL_BEHIND_Z, AFL_BEHIND);
            }
    }

    static void Uprights(Dictionary<S.Vector3i, int> v, int fx, int fz)
    {
        for (int k = 1; k < YARD_LINES; k++)  // yard lines between the end zones
            LineZ(v, -fx + (int)S.Gd.Roundi(fx * 2.0 * k / YARD_LINES), fz);
        foreach (int end in Ends)
        {
            int x = end * (fx + 1);
            Post(v, x, 0, UPRIGHT_BAR);
            Box(v, x, UPRIGHT_BAR, -UPRIGHT_Z, x, UPRIGHT_BAR, UPRIGHT_Z, POST);  // crossbar
            foreach (int side in Ends)
                Box(v, x, UPRIGHT_BAR + 1, side * UPRIGHT_Z, x, UPRIGHT_TOP, side * UPRIGHT_Z, POST);
        }
    }

    static void Goals(Dictionary<S.Vector3i, int> v, int fx)
    {
        Ellipse(v, GOAL_RING, GOAL_RING);
        foreach (int end in Ends)
        {
            Rect(v, end * fx - end * GOAL_BOX, -GOAL_BOX_Z, end * fx, GOAL_BOX_Z);  // penalty box
            int x = end * (fx + 1);
            foreach (int side in Ends) Post(v, x, side * GOAL_Z, GOAL_BAR);
            Box(v, x, GOAL_BAR, -GOAL_Z, x, GOAL_BAR, GOAL_Z, POST);
        }
    }

    static void Stumps(Dictionary<S.Vector3i, int> v)
    {
        Box(v, -STRIP_X, 0, -1, STRIP_X, 0, 1, STRIP);  // the pitch strip
        foreach (int end in Ends)
        {
            LineZ(v, end * CREASE_X, CREASE_Z);  // crease
            for (int z = -1; z <= 1; z++) Box(v, end * STUMP_X, 1, z, end * STUMP_X, STUMP_TOP, z, POST);
        }
    }

    static void Ellipse(Dictionary<S.Vector3i, int> v, int rx, int rz)
    {
        int steps = Math.Max(MIN_STEPS, (int)S.Gd.Roundi((rx + rz) * PER_RADIUS));
        for (int k = 0; k < steps; k++)
        {
            double a = S.Gd.TAU * k / steps;
            v[new S.Vector3i(S.Gd.Roundi(rx * Math.Cos(a)), 0, S.Gd.Roundi(rz * Math.Sin(a)))] = LINE;
        }
    }

    static void Rect(Dictionary<S.Vector3i, int> v, int ax, int az, int bx, int bz)
    {
        int lx = Math.Min(ax, bx), lz = Math.Min(az, bz), hx = Math.Max(ax, bx), hz = Math.Max(az, bz);
        Box(v, lx, 0, lz, hx, 0, lz, LINE);
        Box(v, lx, 0, hz, hx, 0, hz, LINE);
        Box(v, lx, 0, lz, lx, 0, hz, LINE);
        Box(v, hx, 0, lz, hx, 0, hz, LINE);
    }

    static void LineZ(Dictionary<S.Vector3i, int> v, int x, int halfZ) => Box(v, x, 0, -halfZ, x, 0, halfZ, LINE);

    static void Post(Dictionary<S.Vector3i, int> v, int x, int z, int cells) => Box(v, x, 0, z, x, cells - 1, z, POST);

    static void Box(Dictionary<S.Vector3i, int> v, int ax, int ay, int az, int bx, int by, int bz, int kind)
    {
        for (int x = ax; x <= bx; x++)
            for (int y = ay; y <= by; y++)
                for (int z = az; z <= bz; z++) v[new S.Vector3i(x, y, z)] = kind;
    }
}
