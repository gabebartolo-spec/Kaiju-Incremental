using System.Collections.Generic;
using UnityEngine;
using S = Kaiju.Sim;

// Everything past the playable edge (scenes/city_skyline.gd): painted stand-in boxes on the plan's outer blocks,
// two freeways winding through the outskirts, a far shore across the bay with a lattice tower, and lamp heads
// down the outer streets (scenes/skyline_lamps.gd). One box per building, merged per tile; the far shore's boxes
// carry a code (uv0.x: style + 16 x code; 1 far, 2 + i the far box i's fall) that SliceSurface.hlsl hazes as
// the far air (FarHaze) and topples by SkylineRampage's falls. Presentation only. Godot axes in, mirrored at the mesh.
public sealed class CitySkyline
{
    const float TILE = 128f, QUAY_CLEAR = 17f, FREEWAY_CLEAR = 6f, DECK_Y = 7f, DECK_WIDTH = 5f;
    const float FREEWAY_STEP = 6f, FREEWAY_START = 9f, FREEWAY_OUTER = 40f, PARAPET = 2.3f;
    const float LATTICE_HEIGHT = 130f, SUPERTALL = 1.8f, CAP_KNEE = 0.6f, BEACON_ABOVE = 60f;
    const float STYLE_PLAIN = -1f, STYLE_BEACON = -2f;
    const float NEAR_GRAIN = 4f, FAR_GRAIN = 1.2f, GRAIN_UNIT = 32f, SEED_STEPS = 1024f;
    // scenes/city_skyline.gd DETAIL_REACH and _roof_clutter; scenes/skyline_roof_tank.gd CELL and colours.
    const float DETAIL_REACH = 200f, GEAR_LIGHTEN = 0.15f, GEAR_CELL = 0.125f, GEAR_DARKEN = 0.25f;
    const string GEAR_WOOD = "6a5040", GEAR_WHITE = "e6e8e4", GEAR_GLASS = "1b2538";
    // The uv0.x code (SliceSurface.hlsl FacadeCode): far, and the far box whose fall a box follows.
    const float CODE_STRIDE = 16f, CODE_FAR = 1f, CODE_FALLS = 2f, FALL_BOUNDS = 60f;
    // scenes/city_skyline.gd _lattice_tower's tip (a blinking box, never falls); skyline_lamps.gd's lamps.
    const float TIP_SEED = 0.3f, LAMP_START = 3f, LAMP_EVERY = 9f, LAMP_Y = 2.6f, LAMP_OUT = 0.5f;
    const float LAMP_ON_DECK = 2.2f, FREEWAY_LAMP_REACH = 1.5f, STYLE_GLOW = -3f, LAMP_ENERGY = 4f;
    const int PILLAR_EVERY = 3;
    static readonly Vector3 TIP = new Vector3(1f, 2f, 1f), LAMP_HEAD = new Vector3(0.35f, 0.2f, 0.35f);
    const string LAMP_COLOR = "ffd59a";

    sealed class Tile
    {
        public readonly List<Vector3> v = new List<Vector3>(), n = new List<Vector3>();
        public readonly List<Color32> c = new List<Color32>();
        public readonly List<Vector2> a = new List<Vector2>(), b = new List<Vector2>();
        public readonly List<int> t = new List<int>();
        public bool far;
    }

    readonly S.GDict cfg, plan;
    readonly Dictionary<Vector2Int, Tile> tiles = new Dictionary<Vector2Int, Tile>();
    readonly S.RandomNumberGenerator rng;
    readonly List<Color> styles = new List<Color>();
    readonly float coast, windowLit, half;
    readonly Color lot;
    readonly List<Vector3> lamps = new List<Vector3>();
    float grain = NEAR_GRAIN, code;

    public int Boxes { get; private set; }
    public int Lamps => lamps.Count;
    // Two float4 per far box (SliceSurface.hlsl _FarFalls), every one standing until SkylineRampage topples it.
    public ComputeBuffer Falls { get; private set; }
    public const int FALL_STRIDE = 2;
    // The far skyline's boxes in city_skyline.gd _far's order (SkylineRampage topples them), Godot axes.
    public readonly List<SkylineRampagePlan.Box> Far = new List<SkylineRampagePlan.Box>();
    // The far shore's quay edge (coast - bay_width), Godot z.
    public float Shore => coast - F(cfg, "bay_width");

    static float F(S.GDict d, string key) => (float)(double)S.Num.F(d[key]);
    static Color Hex(string s)
    {
        ColorUtility.TryParseHtmlString(s.StartsWith("#") ? s : "#" + s, out Color c);
        return c;
    }

    // city_view.gd: the skyline's stream is the same every run (Seeds.make("skyline", 0)).
    public CitySkyline(S.GDict city, Shader shader, Transform parent)
    {
        cfg = city;
        plan = S.CityGen.Map(city);
        rng = S.Seeds.Make("skyline", 0);
        coast = F(cfg, "coast_z");
        half = F(cfg, "half");
        S.GDict look = S.Content.Look();
        windowLit = F(look, "window_lit");
        lot = Hex(S.Gd.Str(look["lot"]));
        S.GDict render = S.Content.Section("render_opt");
        Shader.SetGlobalVector("_FacadeRoof", Hex(S.Gd.Str(look["roof"])).linear);
        Shader.SetGlobalVector("_FacadeWindow", Hex(S.Gd.Str(look["window"])).linear);
        Shader.SetGlobalFloat("_FacadeFilterStart", F(render, "facade_aa_start"));
        Shader.SetGlobalFloat("_FacadeFilterCells", F(render, "facade_aa_cells"));
        S.GArray<S.Variant> raw = look["styles"];
        foreach (S.Variant style in raw) styles.Add(Hex(S.Gd.Str(style)));
        OuterBlocks();
        Freeways();
        FarShore();
        code = 0f;
        OuterStreetLamps();
        Color head = Hex(LAMP_COLOR);
        foreach (Vector3 at in lamps) Box(at, LAMP_HEAD, Vector2.right, head, STYLE_GLOW, LAMP_ENERGY, 0f);
        Build(shader, parent);
        FarAir(look);
        Falls = new ComputeBuffer(Mathf.Max(1, Far.Count) * FALL_STRIDE, sizeof(float) * 4);
        var standing = new Vector4[Falls.count];
        for (int i = 1; i < standing.Length; i += FALL_STRIDE) standing[i] = new Vector4(-1f, 0f, 0f, 0f);
        Falls.SetData(standing);
        Shader.SetGlobalBuffer("_FarFalls", Falls);
    }

    // far_haze.gd apply_default (tuning city far_fog): the far skyline in the same air as the bay, its own built haze
    // (city far_haze) kept at own_haze, and the height fog at its foot; off, its built haze alone.
    void FarAir(S.GDict look)
    {
        S.GDict fog = cfg["far_fog"];
        bool on = fog["on"];
        float haze = F(cfg, "far_haze") * (on ? F(fog, "own_haze") : 1f);
        Shader.SetGlobalVector("_FarHaze", new Vector4(haze, F(fog, "start"), on ? F(fog, "base") : 0f, F(fog, "base_height")));
        Shader.SetGlobalVector("_FarHazeColor", Hex(S.Gd.Str(look["fog_color"])).linear);
    }

    public void Dispose() => Falls?.Release();

    float Rand(float a, float b) => (float)(double)rng.RandfRange(a, b);
    float Lit() => windowLit * Rand(0.6f, 1.4f);
    float InlandX(float side, float z) => side * (half + 62f + Mathf.Sin(z / 53f + side) * 22f + Mathf.Sin(z / 23f) * 6f);
    bool UnderFreeway(float x, float z) => Mathf.Abs(x - InlandX(-1f, z)) < FREEWAY_CLEAR || Mathf.Abs(x - InlandX(1f, z)) < FREEWAY_CLEAR;

    void OuterBlocks()
    {
        S.GDict outer = cfg.Duplicate();
        outer["cores"] = cfg["outer_cores"];
        S.GArray<S.GDict> blocks = plan["blocks"];
        foreach (S.GDict block in blocks)
        {
            if (S.Gd.Str(block["use"]) != "outer") continue;
            S.Rect2 rect = block["rect"];
            if ((float)(double)rect.position.y < coast + QUAY_CLEAR) continue;  // the waterfront: the quay
            float scale = Rand(0.5f, 1.4f);
            foreach (S.GDict l in S.CityLots.FillBlock(rng, plan, block, outer, scale))
            {
                float x = F(l, "x"), z = F(l, "z"), h = F(l, "h"), w = F(l, "w"), d = F(l, "d");
                if (UnderFreeway(x, z) || S.EmergeReach.LotInView(plan, cfg, l)) continue;
                int style = (int)S.Num.I(l["style"]);
                int pick = Mathf.Abs(style + Mathf.RoundToInt(x * 3f + z)) % styles.Count;
                Facade(new Vector3(x, h * 0.5f, z), new Vector3(w, h, d), styles[pick], style % 4, Lit(), h > 18f);
                if (new Vector2(x, z).magnitude < DETAIL_REACH) RoofClutter(new Vector3(x, h, z), new Vector2(w, d));
            }
        }
    }

    // city_skyline.gd _roof_clutter: up to two pieces of gear on a near roof, so the roofs the camera looks down on
    // are not bare: a stair hut first, then a water tower or a heater (scenes/skyline_roof_tank.gd).
    void RoofClutter(Vector3 top, Vector2 size)
    {
        Color gear = Color.Lerp(Hex(S.Gd.Str(S.Content.Look()["roof"])), Color.white, GEAR_LIGHTEN);
        int count = (int)rng.RandiRange(0, 2);
        for (int n = 0; n < count; n++)
        {
            float sx = Rand(0.6f, 1.4f), sy = Rand(0.4f, 1f), sz = Rand(0.6f, 1.4f);
            float ox = Rand(-0.5f, 0.5f) * Mathf.Max(0f, size.x - sx - 0.6f);
            float oz = Rand(-0.5f, 0.5f) * Mathf.Max(0f, size.y - sz - 0.6f);
            if (n == 0)
            {
                Plain(top + new Vector3(ox, sy * 0.5f, oz), new Vector3(sx, sy, sz), Vector2.right, gear);
                continue;
            }
            Vector3 at = top + new Vector3(ox, 0f, oz);
            if (S.RoofTank.WoodenAt(at.x, at.z))
            {
                Color wood = Hex(GEAR_WOOD), dark = Color.Lerp(wood, Color.black, GEAR_DARKEN);
                GearPart(at, new Vector3(5, 3, 5), 0, gear);
                GearPart(at, new Vector3(5, 6, 5), 3, wood);
                GearPart(at, new Vector3(7, 1, 7), 9, dark);
                GearPart(at, new Vector3(3, 2, 3), 10, dark);
                continue;
            }
            GearPart(at, new Vector3(9, 2, 7), 0, gear);
            GearPart(at, new Vector3(9, 2, 7), 2, Hex(GEAR_GLASS));
            GearPart(at + new Vector3(0f, 0f, 3 * GEAR_CELL), new Vector3(7, 2, 2), 4, Hex(GEAR_WHITE));
        }
    }

    // skyline_roof_tank.gd _part: a box `cells` big standing `up` cells above the roof.
    void GearPart(Vector3 at, Vector3 cells, int up, Color color)
    {
        Vector3 s = cells * GEAR_CELL;
        Plain(at + new Vector3(0f, up * GEAR_CELL + s.y * 0.5f, 0f), s, Vector2.right, color);
    }

    void Freeways()
    {
        float outer = F(cfg, "outer_half") + FREEWAY_OUTER;
        S.Rect2 front = S.CityHarbour.RectOf(cfg);
        float from = front.HasArea() ? (float)(double)front.end.y : coast + FREEWAY_START;
        Color deck = lot * 0.9f;
        Color rail = Color.Lerp(deck, Color.white, 0.1f);
        foreach (float side in new[] { -1f, 1f })
        {
            int i = 0;
            for (float z = from; z + FREEWAY_STEP <= outer; z += FREEWAY_STEP, i++)
            {
                var a = new Vector2(InlandX(side, z), z);
                var b = new Vector2(InlandX(side, z + FREEWAY_STEP), z + FREEWAY_STEP);
                Vector2 mid = (a + b) * 0.5f, dir = (b - a).normalized;
                float length = (b - a).magnitude + 0.2f;
                Plain(new Vector3(mid.x, DECK_Y, mid.y), new Vector3(length, 0.7f, DECK_WIDTH), dir, deck);
                var off = new Vector2(-dir.y, dir.x) * PARAPET;
                Plain(new Vector3(mid.x + off.x, DECK_Y + 0.65f, mid.y + off.y), new Vector3(length, 0.6f, 0.3f), dir, rail);
                Plain(new Vector3(mid.x - off.x, DECK_Y + 0.65f, mid.y - off.y), new Vector3(length, 0.6f, 0.3f), dir, rail);
                if (i % PILLAR_EVERY != 0) continue;  // a pillar every 18 units, and a lamp on it
                Plain(new Vector3(a.x, DECK_Y * 0.5f, a.y), new Vector3(1.2f, DECK_Y, 1.6f), Vector2.right, deck);
                if (a.magnitude < DETAIL_REACH * FREEWAY_LAMP_REACH) lamps.Add(new Vector3(a.x, DECK_Y + LAMP_ON_DECK, a.y));
            }
        }
    }

    float Capped(float tall)
    {
        float cap = F(cfg, "far_tower_cap"), knee = cap * CAP_KNEE;
        if (cap <= 0f || tall <= knee) return tall;
        return knee + (cap - knee) * (float)System.Math.Tanh((tall - knee) / (cap - knee));
    }

    void FarShore()
    {
        grain = FAR_GRAIN;
        code = CODE_FAR;
        float shore = Shore;
        Plain(new Vector3(0f, -0.2f, shore - 200f), new Vector3(2400f, 2f, 400f), Vector2.right, lot * 0.8f);
        for (float x = -700f; x < 700f; x += Rand(14f, 26f))
        {
            float downtown = Mathf.Max(0f, 1f - Mathf.Abs(x - 60f) / 260f);
            int rows = 2 + Mathf.RoundToInt(downtown * 4f);
            for (int r = 0; r < rows; r++)
            {
                float w = Rand(8f, 22f), d = Rand(8f, 20f);
                float tall = Mathf.Max(Mathf.Lerp(8f, 70f, Mathf.Pow(downtown, 1.5f)) * Rand(0.5f, 1.4f), 6f);
                if (Rand(0f, 1f) < downtown * 0.15f) tall *= SUPERTALL;
                tall = Capped(tall);
                var at = new Vector3(x + Rand(-4f, 4f), tall * 0.5f, shore - 12f - r * 26f - d * 0.5f);
                int style = (int)rng.RandiRange(0, 3);
                Color tint = styles[style % styles.Count];
                int index = Far.Count;
                code = CODE_FALLS + index;
                FarBox(at, new Vector3(w, tall, d), -1);
                Facade(at, new Vector3(w, tall, d), tint * 0.85f, style, Lit() * 0.7f, tall > BEACON_ABOVE);
                if (tall <= 90f) continue;
                // A stepped crown on the supertalls, New York style; it falls with its tower.
                var crownAt = at + new Vector3(0f, tall * 0.56f, 0f);
                var crown = new Vector3(w * 0.6f, tall * 0.12f, d * 0.6f);
                FarBox(crownAt, crown, index);
                Facade(crownAt, crown, tint, style, Lit(), true);
            }
        }
        code = CODE_FAR;
        Lattice(new Vector3(-160f, 0f, shore - 70f));
    }

    void FarBox(Vector3 at, Vector3 size, int crownOf) => Far.Add(new SkylineRampagePlan.Box
    {
        at = new S.Vector3(at.x, at.y, at.z), size = new S.Vector3(size.x, size.y, size.z), crownOf = crownOf,
    });

    // skyline_lamps.gd outer_streets: a lamp every 9 units down each outer street within DETAIL_REACH (inside the
    // playable city the decor puts real ones), none on the waterfront.
    void OuterStreetLamps()
    {
        S.GArray<S.Vector2> nodes = plan["nodes"];
        S.GArray<S.GDict> streets = plan["streets"];
        foreach (S.GDict street in streets)
        {
            if (S.Gd.Str(street["kind"]) == S.CityGen.ALLEY) continue;
            S.Vector2 ga = nodes[(int)S.Num.I(street["from"])], gb = nodes[(int)S.Num.I(street["to"])];
            var a = new Vector2((float)ga.x, (float)ga.y);
            var b = new Vector2((float)gb.x, (float)gb.y);
            if (Mathf.Max(Mathf.Abs(a.x), Mathf.Abs(a.y)) <= half + 1f && Mathf.Max(Mathf.Abs(b.x), Mathf.Abs(b.y)) <= half + 1f) continue;
            if (Mathf.Min(a.y, b.y) < coast) continue;
            Vector2 dir = (b - a).normalized;
            Vector2 side = new Vector2(-dir.y, dir.x) * (F(street, "width") * 0.5f + LAMP_OUT);
            for (float t = LAMP_START; t < Vector2.Distance(a, b); t += LAMP_EVERY)
            {
                Vector2 p = a + dir * t + side;
                if (p.magnitude < DETAIL_REACH) lamps.Add(new Vector3(p.x, LAMP_Y, p.y));
            }
        }
    }

    // A red-and-white lattice broadcast tower (a Tokyo Tower silhouette).
    void Lattice(Vector3 foot)
    {
        Color red = Hex("b0402c"), white = Hex("c8c4b8");
        float height = Capped(LATTICE_HEIGHT);
        const int LEVELS = 26;
        for (int i = 0; i < LEVELS; i++)
        {
            float t = (float)i / LEVELS, w = Mathf.Lerp(16f, 1.2f, Mathf.Pow(t, 0.7f)), y = t * height;
            Color color = (i >> 1) % 2 == 0 ? red : white;
            foreach (float sx in new[] { -1f, 1f })
            {
                foreach (float sz in new[] { -1f, 1f })
                    Plain(foot + new Vector3(w * sx, y, w * sz), new Vector3(0.9f, height / LEVELS + 0.2f, 0.9f), Vector2.right, color);
                Plain(foot + new Vector3(0f, y, w * sx), new Vector3(w * 2f, 0.5f, 0.5f), Vector2.right, color);
                Plain(foot + new Vector3(w * sx, y, 0f), new Vector3(0.5f, 0.5f, w * 2f), Vector2.right, color);
            }
            if (i == 9 || i == 17) Plain(foot + new Vector3(0f, y, 0f), new Vector3(w * 2.4f, 3f, w * 2.4f), Vector2.right, white);
        }
        // Its blinking tip, a far box of its own (never falls: under SkylineRampagePlan's least height).
        var tip = foot + new Vector3(0f, height + TIP.y * 0.5f, 0f);
        code = CODE_FALLS + Far.Count;
        FarBox(tip, TIP, -1);
        Facade(tip, TIP, red, 0, 0f, true, TIP_SEED);
    }

    // ---------- Boxes ----------

    void Facade(Vector3 centre, Vector3 size, Color wall, int style, float lit, bool beacon, float drawn = -1f)
    {
        float seed = Mathf.Round((drawn >= 0f ? drawn : Rand(0f, 1f)) * SEED_STEPS) / SEED_STEPS;
        Box(centre, size, Vector2.right, wall, style, lit, seed);
        if (beacon)
            Box(centre + new Vector3(0f, size.y * 0.5f + 0.05f, 0f), new Vector3(1.2f, 0.1f, 1.2f), Vector2.right, Color.red, STYLE_BEACON, 0f, seed);
    }

    void Plain(Vector3 centre, Vector3 size, Vector2 along, Color color) => Box(centre, size, along, color, STYLE_PLAIN, 0f, 0f);

    // `along` turns the box's x about the vertical (Godot ground plane).
    void Box(Vector3 centre, Vector3 size, Vector2 along, Color color, float style, float lit, float seed)
    {
        Vector2Int key = new Vector2Int(Mathf.FloorToInt(centre.x / TILE), Mathf.FloorToInt(centre.z / TILE));
        if (!tiles.TryGetValue(key, out Tile tile)) tiles[key] = tile = new Tile();
        tile.far |= code > 0f;
        style += CODE_STRIDE * code;
        Boxes++;
        var ux = new Vector3(along.x, 0f, -along.y) * (size.x * 0.5f);   // mirrored into Unity
        var uz = new Vector3(along.y, 0f, along.x) * (size.z * 0.5f);
        var uy = new Vector3(0f, size.y * 0.5f, 0f);
        var c = new Vector3(centre.x, centre.y, -centre.z);
        float top = centre.y + size.y * 0.5f;
        Color32 paint = color;
        paint.a = (byte)Mathf.RoundToInt(grain * GRAIN_UNIT);
        Face(tile, c, ux, uz, uy, paint, style, lit, top, seed);
        Face(tile, c, -ux, uz, uy, paint, style, lit, top, seed);
        Face(tile, c, uz, ux, uy, paint, style, lit, top, seed);
        Face(tile, c, -uz, ux, uy, paint, style, lit, top, seed);
        Face(tile, c, uy, ux, uz, paint, style, lit, top, seed);
    }

    // Front-facing order in Unity: for normal n, u across it and v = Cross(u, n): (-u,-v), (-u,+v), (+u,+v), (+u,-v).
    static void Face(Tile k, Vector3 centre, Vector3 outward, Vector3 u, Vector3 v, Color32 paint, float style, float lit, float top, float seed)
    {
        Vector3 n = outward.normalized;
        if (Vector3.Dot(Vector3.Cross(u, n), v) < 0f) u = -u;
        Vector3 mid = centre + outward;
        int at = k.v.Count;
        k.v.Add(mid - u - v);
        k.v.Add(mid - u + v);
        k.v.Add(mid + u + v);
        k.v.Add(mid + u - v);
        for (int i = 0; i < 4; i++)
        {
            k.n.Add(n);
            k.c.Add(paint);
            k.a.Add(new Vector2(style, lit));
            k.b.Add(new Vector2(top, seed));
        }
        k.t.Add(at); k.t.Add(at + 1); k.t.Add(at + 2);
        k.t.Add(at); k.t.Add(at + 2); k.t.Add(at + 3);
    }

    void Build(Shader shader, Transform parent)
    {
        var material = new Material(shader);
        material.EnableKeyword("SLICE_FACADE");
        var root = new GameObject("skyline").transform;
        root.SetParent(parent, false);
        foreach (Tile tile in tiles.Values)
        {
            var mesh = new Mesh { indexFormat = UnityEngine.Rendering.IndexFormat.UInt32 };
            mesh.SetVertices(tile.v);
            mesh.SetNormals(tile.n);
            mesh.SetColors(tile.c);
            mesh.SetUVs(0, tile.a);
            mesh.SetUVs(1, tile.b);
            mesh.SetTriangles(tile.t, 0);
            if (tile.far)  // a far tower leans and sinks out of its box as it falls
            {
                Bounds bounds = mesh.bounds;
                bounds.Expand(FALL_BOUNDS * 2f);
                mesh.bounds = bounds;
            }
            mesh.UploadMeshData(true);
            var go = new GameObject("tile");
            go.transform.SetParent(root, false);
            go.AddComponent<MeshFilter>().sharedMesh = mesh;
            var shown = go.AddComponent<MeshRenderer>();
            shown.sharedMaterial = material;
            shown.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
        }
        tiles.Clear();
    }
}
