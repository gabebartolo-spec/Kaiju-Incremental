using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Threading.Tasks;
using Unity.Collections;
using Unity.Collections.LowLevel.Unsafe;
using Unity.Jobs;
using UnityEngine;
using UnityEngine.Rendering;
using S = Kaiju.Sim;

// The sim's city as the view draws it, and nothing else: every building stands as one baked shell
// until the sim promotes it (cells_promoted); from then on it is drawn from a copy of its fine cells,
// fed in order with every cell the sim takes (cells_carved, fall_start). A falling section is exactly
// its cells. Reads the sim's grid and events and decides nothing (hard rule 3). Godot axes inside the
// grids, z negated at the mesher (mirror 1).
public sealed unsafe class CityDraw : IDisposable
{
    const int REGION = 16;
    const int RES = 8;
    const float VOXEL = 1f / RES;
    // Look ids past the materials table (scenes/cell_mesher.gd).
    const byte LIT = 254, SHOP_LIT = 255;
    // Nothing sits below a falling piece, so its underside draws (the mesher's ground test).
    const int ABOVE_GROUND = 1 << 20;
    static readonly string[] Finishes = { "rough", "glass", "metal" };

    struct Item
    {
        public IntPtr mesher, drawn;
        public int rx, ry, rz;
    }

    struct MeshJob : IJobParallelFor
    {
        [ReadOnly] public NativeArray<Item> items;
        [ReadOnly] public NativeArray<VertexAttributeDescriptor> layout;
        public Mesh.MeshDataArray data;

        public void Execute(int i)
        {
            Item it = items[i];
            int nv, ni;
            Native.kc_mesh_region(it.mesher, (byte*)it.drawn, it.rx, it.ry, it.rz, &nv, &ni);
            Mesh.MeshData m = data[i];
            m.SetVertexBufferParams(nv, layout);
            m.SetIndexBufferParams(ni, IndexFormat.UInt32);
            NativeArray<KcVertex> v = m.GetVertexData<KcVertex>();
            NativeArray<uint> x = m.GetIndexData<uint>();
            Native.kc_mesh_copy((KcVertex*)NativeArrayUnsafeUtility.GetUnsafePtr(v), (uint*)NativeArrayUnsafeUtility.GetUnsafePtr(x));
            m.subMeshCount = 1;
            m.SetSubMesh(0, new SubMeshDescriptor(0, ni), MeshUpdateFlags.DontRecalculateBounds | MeshUpdateFlags.DontValidateIndices);
        }
    }

    // A grid drawn region by region: a promoted building, or a piece that fell off one.
    sealed class FineBody
    {
        public GameObject go;
        public Transform parent;
        public int w, h, d, nrx, nry, nrz;
        public Vector3 origin;
        public Material mat;
        public IntPtr mesher;
        public NativeArray<byte> cells, drawn, looks;
        public Mesh[] meshes;
        public MeshRenderer[] renderers;
        public bool[] dirty;
        public readonly List<int> dirtyList = new List<int>();
        public bool building, shown;

        public byte* Cells => (byte*)NativeArrayUnsafeUtility.GetUnsafePtr(cells);
        public byte* Drawn => (byte*)NativeArrayUnsafeUtility.GetUnsafePtr(drawn);
        public byte* Looks => (byte*)NativeArrayUnsafeUtility.GetUnsafePtr(looks);

        public void MarkAll()
        {
            for (int i = 0; i < dirty.Length; i++) Mark(i);
        }

        public void Mark(int i)
        {
            if (dirty[i]) return;
            dirty[i] = true;
            dirtyList.Add(i);
        }

        // A removed cell opens a face on its neighbours, so one over on every side.
        public void MarkCell(int i)
        {
            int plan = w * d;
            int x = i % w, z = (i / w) % d, y = i / plan;
            for (int ry = Mathf.Max(y - 1, 0) >> 4; ry <= Mathf.Min(y + 1, h - 1) >> 4; ry++)
                for (int rz = Mathf.Max(z - 1, 0) >> 4; rz <= Mathf.Min(z + 1, d - 1) >> 4; rz++)
                    for (int rx = Mathf.Max(x - 1, 0) >> 4; rx <= Mathf.Min(x + 1, w - 1) >> 4; rx++)
                        Mark(rx + rz * nrx + ry * nrx * nrz);
        }

        public Bounds Box(int rx, int ry, int rz)
        {
            float x0 = origin.x + (rx * REGION - 0.5f) * VOXEL, x1 = x0 + REGION * VOXEL;
            float y0 = origin.y + (ry * REGION - 0.5f) * VOXEL, y1 = y0 + REGION * VOXEL;
            float z1 = -(origin.z + (rz * REGION - 0.5f) * VOXEL), z0 = z1 - REGION * VOXEL;
            var b = new Bounds();
            b.SetMinMax(new Vector3(x0, y0, z0), new Vector3(x1, y1, z1));
            return b;
        }
    }

    // One building: what its shell and its fine view are drawn from.
    sealed class Site
    {
        public S.RampageSim.Building b;
        public S.GDict party;
        public Material mat;
        public Vector3 origin;
        public int ox, oy, oz;
        public NativeArray<byte> palette, finish;
        public int[] lit, shopLit, hidden;
        public GameObject shell;
        public Mesh shellMesh;
        public FineBody fine;
        // The bake's output until the main thread has made the shell.
        public KcVertex[] verts;
        public uint[] index;
        public int nv, ni;
    }

    sealed class Fall
    {
        public FineBody body;
        public Transform pivot;
        public string kind;
        public Vector2 dir;
        public float drop, duration, t, dropped, y;
    }

    public long totalVerts;
    public int promoted;
    public double lastMeshMs;
    public int lastRegions;
    public int Falling => falls.Count;

    readonly S.RampageSim sim;
    readonly Shader shader;
    readonly Debris debris;
    readonly Transform root;
    readonly Site[] sites;
    readonly S.GDict toppleCfg;
    readonly List<FineBody> bodies = new List<FineBody>();
    readonly Dictionary<long, Fall> falls = new Dictionary<long, Fall>();
    readonly List<long> fallIds = new List<long>();
    readonly List<Mesh> meshList = new List<Mesh>();
    readonly List<int> meshRegion = new List<int>();
    readonly List<FineBody> meshBody = new List<FineBody>();
    NativeArray<VertexAttributeDescriptor> layout;
    readonly byte[] finishById = new byte[256];
    readonly Dictionary<string, int> materialIds = new Dictionary<string, int>();
    readonly byte finishLit, finishShopLit;
    readonly float noise;
    readonly Color[] styles;
    readonly float litShare;
    readonly Color lit, window, roof;
    uint tick;

    public CityDraw(S.RampageSim simulation, Shader buildingShader, Debris debrisField, Transform parent)
    {
        sim = simulation;
        shader = buildingShader;
        debris = debrisField;
        root = parent;
        toppleCfg = S.Content.Section("topple_fx");
        layout = new NativeArray<VertexAttributeDescriptor>(4, Allocator.Persistent);
        layout[0] = new VertexAttributeDescriptor(VertexAttribute.Position, VertexAttributeFormat.Float32, 3);
        layout[1] = new VertexAttributeDescriptor(VertexAttribute.Normal, VertexAttributeFormat.Float32, 3);
        layout[2] = new VertexAttributeDescriptor(VertexAttribute.Color, VertexAttributeFormat.UNorm8, 4);
        layout[3] = new VertexAttributeDescriptor(VertexAttribute.TexCoord0, VertexAttributeFormat.Float32, 2);

        foreach (S.GDict m in S.Content.Materials())
        {
            int id = (int)S.Num.I(m["id"]);
            string name = S.Gd.Str(m["name"]);
            materialIds[name] = id;
            finishById[id] = (byte)Mathf.Max(0, Array.IndexOf(Finishes, S.Gd.Str(m.Get("finish", "rough"))));
        }
        finishLit = finishById[materialIds["window"]];
        finishShopLit = finishById[materialIds["shop"]];
        S.GDict look = S.Content.Look();
        noise = (float)S.Num.F(look.Get("color_noise", 0.0));
        litShare = (float)S.Num.F(look.Get("window_lit", 0.0));
        lit = Hex(look["window_lit_color"]);
        lit.a = S.Num.F(look.Get("window_glow", 0.0)) > 0.0 ? 1f / 255f : 1f;
        window = Hex(look["window"]);
        roof = Hex(look["roof"]);
        var raw = (S.GArray<S.Variant>)look["styles"];
        styles = new Color[raw.Size()];
        for (int i = 0; i < styles.Length; i++) styles[i] = Hex(raw[i]);

        int count = (int)sim.buildings.Size();
        sites = new Site[count];
        S.GArray<S.GDict> party = S.PartyWalls.Of(sim.buildings);
        for (int n = 0; n < count; n++)
        {
            S.RampageSim.Building b = sim.buildings[n];
            sites[n] = new Site { b = b, party = party[n] };
        }
        BakeAll();
    }

    static Color Hex(S.Variant v)
    {
        string s = S.Gd.Str(v);
        int c = Convert.ToInt32(s.Substring(0, 6), 16);
        return new Color(((c >> 16) & 255) / 255f, ((c >> 8) & 255) / 255f, (c & 255) / 255f, 1);
    }

    static Color Hex(string s) => Hex((S.Variant)s);
    static Color Lighter(Color c, float a) => new Color(c.r + (1 - c.r) * a, c.g + (1 - c.g) * a, c.b + (1 - c.b) * a, c.a);
    static Color Darker(Color c, float a) => new Color(c.r * (1 - a), c.g * (1 - a), c.b * (1 - a), c.a);

    static bool Plain(S.RampageSim.Building b) => b.landmark == "" && b.model == "" && b.hazard == "" && !b.IsSpan();

    static long PosMod(long a, long n) => ((a % n) + n) % n;

    S.CellGrid Grid(S.RampageSim.Building b, S.GDict party)
    {
        if (b.landmark != "" || b.model != "") return new S.LandmarkCells(b);
        if (b.hazard != "") return new S.HazardCells(b);
        return new S.BuildingCells(b, party);
    }

    // scenes/building_voxels.gd _make_palette and scenes/cell_mesher.gd _fill_palette. A material the
    // plain palette does not name (a landmark's, a rail's) draws in the building's base colour until
    // their voxel kinds are ported.
    void FillPalette(Site s)
    {
        S.RampageSim.Building b = s.b;
        Color Base = styles[PosMod(b.style + (long)Math.Round((double)b.x * 3.0 + (double)b.z), styles.Length)];
        Color sill = Lighter(Base, 0.28f);
        Color shopLit = Hex("ffd9a0");
        shopLit.a = lit.a;
        string[] awnings = { "7d4636", "3f5a4a", "6a5a3a", "4a4f66" };
        string[] bands = { "2a2f3a", "5a2a26", "2e4a3a", "3a3a3a" };
        string[] neon = { "ff4f8b", "4fd8ff", "ffb347", "8dff6a" };
        Color beacon = new Color(1f, 0.25f, 0.2f, 0f);
        var named = new Dictionary<string, Color>
        {
            { "wall", Base }, { "pillar", Darker(Base, 0.1f) }, { "trim", Lighter(Base, 0.16f) }, { "sill", sill },
            { "window", window }, { "frame", Darker(Base, 0.3f) },
            { "glass", Lighter(Color.LerpUnclamped(window, Base, 0.3f), 0.1f) },
            { "mullion", Darker(Base, 0.45f) }, { "spandrel", Darker(Base, 0.18f) }, { "party", Darker(Base, 0.06f) },
            { "shop", Hex("1e2429") },
            { "awning", Hex(awnings[PosMod((long)Math.Round((double)b.x + (double)b.z * 3.0), 4)]) },
            { "band", Hex(bands[PosMod((long)Math.Round((double)b.x * 7.0 + (double)b.z), 4)]) },
            { "rail", sill }, { "slab", Hex("8a8780") }, { "roof", roof }, { "gear", Hex("a9aaa4") },
            { "vent", Hex("3a3c3e") }, { "pipe", Hex("6b6f72") }, { "tank", Hex("6a5040") },
            { "heater", Hex("e6e8e4") }, { "heater_hi", Hex("f8faf6") }, { "solar", Hex("1b2538") },
            { "beacon", beacon }, { "sign_frame", Hex("1c1e22") },
        };
        for (int i = 0; i < neon.Length; i++)
        {
            Color c = Hex(neon[i]);
            c.a = 0;
            named["neon" + i] = c;
        }
        s.palette = new NativeArray<byte>(1024, Allocator.Persistent, NativeArrayOptions.ClearMemory);
        s.finish = new NativeArray<byte>(256, Allocator.Persistent, NativeArrayOptions.ClearMemory);
        foreach (KeyValuePair<string, int> m in materialIds)
        {
            Color c = named.TryGetValue(m.Key, out Color got) ? got : Base;
            Put(s.palette, m.Value, c);
            s.finish[m.Value] = finishById[m.Value];
        }
        Put(s.palette, LIT, lit);
        Put(s.palette, SHOP_LIT, shopLit);
        s.finish[LIT] = finishLit;
        s.finish[SHOP_LIT] = finishShopLit;
    }

    static void Put(NativeArray<byte> palette, int id, Color c)
    {
        palette[id * 4] = (byte)Mathf.Clamp(Mathf.RoundToInt(c.r * 255f), 0, 255);
        palette[id * 4 + 1] = (byte)Mathf.Clamp(Mathf.RoundToInt(c.g * 255f), 0, 255);
        palette[id * 4 + 2] = (byte)Mathf.Clamp(Mathf.RoundToInt(c.b * 255f), 0, 255);
        palette[id * 4 + 3] = (byte)Mathf.Clamp(Mathf.RoundToInt(c.a * 255f), 0, 255);
    }

    // Which cells draw lit or not at all (scenes/cell_mesher.gd _read_looks), kept as short lists: a
    // promotion rebuilds its looks from them at once, with no layout pass in the frame of the first blow.
    void ReadLooks(Site s, S.CellGrid grid)
    {
        var lits = new List<int>();
        var shops = new List<int>();
        var hides = new List<int>();
        if (Plain(s.b))
        {
            int gw = (int)grid.dims.x, gh = (int)grid.dims.y, gd = (int)grid.dims.z;
            int ox = (int)grid.offset.x, oy = (int)grid.offset.y, oz = (int)grid.offset.z;
            int footX = (int)s.b.w * RES, footZ = (int)s.b.d * RES;
            var laid = new S.BuildingLayout(s.b, RES, s.party, litShare);
            foreach (S.Variant key in laid.cells.Keys())
            {
                string what = S.Gd.Str(laid.cells[key]);
                bool isLit = what == "lit", isShop = what == "shop_lit", isSlab = what == "slab";
                if (!isLit && !isShop && !isSlab) continue;
                S.Vector3i c = key;
                int x = (int)c.x - ox, y = (int)c.y - oy, z = (int)c.z - oz;
                if (x < 0 || y < 0 || z < 0 || x >= gw || y >= gh || z >= gd) continue;
                int i = x + z * gw + y * gw * gd;
                if (isLit) lits.Add(i);
                else if (isShop) shops.Add(i);
                else if ((int)c.x < 0 || (int)c.z < 0 || (int)c.x >= footX || (int)c.z >= footZ) hides.Add(i);
            }
        }
        s.lit = lits.ToArray();
        s.shopLit = shops.ToArray();
        s.hidden = hides.ToArray();
    }

    void Bake(Site s)
    {
        S.RampageSim.Building b = s.b;
        S.CellGrid grid = Grid(b, s.party);
        FillPalette(s);
        ReadLooks(s, grid);
        int w = (int)grid.dims.x, h = (int)grid.dims.y, d = (int)grid.dims.z;
        s.ox = (int)grid.offset.x;
        s.oy = (int)grid.offset.y;
        s.oz = (int)grid.offset.z;
        s.origin = new Vector3(
            (float)((double)b.x - (double)b.w * 0.5 + VOXEL * 0.5) + s.ox * VOXEL,
            (float)(double)b.@base + VOXEL * 0.5f + s.oy * VOXEL,
            (float)((double)b.z - (double)b.d * 0.5 + VOXEL * 0.5) + s.oz * VOXEL);
        int size = w * h * d;
        var drawn = new NativeArray<byte>(size, Allocator.TempJob, NativeArrayOptions.UninitializedMemory);
        var looks = new NativeArray<byte>(size, Allocator.TempJob, NativeArrayOptions.UninitializedMemory);
        byte[] raw = grid.cells.Raw;
        NativeArray<byte>.Copy(raw, drawn, size);
        NativeArray<byte>.Copy(raw, looks, size);
        foreach (int i in s.lit) looks[i] = LIT;
        foreach (int i in s.shopLit) looks[i] = SHOP_LIT;
        foreach (int i in s.hidden) drawn[i] = 0;
        byte* dp = (byte*)NativeArrayUnsafeUtility.GetUnsafePtr(drawn);
        FillEnclosed(dp, w, h, d);

        IntPtr mesher = Native.kc_mesher_create(w, h, d, s.ox, s.oy, s.oz, s.origin.x, s.origin.y, s.origin.z, VOXEL,
            (byte*)NativeArrayUnsafeUtility.GetUnsafePtr(looks),
            (byte*)NativeArrayUnsafeUtility.GetUnsafePtr(s.palette),
            (byte*)NativeArrayUnsafeUtility.GetUnsafePtr(s.finish), 1);
        int nrx = (w + REGION - 1) / REGION, nry = (h + REGION - 1) / REGION, nrz = (d + REGION - 1) / REGION;
        var verts = new KcVertex[4096];
        var index = new uint[8192];
        int tv = 0, ti = 0;
        for (int ry = 0; ry < nry; ry++)
            for (int rz = 0; rz < nrz; rz++)
                for (int rx = 0; rx < nrx; rx++)
                {
                    int nv, ni;
                    Native.kc_mesh_region(mesher, dp, rx, ry, rz, &nv, &ni);
                    if (nv == 0) continue;
                    if (tv + nv > verts.Length) Array.Resize(ref verts, Mathf.Max(verts.Length * 2, tv + nv));
                    if (ti + ni > index.Length) Array.Resize(ref index, Mathf.Max(index.Length * 2, ti + ni));
                    fixed (KcVertex* vp = &verts[tv])
                    fixed (uint* ip = &index[ti])
                        Native.kc_mesh_copy(vp, ip);
                    for (int k = ti; k < ti + ni; k++) index[k] += (uint)tv;
                    tv += nv;
                    ti += ni;
                }
        Native.kc_mesher_destroy(mesher);
        drawn.Dispose();
        looks.Dispose();
        s.verts = verts;
        s.index = index;
        s.nv = tv;
        s.ni = ti;
    }

    // The standing building's hollow counts as solid (BuildingMesher's shell): air no flood from
    // outside reaches draws no face, so the rooms cost nothing until a blow opens them.
    static void FillEnclosed(byte* cells, int w, int h, int d)
    {
        int size = w * h * d, plan = w * d;
        var seen = new NativeArray<byte>(size, Allocator.TempJob, NativeArrayOptions.ClearMemory);
        var stack = new NativeArray<int>(size, Allocator.TempJob, NativeArrayOptions.UninitializedMemory);
        byte* sn = (byte*)NativeArrayUnsafeUtility.GetUnsafePtr(seen);
        int* st = (int*)NativeArrayUnsafeUtility.GetUnsafePtr(stack);
        int top = 0;
        for (int y = 0; y < h; y++)
            for (int z = 0; z < d; z++)
                for (int x = 0; x < w; x++)
                {
                    if (x != 0 && x != w - 1 && z != 0 && z != d - 1 && y != h - 1) { x = w - 2; continue; }
                    int i = x + z * w + y * plan;
                    if (cells[i] == 0 && sn[i] == 0) { sn[i] = 1; st[top++] = i; }
                }
        while (top > 0)
        {
            int i = st[--top];
            int x = i % w, z = (i / w) % d, y = i / plan;
            if (x > 0 && cells[i - 1] == 0 && sn[i - 1] == 0) { sn[i - 1] = 1; st[top++] = i - 1; }
            if (x < w - 1 && cells[i + 1] == 0 && sn[i + 1] == 0) { sn[i + 1] = 1; st[top++] = i + 1; }
            if (z > 0 && cells[i - w] == 0 && sn[i - w] == 0) { sn[i - w] = 1; st[top++] = i - w; }
            if (z < d - 1 && cells[i + w] == 0 && sn[i + w] == 0) { sn[i + w] = 1; st[top++] = i + w; }
            if (y > 0 && cells[i - plan] == 0 && sn[i - plan] == 0) { sn[i - plan] = 1; st[top++] = i - plan; }
            if (y < h - 1 && cells[i + plan] == 0 && sn[i + plan] == 0) { sn[i + plan] = 1; st[top++] = i + plan; }
        }
        for (int i = 0; i < size; i++)
            if (cells[i] == 0 && sn[i] == 0) cells[i] = 1;
        seen.Dispose();
        stack.Dispose();
    }

    void BakeAll()
    {
        var watch = Stopwatch.StartNew();
        // The first alone: the sim's content caches fill once, off the workers' path.
        if (sites.Length > 0) Bake(sites[0]);
        var options = new ParallelOptions { MaxDegreeOfParallelism = Mathf.Max(1, SystemInfo.processorCount - 2) };
        Parallel.For(1, sites.Length, options, n => Bake(sites[n]));
        double bakeMs = watch.Elapsed.TotalMilliseconds;
        watch.Restart();
        foreach (Site s in sites) MakeShell(s);
        UnityEngine.Debug.Log($"rampage: {sites.Length} buildings, {totalVerts:N0} verts, bake {bakeMs:F0} ms, upload {watch.Elapsed.TotalMilliseconds:F0} ms");
    }

    void MakeShell(Site s)
    {
        S.RampageSim.Building b = s.b;
        s.mat = new Material(shader);
        s.mat.EnableKeyword("SLICE_BUILDING");
        s.mat.SetFloat("_CullMode", 0);
        s.mat.SetFloat("_CullModeForward", 0);
        s.mat.SetVector("_VoxelOrigin", s.origin);
        s.mat.SetFloat("_VoxelSize", VOXEL);
        s.mat.SetFloat("_Salt", (float)(long)b.style);
        s.mat.SetFloat("_Noise", noise);
        bool glassy = Plain(b) && b.style % 4 == S.BuildingLayout.GLASS;
        var unit = glassy ? new Vector2(2f, 0.5f) : Vector2.one;
        s.mat.SetVector("_WinUnit", unit);
        s.mat.SetVector("_WinAlign", new Vector2(FloatMod((float)((double)b.x - (double)b.w * 0.5), unit.x), FloatMod((float)((double)b.z - (double)b.d * 0.5), unit.x)));
        totalVerts += s.nv;
        if (s.nv > 0)
        {
            s.shellMesh = new Mesh { name = "shell" };
            s.shellMesh.SetVertexBufferParams(s.nv, layout);
            s.shellMesh.SetVertexBufferData(s.verts, 0, 0, s.nv);
            s.shellMesh.SetIndexBufferParams(s.ni, IndexFormat.UInt32);
            s.shellMesh.SetIndexBufferData(s.index, 0, 0, s.ni, MeshUpdateFlags.DontValidateIndices);
            s.shellMesh.subMeshCount = 1;
            s.shellMesh.SetSubMesh(0, new SubMeshDescriptor(0, s.ni), MeshUpdateFlags.DontValidateIndices);
            s.shellMesh.RecalculateBounds();
            s.shellMesh.UploadMeshData(true);
            s.shell = new GameObject("shell");
            s.shell.transform.SetParent(root, false);
            s.shell.AddComponent<MeshFilter>().sharedMesh = s.shellMesh;
            var mr = s.shell.AddComponent<MeshRenderer>();
            mr.sharedMaterial = s.mat;
        }
        s.verts = null;
        s.index = null;
    }

    static float FloatMod(float a, float n)
    {
        float m = a % n;
        return m < 0 ? m + n : m;
    }

    FineBody Body(string name, int w, int h, int d, Vector3 origin, Material mat, NativeArray<byte> cells, NativeArray<byte> drawn, NativeArray<byte> looks, NativeArray<byte> palette, NativeArray<byte> finish, int ox, int oy, int oz, Transform parent)
    {
        var f = new FineBody { w = w, h = h, d = d, origin = origin, mat = mat, cells = cells, drawn = drawn, looks = looks, parent = parent };
        f.go = new GameObject(name);
        f.go.transform.SetParent(parent, false);
        f.nrx = (w + REGION - 1) / REGION;
        f.nry = (h + REGION - 1) / REGION;
        f.nrz = (d + REGION - 1) / REGION;
        int n = f.nrx * f.nry * f.nrz;
        f.meshes = new Mesh[n];
        f.renderers = new MeshRenderer[n];
        f.dirty = new bool[n];
        f.mesher = Native.kc_mesher_create(w, h, d, ox, oy, oz, origin.x, origin.y, origin.z, VOXEL, f.Looks,
            (byte*)NativeArrayUnsafeUtility.GetUnsafePtr(palette), (byte*)NativeArrayUnsafeUtility.GetUnsafePtr(finish), 1);
        bodies.Add(f);
        return f;
    }

    // cells_promoted: the fine view, from the grid as it was before the sim's first blow, so the same
    // tick's carves replay on it in order. The shell stands until the first remesh draws it.
    void Promote(int n)
    {
        Site s = sites[n];
        if (s.fine != null) return;
        S.CellGrid grid = Grid(s.b, s.party);
        int w = (int)grid.dims.x, h = (int)grid.dims.y, d = (int)grid.dims.z, size = w * h * d;
        var cells = new NativeArray<byte>(size, Allocator.Persistent, NativeArrayOptions.UninitializedMemory);
        var drawn = new NativeArray<byte>(size, Allocator.Persistent, NativeArrayOptions.UninitializedMemory);
        var looks = new NativeArray<byte>(size, Allocator.Persistent, NativeArrayOptions.UninitializedMemory);
        byte[] raw = grid.cells.Raw;
        NativeArray<byte>.Copy(raw, cells, size);
        NativeArray<byte>.Copy(raw, drawn, size);
        NativeArray<byte>.Copy(raw, looks, size);
        foreach (int i in s.lit) looks[i] = LIT;
        foreach (int i in s.shopLit) looks[i] = SHOP_LIT;
        foreach (int i in s.hidden) drawn[i] = 0;
        s.fine = Body("fine", w, h, d, s.origin, s.mat, cells, drawn, looks, s.palette, s.finish, s.ox, s.oy, s.oz, root);
        s.fine.building = true;
        s.fine.MarkAll();
        promoted++;
    }

    public void SetCut(int n, float cut) => sites[n].mat.SetFloat("_BubbleCut", cut);

    public void OnEvent(S.GDict e)
    {
        string type = S.Gd.Str(e["type"]);
        switch (type)
        {
            case "cells_promoted":
                Promote((int)S.Num.I(e["building"]));
                break;
            case "cells_carved":
                Carved(e);
                break;
            case "fall_start":
                FallStart(e);
                break;
            case "fall_land":
                FallLand(e);
                break;
        }
    }

    Vector3 Away(Site s, Vector3 from)
    {
        var d = new Vector3((float)(double)s.b.x - from.x, 0, -((float)(double)s.b.z - from.z));
        return d.sqrMagnitude > 1e-6f ? d.normalized : Vector3.up;
    }

    void Carved(S.GDict e)
    {
        Site s = sites[(int)S.Num.I(e["building"])];
        FineBody f = s.fine;
        if (f == null) return;
        int[] index = ((S.PackedInt32Array)e["index"]).Raw;
        int n = (int)((S.PackedInt32Array)e["index"]).Size();
        if (n == 0) return;
        byte* drawn = f.Drawn, cells = f.Cells;
        for (int k = 0; k < n; k++)
        {
            int i = index[k];
            drawn[i] = 0;
            cells[i] = 0;
            f.MarkCell(i);
        }
        tick++;
        fixed (int* ip = index)
        {
            Vector3 away = Away(s, new Vector3((float)(double)sim.kaijuPos.x, 0, (float)(double)sim.kaijuPos.y));
            debris.Spawn(f.mesher, Matrix4x4.identity, ip, n, f.go.transform.position, away * debris.BurstSpeed, debris.BurstSpeed, tick);
        }
    }

    void FallStart(S.GDict e)
    {
        if (!e.Has("index")) return;
        long id = S.Num.I(e["id"]);
        Site s = sites[(int)S.Num.I(e["building"])];
        FineBody f = s.fine;
        var indexArray = (S.PackedInt32Array)e["index"];
        int n = (int)indexArray.Size();
        if (f == null || n == 0) return;
        int* lo = stackalloc int[3];
        int* hi = stackalloc int[3];
        fixed (int* ip = indexArray.Raw)
        {
            Native.kc_cells_bounds(ip, n, f.w, f.d, lo, hi);
            int nw = hi[0] - lo[0], nh = hi[1] - lo[1], nd = hi[2] - lo[2], size = nw * nh * nd;
            var cells = new NativeArray<byte>(size, Allocator.Persistent, NativeArrayOptions.ClearMemory);
            var drawn = new NativeArray<byte>(size, Allocator.Persistent, NativeArrayOptions.ClearMemory);
            var looks = new NativeArray<byte>(size, Allocator.Persistent, NativeArrayOptions.ClearMemory);
            Native.kc_cells_move(f.Cells, f.Drawn, f.Looks, ip, n, f.w, f.d, lo, nw, nd,
                (byte*)NativeArrayUnsafeUtility.GetUnsafePtr(cells),
                (byte*)NativeArrayUnsafeUtility.GetUnsafePtr(drawn),
                (byte*)NativeArrayUnsafeUtility.GetUnsafePtr(looks));
            for (int k = 0; k < n; k++) f.MarkCell(ip[k]);
            S.Vector3 pivot = e["pivot"];
            var at = new Vector3((float)pivot.x, (float)pivot.y, -(float)pivot.z);
            var hinge = new GameObject("fall");
            hinge.transform.SetParent(root, false);
            hinge.transform.position = at;
            var holder = new GameObject("rest").transform;
            holder.SetParent(hinge.transform, false);
            holder.localPosition = -at;
            Vector3 origin = f.origin + new Vector3(lo[0], lo[1], lo[2]) * VOXEL;
            FineBody piece = Body("piece", nw, nh, nd, origin, f.mat, cells, drawn, looks, s.palette, s.finish, 0, ABOVE_GROUND, 0, holder);
            piece.shown = true;
            piece.MarkAll();
            S.Vector2 dir = e["dir"];
            falls[id] = new Fall
            {
                body = piece,
                pivot = hinge.transform,
                kind = S.Gd.Str(e["kind"]),
                dir = new Vector2((float)dir.x, (float)dir.y),
                drop = (float)S.Num.F(e["drop"]),
                duration = Mathf.Max(0.05f, (float)S.Num.F(e["duration"])),
                y = at.y,
            };
        }
    }

    // Gravity drives it: the angle (topple) or the drop grows with the square of time (scenes/city_falls.gd).
    public void Animate(float dt)
    {
        foreach (KeyValuePair<long, Fall> kv in falls)
        {
            Fall f = kv.Value;
            f.t += dt;
            float k = Mathf.Clamp01(f.t / f.duration);
            if (f.kind == "topple")
            {
                // A Godot rotation seen through the z mirror: its axis mirrors and its angle flips.
                float angle = (float)S.FallContact.Tilt(toppleCfg, f.t, f.duration);
                var axis = new Vector3(f.dir.y, 0, f.dir.x);
                f.pivot.rotation = Quaternion.AngleAxis(-angle * Mathf.Rad2Deg, axis.sqrMagnitude > 1e-6f ? axis.normalized : Vector3.right);
            }
            f.dropped = f.drop * k * k;
            Vector3 p = f.pivot.position;
            p.y = f.y - f.dropped;
            f.pivot.position = p;
        }
    }

    // It hit the ground: its cells go to debris and the piece goes. Rubble and the slower break-up follow.
    void FallLand(S.GDict e)
    {
        long id = S.Num.I(e["id"]);
        if (!falls.TryGetValue(id, out Fall f)) return;
        falls.Remove(id);
        FineBody p = f.body;
        var keep = new List<int>();
        byte* drawn = p.Drawn;
        for (int i = 0, size = p.w * p.h * p.d; i < size; i++)
            if (drawn[i] != 0) keep.Add(i);
        tick++;
        int[] all = keep.ToArray();
        if (all.Length > 0)
            fixed (int* ip = all)
                debris.Spawn(p.mesher, p.go.transform.localToWorldMatrix, ip, all.Length, f.pivot.position, Vector3.up, debris.BurstSpeed, tick);
        Free(p);
        UnityEngine.Object.Destroy(f.pivot.gameObject);
    }

    void Free(FineBody f)
    {
        bodies.Remove(f);
        foreach (Mesh m in f.meshes)
            if (m != null) UnityEngine.Object.Destroy(m);
        Native.kc_mesher_destroy(f.mesher);
        f.cells.Dispose();
        f.drawn.Dispose();
        f.looks.Dispose();
        f.mesher = IntPtr.Zero;
        UnityEngine.Object.Destroy(f.go);
    }

    // Every changed region, this frame, in parallel. The first remesh of a building takes its shell away
    // in the same frame its cells appear, so it never blinks.
    public void Remesh()
    {
        var watch = Stopwatch.StartNew();
        meshList.Clear();
        meshRegion.Clear();
        meshBody.Clear();
        int* lo = stackalloc int[3];
        int* hi = stackalloc int[3];
        foreach (FineBody f in bodies)
        {
            foreach (int index in f.dirtyList)
            {
                f.dirty[index] = false;
                int rx = index % f.nrx, rz = (index / f.nrx) % f.nrz, ry = index / (f.nrx * f.nrz);
                int faces = Native.kc_region_bbox(f.Drawn, f.w, f.h, f.d, rx, ry, rz, lo, hi);
                if (faces == 0)
                {
                    if (f.renderers[index] != null) f.renderers[index].enabled = false;
                    continue;
                }
                if (f.meshes[index] == null)
                {
                    var go = new GameObject("r");
                    go.transform.SetParent(f.go.transform, false);
                    var mesh = new Mesh { name = "region" };
                    mesh.MarkDynamic();
                    go.AddComponent<MeshFilter>().sharedMesh = mesh;
                    var mr = go.AddComponent<MeshRenderer>();
                    mr.sharedMaterial = f.mat;
                    f.meshes[index] = mesh;
                    f.renderers[index] = mr;
                }
                f.renderers[index].enabled = true;
                meshList.Add(f.meshes[index]);
                meshRegion.Add(index);
                meshBody.Add(f);
            }
            f.dirtyList.Clear();
        }
        lastRegions = meshList.Count;
        if (meshList.Count > 0)
        {
            var items = new NativeArray<Item>(meshList.Count, Allocator.TempJob);
            for (int i = 0; i < items.Length; i++)
            {
                FineBody f = meshBody[i];
                int index = meshRegion[i];
                items[i] = new Item { mesher = f.mesher, drawn = (IntPtr)f.Drawn, rx = index % f.nrx, rz = (index / f.nrx) % f.nrz, ry = index / (f.nrx * f.nrz) };
            }
            Mesh.MeshDataArray data = Mesh.AllocateWritableMeshData(meshList.Count);
            new MeshJob { items = items, layout = layout, data = data }.Schedule(items.Length, 4).Complete();
            Mesh.ApplyAndDisposeWritableMeshData(data, meshList, MeshUpdateFlags.DontRecalculateBounds | MeshUpdateFlags.DontValidateIndices);
            for (int i = 0; i < items.Length; i++)
                meshList[i].bounds = meshBody[i].Box(items[i].rx, items[i].ry, items[i].rz);
            items.Dispose();
        }
        foreach (Site s in sites)
        {
            if (s.fine == null || s.fine.shown) continue;
            s.fine.shown = true;
            if (s.shell != null) s.shell.SetActive(false);
        }
        lastMeshMs = watch.Elapsed.TotalMilliseconds;
    }

    public void Dispose()
    {
        foreach (FineBody f in new List<FineBody>(bodies)) Free(f);
        foreach (Site s in sites)
        {
            if (s.palette.IsCreated) s.palette.Dispose();
            if (s.finish.IsCreated) s.finish.Dispose();
            if (s.shellMesh != null) UnityEngine.Object.Destroy(s.shellMesh);
            if (s.mat != null) UnityEngine.Object.Destroy(s.mat);
        }
        if (layout.IsCreated) layout.Dispose();
    }
}
