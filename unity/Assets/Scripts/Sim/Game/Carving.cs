// Generated from sim/carving.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class Carving : RefCounted
    {
        public static implicit operator Carving(Variant v) => (Carving)v.Obj;

        // The rampage on the fine destruction grid (D-094 WP7; D-097 "true physics ... carving
        // included"; D-099 carved towers fall toward the cut side). A building's first hit promotes it
        // (CellPromoter: its BuildingCells grid in a VoxelFrame); from then on every blow carves its
        // cells, and VoxelFrame.settle() (VoxelSupport) decides what drops and what topples, and which
        // way. Part of RampageSim. Landmarks carve too ("carve is universal", director 2026-10-26): their
        // grid is LandmarkCells (WP6), and a ring landmark's arc (the stadium) that has lost
        // arc_shed_cells cells brings its section above the stub down as one topple before the settle,
        // the chunk Structure's rule (Arcs) on cells.
        //
        // Wear: each grid column keeps, per floor, the sum of every blow that reached it (the force at
        // that column, so a stomp's falloff carves a round crater); a cell breaks once its column's sum
        // reaches its material's strength x the building's chunk_hp, today's chunk rule cell by cell
        // (a building that dwarfs the kaiju takes Growth.dwarf_mult of each blow, D-091, and they
        // still add up).
        //
        // The chunk Structure stays as a coarse mirror for what still reads chunks (army squads, the
        // kaiju's blocking, nearest_standing): a chunk is gone once at most chunk_alive_share
        // of the cells it had at promotion are left, and only then pays its rubble and counts as
        // destroyed, as a broken chunk does today (one that falls pays when it lands, with the topple
        // bonus). Pure and deterministic: fixed scan orders, no RNG, no clock.
        // One promoted building's grid and the bookkeeping beside it.

        public class Grid : RefCounted
        {
            public static implicit operator Grid(Variant v) => (Grid)v.Obj;

            public VoxelFrame frame;
            // Per grid column and floor: the blows it has taken (x + z * w + floor * w * d).
            public PackedFloat32Array wear = new PackedFloat32Array();
            // Per chunk (Structure.index): cells left, cells at promotion, 1 once the chunk is gone.
            public PackedInt32Array live = new PackedInt32Array();
            public PackedInt32Array full = new PackedInt32Array();
            public PackedByteArray dead = new PackedByteArray();
            // Grid x, z, y -> the chunk column and floor that owns it (BuildingCells.clear_chunk's
            // rule: what stands proud of a face or above the roof belongs to the edge chunk).
            public PackedInt32Array cx = new PackedInt32Array();
            public PackedInt32Array cz = new PackedInt32Array();
            public PackedInt32Array fy = new PackedInt32Array();
            public long bw;
            public long bd;
            public long floors;
            public double hp;
            // A ring landmark's grid (its arcs count what it loses, LandmarkCells.shed), else null.
            public LandmarkCells ring;
            // What the blow being worked out has broken: grid indices and their materials.
            public PackedInt32Array removed = new PackedInt32Array();
            public PackedByteArray mats = new PackedByteArray();

            public long Chunk(long i)
            {
                long w = frame.w;
                long x = cx[i % w];
                long z = cz[(i / w) % frame.d];
                return x + z * bw + fy[i / (w * frame.d)] * bw * bd;
            }

            void _InitFields()
            {
            }
            public Grid() { _InitFields(); }
        }
        public RampageSim sim;
        // Off: every building stays on its chunk Structure (data/tuning.json destruction.carve).
        public bool on = false;
        public double aliveShare = 0.5;
        // How far beyond the kaiju's strike reach a building is warmed (sim units, tuning destruction),
        // and how far while it emerges (it strikes nothing then, so the nearest are made ready first).
        public double warmMargin = 3.0;
        public double warmEmergeMargin = 3.0;
        public CellPromoter promoter = new CellPromoter();
        // Building index -> Grid, for the buildings hit so far.
        public GDict grids = new GDict();
        // Cells carved by blows and cells that fell, over the rampage.
        public long cellsCarved = 0;
        public long cellsFallen = 0;
        public GArray<GDict> _materials = new GArray<GDict>();
        public PackedFloat32Array _strength = new PackedFloat32Array();
        public double _weakest = Gd.INF;
        public GArray<GDict> _party = new GArray<GDict>();
        // The building being warmed and the stage it is at (see warm()); -1 when none.
        public long _warming = -1;
        public long _warmStage = 0;

        public Carving(RampageSim pSim, GDict tuning)
        {
            _InitFields();
            sim = pSim;
            GDict cfg = tuning.Get("destruction", new GDict());
            on = cfg.Get("carve", false) == true;
            aliveShare = Num.F(cfg.Get("chunk_alive_share", 0.5));
            warmMargin = Num.F(cfg.Get("warm_margin", 3.0));
            warmEmergeMargin = Num.F(cfg.Get("warm_emerge_margin", warmMargin));
            promoter.ahead = Num.I(cfg.Get("warm_ahead", 0));
            _materials = Content.Materials();
            // a landmark's first hit then only builds its grid
            LandmarkCells.PreloadModels(on);
            _strength.Resize(256);
            foreach (GDict m in _materials)
            {
                double s = Num.F(m.Get("strength", 1.0));
                _strength[Num.I(m["id"])] = s;
                _weakest = Gd.Minf(_weakest, s);
            }
        }
        // True when building n is carved rather than broken by chunks.

        public bool Takes(long _n)
        {
            return on;
        }

        public bool Promoted(long n)
        {
            return grids.Has(n);
        }

        public VoxelFrame Frame(long n)
        {
            Carving.Grid g = grids.Get(n, default(Variant));
            return (g != null ? g.frame : null);
        }
        // Pre-promotion (b2-3): one stage of the work a building's first hit would otherwise do all at
        // once, per sim step, on the nearest buildings the kaiju can reach (or is about to) that are not
        // promoted yet: stage 0 generates its cells, stage 1 makes the fine grid, stage 2 does its first
        // settle. A hit that arrives first just does the stages it finds undone. Nearest first, ties
        // by building index: the same order for the same run. Nothing a hit would not do is done, only
        // sooner: the first settle's falls (if the generated grid had any) start as any settle's do.
        // While the kaiju emerges (Emergence.step) it warms out to warm_emerge_margin instead.

        public void Warm(bool emerging = false)
        {
            if (!on)
            {
                return;
            }
            if (_warming < 0)
            {
                double margin = (emerging ? warmEmergeMargin : warmMargin);
                _warming = WarmOrder.NextCold(this, sim.buildings, margin);
                _warmStage = 0;
                WarmOrder.Ahead(this, margin);
                if (_warming < 0)
                {
                    return;
                }
            }
            long n = _warming;
            if (_warmStage == 0)
            {
                CarvingPromote.CellsOf(this, n);
            }
            else if (_warmStage == 1)
            {
                _Promote(n);
            }
            else if (_warmStage == 2 && !(Frame(n).settledOnce))
            {
                sim.collapse.Settle(n);
            }
            _warmStage += 1;
            if (_warmStage > 2)
            {
                _warming = -1;
            }
        }
        // Makes the cells of every carvable building within warm_emerge_margin of the kaiju's strike
        // reach anywhere along a to b (the emergence's rise and bank), at load, so Emergence.step's
        // warm() finds stage 0 done (perf, director 2026-10-31). The warm schedule, and so the run, is
        // unchanged: nothing counts these as promoted, and nothing touches a building before the
        // kaiju emerges (Emergence drops what is left then).

        public void PrepareAlong(Vector2 a, Vector2 b)
        {
            if (!on)
            {
                return;
            }
            if (_party.IsEmpty())
            {
                _party = PartyWalls.Of(sim.buildings);
            }
            double reach = Gd.Maxf(2.0 * sim.StompRadius(), sim.AbilityReach()) + warmEmergeMargin;
            long steps = Gd.Maxi(1, Gd.Ceili(a.DistanceTo(b) / Gd.Maxf(1.0, sim.grid.pad)));
            foreach (long i in Gd.Range(steps + 1))
            {
                var p = a.Lerp(b, Gd.Float(i) / steps);
                foreach (long n in sim.grid.Around(p, reach + 2.0 * sim.grid.pad))
                {
                    if ((Promoted(n) || !Takes(n)))
                    {
                        continue;
                    }
                    var bd = sim.buildings[n];
                    double d = new Vector2(bd.x, bd.z).DistanceTo(p);
                    if (d - new Vector2(bd.w, bd.d).Length() * 0.5 <= reach)
                    {
                        promoter.Prepare(n, bd, _party[n]);
                    }
                }
            }
        }
        // A force-shaped blow (RampageSim.hit_area's force and damage) on floors floors.x..floors.y-1
        // of building n (a coating, sim.hit_coat, covers the chunks it reaches).

        public void Hit(long n, Callable force, double damage, Vector2i floors)
        {
            var b = sim.buildings[n];
            Carving.Grid g = grids.Get(n, default(Variant));
            var chunks = _Reached(b, g, force, floors);
            if (chunks.IsEmpty())
            {
                return;
            }
            if (!sim.hitCoat.IsEmpty())
            {
                sim.powers.Coat(n, chunks);
            }
            g = _Promote(n);
            var f = g.frame;
            long res = f.res;
            double mult = _Mult(b);
            // per chunk: its grid columns and floor
            var spans = new PackedInt32Array();
            foreach (Vector3i c in chunks)
            {
                var xs = _Span(c.x, b.w, f.offset.x, f.w, res);
                var zs = _Span(c.z, b.d, f.offset.z, f.d, res);
                spans.AppendArray(Gd.Arr(xs.x, xs.y, zs.x, zs.y, c.y));
            }
            var at = _ForceAt(b, f, spans, force);
            CarvingCells.Wear(this, g, spans, at, new PackedFloat32Array(), damage, mult);
            _Finish(n, g);
        }
        // The live chunks of b on floors [floors.x, floors.y) that force reaches, floor by floor; force
        // ignores height, so it is asked once per chunk column.

        public GArray<Vector3i> _Reached(RampageSim.Building b, Carving.Grid g, Callable force, Vector2i floors)
        {
            GArray<Vector3i> chunks = new GArray<Vector3i>();
            long top = Gd.Mini(floors.y, b.height);
            // per chunk column: 2 = not asked yet, 1 reached, 0 not
            var reached = new PackedByteArray();
            reached.Resize(b.w * b.d);
            reached.Fill(2);
            foreach (long y in Gd.Range(Gd.Maxi(0, floors.x), top))
            {
                foreach (long x in Gd.Range(b.w))
                {
                    foreach (long z in Gd.Range(b.d))
                    {
                        var c = new Vector3i(x, y, z);
                        if (!(((g == null ? b.frame.Alive(c) : g.live[b.frame.Index(c)] > 0))))
                        {
                            continue;
                        }
                        long i = x + z * b.w;
                        if (reached[i] == 2)
                        {
                            var p = b.ChunkWorld(c);
                            double k = force.Call(new Vector2(p.x, p.z), 0.5);
                            reached[i] = (k > 0.0 ? 1 : 0);
                        }
                        if (reached[i] == 1)
                        {
                            chunks.Append(c);
                        }
                    }
                }
            }
            return chunks;
        }
        // The force at each grid column the spans cover (-1 elsewhere): the beam's natively, else
        // force sampled once per column.

        public PackedFloat32Array _ForceAt(RampageSim.Building b, VoxelFrame f, PackedInt32Array spans, Callable force)
        {
            var at = CarvingCells.BeamAt(sim.hitBeam, b, f, spans);
            if (!at.IsEmpty())
            {
                return at;
            }
            long res = f.res;
            at.Resize(f.w * f.d);
            at.Fill(-1.0);
            foreach (long s in Gd.Range(0, spans.Size(), 5))
            {
                foreach (long gz in Gd.Range(spans[s + 2], spans[s + 3]))
                {
                    foreach (long gx in Gd.Range(spans[s], spans[s + 1]))
                    {
                        long col = gx + gz * f.w;
                        if (at[col] < 0.0)
                        {
                            var local = new Vector3(gx + f.offset.x + 0.5, 0.0, gz + f.offset.z + 0.5) / res;
                            var p = b.LocalToWorld(local);
                            double k = force.Call(new Vector2(p.x, p.z), 0.5 / res);
                            at[col] = Gd.Maxf(0.0, k);
                        }
                    }
                }
            }
            return at;
        }
        // Even blows on chunks of building n, each by its own amount (impacts, coatings, powers).
        // Returns the chunks that went.

        public long Apply(long n, GArray<Vector3i> cells, PackedFloat32Array amounts)
        {
            var b = sim.buildings[n];
            Carving.Grid g = grids.Get(n, default(Variant));
            GArray<long> hits = new GArray<long>();
            foreach (long k in Gd.Range(cells.Size()))
            {
                var c = cells[k];
                if (b.frame.Inside(c) && ((g == null ? b.frame.Alive(c) : g.live[b.frame.Index(c)] > 0)))
                {
                    hits.Append(k);
                }
            }
            if (hits.IsEmpty())
            {
                return 0;
            }
            g = _Promote(n);
            var f = g.frame;
            // per chunk hit: its grid columns and floor, and its blow
            var spans = new PackedInt32Array();
            var each = new PackedFloat32Array();
            foreach (long k in hits)
            {
                var c = cells[k];
                var xs = _Span(c.x, b.w, f.offset.x, f.w, f.res);
                var zs = _Span(c.z, b.d, f.offset.z, f.d, f.res);
                spans.AppendArray(Gd.Arr(xs.x, xs.y, zs.x, zs.y, c.y));
                each.Append(amounts[k]);
            }
            CarvingCells.Wear(this, g, spans, new PackedFloat32Array(), each, 0.0, _Mult(b));
            return _Finish(n, g);
        }
        // What lost support in building n since its last settle, in Collapse's part shape: "cells"
        // are the chunks the part took with it (they pay when it lands), and the fine part rides along
        // ("index": grid indices, "mats": their materials, "low" and "height" in floors, "width"
        // across a topple and "drop" for the rest, in sim units; "base": the footprint of its lowest
        // layer, building-local x, z; "gutted": nothing under that layer and taller than its narrower
        // side, Collapse's rule for a tower whose base went at once, D-099).

        public GArray<GDict> Settle(long n)
        {
            Carving.Grid g = grids[n];
            var f = g.frame;
            GArray<GDict> @out = new GArray<GDict>();
            foreach (GDict part in _Shed(g) + f.Settle(g.ring == null))
            {
                PackedInt32Array index = part["index"];
                _Lost(g, index);
                // g.live loses its cells
                GArray<Variant> info = CarvingCells.Fallen(g, index);
                cellsFallen += index.Size();
                @out.Append(CarvingCells.PartEvent(f, part, info, _Deaths(n, g)));
            }
            return @out;
        }
        // A ring landmark's arcs that lost arc_shed_cells cells (LandmarkCells.shed): each section above
        // the stub taken out of the grid as a topple over the stub's edge, the rim outward and the stands
        // inward, in settle()'s part shape.

        public GArray<GDict> _Shed(Carving.Grid g)
        {
            GArray<GDict> @out = new GArray<GDict>();
            if (g.ring == null)
            {
                return @out;
            }
            var f = g.frame;
            foreach (GDict section in g.ring.Shed())
            {
                var index = new PackedInt32Array();
                foreach (Vector3i c in Gd.Iter(section["cells"]))
                {
                    g.ring.ClearCell(c);
                    long i = f.Index(c);
                    if (f.cells[i] != VoxelFrame.EMPTY)
                    {
                        index.Append(i);
                    }
                }
                if (index.IsEmpty())
                {
                    continue;
                }
                GDict part = f.Take(index);
                Vector3 pivot = section["pivot"];
                part["kind"] = "topple";
                part["pivot"] = pivot / f.res;
                part["dir"] = section["dir"];
                @out.Append(part);
            }
            return @out;
        }
        // Cells that left grid g: a ring landmark's arcs count them (a cell already gone from its own
        // copy counts nothing).

        public void _Lost(Carving.Grid g, PackedInt32Array index)
        {
            if (g.ring == null)
            {
                return;
            }
            var f = g.frame;
            long plan = f.w * f.d;
            foreach (long i in index)
            {
                g.ring.ClearCell(new Vector3i(i % f.w, i / plan, (i / f.w) % f.d) + f.offset);
            }
        }
        // Building n's grid, made on its first hit (CarvingPromote.promote).

        public Carving.Grid _Promote(long n)
        {
            return CarvingPromote.Promote(this, n);
        }
        // By material id, the blow (in chunk_hp) that breaks a cell of it; and the weakest of them.

        public PackedFloat32Array Strengths()
        {
            return _strength;
        }

        public double Weakest()
        {
            return _weakest;
        }
        // A blow of `amount` on grid column `col` (x + z * w) at floor `floor_y`: breaks every cell
        // there whose material its worn total now reaches (into g.removed and g.mats).

        public void WearColumn(Carving.Grid g, long col, long floorY, double amount)
        {
            var f = g.frame;
            long wi = col + floorY * f.w * f.d;
            g.wear[wi] += amount;
            double level = g.wear[wi] / g.hp;
            if (level < _weakest)
            {
                return;
            }
            long plan = f.w * f.d;
            var rows = _Span(floorY, g.floors, f.offset.y, f.h, f.res);
            foreach (long gy in Gd.Range(rows.x, rows.y))
            {
                long i = col + gy * plan;
                long m = f.cells[i];
                if (m != VoxelFrame.EMPTY && level >= _strength[m])
                {
                    f.ClearIndex(i);
                    g.removed.Append(i);
                    g.mats.Append(m);
                    g.live[g.Chunk(i)] -= 1;
                }
            }
        }
        // After a blow: the events, the chunks it finished (paid now) and the settle. Returns the
        // chunks that went.

        public long _Finish(long n, Carving.Grid g)
        {
            var b = sim.buildings[n];
            var removed = g.removed;
            var mats = g.mats;
            g.removed = new PackedInt32Array();
            g.mats = new PackedByteArray();
            if (removed.IsEmpty())
            {
                return 0;
            }
            cellsCarved += removed.Size();
            _Lost(g, removed);
            sim.events.Append(new GDict { { "type", "cells_carved" }, { "building", n }, { "index", removed }, { "mats", mats } });
            var broken = _Deaths(n, g);
            if (!broken.IsEmpty())
            {
                sim.Pay(b, broken.Size(), 1.0);
                sim.events.Append(new GDict { { "type", "chunks_broken" }, { "building", n }, { "cells", broken } });
            }
            sim.collapse.Settle(n);
            return broken.Size();
        }
        // Chunks of building n left with at most alive_share of their cells (CarvingCells.gone): gone
        // from the Structure mirror now (top floor first, so an empty chunk follows the one it held up).

        public GArray<Vector3i> _Deaths(long n, Carving.Grid g)
        {
            var b = sim.buildings[n];
            GArray<Vector3i> @out = new GArray<Vector3i>();
            foreach (long ci in Gd.Range(g.live.Size() - 1, -1, -1))
            {
                if (g.dead[ci] == 0 && CarvingCells.Gone(g, ci, aliveShare))
                {
                    g.dead[ci] = 1;
                    var c = _ChunkCell(g, ci);
                    b.frame.Remove(c);
                    @out.Append(c);
                }
            }
            return @out;
        }

        public double _Mult(RampageSim.Building b)
        {
            return Growth.DwarfMult(sim.SizeTier(), b.tier, sim.city);
        }

        public static Vector3i _ChunkCell(Carving.Grid g, long ci)
        {
            return new Vector3i(ci % g.bw, ci / (g.bw * g.bd), (ci / g.bw) % g.bd);
        }
        // Grid range [x, y) along one axis of chunk `c` (of `count`): RES cells, run on to the grid's
        // edge for the first and last chunk.

        public static Vector2i _Span(long c, long count, long offset, long size, long res)
        {
            long lo = (c == 0 ? 0 : c * res - offset);
            long hi = (c == count - 1 ? size : (c + 1) * res - offset);
            return new Vector2i(Gd.Clampi(lo, 0, size), Gd.Clampi(hi, 0, size));
        }

        void _InitFields()
        {
        }
    }
}
