// Generated from sim/rail_layout.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class RailLayout : RefCounted
    {
        public static implicit operator RailLayout(Variant v) => (RailLayout)v.Obj;

        // The railway's viaduct and station as voxel structures (D-247; the director 2026-10-25 "it needs
        // to be destroyed with the same logic as all other buildings", 2026-10-26 "carve is a universal
        // feature for all buildings"). The line is cut into pieces of piece_bays bays, each a building in
        // the city's list (RampageSim.Building with `rail` set): column bents every bay_length under a
        // concrete deck slab with parapets, ballast, sleepers and two rails per track; the pieces round
        // the station also carry its platforms, canopy on posts, a sign and stairs to the street. The
        // cells are laid here once, for the sim's grid (BuildingCells) and the view's voxels
        // (RailVoxels) alike, in building-local cells (RES per sim unit), so they carve, settle, fall and
        // pay by the very rules every building does (Carving, VoxelFrame, Collapse). Pure sim; sizes:
        // tuning rail.structure.
        // Laid pieces by key: [cells (Vector3i -> material name), chunk layers].
        public static GDict _cache = new GDict();
        public static Mutex _lock = new Mutex();
        // The line's north and south ends (world z): tuning "span" of the city's half extent, its north
        // end moved south to the first piece boundary past the sea bay's coast road when the line runs
        // up into the bay (CityHarbour: no street enters it, so the line starts at the beach, never
        // over the water).

        public static Vector2 Ends(GDict city, GDict cfg)
        {
            double half = CityGen.HalfExtent(city);
            GArray<Variant> span = cfg["span"];
            double north = half * Num.F(span[0]);
            var bay = CityHarbour.RectOf(city);
            double x = Rail.AvenueX(city);
            double reach = Num.F(cfg["deck_width"]) * 0.5;
            if ((bay.HasArea() && x + reach > bay.position.x && x - reach < bay.end.x && north < bay.end.y))
            {
                double @long = Num.F(cfg["bay_length"]) * Num.I(cfg["piece_bays"]);
                north = Gd.Ceilf(bay.end.y / @long) * @long;
            }
            return new Vector2(north, half * Num.F(span[1]));
        }
        // The station's platforms along the line (world z): whole pieces, enough for a train's length
        // and a little, centred as near station_share of the line as piece boundaries allow (both
        // tracks share the platforms). Whole pieces, so no piece carries a stub of platform, canopy
        // and stair too short to stand on its own (it toppled where the bay moved the line's end).

        public static Vector2 StationZ(GDict city, GDict cfg)
        {
            var line = Ends(city, cfg);
            double at = line.x + (line.y - line.x) * Num.F(cfg["station_share"]);
            double train = Num.I(cfg["cars"]) * (Num.F(cfg["car_length"]) + 0.3) + 2.0;
            double piece = Num.F(cfg["bay_length"]) * Num.I(cfg["piece_bays"]);
            double n = Gd.Ceilf(train / piece);
            double lo = Gd.Roundf(at / piece - n * 0.5) * piece;
            return new Vector2(lo, lo + n * piece);
        }
        // The layout entries (CityGen's shape, plus "chunks" and "rail") of the line's pieces, north to
        // south: whole pieces aligned to multiples of piece_bays x bay_length on z, covering the line.

        public static GArray<GDict> Pieces(GDict city, GDict cfg)
        {
            GDict s = cfg["structure"];
            var line = Ends(city, cfg);
            double @long = Num.F(cfg["bay_length"]) * Num.I(cfg["piece_bays"]);
            var st = StationZ(city, cfg);
            double deck = Num.F(cfg["deck_width"]);
            double plat = Num.F(s["platform"]) + Num.F(s["stair"]);
            GArray<Variant> parapet = s["parapet"];
            GArray<GDict> @out = new GArray<GDict>();
            foreach (long k in Gd.Range(Gd.Floori(line.x / @long), Gd.Ceili(line.y / @long)))
            {
                double a = k * @long;
                // a sliver carries none
                var station = Gd.Minf(st.y, a + @long) - Gd.Maxf(st.x, a) >= 1.0;
                double top = Num.F(cfg["deck_y"]) + ((station ? Num.F(s["canopy"]) : Num.F(parapet[0])));
                GDict entry = new GDict { { "x", Rail.AvenueX(city) }, { "z", a + @long * 0.5 }, { "w", (station ? Gd.Ceili(deck + plat * 2.0) : Gd.Ceili(deck)) }, { "d", Gd.Roundi(@long) }, { "h", Gd.Ceili(top + 0.25) }, { "tier", Num.I(s["tier"]) }, { "style", 0 }, { "rail", new GDict { { "piece", k }, { "station", (station ? Gd.Arr(st.x, st.y) : Gd.Arr()) } } } };
                entry["chunks"] = Laid(_Building(entry), cfg, CellGrid.CellRes())[1];
                @out.Append(entry);
            }
            return @out;
        }
        // Appends the railway's pieces to the sim's buildings (built like the city).
        // Returns the index of the first piece.

        public static long AddPieces(GArray<RampageSim.Building> buildings, GDict city, GDict cfg)
        {
            long first = buildings.Size();
            foreach (GDict entry in Pieces(city, cfg))
            {
                var b = Landmarks.Building(entry, Num.F(city["chunk_hp"]));
                b.rail = entry["rail"];
                b.startChunks = b.frame.aliveCount;
                // it breaks and pays, but the city's fall is its lots (CityBand's rule)
                b.inArena = false;
                buildings.Append(b);
            }
            return first;
        }

        public static RampageSim.Building _Building(GDict entry)
        {
            var b = new RampageSim.Building();
            b.x = Num.F(entry["x"]);
            b.z = Num.F(entry["z"]);
            b.w = Num.I(entry["w"]);
            b.d = Num.I(entry["d"]);
            b.height = Num.I(entry["h"]);
            b.rail = entry["rail"];
            return b;
        }
        // Where along the line (from its north end) piece b's deck is gone under a track: every
        // stretch (one sim unit) whose deck chunk under either track has left the chunk mirror (Carving:
        // at most chunk_alive_share of its cells are left).

        public static GArray<double> DeckGaps(RampageSim.Building b, Rail rail)
        {
            GArray<double> @out = new GArray<double>();
            long deckFloor = Gd.Floori(Num.F(rail.cfg["deck_y"]));
            double north = rail.Point(0.0, 1).y;
            foreach (long dir in Gd.Arr(1, -1))
            {
                long cx = Gd.Clampi(Gd.Floori(rail.TrackX(dir) - (b.x - b.w * 0.5)), 0, b.w - 1);
                foreach (long cz in Gd.Range(b.d))
                {
                    double s = b.z - b.d * 0.5 + cz + 0.5 - north;
                    if (s >= 0.0 && s <= rail.length && !(b.frame.Alive(new Vector3i(cx, deckFloor, cz))))
                    {
                        @out.Append(s);
                    }
                }
            }
            return @out;
        }
        // A piece's cells (building-local, `res` per sim unit) -> material name, and the chunk layers
        // its Structure keeps (Structure.keep's shape: a "1" per chunk holding any cell). Laid once per
        // piece and shared: callers must not change them.

        public static GArray<Variant> Laid(RampageSim.Building b, GDict cfg, long res)
        {
            var key = Gd.Format("%s|%s|%d|%d|%d|%s|%d", Gd.Arr(b.x, b.z, b.w, b.d, b.height, Gd.Str(b.rail), res));
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
                var row = "0".Repeat(b.w * b.d);
                layers.Append(row);
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

        public static GDict _Lay(RampageSim.Building b, GDict cfg, long res)
        {
            var g = new _Geometry(b, cfg, res);
            GDict @out = new GDict();
            foreach (long cz in Gd.Range(g.nz))
            {
                long zw = g.zCell0 + cz;
                var bent = g.BentAt(cz);
                var inStation = g.Station(cz);
                foreach (long cx in Gd.Range(g.nx))
                {
                    double dx = cx + 0.5 - g.mid;
                    double ax = Gd.Absf(dx);
                    if (ax <= g.deckHalf)
                    {
                        _DeckColumn(g, @out, new Vector2i(cx, cz), dx, zw, inStation);
                        if (bent)
                        {
                            _BentColumn(g, @out, new Vector2i(cx, cz), ax);
                        }
                    }
                    else if (inStation && ax <= g.deckHalf + g.platform + g.stair)
                    {
                        _StationColumn(g, @out, new Vector2i(cx, cz), ax, cz);
                    }
                }
            }
            return @out;
        }
        // One column of the deck: the slab (seams across it), parapets at the edges outside the
        // station, ballast with sleepers and two rails per track on top.

        public static void _DeckColumn(RailLayout._Geometry g, GDict @out, Vector2i at, double dx, long zw, bool inStation)
        {
            var seam = Gd.Posmod(zw, g.seamEvery) == 0;
            foreach (long y in Gd.Range(g.top - g.slab + 1, g.top + 1))
            {
                @out[new Vector3i(at.x, y, at.y)] = (seam ? "viaduct_seam" : "viaduct_concrete");
            }
            double ax = Gd.Absf(dx);
            if (ax > g.deckHalf - g.parapetW)
            {
                if (!inStation)
                {
                    foreach (long y in Gd.Range(g.top + 1, g.top + 1 + g.parapetH))
                    {
                        @out[new Vector3i(at.x, y, at.y)] = "viaduct_parapet";
                    }
                }
                return;
            }
            foreach (double t in Gd.Arr(-g.track, g.track))
            {
                double e = Gd.Absf(dx - t);
                if (e > g.ballast)
                {
                    continue;
                }
                var sleeper = Gd.Posmod(zw, g.sleeperEvery) == 0;
                @out[new Vector3i(at.x, g.top + 1, at.y)] = (sleeper ? "viaduct_sleeper" : "viaduct_ballast");
                if (Gd.Absf(e - g.rail) < 0.5)
                {
                    @out[new Vector3i(at.x, g.top + 2, at.y)] = "viaduct_rail";
                }
            }
        }
        // A bent under the deck: a cap beam across it and two square columns down to the street.

        public static void _BentColumn(RailLayout._Geometry g, GDict @out, Vector2i at, double ax)
        {
            long capLo = g.top - g.slab + 1 - g.cap;
            if (ax <= g.deckHalf - g.parapetW)
            {
                foreach (long y in Gd.Range(capLo, capLo + g.cap))
                {
                    @out[new Vector3i(at.x, y, at.y)] = "viaduct_column";
                }
            }
            if (Gd.Absf(ax - g.columnX) < g.column * 0.5)
            {
                foreach (long y in Gd.Range(capLo))
                {
                    @out[new Vector3i(at.x, y, at.y)] = (y % g.res == 0 ? "viaduct_seam" : "viaduct_column");
                }
            }
        }
        // Beside the deck at the station: a platform (its edge by the tracks), the canopy over it on
        // posts along its outer edge, the sign under the canopy at the middle, the stairs at its end.

        public static void _StationColumn(RailLayout._Geometry g, GDict @out, Vector2i at, double ax, long cz)
        {
            double w = ax - g.deckHalf;
            if (w <= g.platform)
            {
                var edge = w < 1.0;
                foreach (long y in Gd.Range(g.top - 1, g.top + 1))
                {
                    var pave = (Gd.Posmod(cz + Gd.Int(w), 4) != 0 ? "station_platform" : "viaduct_seam");
                    @out[new Vector3i(at.x, y, at.y)] = (edge && y == g.top ? "station_edge" : pave);
                }
                var rib = Gd.Posmod(g.zCell0 + cz, g.res) == 0;
                @out[new Vector3i(at.x, g.canopy, at.y)] = (rib ? "station_rib" : "station_canopy");
                var outer = w > g.platform - 1.0;
                if (outer && Gd.Posmod(g.zCell0 + cz, g.postEvery) == 0)
                {
                    foreach (long y in Gd.Range(g.top + 1, g.canopy))
                    {
                        @out[new Vector3i(at.x, y, at.y)] = "viaduct_column";
                    }
                }
                else if (outer && Gd.Absf(cz - g.stationMid) <= g.res)
                {
                    foreach (long y in Gd.Range(g.canopy - 2, g.canopy))
                    {
                        @out[new Vector3i(at.x, y, at.y)] = "station_sign";
                    }
                }
                return;
            }
            // The stairs, past the platform at the station's south end: two cells per step so each
            // touches the next by a face (the support flood is face-connected).
            long rise = g.stationEnd - cz;
            foreach (long y in Gd.Arr(rise - 1, rise))
            {
                if (y >= 0 && y <= g.top)
                {
                    @out[new Vector3i(at.x, y, at.y)] = "station_stair";
                }
            }
        }
        // A piece's sizes in cells.

        public class _Geometry : RefCounted
        {
            public static implicit operator _Geometry(Variant v) => (_Geometry)v.Obj;

            public long res;
            public long nx;
            public long nz;
            public double mid;
            public long zCell0;
            public double deckHalf;
            public long top;
            public long slab;
            public long parapetH;
            public double parapetW;
            public double track;
            public double ballast;
            public double rail;
            public long sleeperEvery;
            public long seamEvery;
            public double column;
            public double columnX;
            public long cap;
            public double platform;
            public double stair;
            public long canopy;
            public long postEvery;
            // Bent z ranges in local cells ([from, to) pairs), the station's local z range and middle,
            // and its south end (local cells; past nz when it ends beyond this piece).
            public PackedInt32Array bents = new PackedInt32Array();
            public long stationLo = 0;
            public long stationHi = -1;
            public double stationMid = -1000.0;
            public long stationEnd = -1000;

            public _Geometry(RampageSim.Building b, GDict cfg, long pRes)
            {
                _InitFields();
                GDict s = cfg["structure"];
                res = pRes;
                double r = Gd.Float(res);
                nx = b.w * res;
                nz = b.d * res;
                mid = nx * 0.5;
                double z0 = b.z - b.d * 0.5;
                zCell0 = Gd.Roundi(z0 * r);
                deckHalf = Num.F(cfg["deck_width"]) * 0.5 * r;
                top = Gd.Roundi(Num.F(cfg["deck_y"]) * r) + 1;
                slab = Gd.Roundi(Num.F(s["slab"]) * r);
                GArray<Variant> parapet = s["parapet"];
                parapetH = Gd.Roundi(Num.F(parapet[0]) * r);
                parapetW = Num.F(parapet[1]) * r;
                track = Num.F(cfg["track_gap"]) * 0.5 * r;
                ballast = Num.F(s["ballast_half"]) * r;
                rail = Num.F(s["rail_offset"]) * r;
                sleeperEvery = Gd.Maxi(1, Gd.Roundi(Num.F(s["sleeper_every"]) * r));
                seamEvery = Gd.Maxi(1, Gd.Roundi(Num.F(s["seam_every"]) * r));
                column = Num.F(s["column"]) * r;
                columnX = deckHalf - Num.F(s["column_inset"]) * r;
                cap = Gd.Roundi(Num.F(s["cap"]) * r);
                platform = Num.F(s["platform"]) * r;
                stair = Num.F(s["stair"]) * r;
                canopy = Gd.Roundi((Num.F(cfg["deck_y"]) + Num.F(s["canopy"])) * r);
                postEvery = Gd.Maxi(1, Gd.Roundi(Num.F(s["post_every"]) * r));
                double bay = Num.F(cfg["bay_length"]);
                long col = Gd.Roundi(Num.F(s["column"]) * r);
                foreach (long j in Gd.Range(Gd.Ceili(z0 / bay - 0.001), Gd.Floori((z0 + b.d) / bay + 0.001) + 1))
                {
                    long at = Gd.Roundi((j * bay - z0) * r);
                    long lo = Gd.Clampi(at - col / 2, 0, nz - col);
                    bents.AppendArray(Gd.Arr(lo, lo + col));
                }
                GArray<Variant> st = b.rail.Get("station", Gd.Arr());
                if (!st.IsEmpty())
                {
                    stationLo = Gd.Roundi((Num.F(st[0]) - z0) * r);
                    stationHi = Gd.Roundi((Num.F(st[1]) - z0) * r);
                    stationMid = (stationLo + stationHi) * 0.5;
                    stationEnd = stationHi - 1;
                }
            }

            public bool BentAt(long cz)
            {
                foreach (long i in Gd.Range(0, bents.Size(), 2))
                {
                    if (cz >= bents[i] && cz < bents[i + 1])
                    {
                        return true;
                    }
                }
                return false;
            }

            public bool Station(long cz)
            {
                return cz >= stationLo && cz < stationHi;
            }

            void _InitFields()
            {
            }
        }

        void _InitFields()
        {
        }
        public RailLayout() { _InitFields(); }
    }
}
