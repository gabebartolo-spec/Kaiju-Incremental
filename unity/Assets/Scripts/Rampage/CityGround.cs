using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using S = Kaiju.Sim;

// The ground of the street plan: scenes/city_ground.gd and its helpers (ground_kit, road_junctions, ground_river,
// diagonal_paving, harbour_view, road_paint), the same slabs in the same places. Godot lays them as instanced boxes;
// here they are one static mesh whose vertices name their slab, and the slabs' colour and kind sit in a buffer
// (CityGround.hlsl). Everything is laid in Godot's axes; z is negated once, where a vertex is written.
public sealed partial class CityGround : IDisposable
{
    const float PAVE_TOP = 0.1f, DIAG_TOP = 0.003f, PLAZA_RISE = 0.01f, PAINT = 0.02f, WATER_Y = -0.8f, RIVER_QUAY = 0.6f;
    const float PARAPET_H = 0.9f, PARAPET_W = 0.3f, FAR = 1400f, ROAD_TOP = 0.005f, CROSSING_TOP = 0.006f, KERB = 0.3f;
    const float REACH_NONE = 1000f;  // diagonal_paving SPREAD: a prism's slab is huge, so no gutter grime across the cut
    const float COLUMN = 1f, CELL = 1f;  // harbour_view: a curved band's column, the beach's height-field cell
    const float ZEBRA_OFF = 0.9f, ZEBRA_HALF = 0.6f, PERPENDICULAR = 0.999f, DASH_SLANT = 0.01f;  // road_paint
    const float PAINT_THICK = 0.04f;
    const float NO_WATER = -100f;
    const int K_ASPHALT = 0, K_ROAD = 1, K_PAVEMENT = 2, K_LAWN = 3, K_CONCRETE = 4, K_DECK = 5, K_PAINT = 6, K_JUNCTION = 7, K_SAND = 8;
    const int ALONG_X = 0, ALONG_Z = 1, TURNED = 2;
    static readonly string[] BLOCK_KEYS =
    {
        "block", "block_noise", "patch_noise", "speck_chance", "speck_dark", "seam", "fade_near", "fade_far", "mottle", "track", "tar",
        "patch_dark", "stain", "gutter", "panel", "damp", "streak", "soil", "paving", "band_h", "night_floor",
    };
    static readonly Color PAINT_COLOR = SliceData.Hex("8c8a82");

    struct R
    {
        public float x0, z0, x1, z1;
        public R(float x0, float z0, float x1, float z1) { this.x0 = x0; this.z0 = z0; this.x1 = x1; this.z1 = z1; }
        public float W => x1 - x0;
        public float D => z1 - z0;
        public Vector2 Centre => new Vector2((x0 + x1) * 0.5f, (z0 + z1) * 0.5f);
        public R Grow(float by) => new R(x0 - by, z0 - by, x1 + by, z1 + by);
        public bool Overlaps(R o) => x0 < o.x1 && o.x0 < x1 && z0 < o.z1 && o.z0 < z1;
        public List<Vector2> Poly() => new List<Vector2> { new Vector2(x0, z0), new Vector2(x1, z0), new Vector2(x1, z1), new Vector2(x0, z1) };
    }

    struct Slab
    {
        public Vector4 color, data, axes, extent;
    }

    struct Band
    {
        public Vector2 at, dir;
        public float half;
    }

    struct Piece
    {
        public R rect;
        public Vector4 data;
    }

    readonly S.GDict plan, cfg;
    readonly float coast;
    readonly List<Vector3> verts = new List<Vector3>();
    readonly List<Vector3> normals = new List<Vector3>();
    readonly List<Vector2> uv0 = new List<Vector2>();
    readonly List<Vector2> uv1 = new List<Vector2>();
    readonly List<int> tris = new List<int>();
    readonly List<Slab> slabs = new List<Slab>();
    readonly List<R> basin = new List<R>();
    readonly List<S.GDict> cutBlocks = new List<S.GDict>();
    readonly List<R> cutWalls = new List<R>();
    readonly List<Piece> streetPieces = new List<Piece>();
    readonly List<List<Vector2>> diagonalPieces = new List<List<Vector2>>();
    readonly Color asphalt, pavement, stone, outskirts, sand;

    // The water this ground holds, for WaterView.
    public readonly List<WaterRect> Sheets = new List<WaterRect>();

    Mesh mesh;
    Material mat;
    GraphicsBuffer buffer;
    public int SlabCount => slabs.Count;
    public int VertexCount => verts.Count;

    static float F(S.Variant v) => (float)S.Num.F(v);
    static Vector2 V(S.Vector2 v) => new Vector2((float)(double)v.x, (float)(double)v.y);
    static R Rect(S.Rect2 r)
    {
        Vector2 p = V(r.position), s = V(r.size);
        return new R(p.x, p.y, p.x + s.x, p.y + s.y);
    }
    static List<R> Rects(S.GArray<S.Rect2> list)
    {
        var o = new List<R>();
        foreach (S.Rect2 r in list) o.Add(Rect(r));
        return o;
    }
    static Color Look(string key) => SliceData.Hex(S.Gd.Str(S.Content.Look()[key]));
    static Color Darkened(Color c, float a) => new Color(c.r * (1f - a), c.g * (1f - a), c.b * (1f - a));
    static Color Lightened(Color c, float a) => new Color(c.r + (1f - c.r) * a, c.g + (1f - c.g) * a, c.b + (1f - c.b) * a);
    static bool Same(float a, float b) => Mathf.Abs(a - b) < Mathf.Max(0.00001f * Mathf.Abs(a), 0.00001f);
    static float Cross2(Vector2 a, Vector2 b) => a.x * b.y - a.y * b.x;

    static Vector4 Kind(int kind, float waterY = 0f) => new Vector4(kind, waterY, 0f, 0f);

    static Vector4 RoadKind(int kind, int axis, float centre, float half)
    {
        float big = Mathf.Round(centre / 16f) * 16f;
        return new Vector4(kind + axis / 8f, big, centre - big, half);
    }

    public CityGround(S.GDict cfg, Shader lit, Transform parent)
    {
        this.cfg = cfg;
        plan = S.CityGen.Map(cfg);
        coast = F(cfg["coast_z"]);
        asphalt = Look("asphalt");
        pavement = Look("lot");
        stone = Lightened(pavement, 0.12f);
        outskirts = Look("outskirts");
        sand = Look("sand");
        Lay();
        Build(lit, parent);
    }

    void Lay()
    {
        float outer = F(cfg["outer_half"]);
        List<R> channels = Rects(S.CityRiver.Channels(plan, cfg));
        basin.AddRange(Rects(S.CityHarbour.Basin(plan)));
        foreach (R land in Cut(new List<R> { new R(-FAR, coast, FAR, coast + FAR) }, channels))
            Of(K_ASPHALT, land, -0.01f, 0.4f, Darkened(asphalt, 0.25f));
        foreach (R land in Cut(new List<R> { new R(-outer, coast, outer, outer) }, channels))
            Of(K_ASPHALT, land, 0.001f, 0.4f, asphalt);
        S.GArray<S.GDict> blocks = plan["blocks"];
        foreach (S.GDict block in blocks) Block(block);
        var wet = new List<R>(channels);
        wet.AddRange(basin);
        Roads(wet);
        River(channels);
        Diagonal();
        Markings();
        Quay();
        Harbour();
        DiagonalPaving();
        WaterSheet(new R(-FAR * 2f, coast - FAR * 2f, FAR * 2f, coast), WATER_Y, true, false);
    }

    void Block(S.GDict block)
    {
        R rect = Rect(block["rect"]);
        if (rect.z0 < coast) return;
        R walk = Rect(S.CityGen.Pavement(block, cfg));
        string use = S.Gd.Str(block["use"]);
        if (use != "river" && use != "harbour" && Cuts(block))
        {
            cutBlocks.Add(block);
            return;
        }
        switch (use)
        {
            case "park":
                Of(K_PAVEMENT, walk, PAVE_TOP, KERB, pavement);
                Of(K_LAWN, rect.Grow(-0.5f), PAVE_TOP + 0.02f, KERB, outskirts);
                break;
            case "plaza":
            case "landmark":
                List<R> inlets = Rects(S.CityRiver.Inlets(plan));
                foreach (R piece in Cut(new List<R> { walk }, inlets)) Of(K_PAVEMENT, piece, PAVE_TOP, KERB, pavement);
                foreach (R piece in Cut(new List<R> { walk.Grow(-F(cfg["sidewalk"])) }, inlets)) Of(K_PAVEMENT, piece, PAVE_TOP + PLAZA_RISE, KERB, stone);
                break;
            case "parking":
                Of(K_PAVEMENT, walk, PAVE_TOP, KERB, pavement);
                R bay = rect.Grow(-0.6f);
                Of(K_ASPHALT, bay, PAVE_TOP + 0.01f, KERB, Lightened(asphalt, 0.06f));
                ParkingBays(bay);
                break;
            case "river":
            case "harbour":
                break;
            default:
                Of(K_PAVEMENT, walk, PAVE_TOP, KERB, pavement);
                break;
        }
    }

    void ParkingBays(R rect)
    {
        Color under = Lightened(asphalt, 0.06f);
        for (float x = rect.x0 + 1f; x < rect.x1 - 0.5f; x += 1.3f)
        {
            PaintBox(new Vector2(x, rect.z0 + 1.2f), Vector2.right, new Vector2(0.05f, 1.1f), PAVE_TOP + 0.03f, under);
            PaintBox(new Vector2(x, rect.z1 - 1.2f), Vector2.right, new Vector2(0.05f, 1.1f), PAVE_TOP + 0.03f, under);
        }
    }

    void Face(R rect, float top, float thick, Color color, float waterY) => Box(rect, top, thick, color, Kind(K_CONCRETE, waterY));

    void Of(int kind, R rect, float top, float thick, Color color)
    {
        foreach (R dry in Cut(new List<R> { rect }, basin)) Box(dry, top, thick, color, Kind(kind));
    }

    // ---- roads (road_junctions.gd) ----

    static bool Laid(S.GDict street)
    {
        string k = S.Gd.Str(street["kind"]);
        return k != S.CityGen.DIAGONAL && k != S.CityGen.ALLEY;
    }

    void Roads(List<R> channels)
    {
        S.GArray<S.Vector2> nodes = plan["nodes"];
        S.GArray<S.GDict> streets = plan["streets"];
        // node -> (widest z street's half, widest x street's half)
        var half = new Dictionary<int, Vector2>();
        var count = new Dictionary<(int, int), int>();
        foreach (S.GDict street in streets)
        {
            if (!Laid(street)) continue;
            int a = (int)S.Num.I(street["from"]), b = (int)S.Num.I(street["to"]);
            bool alongX = Same(V(nodes[a]).y, V(nodes[b]).y);
            float w = F(street["width"]) * 0.5f;
            foreach (int n in new[] { a, b })
            {
                half.TryGetValue(n, out Vector2 h);
                half[n] = alongX ? new Vector2(h.x, Mathf.Max(h.y, w)) : new Vector2(Mathf.Max(h.x, w), h.y);
                var key = (n, alongX ? 0 : 1);
                count.TryGetValue(key, out int c);
                count[key] = c + 1;
            }
        }
        var boxes = new Dictionary<int, Vector2>();
        foreach (KeyValuePair<int, Vector2> kv in half)
            if (kv.Value.x > 0f && kv.Value.y > 0f && V(nodes[kv.Key]).y >= coast) boxes[kv.Key] = kv.Value;

        float Reach(int n, int axis, float h)
        {
            if (boxes.TryGetValue(n, out Vector2 box)) return -(axis == 0 ? box.x : box.y);
            count.TryGetValue((n, axis), out int c);
            return c > 1 ? 0f : h;
        }

        foreach (S.GDict street in streets)
        {
            if (!Laid(street)) continue;
            int ea = (int)S.Num.I(street["from"]), eb = (int)S.Num.I(street["to"]);
            Vector2 a = V(nodes[ea]), b = V(nodes[eb]);
            if (Mathf.Min(a.y, b.y) < coast) continue;
            float h = F(street["width"]) * 0.5f;
            bool alongX = Same(a.y, b.y);
            int axis = alongX ? 0 : 1;
            float ta = alongX ? a.x : a.y, tb = alongX ? b.x : b.y;
            int loN = ta <= tb ? ea : eb, hiN = ta <= tb ? eb : ea;
            float lo = Mathf.Min(ta, tb) - Reach(loN, axis, h);
            float hi = Mathf.Max(ta, tb) + Reach(hiN, axis, h);
            if (hi - lo <= 0f) continue;
            float centre = alongX ? a.y : a.x;
            R rect = alongX ? new R(lo, centre - h, hi, centre + h) : new R(centre - h, lo, centre + h, hi);
            Vector4 data = RoadKind(K_ROAD, alongX ? ALONG_X : ALONG_Z, centre, h);
            foreach (R piece in Cut(new List<R> { rect }, channels))
            {
                Box(piece, ROAD_TOP, KERB, asphalt, data);
                streetPieces.Add(new Piece { rect = piece, data = data });
            }
        }
        foreach (KeyValuePair<int, Vector2> kv in boxes)
        {
            Vector2 at = V(nodes[kv.Key]);
            var box = new R(at.x - kv.Value.x, at.y - kv.Value.y, at.x + kv.Value.x, at.y + kv.Value.y);
            foreach (R piece in Cut(new List<R> { box }, channels)) Of(K_JUNCTION, piece, ROAD_TOP, KERB, asphalt);
        }
    }

    void Diagonal()
    {
        S.GArray<S.Vector2> nodes = plan["nodes"];
        S.GArray<S.GDict> streets = plan["streets"];
        foreach (S.GDict street in streets)
        {
            if (S.Gd.Str(street["kind"]) != S.CityGen.DIAGONAL) continue;
            Vector2 a = V(nodes[S.Num.I(street["from"])]), b = V(nodes[S.Num.I(street["to"])]);
            if (Mathf.Min(a.y, b.y) < coast) continue;
            float width = F(street["width"]);
            Vector2 mid = (a + b) * 0.5f;
            float length = Vector2.Distance(a, b) + width;
            Vector2 unit = (b - a).normalized;
            Turned(mid, unit, new Vector2(length * 0.5f, width * 0.5f), DIAG_TOP, KERB, asphalt, RoadKind(K_ROAD, TURNED, 0f, width * 0.5f));
            Vector2 dir = unit * (length * 0.5f), side = new Vector2(-unit.y, unit.x) * (width * 0.5f);
            diagonalPieces.Add(new List<Vector2> { mid - dir - side, mid + dir - side, mid + dir + side, mid - dir + side });
        }
    }

    // ---- river (ground_river.gd) ----

    void River(List<R> channels)
    {
        float depth = F(cfg["river_depth"]);
        List<R> bridges = Rects(S.CityRiver.Bridges(plan, cfg));
        List<Band> road = Bands(0f);
        foreach (R channel in channels)
        {
            WaterSheet(channel, -depth, false, false);
            var banks = new List<R>
            {
                new R(channel.x0, channel.z0, channel.x1, channel.z0 + RIVER_QUAY),
                new R(channel.x0, channel.z1 - RIVER_QUAY, channel.x1, channel.z1),
            };
            var open = new List<R>(bridges);
            foreach (R other in channels)
                if (!other.Equals(channel)) open.Add(other.Grow(RIVER_QUAY));
            foreach (R side in Cut(banks, open))
            {
                if (Whole(side, road)) Face(side, PAVE_TOP, depth + 0.5f, stone, -depth);
                else cutWalls.Add(side);
            }
            Face(new R(channel.x0, channel.z0, channel.x0 + RIVER_QUAY, channel.z1), PAVE_TOP, depth + 0.5f, stone, -depth);
            Face(new R(channel.x1 - RIVER_QUAY, channel.z0, channel.x1, channel.z1), PAVE_TOP, depth + 0.5f, stone, -depth);
        }
        S.GArray<S.GDict> decks = S.CityRiver.DiagonalDecks(plan, cfg);
        foreach (S.GDict over in decks) DiagonalDeck(over, channels[0]);
        foreach (R deck in bridges)
        {
            foreach (R channel in channels)
            {
                if (!channel.Overlaps(deck)) continue;
                Face(new R(deck.x0, channel.z0, deck.x1, channel.z0 + RIVER_QUAY), -0.4f, depth, stone, -depth);
                Face(new R(deck.x0, channel.z1 - RIVER_QUAY, deck.x1, channel.z1), -0.4f, depth, stone, -depth);
            }
        }
    }

    void DiagonalDeck(S.GDict over, R channel)
    {
        Vector2 a = V(over["from"]), b = V(over["to"]);
        float width = F(over["width"]);
        Vector2 dir = (b - a).normalized, mid = (a + b) * 0.5f;
        float length = Vector2.Distance(a, b);
        Turned(mid, dir, new Vector2(length * 0.5f, width * 0.5f), DIAG_TOP, 0.5f, asphalt, RoadKind(K_DECK, TURNED, 0f, width * 0.5f));
        foreach (float side in new[] { -1f, 1f })
        {
            Vector2 line = mid + new Vector2(-dir.y, dir.x) * (side * (width - PARAPET_W) * 0.5f);
            float t0 = (channel.z0 - line.y) / dir.y, t1 = (channel.z1 - line.y) / dir.y;
            Vector2 at = line + dir * ((t0 + t1) * 0.5f);
            Turned(at, dir, new Vector2(Mathf.Abs(t1 - t0) * 0.5f, PARAPET_W * 0.5f), PARAPET_H, 1f, stone, Kind(K_CONCRETE, NO_WATER));
        }
    }

    // ---- the diagonal's cuts (diagonal_paving.gd) ----

    bool Cuts(S.GDict block)
    {
        S.Rect2 walk = S.CityGen.Pavement(block, cfg);
        float half = (float)S.CityGen.WidthOf(S.CityGen.DIAGONAL, cfg) * 0.5f;
        R w = Rect(walk);
        var size = new Vector2(w.W, w.D);
        return S.CityGen.DiagonalDistance(plan, walk.GetCenter()) < size.magnitude * 0.5f + half;
    }

    List<Band> Bands(float grow)
    {
        var o = new List<Band>();
        float half = (float)S.CityGen.WidthOf(S.CityGen.DIAGONAL, cfg) * 0.5f + grow;
        foreach (S.GDict d in S.Gd.Iter(plan["diagonals"]))
            o.Add(new Band { at = V(d["at"]), dir = V(d["dir"]), half = half });
        return o;
    }

    // What is left of rect with every band cut out: the two sides of each (the bands outrun the plan, so never their ends).
    static List<List<Vector2>> Pieces(R rect, List<Band> bands)
    {
        var o = new List<List<Vector2>> { rect.Poly() };
        foreach (Band band in bands)
        {
            var left = new List<List<Vector2>>();
            var across = new Vector2(-band.dir.y, band.dir.x);
            foreach (List<Vector2> poly in o)
            {
                List<Vector2> one = Clip(poly, across, Vector2.Dot(across, band.at) + band.half);
                if (one.Count >= 3) left.Add(one);
                List<Vector2> two = Clip(poly, -across, -Vector2.Dot(across, band.at) + band.half);
                if (two.Count >= 3) left.Add(two);
            }
            o = left;
        }
        return o;
    }

    // Convex poly less everything behind the line: keeps dot(p, n) >= d (Sutherland-Hodgman).
    static List<Vector2> Clip(List<Vector2> poly, Vector2 n, float d)
    {
        var o = new List<Vector2>();
        for (int i = 0; i < poly.Count; i++)
        {
            Vector2 a = poly[i], b = poly[(i + 1) % poly.Count];
            float da = Vector2.Dot(a, n) - d, db = Vector2.Dot(b, n) - d;
            if (da >= 0f) o.Add(a);
            if ((da > 0f && db < 0f) || (da < 0f && db > 0f)) o.Add(a + (b - a) * (da / (da - db)));
        }
        return o;
    }

    static float Area(List<Vector2> poly)
    {
        float a = 0f;
        for (int i = 0; i < poly.Count; i++) a += Cross2(poly[i], poly[(i + 1) % poly.Count]);
        return Mathf.Abs(a) * 0.5f;
    }

    static bool Whole(R rect, List<Band> bands)
    {
        float left = 0f;
        foreach (List<Vector2> p in Pieces(rect, bands)) left += Area(p);
        return Mathf.Abs(left - rect.W * rect.D) < 0.001f;
    }

    void DiagonalPaving()
    {
        List<Band> road = Bands(0f);
        List<Band> kerbed = Bands(F(cfg["sidewalk"]));
        float depth = F(cfg["river_depth"]);
        foreach (R side in cutWalls)
            foreach (List<Vector2> p in Pieces(side, road)) Prism(p, PAVE_TOP, depth + 0.5f, stone, Kind(K_CONCRETE, -depth));
        foreach (S.GDict block in cutBlocks)
        {
            foreach (List<Vector2> p in Pieces(Rect(S.CityGen.Pavement(block, cfg)), road)) Prism(p, PAVE_TOP, KERB, pavement, Kind(K_PAVEMENT));
            string use = S.Gd.Str(block["use"]);
            if (use != "park" && use != "parking") continue;
            bool park = use == "park";
            R inner = Rect(block["rect"]).Grow(park ? -0.5f : -0.6f);
            foreach (List<Vector2> p in Pieces(inner, kerbed))
                Prism(p, PAVE_TOP + (park ? 0.02f : 0.01f), KERB, park ? outskirts : Lightened(asphalt, 0.06f), Kind(park ? K_LAWN : K_ASPHALT));
        }
        // Where the diagonal crosses a street: the street's asphalt, its gutter off, over both.
        foreach (Piece street in streetPieces)
        {
            var data = new Vector4(street.data.x, street.data.y, street.data.z, -Mathf.Abs(street.data.w));
            foreach (List<Vector2> quad in diagonalPieces)
            {
                List<Vector2> common = street.rect.Poly();
                Vector2 mid = (quad[0] + quad[2]) * 0.5f;
                for (int i = 0; i < 4 && common.Count >= 3; i++)
                {
                    Vector2 a = quad[i], b = quad[(i + 1) % 4];
                    var n = new Vector2(-(b - a).y, (b - a).x);
                    if (Vector2.Dot(n, mid - a) < 0f) n = -n;
                    common = Clip(common, n, Vector2.Dot(n, a));
                }
                if (common.Count >= 3 && Area(common) > 0f) Prism(common, CROSSING_TOP, 0.01f, asphalt, data);
            }
        }
    }

    // ---- quay and harbour (city_ground.gd, harbour_view.gd) ----

    void Quay()
    {
        Vector4 wet = Kind(K_CONCRETE, WATER_Y);
        foreach (R edge in Cut(new List<R> { new R(-FAR, coast, FAR, coast + 3f) }, basin))
            Box(edge, PAVE_TOP + 0.3f, 1.6f, Darkened(pavement, 0.15f), wet);
        foreach (R lip in Cut(new List<R> { new R(-FAR, coast - 0.4f, FAR, coast) }, basin))
            Box(lip, PAVE_TOP + 0.7f, 1f, Darkened(pavement, 0.3f), wet);
    }

    static float[] BandsAt(S.GDict h, float x)
    {
        S.PackedFloat32Array at = S.CityHarbour.Bands(h, x);
        return new[] { (float)at[0], (float)at[1], (float)at[2], (float)at[3] };
    }

    void Harbour()
    {
        if (!plan.Has("harbour")) return;
        S.GDict b = plan["harbour"];
        S.GDict h = b["h"];
        R rect = Rect(b["rect"]);
        float east = F(b["beach_east"]), quay = F(b["quay_z"]), sea = (float)S.CityHarbour.Sea(cfg);
        float kerbEast = BandsAt(h, east)[2];
        Face(new R(east, quay, rect.x1, kerbEast), PAVE_TOP + 0.3f, 1.6f, Darkened(pavement, 0.15f), sea);
        foreach (R pier in Rects(b["piers"])) Face(pier, PAVE_TOP + 0.3f, 1.6f, Darkened(pavement, 0.15f), sea);
        foreach (R wall in Rects(b["walls"])) Face(wall, PAVE_TOP + 0.3f, 1.6f, Darkened(pavement, 0.15f), sea);

        float street = (float)S.CityGen.WidthOf(S.CityGen.STREET, cfg) * 0.5f;
        var sides = new List<float>();
        S.GArray<double> sideList = b["sides"];
        foreach (double s in sideList) sides.Add((float)s);
        for (float x = rect.x0; x < rect.x1 - 0.001f;)
        {
            float w = Mathf.Min(COLUMN, rect.x1 - x);
            if (x < east) w = Mathf.Min(w, east - x);
            float mid = x + w * 0.5f;
            float[] at = BandsAt(h, mid);
            if (x < east) Box(new R(x, at[1], x + w, at[2]), PAVE_TOP, KERB, pavement, Kind(K_PAVEMENT));
            Box(new R(x, at[2], x + w, at[3]), ROAD_TOP, KERB, asphalt, Kind(K_ASPHALT));
            var back = new R(x, at[3], x + w, rect.z1);
            if (sides.Exists(s => Mathf.Abs(mid - s) < street)) Box(back, ROAD_TOP, KERB, asphalt, Kind(K_ASPHALT));
            else if (x >= east) Box(back, PAVE_TOP, KERB, Darkened(pavement, 0.15f), Kind(K_CONCRETE));
            else Box(back, PAVE_TOP, KERB, pavement, Kind(K_PAVEMENT));
            x += w;
        }
        float mouth = F(b["mouth"]), reach = quay;
        S.PackedVector2Array arc = S.CityHarbour.Arc(plan, cfg);
        foreach (S.Vector2 p in arc) reach = Mathf.Max(reach, V(p).y);
        WaterSheet(new R(rect.x0, mouth, rect.x1, reach), sea, true, true);
        Beach(b, rect, east, arc);
    }

    void Beach(S.GDict b, R rect, float east, S.PackedVector2Array arc)
    {
        S.GDict h = cfg["harbour"];
        S.GDict lap = S.Content.Section("water")["lap"];
        float wetWidth = F(lap["wet_width"]);
        float reach = Mathf.Max(F(h["shelf"]), F(h["beach"]) + 2f * F(h["hollow"]) + F(h["hollow_edge"]));
        float z0 = float.PositiveInfinity, z1 = float.NegativeInfinity;
        foreach (S.Vector2 sp in arc)
        {
            Vector2 p = V(sp);
            z0 = Mathf.Min(z0, p.y - reach);
            z1 = Mathf.Max(z1, BandsAt(h, p.x)[1]);
        }
        float x0 = rect.x0;
        int nx = Mathf.CeilToInt((east - x0) / CELL), nz = Mathf.CeilToInt((z1 - z0) / CELL);
        S.GDict planH = b["h"];
        double top = S.Num.F(h["sand_top"]), waterline = S.CityHarbour.Waterline(cfg), shelf = S.CityHarbour.ShelfFloor(cfg);
        var own = new double[nx + 1];
        var plans = new double[nx + 1];
        for (int i = 0; i <= nx; i++)
        {
            double x = Math.Min(x0 + i * (double)CELL, east);
            own[i] = S.CityHarbour.ShoreAt(h, x);
            plans[i] = S.CityHarbour.ShoreAt(planH, x);
        }
        int count = (nx + 1) * (nz + 1);
        var ground = new Vector3[count];
        var ups = new float[count];
        for (int j = 0; j <= nz; j++)
        {
            for (int i = 0; i <= nx; i++)
            {
                var p = new S.Vector2(Math.Min(x0 + i * (double)CELL, east), z0 + j * (double)CELL);
                double y = (double)p.y;
                double up = y - own[i] + waterline;
                double off = up >= 0.0 ? top : shelf;
                double floor = S.CityHarbour.HoldsAt(plan, p, plans[i]) ? S.CityHarbour.FloorHeld(plan, cfg, p, own[i]) : off;
                int k = j * (nx + 1) + i;
                ground[k] = new Vector3(Mathf.Min(x0 + i * CELL, east), (float)floor, z0 + j * CELL);
                ups[k] = Mathf.Clamp01((float)(up / wetWidth));
            }
        }
        var sums = new Vector3[count];
        void Add(int a, int c, int e)
        {
            Vector3 n = Vector3.Cross(ground[a] - ground[e], ground[a] - ground[c]).normalized;
            sums[a] += n;
            sums[c] += n;
            sums[e] += n;
        }
        for (int j = 0; j < nz; j++)
        {
            for (int i = 0; i < nx; i++)
            {
                int q = j * (nx + 1) + i, r = q + nx + 1;
                Add(q, q + 1, r + 1);
                Add(q, r + 1, r);
            }
        }
        int id = AddSlab(sand, new Vector4(K_SAND, 0f, 0f, 0f), Vector2.right, Vector2.zero, Vector2.one);
        int first = verts.Count;
        for (int k = 0; k < count; k++)
            Vert(ground[k], sums[k].normalized, id, ups[k], Vector2.zero);
        Vector3 upN = new Vector3(0f, 1f, 0f);
        for (int j = 0; j < nz; j++)
        {
            for (int i = 0; i < nx; i++)
            {
                int q = first + j * (nx + 1) + i, r = q + nx + 1;
                Tri(q, q + 1, r + 1, upN);
                Tri(q, r + 1, r, upN);
            }
        }
    }

    void WaterSheet(R rect, float y, bool bay, bool lap)
    {
        Sheets.Add(new WaterRect { x0 = rect.x0, z0 = rect.z0, x1 = rect.x1, z1 = rect.z1, y = y, bay = bay, lap = lap });
    }

    // ---- road paint (road_paint.gd) ----

    S.GDict rp;
    Dictionary<int, List<(Vector2 from, Vector2 to, float half)>> crossing;
    Dictionary<Vector2, int> nodeIndex;

    void Markings()
    {
        rp = cfg["road_paint"];
        S.GArray<S.Vector2> nodes = plan["nodes"];
        S.GArray<S.GDict> streets = plan["streets"];
        var positions = new Vector2[nodes.Size()];
        nodeIndex = new Dictionary<Vector2, int>();
        for (int i = 0; i < positions.Length; i++)
        {
            positions[i] = V(nodes[i]);
            if (!nodeIndex.ContainsKey(positions[i])) nodeIndex[positions[i]] = i;
        }
        crossing = new Dictionary<int, List<(Vector2, Vector2, float)>>();
        foreach (S.GDict street in streets)
        {
            if (S.Gd.Str(street["kind"]) == S.CityGen.ALLEY) continue;
            int a = (int)S.Num.I(street["from"]), b = (int)S.Num.I(street["to"]);
            var road = (positions[a], positions[b], F(street["width"]) * 0.5f);
            foreach (int e in new[] { a, b })
            {
                if (!crossing.TryGetValue(e, out var list)) crossing[e] = list = new List<(Vector2, Vector2, float)>();
                list.Add(road);
            }
        }
        HashSet<int> zebras = ZebraJunctions(positions, streets);
        foreach (S.GDict street in streets)
        {
            string kind = S.Gd.Str(street["kind"]);
            float width = F(street["width"]);
            if (kind == S.CityGen.ALLEY || width < F(rp["two_lane_min"])) continue;
            int ea = (int)S.Num.I(street["from"]), eb = (int)S.Num.I(street["to"]);
            Vector2 a = positions[ea], b = positions[eb];
            if (Mathf.Min(a.y, b.y) < coast) continue;
            Vector2 dir = (b - a).normalized;
            var near = NearCrossings(ea, eb, dir);
            float lift = PAINT + (kind == S.CityGen.DIAGONAL ? DIAG_TOP : 0f);
            RoadLines(a, dir, Vector2.Distance(a, b), width, lift, near);
            if (kind == S.CityGen.DIAGONAL) continue;
            JunctionEnd(positions[ea], dir, width, near, ea, zebras);
            JunctionEnd(positions[eb], -dir, width, near, eb, zebras);
        }
        if (plan.Has("harbour")) HarbourPaint();
    }

    HashSet<int> ZebraJunctions(Vector2[] nodes, S.GArray<S.GDict> streets)
    {
        var alongX = new HashSet<int>();
        var alongZ = new HashSet<int>();
        foreach (S.GDict street in streets)
        {
            if (S.Gd.Str(street["kind"]) != S.CityGen.AVENUE) continue;
            int a = (int)S.Num.I(street["from"]), b = (int)S.Num.I(street["to"]);
            HashSet<int> set = Same(nodes[a].y, nodes[b].y) ? alongX : alongZ;
            set.Add(a);
            set.Add(b);
        }
        var both = new List<int>();
        foreach (int n in alongX)
            if (alongZ.Contains(n) && nodes[n].y >= coast) both.Add(n);
        both.Sort((p, q) =>
        {
            float dp = nodes[p].magnitude, dq = nodes[q].magnitude;
            if (!Same(dp, dq)) return dp.CompareTo(dq);
            return nodes[p].x != nodes[q].x ? nodes[p].x.CompareTo(nodes[q].x) : nodes[p].y.CompareTo(nodes[q].y);
        });
        var o = new HashSet<int>();
        for (int k = 0; k < Mathf.Min((int)S.Num.I(cfg["zebra_junctions"]), both.Count); k++) o.Add(both[k]);
        return o;
    }

    List<(Vector2 from, Vector2 to, float half)> NearCrossings(int ea, int eb, Vector2 dir)
    {
        var o = new List<(Vector2, Vector2, float)>();
        foreach (int end in new[] { ea, eb })
        {
            if (!crossing.TryGetValue(end, out var roads)) continue;
            foreach (var road in roads)
            {
                foreach (Vector2 far in new[] { road.from, road.to })
                {
                    if (!crossing.TryGetValue(nodeIndex[far], out var others)) continue;
                    foreach (var other in others)
                    {
                        Vector2 d = (other.to - other.from).normalized;
                        if (Mathf.Abs(Cross2(d, dir)) > DASH_SLANT && !o.Contains(other)) o.Add(other);
                    }
                }
            }
        }
        return o;
    }

    static bool OnCrossing(Vector2 p, List<(Vector2 from, Vector2 to, float half)> roads, float margin)
    {
        foreach (var road in roads)
        {
            float reach = road.half + margin;
            Vector2 dir = (road.to - road.from).normalized;
            float along = Vector2.Dot(p - road.from, dir);
            if (along > -reach && along < Vector2.Distance(road.from, road.to) + reach && Mathf.Abs(Cross2(p - road.from, dir)) < reach) return true;
        }
        return false;
    }

    void JunctionEnd(Vector2 at, Vector2 toward, float width, List<(Vector2 from, Vector2 to, float half)> near, int node, HashSet<int> zebras)
    {
        float box = 0f;
        if (crossing.TryGetValue(node, out var roads))
            foreach (var road in roads)
                if (Mathf.Abs(Cross2((road.to - road.from).normalized, toward)) >= PERPENDICULAR) box = Mathf.Max(box, road.half);
        bool zebra = zebras.Contains(node);
        if (box > 0f) StopLine(at, toward, width, box + (zebra ? ZEBRA_OFF + ZEBRA_HALF : 0f), near);
        if (!zebra) return;
        var clear = near.FindAll(road => road.from != at && road.to != at);
        Zebra(at + toward * (width * 0.5f + ZEBRA_OFF), toward, width, clear);
    }

    void StopLine(Vector2 node, Vector2 toward, float width, float extra, List<(Vector2 from, Vector2 to, float half)> near)
    {
        float inset = F(rp["stop_inset"]);
        float along = width * 0.5f - inset - F(rp["edge_inset"]);
        var side = new Vector2(toward.y, -toward.x);
        float thick = F(rp["stop_width"]);
        Vector2 at = node + toward * (extra + F(rp["stop_gap"]) + thick * 0.5f);
        Vector2 mid = at + side * (inset + along * 0.5f);
        foreach (float end in new[] { -1f, 1f })
            foreach (float ahead in new[] { -1f, 1f })
                if (OnCrossing(mid + side * (along * 0.5f * end) + toward * (thick * 0.5f * ahead), near, 0f)) return;
        Stripe(mid, side, thick, along, PAINT);
    }

    void Stripe(Vector2 p, Vector2 along, float across, float length, float y)
    {
        // Its z axis runs along the road (road_paint _stripe's Basis): x is along turned the other way.
        PaintBox(p, new Vector2(along.y, -along.x), new Vector2(across * 0.5f, length * 0.5f), y + PAINT_THICK * 0.5f, asphalt);
    }

    void RoadLines(Vector2 a, Vector2 dir, float length, float width, float y, List<(Vector2 from, Vector2 to, float half)> near)
    {
        var side = new Vector2(-dir.y, dir.x);
        int lanes = Mathf.FloorToInt(width / (2f * F(rp["lane_width"])));
        if (width >= F(rp["double_min"]))
        {
            float gap = F(rp["double_gap"]) * 0.5f;
            Solid(a + side * gap, dir, length, width, y, near);
            Solid(a - side * gap, dir, length, width, y, near);
        }
        else
        {
            Dashes(a, dir, length, width, y, near);
        }
        for (int k = 1; k < lanes; k++)
        {
            float off = width * 0.5f * k / lanes;
            Dashes(a + side * off, dir, length, width, y, near);
            Dashes(a - side * off, dir, length, width, y, near);
        }
        if (lanes <= 1) return;
        float edge = width * 0.5f - F(rp["edge_inset"]);
        Solid(a + side * edge, dir, length, width, y, near);
        Solid(a - side * edge, dir, length, width, y, near);
    }

    void Dashes(Vector2 a, Vector2 dir, float length, float width, float y, List<(Vector2 from, Vector2 to, float half)> near)
    {
        float clear = F(rp["dash_clear"]), pitch = F(rp["dash_pitch"]), lineW = F(rp["line_width"]), dash = F(rp["dash_length"]);
        for (float t = width * 0.5f + clear; t < length - width * 0.5f - clear; t += pitch)
        {
            Vector2 p = a + dir * t;
            if (!OnCrossing(p, near, clear)) Stripe(p, dir, lineW, dash, y);
        }
    }

    void Solid(Vector2 a, Vector2 dir, float length, float width, float y, List<(Vector2 from, Vector2 to, float half)> near)
    {
        float clear = F(rp["dash_clear"]), step = F(rp["solid_step"]), lineW = F(rp["line_width"]);
        float last = length - width * 0.5f - clear, from = -1f;
        for (float t = width * 0.5f + clear; t <= last + 0.0001f; t += step)
        {
            bool open = !OnCrossing(a + dir * t, near, clear);
            if (open && from < 0f) from = t;
            if (from >= 0f && (!open || t + step > last))
            {
                float to = open ? t : t - step;
                if (to > from) Stripe(a + dir * ((from + to) * 0.5f), dir, lineW, to - from, y);
                from = -1f;
            }
        }
    }

    void Zebra(Vector2 at, Vector2 along, float width, List<(Vector2 from, Vector2 to, float half)> clear)
    {
        var across = new Vector2(-along.y, along.x);
        int n = Mathf.FloorToInt(width / 0.6f);
        for (int i = 0; i < n; i++)
            foreach (float end in new[] { -ZEBRA_HALF, ZEBRA_HALF })
                if (OnCrossing(at + across * ((i + 0.5f) * 0.6f - width * 0.5f) + along * end, clear, 0f)) return;
        for (int i = 0; i < n; i++)
            Stripe(at + across * ((i + 0.5f) * 0.6f - width * 0.5f), along, 0.3f, 1.2f, PAINT);
    }

    void HarbourPaint()
    {
        S.GDict b = plan["harbour"];
        S.GDict h = b["h"];
        R rect = Rect(b["rect"]);
        float road = F(h["road"]), gap = F(rp["double_gap"]) * 0.5f, lineW = F(rp["line_width"]);
        Vector2 Centre(float x)
        {
            float[] at = BandsAt(h, x);
            return new Vector2(x, (at[2] + at[3]) * 0.5f);
        }
        for (float x = rect.x0; x < rect.x1 - 0.001f; x += COLUMN)
        {
            Vector2 a = Centre(x), c = Centre(Mathf.Min(x + COLUMN, rect.x1));
            Vector2 dir = (c - a).normalized, side = new Vector2(-dir.y, dir.x);
            float len = Vector2.Distance(a, c);
            Stripe((a + c) * 0.5f + side * gap, dir, lineW, len, PAINT);
            Stripe((a + c) * 0.5f - side * gap, dir, lineW, len, PAINT);
        }
        R bay = Rect(plan["bay"]);
        float width = (float)S.CityGen.WidthOf(S.CityGen.STREET, cfg);
        S.GArray<double> sides = b["sides"];
        var none = new List<(Vector2, Vector2, float)>();
        foreach (double sd in sides)
        {
            float sx = (float)sd;
            float kerb = BandsAt(h, sx)[3];
            Dashes(new Vector2(sx, kerb), Vector2.up, rect.z1 - kerb, 0f, PAINT, none);
            StopLine(Centre(sx), Vector2.up, width, road * 0.5f, none);
            StopLine(new Vector2(sx, bay.z1), Vector2.down, width, bay.z1 - rect.z1, none);
        }
    }

    // ---- rects ----

    static List<R> Cut(List<R> rects, List<R> holes)
    {
        var o = rects;
        foreach (R hole in holes)
        {
            var left = new List<R>();
            foreach (R r in o)
            {
                if (!r.Overlaps(hole))
                {
                    left.Add(r);
                    continue;
                }
                float cz0 = Mathf.Max(r.z0, hole.z0), cz1 = Mathf.Min(r.z1, hole.z1), cx0 = Mathf.Max(r.x0, hole.x0), cx1 = Mathf.Min(r.x1, hole.x1);
                if (cz0 > r.z0) left.Add(new R(r.x0, r.z0, r.x1, cz0));
                if (cz1 < r.z1) left.Add(new R(r.x0, cz1, r.x1, r.z1));
                if (cx0 > r.x0) left.Add(new R(r.x0, cz0, cx0, cz1));
                if (cx1 < r.x1) left.Add(new R(cx1, cz0, r.x1, cz1));
            }
            o = left;
        }
        return o;
    }

    // ---- the mesh ----

    int AddSlab(Color color, Vector4 data, Vector2 axis, Vector2 centre, Vector2 half)
    {
        slabs.Add(new Slab
        {
            color = new Vector4(color.r, color.g, color.b, 1f),
            data = data,
            axes = new Vector4(axis.x, axis.y, centre.x, centre.y),
            extent = new Vector4(half.x, half.y, 0f, 0f),
        });
        return slabs.Count - 1;
    }

    void Vert(Vector3 p, Vector3 n, int id, float wet, Vector2 local)
    {
        verts.Add(new Vector3(p.x, p.y, -p.z));
        normals.Add(new Vector3(n.x, n.y, -n.z));
        uv0.Add(new Vector2(id, wet));
        uv1.Add(local);
    }

    // A triangle of written vertices, wound so its front faces normal (Godot's axes).
    void Tri(int a, int b, int c, Vector3 normal)
    {
        var n = new Vector3(normal.x, normal.y, -normal.z);
        if (Vector3.Dot(Vector3.Cross(verts[b] - verts[a], verts[c] - verts[a]), n) > 0f)
        {
            tris.Add(a);
            tris.Add(b);
            tris.Add(c);
        }
        else
        {
            tris.Add(a);
            tris.Add(c);
            tris.Add(b);
        }
    }

    void Quad(Vector3 a, Vector3 b, Vector3 c, Vector3 d, Vector3 n, int id, Vector2 la, Vector2 lb, Vector2 lc, Vector2 ld)
    {
        int k = verts.Count;
        Vert(a, n, id, 0f, la);
        Vert(b, n, id, 0f, lb);
        Vert(c, n, id, 0f, lc);
        Vert(d, n, id, 0f, ld);
        Tri(k, k + 1, k + 2, n);
        Tri(k, k + 2, k + 3, n);
    }

    void Flat(int id, Vector2 centre, Vector2 axis, Vector2 half, float y)
    {
        var side = new Vector2(-axis.y, axis.x);
        Vector3 At(float lx, float lz)
        {
            Vector2 p = centre + axis * lx + side * lz;
            return new Vector3(p.x, y, p.y);
        }
        Quad(At(-half.x, -half.y), At(half.x, -half.y), At(half.x, half.y), At(-half.x, half.y), Vector3.up, id,
            new Vector2(-half.x, -half.y), new Vector2(half.x, -half.y), new Vector2(half.x, half.y), new Vector2(-half.x, half.y));
    }

    void Box(R rect, float top, float thick, Color color, Vector4 data) =>
        Turned(rect.Centre, Vector2.right, new Vector2(rect.W, rect.D) * 0.5f, top, thick, color, data);

    // A flat box over a rectangle turned about the vertical: the slab's own x axis is `axis`.
    void Turned(Vector2 centre, Vector2 axis, Vector2 half, float top, float thick, Color color, Vector4 data)
    {
        int id = AddSlab(color, data, axis, centre, half);
        Flat(id, centre, axis, half, top);
        var side = new Vector2(-axis.y, axis.x);
        float low = top - thick;
        var corners = new[] { new Vector2(-half.x, -half.y), new Vector2(half.x, -half.y), new Vector2(half.x, half.y), new Vector2(-half.x, half.y) };
        for (int i = 0; i < 4; i++)
        {
            Vector2 la = corners[i], lb = corners[(i + 1) % 4];
            Vector2 a = centre + axis * la.x + side * la.y, b = centre + axis * lb.x + side * lb.y;
            Vector2 mid = (la + lb) * 0.5f;
            Vector2 outward = (axis * mid.x + side * mid.y).normalized;
            Quad(new Vector3(a.x, top, a.y), new Vector3(b.x, top, b.y), new Vector3(b.x, low, b.y), new Vector3(a.x, low, a.y),
                new Vector3(outward.x, 0f, outward.y), id, la, lb, lb, la);
        }
        // The underside only where a face hangs over the water (an abutment under a bridge deck).
        if (top < 0f)
        {
            int k = verts.Count;
            Vector3 down = Vector3.down;
            foreach (Vector2 l in corners)
            {
                Vector2 p = centre + axis * l.x + side * l.y;
                Vert(new Vector3(p.x, low, p.y), down, id, 0f, l);
            }
            Tri(k, k + 1, k + 2, down);
            Tri(k, k + 2, k + 3, down);
        }
    }

    // A paint mark's top face alone: 4 cm of side is never seen. `under` is what a chip shows.
    void PaintBox(Vector2 centre, Vector2 axis, Vector2 half, float top, Color under)
    {
        int id = AddSlab(PAINT_COLOR, new Vector4(K_PAINT, under.r, under.g, under.b), axis, centre, half);
        Flat(id, centre, axis, half, top);
    }

    void Prism(List<Vector2> poly, float top, float thick, Color color, Vector4 data)
    {
        Vector2 mid = Vector2.zero;
        foreach (Vector2 p in poly) mid += p / poly.Count;
        int id = AddSlab(color, data, Vector2.right, mid, new Vector2(REACH_NONE, REACH_NONE));
        int first = verts.Count;
        foreach (Vector2 p in poly) Vert(new Vector3(p.x, top, p.y), Vector3.up, id, 0f, Vector2.zero);
        for (int k = 1; k + 1 < poly.Count; k++) Tri(first, first + k, first + k + 1, Vector3.up);
        float low = top - thick;
        for (int k = 0; k < poly.Count; k++)
        {
            Vector2 a = poly[k], b = poly[(k + 1) % poly.Count];
            var o = new Vector2(b.y - a.y, a.x - b.x).normalized;
            if (Vector2.Dot(o, (a + b) * 0.5f - mid) < 0f) o = -o;
            Quad(new Vector3(a.x, top, a.y), new Vector3(b.x, top, b.y), new Vector3(b.x, low, b.y), new Vector3(a.x, low, a.y),
                new Vector3(o.x, 0f, o.y), id, Vector2.zero, Vector2.zero, Vector2.zero, Vector2.zero);
        }
    }

    void Build(Shader lit, Transform parent)
    {
        mesh = new Mesh { name = "ground", indexFormat = IndexFormat.UInt32 };
        mesh.SetVertices(verts);
        mesh.SetNormals(normals);
        mesh.SetUVs(0, uv0);
        mesh.SetUVs(1, uv1);
        mesh.SetTriangles(tris, 0, true);
        mesh.UploadMeshData(true);

        buffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, slabs.Count, 64);
        buffer.SetData(slabs);

        mat = new Material(lit);
        mat.EnableKeyword("SLICE_GROUND");
        mat.SetBuffer("_Slabs", buffer);
        S.GDict look = S.Content.Look();
        foreach (string key in BLOCK_KEYS) mat.SetFloat("g_" + key, F(look["ground_" + key]));
        mat.SetFloat("g_seed", S.Num.I(cfg["map_seed"]) % 997);
        mat.SetFloat("g_river_y", -F(cfg["river_depth"]));
        S.GDict lap = S.Content.Section("water")["lap"];
        mat.SetFloat("g_wet_dark", F(lap["wet_dark"]));
        mat.SetFloat("g_wet_rough", F(lap["wet_rough"]));

        var go = new GameObject("ground");
        go.transform.SetParent(parent, false);
        go.AddComponent<MeshFilter>().sharedMesh = mesh;
        var mr = go.AddComponent<MeshRenderer>();
        mr.sharedMaterial = mat;
        mr.shadowCastingMode = ShadowCastingMode.Off;
    }

    public void Dispose()
    {
        buffer?.Dispose();
        if (mesh != null) UnityEngine.Object.Destroy(mesh);
        if (mat != null) UnityEngine.Object.Destroy(mat);
    }
}
