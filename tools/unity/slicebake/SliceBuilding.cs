// One building of the slice as export_slice.gd _building() builds it: the sim's fine grid
// (BuildingCells), its frame (VoxelFrame), and what scenes/cell_mesher.gd makes of its view voxels
// (scenes/building_voxels.gd): each cell's look, the cells the view hides, the palette and finishes.
using System.Collections.Generic;
using System.IO;
using Kaiju.Sim;

sealed class SliceBuilding
{
    // scenes/building_voxels.gd
    const long RES = 8;
    const double VOXEL = 1.0 / RES;
    static readonly string[] AWNINGS = { "7d4636", "3f5a4a", "6a5a3a", "4a4f66" };
    static readonly string[] NEON = { "ff4f8b", "4fd8ff", "ffb347", "8dff6a" };
    static readonly string[] SIGN_BANDS = { "2a2f3a", "5a2a26", "2e4a3a", "3a3a3a" };
    // scenes/cell_mesher.gd: look ids past the materials table, the windows the view draws lit.
    public const int LIT = 254;
    public const int SHOP_LIT = 255;

    public readonly RampageSim.Building b;
    public readonly BuildingCells grid;
    public readonly VoxelFrame frame;
    public readonly Vector3i dims, offset;
    public readonly Vector3 origin;
    public readonly float voxel;
    public readonly long salt;
    public readonly float noise;
    public readonly byte[] looks, drawn, palette, finish;
    readonly float[] unit, align;

    public SliceBuilding(RampageSim.Building building, GDict party)
    {
        b = building;
        GColor baseColor = BaseColor(b);
        Dictionary<string, GColor> named = Palette(baseColor);
        GDict vox = new BuildingLayout(b, RES, party, Look.Value("window_lit")).cells;
        grid = new BuildingCells(b, party);
        frame = new VoxelFrame(new Vector3i(b.w, b.height, b.d), grid.res, Content.Materials());
        // CellMesher._init
        dims = grid.dims;
        offset = grid.offset;
        voxel = (float)VOXEL;
        salt = b.style;
        noise = (float)Look.Value("color_noise");
        var viewOrigin = new Vector3(b.x - b.w * 0.5 + VOXEL * 0.5, (double)b.@base, b.z - b.d * 0.5 + VOXEL * 0.5);
        origin = viewOrigin + new Vector3(0, voxel * 0.5, 0) + new Vector3(offset) * voxel;
        palette = FillPalette(named);
        var hidden = new List<int>();
        looks = ReadLooks(vox, hidden);
        finish = VoxelAO.FinishByLook(LIT, SHOP_LIT);
        drawn = Bytes(grid.cells);
        foreach (int i in hidden) drawn[i] = 0;
        unit = WindowPalette.UnitOf(b);
        align = WindowPalette.AlignOf(b, unit);
    }

    // A packed array's live bytes (its backing store can be longer).
    public static byte[] Bytes(PackedByteArray a)
    {
        var o = new byte[a.Size()];
        System.Array.Copy(a.Raw, o, o.Length);
        return o;
    }

    // scenes/building_colors.gd base()
    static GColor BaseColor(RampageSim.Building b)
    {
        List<GColor> styles = Look.Styles();
        return styles[(int)Gd.Posmod(b.style + Gd.Roundi(b.x * 3.0 + b.z), styles.Count)];
    }

    // BuildingVoxels._make_palette
    Dictionary<string, GColor> Palette(GColor c)
    {
        GColor lit = Look.Color("window_lit_color");
        lit.a = (float)(Look.Value("window_glow") > 0.0 ? WindowPalette.TAG : 1.0);
        GColor sill = c.Lightened(0.28);
        GColor shopLit = GColor.Hex("ffd9a0");
        shopLit.a = lit.a;
        var p = new Dictionary<string, GColor>
        {
            { "wall", c },
            { "pillar", c.Darkened(0.1) },
            { "trim", c.Lightened(0.16) },
            { "sill", sill },
            { "window", Look.Color("window") },
            { "frame", c.Darkened(0.3) },
            { "lit", lit },
            { "glass", Look.Color("window").Lerp(c, 0.3).Lightened(0.1) },
            { "mullion", c.Darkened(0.45) },
            { "spandrel", c.Darkened(0.18) },
            { "party", c.Darkened(0.06) },
            { "shop", GColor.Hex("1e2429") },
            { "shop_lit", shopLit },
            { "awning", GColor.Hex(AWNINGS[Gd.Posmod(Gd.Roundi(b.x + b.z * 3.0), AWNINGS.Length)]) },
            { "band", GColor.Hex(SIGN_BANDS[Gd.Posmod(Gd.Roundi(b.x * 7.0 + b.z), SIGN_BANDS.Length)]) },
            { "rail", sill },
            { "slab", GColor.Hex("8a8780") },
            { "roof", Look.Color("roof") },
            { "gear", GColor.Hex("a9aaa4") },
            { "vent", GColor.Hex("3a3c3e") },
            { "pipe", GColor.Hex("6b6f72") },
            { "tank", GColor.Hex("6a5040") },
            { "heater", GColor.Hex("e6e8e4") },
            { "heater_hi", GColor.Hex("f8faf6") },
            { "solar", GColor.Hex("1b2538") },
            { "beacon", new GColor(1f, 0.25f, 0.2f, 0f) },
            { "sign_frame", GColor.Hex("1c1e22") },
        };
        for (int i = 0; i < NEON.Length; i++)
        {
            GColor neon = GColor.Hex(NEON[i]);
            neon.a = 0f;
            p["neon" + i] = neon;
        }
        return p;
    }

    // CellMesher._fill_palette, stored as export_slice.gd stores it (r8, g8, b8, a8 per look id).
    static byte[] FillPalette(Dictionary<string, GColor> named)
    {
        var colors = new GColor[256];
        for (int i = 0; i < colors.Length; i++) colors[i] = GColor.Magenta;
        foreach (GDict m in Content.Materials())
            colors[Num.I(m["id"])] = named.TryGetValue(Gd.Str(m["name"]), out GColor c) ? c : GColor.Magenta;
        colors[LIT] = named["lit"];
        colors[SHOP_LIT] = named["shop_lit"];
        var o = new byte[1024];
        for (int i = 0; i < colors.Length; i++)
        {
            o[i * 4] = colors[i].R8;
            o[i * 4 + 1] = colors[i].G8;
            o[i * 4 + 2] = colors[i].B8;
            o[i * 4 + 3] = colors[i].A8;
        }
        return o;
    }

    // CellMesher._read_looks: a plain building has no DIRECT (model colour) cells.
    byte[] ReadLooks(GDict vox, List<int> hidden)
    {
        byte[] o = Bytes(grid.cells);
        long footW = b.w * RES, footD = b.d * RES;
        long plan = dims.x * dims.z;
        for (int i = 0; i < o.Length; i++)
        {
            if (o[i] == 0) continue;
            var local = new Vector3i(i % dims.x, i / plan, (i / dims.x) % dims.z) + offset;
            string key = Gd.Str(vox.Get(local, ""));
            if (key == "lit") o[i] = LIT;
            else if (key == "shop_lit") o[i] = SHOP_LIT;
            else if (key == "slab" && !(local.x >= 0 && local.x < footW && local.z >= 0 && local.z < footD)) hidden.Add(i);
            else if (key == "#") throw new System.InvalidOperationException("slicebake: a plain building with model colours");
        }
        return o;
    }

    public GDict Meta() => new GDict
    {
        { "x", b.x }, { "z", b.z }, { "w", b.w }, { "d", b.d }, { "height", b.height }, { "style", b.style }, { "tier", b.tier },
    };

    // export_slice.gd _store
    public void Store(BinaryWriter f)
    {
        foreach (long v in new[] { dims.x, dims.y, dims.z, offset.x, offset.y, offset.z }) f.Write((uint)v);
        foreach (double v in new[] { origin.x, origin.y, origin.z, (double)voxel }) f.Write((float)v);
        f.Write((uint)salt);
        foreach (float v in new[] { noise, unit[0], unit[1], align[0], align[1] }) f.Write(v);
        f.Write(frame.hasFixtures ? 1u : 0u);
        f.Write((uint)grid.res);
        f.Write(grid.cells.Raw, 0, (int)grid.cells.Size());
        f.Write(drawn, 0, drawn.Length);
        f.Write(looks, 0, looks.Length);
        f.Write(palette);
        f.Write(finish);
        f.Write(frame.fixtures.Raw, 0, (int)frame.fixtures.Size());
    }
}
