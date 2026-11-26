// The lab room round Kaiju Creation's bench (scenes/creation_room.gd; the director 2026-10-25: "change the black
// interior to a laboratory setting", "Dark high-tech lab"): a back wall and a left wall of steel panels with a
// rail, status LEDs, shelves of glowing sample jars, two cable runs on brackets and a conduit, wall screens with
// readouts and a cold strip light along the top, in blocks of room "voxel", and the strip's cold washes. Godot's
// cells (y up, z towards the camera); CreationLabView builds and lights them. Every size, place and colour:
// tuning "creation" "lab" "room".
using System;
using System.Collections.Generic;
using Kaiju.Game;
using UnityEngine;
using S = Kaiju.Sim;

public sealed class CreationRoom
{
    // creation_room.gd: a panel's tone steps darker by this per variant (of PANEL_TONES); the LED's place in its
    // panel (cells in from the right edge, up from the bottom); the shelf brackets' inset and their reach.
    const float PANEL_STEP = 0.06f;
    const int PANEL_TONES = 3, LED_IN = 3, LED_UP = 3, BRACKET_IN = 2, BRACKET_REACH = 6;
    // _shelves: the jars from JAR_FROM in, stopping JAR_TO short of the end; how far back they stand
    // (JAR_OUT plus up to depth - JAR_ROOM); the fill's salt and spread below the jar's top.
    const int JAR_FROM = 3, JAR_TO = 4, JAR_OUT = 2, JAR_ROOM = 6, FILL_SALT = 7, FILL_SPREAD = 3;
    // _screens: readout bars every BAR_ROW rows, in runs BAR_RUN cells long, one run in BAR_GAP left dark.
    const int BAR_ROW = 3, BAR_GAP = 3;
    const double BAR_RUN = 5.0;
    // _strip: the strip light's inset from each end of the back wall.
    const int STRIP_IN = 4, STRIP_OUT = 3;

    readonly S.GDict cfg;
    readonly double v;
    readonly Dictionary<Vector3Int, (int rgb, bool glow)> cells = new Dictionary<Vector3Int, (int, bool)>();

    public float Voxel => (float)v;

    CreationRoom()
    {
        cfg = CreationLab.Cfg()["room"];
        v = S.Num.F(cfg["voxel"]);
    }

    // creation_room.gd build: the room's cells (and which glow), in Godot's cells.
    public static CreationRoom Build()
    {
        var room = new CreationRoom();
        room.Walls();
        room.Shelves();
        room.Cables();
        room.Screens();
        room.Strip();
        return room;
    }

    // The room as one model, with the glowing cells marked.
    public ModelColors.Model Model(out bool[] glow)
    {
        var xyz = new S.PackedInt32Array();
        xyz.Resize(cells.Count * 3);
        int[] raw = xyz.Raw;
        var rgb = new int[cells.Count];
        glow = new bool[cells.Count];
        int i = 0;
        foreach (KeyValuePair<Vector3Int, (int rgb, bool glow)> cell in cells)
        {
            raw[i * 3] = cell.Key.x;
            raw[i * 3 + 1] = cell.Key.y;
            raw[i * 3 + 2] = cell.Key.z;
            rgb[i] = cell.Value.rgb;
            glow[i++] = cell.Value.glow;
        }
        return new ModelColors.Model { xyz = xyz, rgb = rgb };
    }

    // creation_room.gd _lights: where the strip's washes hang (Godot axes), their colour, energy and range.
    public List<CreationVec> Washes()
    {
        var at = new List<CreationVec>();
        foreach (S.Variant raw in (S.GArray<S.Variant>)cfg["washes"]) at.Add(CreationLab.Vec(raw));
        return at;
    }

    public Color WashColour => Rgb(C("strip"));
    public double WashEnergy => S.Num.F(cfg["wash"]);
    public float WashRange => (float)S.Num.F(cfg["wash_range"]);

    static Color Rgb(int c) => CreationPaint.Rgb(c);

    static int Hex(string s) => CreationPaint.Hex(s);

    int C(string key)
    {
        S.GDict colors = cfg["colors"];
        return Hex(S.Gd.Str(colors[key]));
    }

    // Godot's absi(hash(Vector2i(a, b))) % n.
    static int Pick(int a, int b, int n) => (int)(S.GodotHash.Vector2i(a, b) % (uint)n);

    static int PosMod(int a, int n) => ((a % n) + n) % n;

    int N(double metres) => (int)Math.Round(metres / v, MidpointRounding.AwayFromZero);

    int N(S.Variant metres) => N(S.Num.F(metres));

    Vector2Int Span(S.Variant raw)
    {
        S.GArray<S.Variant> pair = raw;
        return new Vector2Int(N(pair[0]), N(pair[1]));
    }

    S.GDict Row(string key) => cfg[key];

    // A cell of the back wall's face (x along it, y up, `out` cells towards the bench).
    Vector3Int Back(int x, int y, int outward) => new Vector3Int(x, y, N(Row("back")["z"]) + outward);

    // A cell of the left wall's face (z along it, y up, `out` cells towards the bench).
    Vector3Int Left(int z, int y, int outward) => new Vector3Int(N(Row("left")["x"]) + outward, y, z);

    void Put(Vector3Int cell, int rgb, bool glow = false) => cells[cell] = (rgb, glow);

    // Both walls: steel panels with dark seams, a rail at rail_y, and a status LED on some panels.
    void Walls()
    {
        int h = N(cfg["height"]);
        Vector2Int bx = Span(Row("back")["x"]), lz = Span(Row("left")["z"]);
        for (int x = bx.x; x <= bx.y; x++)
            for (int y = 0; y < h; y++) Panel(Back(x, y, 0), x, y, Back(x, y, 1));
        for (int z = lz.x; z <= lz.y; z++)
            for (int y = 0; y < h; y++) Panel(Left(z, y, 0), z, y, Left(z, y, 1));
    }

    // One wall cell at `cell` (u along the wall, y up); `front` is the cell before it (rail, LED).
    void Panel(Vector3Int cell, int u, int y, Vector3Int front)
    {
        S.GArray<S.Variant> size = cfg["panel"];
        int pw = N(size[0]), ph = N(size[1]), rail = N(cfg["rail_y"]);
        bool seam = PosMod(u, pw) == 0 || PosMod(y, ph) == 0;
        int which = Pick(Mathf.FloorToInt(u / (float)pw), Mathf.FloorToInt(y / (float)ph), PANEL_TONES);
        Put(cell, seam ? C("seam") : Darkened(C("panel"), PANEL_STEP * which));
        if (y == rail || y == rail + 1) Put(front, C("rail"));
        if (PosMod(u, pw) != pw - LED_IN || PosMod(y, ph) != LED_UP || which != 0) return;
        S.GArray<S.Variant> leds = cfg["leds"];
        Put(front, Hex(S.Gd.Str(leds[Pick(u, y, (int)leds.Size())])), true);
    }

    // Godot's Color.darkened: each channel times (1 - amount), back to 8 bits.
    static int Darkened(int c, float amount)
    {
        float k = 1f - amount;
        return CreationPaint.Pack(Mathf.RoundToInt(CreationPaint.R(c) * k), Mathf.RoundToInt(CreationPaint.G(c) * k), Mathf.RoundToInt(CreationPaint.B(c) * k));
    }

    // Shelves on the back wall, each a board on two brackets with a row of sample jars.
    void Shelves()
    {
        S.GDict s = cfg["shelves"];
        Vector2Int xs = Span(s["x"]);
        int depth = N(s["depth"]), every = N(s["jar_every"]);
        foreach (S.Variant raw in (S.GArray<S.Variant>)s["ys"])
        {
            int y = N(raw);
            for (int x = xs.x; x <= xs.y; x++)
                for (int d = 1; d <= depth; d++) Put(Back(x, y, d), C("shelf"));
            foreach (int x in new[] { xs.x + BRACKET_IN, xs.y - BRACKET_IN })
                for (int k = 1; k < Math.Min(depth, BRACKET_REACH); k++) Put(Back(x, y - k, depth - k), C("shelf"));
            for (int x = xs.x + JAR_FROM; x < xs.y - JAR_TO; x += every)
                Jar(x, y + 1, JAR_OUT + Pick(x, y, Math.Max(depth - JAR_ROOM, 1)));
        }
    }

    // A sample jar on a shelf at (x, y), `out` cells from the wall: a dark cap, glass edges, a glowing liquid.
    void Jar(int x, int y, int outward)
    {
        S.GDict s = cfg["shelves"];
        S.GArray<S.Variant> size = s["jar"];
        int w = (int)S.Num.I(size[0]), h = (int)S.Num.I(size[1]);
        S.GArray<S.Variant> tints = s["tints"];
        int liquid = Hex(S.Gd.Str(tints[Pick(y, x, (int)tints.Size())]));
        int fill = h - 2 - Pick(x, y + FILL_SALT, FILL_SPREAD);
        for (int dx = 0; dx < w; dx++)
            for (int dy = 0; dy < h; dy++)
                for (int dz = 0; dz < w; dz++)
                {
                    bool corner = (dx == 0 || dx == w - 1) && (dz == 0 || dz == w - 1);
                    bool wet = dy < fill && !corner && dy != h - 1;
                    int col = dy == h - 1 ? C("cap") : wet ? liquid : C("glass");
                    Put(Back(x + dx, y + dy, outward + dz), col, wet);
                }
    }

    // Two cable runs along the back wall on brackets, and a conduit up the left wall.
    void Cables()
    {
        S.GDict c = cfg["cables"];
        Vector2Int bx = Span(Row("back")["x"]);
        int every = N(c["bracket_every"]);
        foreach (S.Variant raw in (S.GArray<S.Variant>)c["ys"])
        {
            int y = N(raw);
            for (int x = bx.x; x <= bx.y; x++)
            {
                for (int dy = 0; dy < 2; dy++)
                    for (int o = 2; o <= 3; o++) Put(Back(x, y + dy, o), C("cable"));
                if (PosMod(x, every) != 0) continue;
                for (int dy = -1; dy < 3; dy++) Put(Back(x, y + dy, 1), C("rail"));
            }
        }
        int z = N(c["conduit_z"]), h = N(cfg["height"]);
        for (int y = 0; y < h; y++)
            for (int dz = 0; dz < 2; dz++)
                for (int o = 1; o <= 2; o++) Put(Left(z + dz, y, o), C("cable"));
    }

    // Wall screens on the left wall: a steel frame round dark glass with rows of lit readout bars.
    void Screens()
    {
        foreach (S.Variant raw in (S.GArray<S.Variant>)cfg["screens"])
        {
            S.GDict row = raw;
            Vector2Int zs = Span(row["z"]), ys = Span(row["y"]);
            for (int z = zs.x; z <= zs.y; z++)
                for (int y = ys.x; y <= ys.y; y++)
                {
                    bool frame = z == zs.x || z == zs.y || y == ys.x || y == ys.y;
                    bool lit = !frame && y % BAR_ROW == 0 && Pick(y, (int)Math.Floor(z / BAR_RUN), BAR_GAP) != 0;
                    Put(Left(z, y, 1), frame ? C("rail") : lit ? C("readout") : C("screen_glass"), lit);
                }
        }
    }

    // A cold strip light along the top of the back wall.
    void Strip()
    {
        Vector2Int bx = Span(Row("back")["x"]);
        int y = N(cfg["strip_y"]);
        for (int x = bx.x + STRIP_IN; x < bx.y - STRIP_OUT; x++)
            for (int dy = 0; dy < 2; dy++) Put(Back(x, y + dy, 1), C("strip"), true);
    }
}
