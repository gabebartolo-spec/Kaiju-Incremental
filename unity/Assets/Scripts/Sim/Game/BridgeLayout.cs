// Generated from sim/bridge_layout.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class BridgeLayout : RefCounted
    {
        public static implicit operator BridgeLayout(Variant v) => (BridgeLayout)v.Obj;

        // The river bridges as voxel structures (D-389; the director 2026-10-30: carve is universal,
        // "Carve, spans drop", "Keep deck, add piers"). Each cross street's deck over the river
        // (CityRiver.bridges) is cut along the river into pieces about span long, each a building in
        // the city's list (RampageSim.Building with `bridge` set): an asphalt deck slab with its top at
        // street level, a stone parapet along each side, and a stone pier wall down to the riverbed at
        // each end (half a pier where two pieces meet, an abutment at each bank). Below the street: a
        // piece's local floor 0 is the riverbed, `bed` whole floors under the street (Building.base), so
        // its grid stands on layer 0 like any building's (VoxelFrame's ground), the piers are what
        // holds it there, and whatever falls lands on the riverbed, under the water. A deck stretch cut
        // off its piers is a part with nothing under it: it drops, or tips off the pier it still hangs
        // from, into the river (VoxelSupport's rules, as for any building). The cells are laid here once,
        // for the sim's grid (BuildingCells) and the view's voxels (BridgeVoxels) alike, in
        // building-local cells (RES per sim unit) over a box on whole world units. Pure sim; sizes:
        // tuning bridge.
        // Laid pieces by key: [cells (Vector3i -> material name), chunk layers].
        public static GDict _cache = new GDict();
        public static Mutex _lock = new Mutex();
        // The layout entries (CityGen's shape, plus "chunks" and "bridge") of every bridge's pieces,
        // west to east, each north to south. A piece's box is its deck's on whole world units; "x" and
        // "z" in `bridge` are the deck's own edges, which its cells fill.

        public static GArray<GDict> Pieces(GDict city, GDict cfg)
        {
            GArray<GDict> @out = new GArray<GDict>();
            if (!(Gd.Truthy(city.Get("river", false))))
            {
                return @out;
            }
            GArray<Variant> parapet = cfg["parapet"];
            long bed = Num.I(cfg["bed"]);
            foreach (Rect2 deck in CityRiver.Bridges(CityGen.Map(city), city))
            {
                long n = Gd.Maxi(1, Gd.Roundi(deck.size.y / Num.F(cfg["span"])));
                double @long = deck.size.y / n;
                double x0 = Gd.Floorf(deck.position.x);
                long w = Gd.Ceili(deck.end.x) - Gd.Roundi(x0);
                foreach (long k in Gd.Range(n))
                {
                    double za = deck.position.y + @long * k;
                    double zb = za + @long;
                    double z0 = Gd.Floorf(za);
                    long d = Gd.Ceili(zb) - Gd.Roundi(z0);
                    GDict entry = new GDict { { "x", x0 + w * 0.5 }, { "z", z0 + d * 0.5 }, { "w", w }, { "d", d }, { "h", Gd.Ceili(bed + Num.F(parapet[0])) }, { "tier", Num.I(cfg["tier"]) }, { "style", 0 }, { "bridge", new GDict { { "piece", k }, { "of", n }, { "x", Gd.Arr(deck.position.x, deck.end.x) }, { "z", Gd.Arr(za, zb) } } } };
                    entry["chunks"] = Laid(_Building(entry, bed), cfg, CellGrid.CellRes())[1];
                    @out.Append(entry);
                }
            }
            return @out;
        }
        // Appends the bridges' pieces to the sim's buildings (built like the city).
        // Returns the index of the first piece.

        public static long AddPieces(GArray<RampageSim.Building> buildings, GDict city, GDict cfg)
        {
            long first = buildings.Size();
            foreach (GDict entry in Pieces(city, cfg))
            {
                var b = Landmarks.Building(entry, Num.F(city["chunk_hp"]));
                b.bridge = entry["bridge"];
                b.@base = -Num.I(cfg["bed"]);
                b.startChunks = b.frame.aliveCount;
                // it breaks and pays, but the city's fall is its lots (CityBand's rule)
                b.inArena = false;
                buildings.Append(b);
            }
            return first;
        }

        public static RampageSim.Building _Building(GDict entry, long bed)
        {
            var b = new RampageSim.Building();
            b.x = Num.F(entry["x"]);
            b.z = Num.F(entry["z"]);
            b.w = Num.I(entry["w"]);
            b.d = Num.I(entry["d"]);
            b.height = Num.I(entry["h"]);
            b.bridge = entry["bridge"];
            b.@base = -bed;
            return b;
        }
        // A piece's cells (building-local, `res` per sim unit) -> material name, and the chunk layers
        // its Structure keeps (Structure.keep's shape: a "1" per chunk holding any cell). Laid once per
        // piece and shared: callers must not change them.

        public static GArray<Variant> Laid(RampageSim.Building b, GDict cfg, long res)
        {
            var key = Gd.Format("%s|%s|%d|%d|%d|%s|%d", Gd.Arr(b.x, b.z, b.w, b.d, b.height, Gd.Str(b.bridge), res));
            _lock.Lock();
            GArray<Variant> kept = _cache.Get(key, Gd.Arr());
            _lock.Unlock();
            if (!kept.IsEmpty())
            {
                return kept;
            }
            GDict cells = _Lay(b, cfg, res);
            GArray<Variant> layers = Gd.Arr();
            foreach (long y in Gd.Range(b.height))
            {
                layers.Append("0".Repeat(b.w * b.d));
            }
            foreach (Vector3i c in cells)
            {
                long y = c.y / res;
                long k = c.x / res + (c.z / res) * b.w;
                string row = layers[y];
                if (row.At(k) != "1")
                {
                    layers[y] = row.Substr(0, k) + "1" + row.Substr(k + 1);
                }
            }
            kept = Gd.Arr(cells, layers);
            _lock.Lock();
            _cache[key] = kept;
            _lock.Unlock();
            return kept;
        }
        // Every column whose centre lies on the deck: a pier (or abutment) column from the riverbed up
        // at the piece's ends, else the slab under the street; the asphalt on top of both, a parapet
        // over the deck's edges.

        public static GDict _Lay(RampageSim.Building b, GDict cfg, long res)
        {
            double r = Gd.Float(res);
            GArray<Variant> xs = b.bridge["x"];
            GArray<Variant> zs = b.bridge["z"];
            double left = b.x - b.w * 0.5;
            double north = b.z - b.d * 0.5;
            var xSpan = new Vector2(Num.F(xs[0]) - left, Num.F(xs[1]) - left) * r;
            double zLo = (Num.F(zs[0]) - north) * r;
            double zHi = (Num.F(zs[1]) - north) * r;
            long piece = Num.I(b.bridge["piece"]);
            long last = Num.I(b.bridge["of"]) - 1;
            double halfPier = Num.F(cfg["pier"]) * 0.5 * r;
            double abut = Num.F(cfg["abutment"]) * r;
            var ends = new Vector2((piece == 0 ? abut : halfPier), (piece == last ? abut : halfPier));
            GDict @out = new GDict();
            foreach (long cz in Gd.Range(b.d * res))
            {
                double z = cz + 0.5;
                if (z >= zLo && z < zHi)
                {
                    var pier = (z < zLo + ends.x || z >= zHi - ends.y);
                    _Row(@out, new Vector3i(cz, b.w * res, res), xSpan, pier, cfg);
                }
            }
            return @out;
        }
        // One row across the deck at local z cell at.x (at.y cells wide, at.z cells a unit), the deck's
        // own edges at x_span (local cells): every column on it, from the riverbed where a pier stands.

        public static void _Row(GDict @out, Vector3i at, Vector2 xSpan, bool pier, GDict cfg)
        {
            long res = at.z;
            // the street's level, in cells over the riverbed
            long top = Num.I(cfg["bed"]) * res;
            long slab = Gd.Maxi(1, Gd.Roundi(Num.F(cfg["slab"]) * res));
            GArray<Variant> parapet = cfg["parapet"];
            long railH = Gd.Roundi(Num.F(parapet[0]) * res);
            double railW = Num.F(parapet[1]) * res;
            foreach (long cx in Gd.Range(at.y))
            {
                double x = cx + 0.5;
                if ((x < xSpan.x || x >= xSpan.y))
                {
                    continue;
                }
                foreach (long y in Gd.Range((pier ? 0 : top - slab), top))
                {
                    @out[new Vector3i(cx, y, at.x)] = (y == top - 1 ? "bridge_deck" : "bridge_pier");
                }
                if ((x < xSpan.x + railW || x >= xSpan.y - railW))
                {
                    foreach (long y in Gd.Range(top, top + railH))
                    {
                        @out[new Vector3i(cx, y, at.x)] = "bridge_parapet";
                    }
                }
            }
        }

        void _InitFields()
        {
        }
        public BridgeLayout() { _InitFields(); }
    }
}
