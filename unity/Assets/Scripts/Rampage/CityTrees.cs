using System.Collections.Generic;
using UnityEngine;
using S = Kaiju.Sim;

// The city's trees, built new for Unity (D-474) on the rules of scenes/kerb_trees.gd, city_trees.gd and
// city_greenery.gd: kerb rows out to the edge of the view, park lawns, plaza rings and the diagonal's rows.
// Merged per ground tile; a tile remakes its mesh when a tree in it falls. Presentation only.
public sealed class CityTrees
{
    const float VOXEL = 0.25f, TILE = 32f, BLOCK_CELL = 16f;
    const float PARK_INSET = 1.6f, PARK_AREA_PER_TREE = 9f, PARK_PATH = 1.2f, RING_INSET = 1.2f, DIAG_STEP = 4f, DIAG_ROW = 2.5f, DIAG_KERB = 0.6f, DIAG_BACK_ROW = 0.45f;
    const int RING_STEPS = 5, VARIANTS = 3, LEANS = 4;
    const float CHUNK_HEIGHT = 2f;
    static readonly int[] LeanX = { 1, -1, 0, 0 }, LeanZ = { 0, 0, 1, -1 };
    const int BARK = 0x5a4030, LEAF = 0x55703f, LEAF_DARK = 0x3f5832;

    sealed class Shape
    {
        public Vector3[] verts, normals;
        public Color32[] colors;
        public Vector2[] uvs;
        public int[] tris;
    }

    struct Tree
    {
        public Vector3 at;
        public int shape;
        public bool down;
    }

    sealed class Tile
    {
        public readonly List<int> trees = new List<int>();
        public Mesh mesh;
        public bool dirty = true;
    }

    readonly S.GDict city;
    readonly Transform root;
    readonly Material material;
    readonly CityFx fx;
    readonly ArmyView army;
    readonly System.Random rng;
    readonly Shape[] shapes;
    readonly List<Tree> trees = new List<Tree>();
    readonly Dictionary<Vector2Int, Tile> tiles = new Dictionary<Vector2Int, Tile>();
    readonly Dictionary<Vector2Int, List<S.Rect2>> blocked = new Dictionary<Vector2Int, List<S.Rect2>>();
    readonly Dictionary<Vector2Int, List<Vector2>> taken = new Dictionary<Vector2Int, List<Vector2>>();
    readonly List<S.Rect2> water = new List<S.Rect2>();
    readonly S.GDict plan;
    readonly float half, view, apart;
    readonly Color leafChunk, barkChunk;

    public int Count => trees.Count;

    static float F(S.GDict d, string key) => (float)(double)S.Num.F(d[key]);

    public CityTrees(S.RampageSim sim, CityFx fx, ArmyView army, Shader shader, Transform parent, int seed)
    {
        this.fx = fx;
        this.army = army;
        city = sim.city;
        rng = new System.Random(seed);
        root = new GameObject("trees").transform;
        root.SetParent(parent, false);
        material = ArmyView.PlainMaterial(shader, VOXEL);
        plan = S.CityGen.Map(city);
        half = (float)S.CityGen.HalfExtent(city);
        view = (float)(double)sim.arenaHalf + F(city, "view_beyond");
        apart = F(city, "tree_min_apart");
        ColorUtility.TryParseHtmlString("#" + S.Gd.Str(city["tree_debris_leaf"]), out leafChunk);
        ColorUtility.TryParseHtmlString("#" + S.Gd.Str(city["tree_debris_bark"]), out barkChunk);
        foreach (S.RampageSim.Building b in sim.buildings) Block(b);
        foreach (S.RampageSim.Building b in sim.LotBuildings()) Block(b);
        foreach (S.Rect2 r in S.CityRiver.Channels(plan, city)) water.Add(r.Grow(0.5));
        foreach (S.Rect2 r in S.CityHarbour.Basin(plan)) water.Add(r.Grow(0.3));
        shapes = MakeShapes();
        Kerbs();
        Blocks();
        Diagonals();
        foreach (Tile tile in tiles.Values) Remake(tile);
    }

    void Block(S.RampageSim.Building b)
    {
        var r = new S.Rect2((double)b.x - (double)b.w * 0.5, (double)b.z - (double)b.d * 0.5, (double)b.w, (double)b.d);
        Vector2Int lo = Cell((float)r.position.x, (float)r.position.y, BLOCK_CELL);
        Vector2Int hi = Cell((float)r.end.x, (float)r.end.y, BLOCK_CELL);
        for (int x = lo.x; x <= hi.x; x++)
            for (int z = lo.y; z <= hi.y; z++)
            {
                var key = new Vector2Int(x, z);
                if (!blocked.TryGetValue(key, out List<S.Rect2> list)) blocked[key] = list = new List<S.Rect2>();
                list.Add(r);
            }
    }

    static Vector2Int Cell(float x, float z, float size) => new Vector2Int(Mathf.FloorToInt(x / size), Mathf.FloorToInt(z / size));

    bool OnBuilding(Vector2 p)
    {
        if (!blocked.TryGetValue(Cell(p.x, p.y, BLOCK_CELL), out List<S.Rect2> list)) return false;
        var q = new S.Vector2(p.x, p.y);
        foreach (S.Rect2 r in list)
            if (r.HasPoint(q)) return true;
        return false;
    }

    bool OnWater(Vector2 p)
    {
        var q = new S.Vector2(p.x, p.y);
        foreach (S.Rect2 r in water)
            if (r.HasPoint(q)) return true;
        return false;
    }

    bool Crowded(Vector2 p, float reach)
    {
        Vector2Int c = Cell(p.x, p.y, apart);
        int cells = Mathf.CeilToInt(reach / apart);
        for (int x = c.x - cells; x <= c.x + cells; x++)
            for (int z = c.y - cells; z <= c.y + cells; z++)
                if (taken.TryGetValue(new Vector2Int(x, z), out List<Vector2> list))
                    foreach (Vector2 t in list)
                        if ((t - p).magnitude < reach) return true;
        return false;
    }

    bool Plant(Vector2 p, int shape, float reach)
    {
        if (OnBuilding(p) || OnWater(p) || Crowded(p, reach)) return false;
        Vector2Int c = Cell(p.x, p.y, apart);
        if (!taken.TryGetValue(c, out List<Vector2> list)) taken[c] = list = new List<Vector2>();
        list.Add(p);
        var at = new Vector3(Mathf.Round(p.x / VOXEL) * VOXEL, 0f, -Mathf.Round(p.y / VOXEL) * VOXEL);
        Vector2Int t = Cell(at.x, at.z, TILE);
        if (!tiles.TryGetValue(t, out Tile tile)) tiles[t] = tile = new Tile();
        tile.trees.Add(trees.Count);
        trees.Add(new Tree { at = at, shape = shape });
        return true;
    }

    float Between(float a, float b) => a + (float)rng.NextDouble() * (b - a);

    // scenes/kerb_trees.gd: one city-wide spacing down both kerbs, the crown leaning over the road.
    void Kerbs()
    {
        float gap = F(city, "street_tree_gap"), clear = F(city, "street_tree_clear"), kerbIn = F(city, "street_tree_kerb"), walk = F(city, "sidewalk");
        float diagonal = (float)S.CityGen.WidthOf(S.CityGen.DIAGONAL, city) * 0.5f + walk;
        S.GArray<S.Variant> kinds = city["street_tree_kinds"];
        S.GArray<S.Vector2> nodes = plan["nodes"];
        S.GArray<S.GDict> streets = plan["streets"];
        foreach (S.GDict street in streets)
        {
            if (!kinds.Has(street["kind"])) continue;
            S.Vector2 sa = nodes[S.Num.I(street["from"])], sb = nodes[S.Num.I(street["to"])];
            var a = new Vector2((float)sa.x, (float)sa.y);
            var b = new Vector2((float)sb.x, (float)sb.y);
            if (!Inside(a) && !Inside(b)) continue;
            Vector2 dir = (b - a).normalized;
            var side = new Vector2(-dir.y, dir.x);
            float length = (b - a).magnitude, kerb = F(street, "width") * 0.5f + kerbIn;
            foreach (float s in new[] { -1f, 1f })
            {
                int lean = LeanIndex(Mathf.RoundToInt(-side.x * s), Mathf.RoundToInt(-side.y * s));
                float along = Vector2.Dot(a, dir);
                for (float t = Mathf.Ceil((along + clear) / gap) * gap - along; t < length - clear; t += gap)
                {
                    Vector2 p = a + dir * t + side * s * kerb;
                    if (Inside(p) && (float)S.CityGen.DiagonalDistance(plan, new S.Vector2(p.x, p.y)) > diagonal)
                        Plant(p, lean * VARIANTS + rng.Next(VARIANTS), apart);
                }
            }
        }
    }

    bool Inside(Vector2 p) => Mathf.Max(Mathf.Abs(p.x), Mathf.Abs(p.y)) <= view;

    static int LeanIndex(int x, int z)
    {
        for (int i = 0; i < LEANS; i++)
            if (LeanX[i] == x && LeanZ[i] == z) return i;
        return 0;
    }

    int LawnShape() => LEANS * VARIANTS + rng.Next(VARIANTS);

    // scenes/city_trees.gd: lawn trees in parks, a ring round plazas and landmarks.
    void Blocks()
    {
        float spacing = F(city, "park_tree_spacing");
        S.GArray<S.GDict> blocks = plan["blocks"];
        foreach (S.GDict block in blocks)
        {
            S.Rect2 rect = block["rect"];
            string use = S.Gd.Str(block["use"]);
            if (use == "park")
            {
                S.Rect2 inner = rect.Grow(-PARK_INSET);
                float mid = (float)rect.GetCenter().x;
                int count = Mathf.RoundToInt((float)rect.GetArea() / PARK_AREA_PER_TREE);
                for (int n = 0; n < count; n++)
                {
                    var p = new Vector2(Between((float)inner.position.x, (float)inner.end.x), Between((float)inner.position.y, (float)inner.end.y));
                    if (Mathf.Abs(p.x - mid) > PARK_PATH) Plant(p, LawnShape(), Mathf.Max(spacing, apart));
                }
            }
            else if (use == "plaza" || use == "landmark")
            {
                S.Rect2 r = rect.Grow(-RING_INSET);
                float x0 = (float)r.position.x, x1 = (float)r.end.x, z0 = (float)r.position.y, z1 = (float)r.end.y;
                for (int step = 0; step <= RING_STEPS; step++)
                {
                    float t = (float)step / RING_STEPS;
                    Plant(new Vector2(Mathf.Lerp(x0, x1, t), z0), LawnShape(), apart);
                    Plant(new Vector2(Mathf.Lerp(x0, x1, t), z1), LawnShape(), apart);
                    Plant(new Vector2(x0, Mathf.Lerp(z0, z1, t)), LawnShape(), apart);
                    Plant(new Vector2(x1, Mathf.Lerp(z0, z1, t)), LawnShape(), apart);
                }
            }
        }
    }

    // scenes/city_trees.gd _line: a kerb row and two broken rows behind it, on both sides.
    void Diagonals()
    {
        float kerb = (float)S.CityGen.WidthOf(S.CityGen.DIAGONAL, city) * 0.5f + DIAG_KERB;
        S.GArray<S.GDict> diagonals = plan["diagonals"];
        foreach (S.GDict diag in diagonals)
        {
            S.Vector2 sat = diag["at"], sdir = diag["dir"];
            var at = new Vector2((float)sat.x, (float)sat.y);
            var dir = new Vector2((float)sdir.x, (float)sdir.y);
            var side = new Vector2(-dir.y, dir.x);
            float reach = Mathf.Max(half * 1.6f, view / Mathf.Abs(dir.x));
            for (float t = -reach; t < reach; t += DIAG_STEP)
                foreach (float s in new[] { -1f, 1f })
                    for (int row = 0; row < 3; row++)
                    {
                        Vector2 p = at + dir * t + side * s * (kerb + row * DIAG_ROW);
                        bool inCity = Mathf.Max(Mathf.Abs(p.x), Mathf.Abs(p.y)) <= half - 1f;
                        if (!Inside(p) || (!inCity && row > 0)) continue;
                        if (row == 0 || rng.NextDouble() < DIAG_BACK_ROW) Plant(p, LawnShape(), apart);
                    }
        }
    }

    // ---------- The trees' voxels: city_greenery.gd _street_tree and city_trees.gd _tree ----------

    Shape[] MakeShapes()
    {
        var made = new Shape[(LEANS + 1) * VARIANTS];
        S.GArray<S.Variant> crown = city["street_tree_crown"];
        float crownLo = (float)(double)S.Num.F(crown[0]), crownHi = (float)(double)S.Num.F(crown[1]);
        for (int lean = 0; lean < LEANS; lean++)
            for (int v = 0; v < VARIANTS; v++)
            {
                var cells = new Dictionary<Vector3Int, int>();
                int tall = 8 + rng.Next(3);
                Line(cells, Vector3Int.zero, new Vector3Int(0, tall, 0));
                float r = Between(crownLo, crownHi);
                int lx = LeanX[lean] * 2, lz = LeanZ[lean] * 2;
                Line(cells, new Vector3Int(0, tall, 0), new Vector3Int(lx, tall, lz));
                var c = new Vector3(lx, tall + r * 0.6f, lz);
                Blob(cells, c, new Vector3(r, r * 0.8f, r), LEAF);
                Blob(cells, c + new Vector3(r * 0.4f, -r * 0.25f, 0f), new Vector3(r * 0.6f, r * 0.5f, r * 0.6f), LEAF_DARK);
                made[lean * VARIANTS + v] = Bake(cells);
            }
        for (int v = 0; v < VARIANTS; v++)
        {
            var cells = new Dictionary<Vector3Int, int>();
            int tall = 4 + rng.Next(4);
            for (int x = 0; x <= 1; x++)
                for (int z = 0; z <= 1; z++)
                    Line(cells, new Vector3Int(x, 0, z), new Vector3Int(x, tall, z));
            float r = Between(2.6f, 3.6f);
            Blob(cells, new Vector3(0.5f, tall + r * 0.8f, 0.5f), new Vector3(r, r * 0.85f, r), LEAF);
            Blob(cells, new Vector3(0.5f + r * 0.5f, tall + r * 0.5f, 0f), new Vector3(r * 0.7f, r * 0.6f, r * 0.7f), LEAF_DARK);
            made[LEANS * VARIANTS + v] = Bake(cells);
        }
        return made;
    }

    static void Line(Dictionary<Vector3Int, int> cells, Vector3Int a, Vector3Int b)
    {
        for (int x = Mathf.Min(a.x, b.x); x <= Mathf.Max(a.x, b.x); x++)
            for (int y = Mathf.Min(a.y, b.y); y <= Mathf.Max(a.y, b.y); y++)
                for (int z = Mathf.Min(a.z, b.z); z <= Mathf.Max(a.z, b.z); z++)
                    cells[new Vector3Int(x, y, z)] = BARK;
    }

    static void Blob(Dictionary<Vector3Int, int> cells, Vector3 centre, Vector3 radii, int color)
    {
        Vector3Int lo = Vector3Int.FloorToInt(centre - radii), hi = Vector3Int.CeilToInt(centre + radii);
        for (int x = lo.x; x <= hi.x; x++)
            for (int y = lo.y; y <= hi.y; y++)
                for (int z = lo.z; z <= hi.z; z++)
                {
                    Vector3 d = new Vector3(x, y, z) - centre;
                    d = new Vector3(d.x / radii.x, d.y / radii.y, d.z / radii.z);
                    if (d.sqrMagnitude <= 1f) cells[new Vector3Int(x, y, z)] = color;
                }
    }

    static Shape Bake(Dictionary<Vector3Int, int> cells)
    {
        var model = new ModelColors.Model { xyz = new S.PackedInt32Array(), rgb = new int[cells.Count] };
        model.xyz.Resize(cells.Count * 3);
        int[] raw = model.xyz.Raw;
        int i = 0;
        foreach (KeyValuePair<Vector3Int, int> cell in cells)
        {
            raw[i * 3] = cell.Key.x;
            raw[i * 3 + 1] = cell.Key.y;
            raw[i * 3 + 2] = cell.Key.z;
            model.rgb[i++] = cell.Value;
        }
        Mesh mesh = ArmyView.Faces(model, VOXEL, Vector3.zero);
        var uvs = new List<Vector2>();
        mesh.GetUVs(0, uvs);
        var shape = new Shape { verts = mesh.vertices, normals = mesh.normals, colors = mesh.colors32, uvs = uvs.ToArray(), tris = mesh.triangles };
        Object.Destroy(mesh);
        return shape;
    }

    // ---------- Drawing and falling ----------

    readonly List<Vector3> vBuf = new List<Vector3>(), nBuf = new List<Vector3>();
    readonly List<Color32> cBuf = new List<Color32>();
    readonly List<Vector2> uBuf = new List<Vector2>();
    readonly List<int> tBuf = new List<int>();

    void Remake(Tile tile)
    {
        tile.dirty = false;
        vBuf.Clear();
        nBuf.Clear();
        cBuf.Clear();
        uBuf.Clear();
        tBuf.Clear();
        foreach (int index in tile.trees)
        {
            Tree tree = trees[index];
            if (tree.down) continue;
            Shape shape = shapes[tree.shape];
            int at = vBuf.Count;
            foreach (Vector3 v in shape.verts) vBuf.Add(v + tree.at);
            nBuf.AddRange(shape.normals);
            cBuf.AddRange(shape.colors);
            uBuf.AddRange(shape.uvs);
            foreach (int t in shape.tris) tBuf.Add(t + at);
        }
        if (tile.mesh == null)
        {
            tile.mesh = new Mesh { indexFormat = UnityEngine.Rendering.IndexFormat.UInt32 };
            var go = new GameObject("tile");
            go.transform.SetParent(root, false);
            go.AddComponent<MeshFilter>().sharedMesh = tile.mesh;
            go.AddComponent<MeshRenderer>().sharedMaterial = material;
        }
        tile.mesh.Clear();
        tile.mesh.SetVertices(vBuf);
        tile.mesh.SetNormals(nBuf);
        tile.mesh.SetColors(cBuf);
        tile.mesh.SetUVs(0, uBuf);
        tile.mesh.SetTriangles(tBuf, 0);
    }

    // Every tree whose base lies within `radius` of `at` falls (Godot axes): a puff and a few chunks.
    public void Crush(Vector3 at, float radius)
    {
        Vector3 unity = new Vector3(at.x, 0f, -at.z);
        Vector2Int lo = Cell(unity.x - radius, unity.z - radius, TILE), hi = Cell(unity.x + radius, unity.z + radius, TILE);
        for (int x = lo.x; x <= hi.x; x++)
            for (int z = lo.y; z <= hi.y; z++)
            {
                if (!tiles.TryGetValue(new Vector2Int(x, z), out Tile tile)) continue;
                foreach (int index in tile.trees)
                {
                    Tree tree = trees[index];
                    if (tree.down || (tree.at - unity).magnitude > radius) continue;
                    tree.down = true;
                    trees[index] = tree;
                    tile.dirty = true;
                    var godot = new Vector3(tree.at.x, CHUNK_HEIGHT, -tree.at.z);
                    fx.Puff(godot);
                    army.Chunks(godot, 3, leafChunk, barkChunk);
                }
            }
    }

    public void Tick()
    {
        foreach (Tile tile in tiles.Values)
            if (tile.dirty) Remake(tile);
    }
}
