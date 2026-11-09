using System.Collections.Generic;
using UnityEngine;
using S = Kaiju.Sim;

// Everything past the playable edge (scenes/city_skyline.gd): painted stand-in boxes on the plan's outer blocks,
// two freeways winding through the outskirts, and a far shore across the bay with a lattice tower. One box
// per building, merged per tile. Never destroyed; presentation only. Godot axes in, mirrored at the mesh.
public sealed class CitySkyline
{
    const float TILE = 128f, QUAY_CLEAR = 17f, FREEWAY_CLEAR = 6f, DECK_Y = 7f, DECK_WIDTH = 5f;
    const float FREEWAY_STEP = 6f, FREEWAY_START = 9f, FREEWAY_OUTER = 40f, PARAPET = 2.3f;
    const float LATTICE_HEIGHT = 130f, SUPERTALL = 1.8f, CAP_KNEE = 0.6f, BEACON_ABOVE = 60f;
    const float STYLE_PLAIN = -1f, STYLE_BEACON = -2f;
    const float NEAR_GRAIN = 4f, FAR_GRAIN = 1.2f, GRAIN_UNIT = 32f, SEED_STEPS = 1024f;

    sealed class Tile
    {
        public readonly List<Vector3> v = new List<Vector3>(), n = new List<Vector3>();
        public readonly List<Color32> c = new List<Color32>();
        public readonly List<Vector2> a = new List<Vector2>(), b = new List<Vector2>();
        public readonly List<int> t = new List<int>();
    }

    readonly S.GDict cfg, plan;
    readonly Dictionary<Vector2Int, Tile> tiles = new Dictionary<Vector2Int, Tile>();
    readonly S.RandomNumberGenerator rng;
    readonly List<Color> styles = new List<Color>();
    readonly float coast, windowLit, half;
    readonly Color lot;
    float grain = NEAR_GRAIN;

    public int Boxes { get; private set; }

    static float F(S.GDict d, string key) => (float)(double)S.Num.F(d[key]);
    static Color Hex(string s)
    {
        ColorUtility.TryParseHtmlString(s.StartsWith("#") ? s : "#" + s, out Color c);
        return c;
    }

    public CitySkyline(S.GDict city, Shader shader, Transform parent, int seed)
    {
        cfg = city;
        plan = S.CityGen.Map(city);
        rng = S.Seeds.Make("skyline", seed);
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
        Build(shader, parent);
    }

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
            }
        }
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
                if (i % 3 == 0) Plain(new Vector3(a.x, DECK_Y * 0.5f, a.y), new Vector3(1.2f, DECK_Y, 1.6f), Vector2.right, deck);
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
        float shore = coast - F(cfg, "bay_width");
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
                int style = Mathf.FloorToInt(Rand(0f, 4f));
                Color tint = styles[style % styles.Count];
                Facade(at, new Vector3(w, tall, d), tint * 0.85f, style, Lit() * 0.7f, tall > BEACON_ABOVE);
                if (tall > 90f)  // a stepped crown on the supertalls, New York style
                    Facade(at + new Vector3(0f, tall * 0.56f, 0f), new Vector3(w * 0.6f, tall * 0.12f, d * 0.6f), tint, style, Lit(), true);
            }
        }
        Lattice(new Vector3(-160f, 0f, shore - 70f));
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
    }

    // ---------- Boxes ----------

    void Facade(Vector3 centre, Vector3 size, Color wall, int style, float lit, bool beacon)
    {
        float seed = Mathf.Round(Rand(0f, 1f) * SEED_STEPS) / SEED_STEPS;
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
