using System;
using System.Collections.Generic;
using Kaiju.Sim;

// The cells of one plain building that the view draws lit or not at all, as BuildingLayout lays them
// (sim/building_layout.gd): its lit windows ("lit"), lit shopfronts ("shop_lit") and the slab cells outside its
// footprint ("slab": a brick balcony's floor). It lays the same parts in the same order as BuildingLayout, so a
// cell laid twice keeps the last key, but into a box of bytes rather than a GDict of strings: the view's whole
// city reads in a fraction of the time. Only what the result needs is told apart (empty, lit, shop lit, slab,
// anything else). SimTests' WindowLightsCheck holds it cell for cell to BuildingLayout.
public static class WindowLights
{
    const byte EMPTY = 0, OTHER = 1, LIT = 2, SHOP_LIT = 3, SLAB = 4;
    // A plane of "recess": the key goes one cell back. A recessed key of SHOP lights as a shopfront.
    const int RECESS = -1, SHOP = 5;
    // Room round the footprint for what stands proud (signs reach three cells out) and above the roof.
    const int MARGIN = 8, ROOF_ROOM = 40, MIN_SPAN = 16;
    // BuildingLayout's own figures: a curtain-wall panel's roll layer, the footprint a stair hut needs, the room
    // AC units leave at the edge, a mast's height before its tier.
    const long PANEL_LAYER = 77, HUT_MIN = 20, AC_ROOM = 12, MAST_BASE = 16;

    [ThreadStatic] static byte[] box;

    public sealed class Result
    {
        public readonly List<Vector3i> lit = new List<Vector3i>(), shopLit = new List<Vector3i>(), hiddenSlab = new List<Vector3i>();
    }

    sealed class Lay
    {
        public RampageSim.Building b;
        public long res, w, d, h, archetype;
        public double litChance;
        public GDict party;
        public int nx, ny, nz;
        public byte[] cells;

        public void Put(long x, long y, long z, byte key)
        {
            long ix = x + MARGIN, iz = z + MARGIN;
            if (ix < 0 || iz < 0 || y < 0 || ix >= nx || iz >= nz || y >= ny)
                throw new InvalidOperationException($"WindowLights: cell {x},{y},{z} is outside its box");
            cells[ix + iz * nx + y * nx * nz] = key;
        }

        public byte Get(long x, long y, long z) => cells[(x + MARGIN) + (z + MARGIN) * nx + y * nx * nz];

        public void Box(Vector3i a, Vector3i c, byte key)
        {
            for (long x = Math.Min(a.x, c.x); x <= Math.Max(a.x, c.x); x++)
                for (long y = Math.Min(a.y, c.y); y <= Math.Max(a.y, c.y); y++)
                    for (long z = Math.Min(a.z, c.z); z <= Math.Max(a.z, c.z); z++)
                        Put(x, y, z, key);
        }

        public void At(Vector2i side, long p, long y, long layer, byte key)
        {
            if (side.x < 0) Put(layer, y, p, key);
            else if (side.x > 0) Put(w - 1 - layer, y, p, key);
            else if (side.y < 0) Put(p, y, layer, key);
            else Put(p, y, d - 1 - layer, key);
        }

        public long Roll(Vector3i cell, long mod) => BuildingLayout.RollFor(b, cell, mod);
    }

    public static Result Read(RampageSim.Building b, long res, GDict party, double litChance)
    {
        Lay l = Open(b, res, party, litChance);
        foreach (Vector2i side in BuildingLayout.SIDES) Face(l, side);
        if (l.archetype == BuildingLayout.GLASS) Apply(l, GlassFrame.Cells(l.w, l.d, l.h, res));
        Slabs(l);
        Roof(l);
        Sign(l);
        return Collect(l);
    }

    // An empty box round the building, with room for what stands proud of its faces and roof.
    static Lay Open(RampageSim.Building b, long res, GDict party, double litChance)
    {
        var l = new Lay { b = b, res = res, party = party, litChance = litChance, w = b.w * res, d = b.d * res, h = b.height * res, archetype = b.style % 4 };
        l.nx = (int)Math.Max(l.w, MIN_SPAN) + 2 * MARGIN;
        l.nz = (int)Math.Max(l.d, MIN_SPAN) + 2 * MARGIN;
        l.ny = (int)(l.h + ROOF_ROOM + b.tier * 8);
        int size = l.nx * l.ny * l.nz;
        if (box == null || box.Length < size) box = new byte[Math.Max(size, box == null ? 0 : box.Length * 2)];
        else Array.Clear(box, 0, size);
        l.cells = box;
        return l;
    }

    static Result Collect(Lay l)
    {
        var result = new Result();
        for (int y = 0; y < l.ny; y++)
            for (int z = 0; z < l.nz; z++)
                for (int x = 0; x < l.nx; x++)
                {
                    byte key = l.cells[x + z * l.nx + y * l.nx * l.nz];
                    if (key < LIT) continue;
                    var cell = new Vector3i(x - MARGIN, y, z - MARGIN);
                    if (key == LIT) result.lit.Add(cell);
                    else if (key == SHOP_LIT) result.shopLit.Add(cell);
                    else if (cell.x < 0 || cell.z < 0 || cell.x >= l.w || cell.z >= l.d) result.hiddenSlab.Add(cell);
                }
        return result;
    }

    static void Apply(Lay l, GDict laid)
    {
        foreach (Vector3i cell in laid) l.Put(cell.x, cell.y, cell.z, Gd.Str(laid[cell]) == "slab" ? SLAB : OTHER);
    }

    // BuildingLayout._face: the wall plane, recessed glass, and what stands proud of it.
    static void Face(Lay l, Vector2i side)
    {
        long length = side.x != 0 ? l.d : l.w;
        var spec = new int[4];
        for (long y = 0; y < l.h; y++)
            for (long p = 0; p < length; p++)
            {
                if (p == 0 || p == length - 1)
                {
                    l.At(side, p, y, 0, OTHER);
                    continue;
                }
                if (y < l.res) Ground(l, y, p, spec);
                else Upper(l, y, p, spec);
                if (spec[0] == RECESS) l.At(side, p, y, 1, LitOr(l, spec[1] == SHOP, side, p, y));
                else l.At(side, p, y, 0, (byte)spec[0]);
                if (spec[2] != EMPTY) l.At(side, p, y, -1, (byte)spec[2]);
                if (spec[3] != EMPTY) l.At(side, p, y, -2, (byte)spec[3]);
            }
    }

    static byte LitOr(Lay l, bool shop, Vector2i side, long p, long y)
    {
        if (l.litChance > 0.0)
        {
            var window = new Vector3i(Gd.Floori(Gd.Float(p) / l.res), Gd.Floori(Gd.Float(y) / l.res), side.x * 3 + side.y);
            if (l.Roll(window, 1000) < l.litChance * 1000.0) return shop ? SHOP_LIT : LIT;
        }
        return OTHER;
    }

    static void Spec(int[] s, int plane, int recessed, int proud, int further)
    {
        s[0] = plane;
        s[1] = recessed;
        s[2] = proud;
        s[3] = further;
    }

    static void Ground(Lay l, long y, long p, int[] s)
    {
        if (y == l.res - 1) Spec(s, OTHER, 0, OTHER, OTHER);
        else if (y == l.res - 2) Spec(s, OTHER, 0, OTHER, EMPTY);
        else if (p % l.res == 0 || y == 0) Spec(s, OTHER, 0, EMPTY, EMPTY);
        else Spec(s, RECESS, SHOP, EMPTY, EMPTY);
    }

    static void Upper(Lay l, long y, long p, int[] s)
    {
        long r = y % l.res, q = p % l.res;
        bool topRow = y >= l.h - 2;
        if (l.archetype == BuildingLayout.OFFICE) Office(r, q, topRow, s);
        else if (l.archetype == BuildingLayout.BRICK) Brick(r, q, Gd.Floori(Gd.Float(y) / l.res), s);
        else if (l.archetype == BuildingLayout.GLASS)
        {
            if (q == 0 || r == 0 || r == 4) Spec(s, OTHER, 0, EMPTY, EMPTY);
            else Spec(s, LitPanel(l, p, y) ? LIT : OTHER, 0, EMPTY, EMPTY);
        }
        else Stone(r, q, topRow || (r == 0 && Gd.Floori(Gd.Float(y) / l.res) % 5 == 0), topRow, s);
    }

    static void Office(long r, long q, bool topRow, int[] s)
    {
        if (r <= 1) Spec(s, OTHER, 0, EMPTY, EMPTY);
        else if (topRow) Spec(s, OTHER, 0, OTHER, EMPTY);
        else if (q == 0 || r == 7) Spec(s, OTHER, 0, EMPTY, EMPTY);
        else Spec(s, RECESS, OTHER, EMPTY, EMPTY);
    }

    static void Brick(long r, long q, long floorN, int[] s)
    {
        bool balcony = floorN % 2 == 0 && In(q, 1, 6), punched = In(q, 2, 5);
        if (punched && In(r, 2, 6)) Spec(s, RECESS, OTHER, EMPTY, EMPTY);
        else if (r == 7 && punched) Spec(s, OTHER, 0, OTHER, EMPTY);
        else if (r == 1 && In(q, 1, 6)) Spec(s, OTHER, 0, OTHER, balcony ? OTHER : EMPTY);
        else if (r == 0 && balcony) Spec(s, OTHER, 0, SLAB, SLAB);
        else Spec(s, OTHER, 0, EMPTY, EMPTY);
    }

    static void Stone(long r, long q, bool course, bool topRow, int[] s)
    {
        if (course) Spec(s, OTHER, 0, OTHER, topRow ? OTHER : EMPTY);
        else if (q == 0) Spec(s, OTHER, 0, OTHER, EMPTY);
        else if (In(q, 2, 5) && In(r, 2, 6)) Spec(s, RECESS, OTHER, EMPTY, EMPTY);
        else if (r == 1 && In(q, 2, 5)) Spec(s, OTHER, 0, OTHER, EMPTY);
        else if (r == 7 && In(q, 3, 4)) Spec(s, OTHER, 0, OTHER, EMPTY);
        else Spec(s, OTHER, 0, EMPTY, EMPTY);
    }

    static bool In(long v, long lo, long hi) => v >= lo && v <= hi;

    static bool LitPanel(Lay l, long p, long y)
    {
        if (l.litChance <= 0.0) return false;
        var panel = new Vector3i(Gd.Floori(Gd.Float(p) / (l.res * 2)), Gd.Floori(Gd.Float(y) / (l.res / 2.0)), PANEL_LAYER);
        return l.Roll(panel, 1000) < l.litChance * 1000.0;
    }

    static void Slabs(Lay l)
    {
        for (long floorY = 0; floorY < l.h; floorY += l.res)
            for (long x = 1; x < l.w - 1; x++)
                for (long z = 1; z < l.d - 1; z++)
                    if (l.Get(x, floorY, z) == EMPTY) l.Put(x, floorY, z, SLAB);
        for (long x = 1; x < l.w - 1; x++)
            for (long z = 1; z < l.d - 1; z++)
                l.Put(x, l.h - 1, z, OTHER);
    }

    static void Roof(Lay l)
    {
        long top = l.h;
        Parapet(l, top);
        if (l.w >= HUT_MIN && l.d >= HUT_MIN)
        {
            var hut = new Vector3i(3, top, 3);
            l.Box(hut, hut + new Vector3i(7, 6, 6), OTHER);
            l.Box(hut + new Vector3i(2, 0, 7), hut + new Vector3i(4, 4, 7), OTHER);
        }
        if (l.archetype == BuildingLayout.OFFICE) AcUnits(l, top);
        else if (l.archetype == BuildingLayout.BRICK)
        {
            var tank = new GDict();
            new RoofTank(tank, l.w, l.d).Lay(l.b, top);
            Apply(l, tank);
        }
        else if (l.archetype == BuildingLayout.GLASS) Mast(l, top);
        else SteppedRoof(l, top);
        for (long v = 0; v < Gd.Clampi(l.b.d, 1, 3); v++)
        {
            var at = new Vector3i(2 + l.Roll(new Vector3i(v, 5, 1), Gd.Maxi(1, l.w - 4)), top, 2 + l.Roll(new Vector3i(v, 5, 2), Gd.Maxi(1, l.d - 4)));
            l.Box(at, at + new Vector3i(0, 3, 0), OTHER);
        }
    }

    static void Parapet(Lay l, long top)
    {
        for (long x = 0; x < l.w; x++)
            for (long z = 0; z < l.d; z++)
                if (x == 0 || z == 0 || x == l.w - 1 || z == l.d - 1) l.Box(new Vector3i(x, top, z), new Vector3i(x, top + 1, z), OTHER);
    }

    static void AcUnits(Lay l, long top)
    {
        for (long i = 0; i < Gd.Clampi(l.b.w, 1, 4); i++)
        {
            var at = new Vector3i(4 + l.Roll(new Vector3i(i, 1, 0), Gd.Maxi(1, l.w - AC_ROOM)), top, 4 + l.Roll(new Vector3i(i, 2, 0), Gd.Maxi(1, l.d - AC_ROOM)));
            l.Box(at, at + new Vector3i(4, 3, 3), OTHER);
            l.Box(at + new Vector3i(1, 4, 1), at + new Vector3i(3, 4, 2), OTHER);
            l.Box(at + new Vector3i(5, 1, 1), at + new Vector3i(8, 1, 1), OTHER);
        }
    }

    static void SteppedRoof(Lay l, long top)
    {
        for (long step = 0; step < 3; step++)
            for (long x = 2 + step * 4; x < l.w - 2 - step * 4; x++)
                for (long z = 2 + step * 4; z < l.d - 2 - step * 4; z++)
                    l.Box(new Vector3i(x, top + step * 2, z), new Vector3i(x, top + step * 2 + 1, z), OTHER);
    }

    static void Mast(Lay l, long top)
    {
        if (l.b.tier < 2) return;
        var mast = new Vector3i(l.w >> 1, top, l.d >> 1);
        long mastH = MAST_BASE + l.b.tier * 8;
        l.Box(mast, mast + new Vector3i(0, mastH, 0), OTHER);
        l.Box(mast + new Vector3i(-2, 0, -2), mast + new Vector3i(2, 4, 2), OTHER);
        for (long ring = 8; ring < mastH; ring += 8) l.Box(mast + new Vector3i(-1, ring, -1), mast + new Vector3i(1, ring, 1), OTHER);
        l.Put(mast.x, mast.y + mastH + 1, mast.z, OTHER);
    }

    // BuildingLayout._sign: every cell of the sign is "anything else"; only where it lands matters.
    static void Sign(Lay l)
    {
        if (l.b.height < 3 || l.archetype == BuildingLayout.GLASS || l.Roll(new Vector3i(7, 7, 7), 1000) >= BuildingLayout.SIGN_CHANCE * 1000) return;
        var open = new List<Vector2i>();
        foreach (Vector2i side in BuildingLayout.SIDES)
            if (!l.party.Has(side)) open.Add(side);
        if (open.Count == 0) return;
        Vector2i at = open[(int)l.Roll(new Vector3i(3, 1, 4), open.Count)];
        long length = at.x != 0 ? l.d : l.w;
        long along = l.Roll(new Vector3i(1, 2, 3), 2) == 0 ? 4 : length - 8;
        for (long y = l.res + 2; y < Gd.Mini(l.h - 6, l.res * 5); y++) SignRow(l, at, along, y);
    }

    static void SignRow(Lay l, Vector2i side, long along, long y)
    {
        for (long a = 0; a < 4; a++)
            for (long o = -3; o < -1; o++) l.At(side, along + a, y, o, OTHER);
        if (l.archetype == BuildingLayout.OFFICE && y % l.res == 1)
        {
            l.At(side, along, y, -1, OTHER);
            l.At(side, along + 3, y, -1, OTHER);
        }
    }
}
