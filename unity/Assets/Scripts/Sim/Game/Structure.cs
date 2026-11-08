// Generated from sim/structure.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class Structure : RefCounted
    {
        public static implicit operator Structure(Variant v) => (Structure)v.Obj;

        // A building as a real structure: a grid of chunks (one sim unit each way, one floor tall),
        // each with its own strength. Nothing has a health bar; what stands is whatever is still
        // held up. settle() finds what has lost support:
        // - "drop":   a part no longer connected to the ground falls straight down;
        // - "topple": a grounded part whose centre of mass hangs past what holds it up (a tower with
        // its base eaten away on one side) tips over its supporting edge, like Jenga.
        // Pure and deterministic: same damage, same collapse.
        public long w;
        public long d;
        public long h;
        public double maxHp;
        public long aliveCount;
        // A ring landmark's arcs (Arcs): settle() first brings down every arc that lost a chunk.
        public Arcs arcs;
        public PackedFloat32Array _hp = new PackedFloat32Array();

        public Structure(long pW, long pD, long pH, double chunkHp)
        {
            _InitFields();
            w = pW;
            d = pD;
            h = pH;
            maxHp = chunkHp;
            _hp = new PackedFloat32Array();
            _hp.Resize(w * d * h);
            _hp.Fill(chunkHp);
            aliveCount = w * d * h;
        }
        // Keeps only the chunks a shape marks: one string per floor, a "1" per chunk that exists,
        // x fastest then z (a landmark's baked chunks). Every other chunk is gone from the start.

        public void Keep(GArray<Variant> layers)
        {
            foreach (long y in Gd.Range(h))
            {
                var row = (y < layers.Size() ? Gd.Str(layers[y]) : "");
                foreach (long z in Gd.Range(d))
                {
                    foreach (long x in Gd.Range(w))
                    {
                        long k = x + z * w;
                        if ((k >= row.Length() || row.At(k) != "1"))
                        {
                            Remove(new Vector3i(x, y, z));
                        }
                    }
                }
            }
        }

        public long Index(Vector3i c)
        {
            return c.x + c.z * w + c.y * w * d;
        }

        public bool Inside(Vector3i c)
        {
            return c.x >= 0 && c.y >= 0 && c.z >= 0 && c.x < w && c.y < h && c.z < d;
        }

        public bool Alive(Vector3i c)
        {
            return Inside(c) && _hp[Index(c)] > 0.0;
        }
        // Damages one chunk; true if it broke now.

        public bool Damage(Vector3i c, double amount)
        {
            if (!Alive(c))
            {
                return false;
            }
            long i = Index(c);
            _hp[i] -= amount;
            if (_hp[i] <= 0.0)
            {
                aliveCount -= 1;
                return true;
            }
            return false;
        }

        public void Remove(Vector3i c)
        {
            if (Alive(c))
            {
                _hp[Index(c)] = 0.0;
                aliveCount -= 1;
            }
        }
        // Highest standing chunk in column (x, z) below `below_y`, or -1.

        public long TopBelow(long x, long z, long belowY)
        {
            foreach (long y in Gd.Range(Gd.Mini(belowY, h) - 1, -1, -1))
            {
                if (Alive(new Vector3i(x, y, z)))
                {
                    return y;
                }
            }
            return -1;
        }
        // Removes and returns every part that lost support, as
        // {"cells": Array[Vector3i], "kind": "drop"|"topple", "pivot": Vector3 (local), "dir": Vector2i}.

        public GArray<GDict> Settle()
        {
            GArray<GDict> @out = new GArray<GDict>();
            _ShedArcs(@out);
            _DropLoose(@out);
            GDict tipping = _ToppleCheck();
            if (!tipping.IsEmpty())
            {
                _RemoveAll(tipping);
                @out.Append(tipping);
            }
            return @out;
        }
        // A ring landmark's arcs that lost a chunk come down first (Arcs.shed): removed, added to `out`.

        public void _ShedArcs(GArray<GDict> @out)
        {
            if (arcs == null)
            {
                return;
            }
            foreach (GDict part in arcs.Shed(this))
            {
                _RemoveAll(part);
                @out.Append(part);
            }
        }
        // Groups every standing chunk not joined to the ground into parts that drop and adds them to `out`;
        // then everything in `out` (the arcs' parts too) is removed.

        public void _DropLoose(GArray<GDict> @out)
        {
            var grounded = _Grounded();
            GDict loose = new GDict();
            foreach (long y in Gd.Range(h))
            {
                foreach (long x in Gd.Range(w))
                {
                    foreach (long z in Gd.Range(d))
                    {
                        long i = x + z * w + y * w * d;
                        if (_hp[i] > 0.0 && grounded[i] == 0 && !(loose.Has(new Vector3i(x, y, z))))
                        {
                            var part = _Component(new Vector3i(x, y, z), loose);
                            @out.Append(new GDict { { "cells", part }, { "kind", "drop" }, { "pivot", Vector3.ZERO }, { "dir", Vector2i.ZERO } });
                        }
                    }
                }
            }
            foreach (GDict part in @out)
            {
                _RemoveAll(part);
            }
        }

        public void _RemoveAll(GDict part)
        {
            GArray<Vector3i> cells = part["cells"];
            foreach (Vector3i c in cells)
            {
                Remove(c);
            }
        }
        // Every standing chunk joined to the ground floor (1 per chunk index), flooded over the raw
        // strengths: a Dictionary of Vector3i and an alive() call per step cost the stadium ~10 ms a
        // settle (lead, 2026-10-19).

        public PackedByteArray _Grounded()
        {
            long plan = w * d;
            var seen = new PackedByteArray();
            seen.Resize(plan * h);
            var frontier = new PackedInt32Array();
            foreach (long i in Gd.Range(plan))
            {
                if (_hp[i] > 0.0)
                {
                    seen[i] = 1;
                    frontier.Append(i);
                }
            }
            while (!frontier.IsEmpty())
            {
                long i = frontier[frontier.Size() - 1];
                frontier.Resize(frontier.Size() - 1);
                foreach (long n in _Neighbours(i, plan))
                {
                    if (n >= 0 && seen[n] == 0 && _hp[n] > 0.0)
                    {
                        seen[n] = 1;
                        frontier.Append(n);
                    }
                }
            }
            return seen;
        }
        // Chunk index i's six face neighbours (plan: w x d); -1 past an edge.

        public GArray<long> _Neighbours(long i, long plan)
        {
            long x = i % w;
            long z = (i / w) % d;
            long y = i / plan;
            return new GArray<long> { (x > 0 ? i - 1 : -1), (x < w - 1 ? i + 1 : -1), (z > 0 ? i - w : -1), (z < d - 1 ? i + w : -1), (y > 0 ? i - plan : -1), (y < h - 1 ? i + plan : -1) };
        }
        // The raw chunk strengths, by index() (Arcs counts over them without a call per chunk).

        public PackedFloat32Array Standing()
        {
            return _hp;
        }

        public void _Flood(GArray<Vector3i> frontier, GDict seen)
        {
            GArray<Vector3i> dirs = new GArray<Vector3i> { Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK };
            while (!frontier.IsEmpty())
            {
                Vector3i c = frontier.PopBack();
                foreach (Vector3i step in dirs)
                {
                    var n = c + step;
                    if (Alive(n) && !seen.Has(n))
                    {
                        seen[n] = true;
                        frontier.Append(n);
                    }
                }
            }
        }

        public GArray<Vector3i> _Component(Vector3i start, GDict seen)
        {
            GDict local = new GDict { { start, true } };
            GArray<Vector3i> frontier = new GArray<Vector3i> { start };
            _Flood(frontier, local);
            GArray<Vector3i> cells = new GArray<Vector3i>();
            foreach (Vector3i c in local)
            {
                cells.Append(c);
                seen[c] = true;
            }
            return cells;
        }
        // Lowest floor whose load (everything standing at or above it) has its centre of mass outside
        // the chunks holding it up from the floor below. Returns the toppling part, or {}.
        // Each floor's mass and centre are summed once and every load is a running total from the top
        // down: a rescan of all the floors above each one cost the stadium (28 x 28 x 13) ~66k alive()
        // calls per settle, a frame stall at every hit (lead, 2026-10-19). The sums are of half-integers
        // well under 2^23, exact in float, so the order of adding does not change the result.

        public GDict _ToppleCheck()
        {
            GDict loads = _FloorLoads();
            PackedInt32Array floorMass = loads["mass"];
            PackedVector2Array floorSum = loads["sum"];
            foreach (long level in Gd.Range(1, h))
            {
                long mass = floorMass[level];
                if (mass == 0)
                {
                    return new GDict();
                }
                var com = floorSum[level] / mass;
                var held = _HeldBox(level);
                if (held.IsEmpty())
                {
                    // nothing touches across this floor: settle()'s drop handles it
                    continue;
                }
                var over = _Overhang(com, held[0], held[1]);
                if (over != Vector2.ZERO)
                {
                    return _Topple(level, com, held, over);
                }
            }
            return new GDict();
        }
        // Per floor, the mass (chunks standing) and the sum of their plan centres, each a running total
        // of that floor and every one above it: {"mass": PackedInt32Array, "sum": PackedVector2Array},
        // h + 1 entries each (the last stays 0).

        public GDict _FloorLoads()
        {
            var floorMass = new PackedInt32Array();
            floorMass.Resize(h + 1);
            var floorSum = new PackedVector2Array();
            floorSum.Resize(h + 1);
            long plan = w * d;
            foreach (long y in Gd.Range(h))
            {
                foreach (long z in Gd.Range(d))
                {
                    foreach (long x in Gd.Range(w))
                    {
                        if (_hp[x + z * w + y * plan] > 0.0)
                        {
                            floorMass[y] += 1;
                            floorSum[y] += new Vector2(x + 0.5, z + 0.5);
                        }
                    }
                }
            }
            foreach (long y in Gd.Range(h - 1, -1, -1))
            {
                floorMass[y] += floorMass[y + 1];
                floorSum[y] += floorSum[y + 1];
            }
            return new GDict { { "mass", floorMass }, { "sum", floorSum } };
        }
        // The plan box [low, high] of the chunks at `level` that stand on a standing chunk below, or []
        // when none does.

        public GArray<Vector2> _HeldBox(long level)
        {
            long plan = w * d;
            var lo = new Vector2(Gd.INF, Gd.INF);
            var hi = new Vector2(-Gd.INF, -Gd.INF);
            foreach (long x in Gd.Range(w))
            {
                foreach (long z in Gd.Range(d))
                {
                    long k = x + z * w + level * plan;
                    if (_hp[k] > 0.0 && _hp[k - plan] > 0.0)
                    {
                        lo = new Vector2(Gd.Minf(lo.x, x), Gd.Minf(lo.y, z));
                        hi = new Vector2(Gd.Maxf(hi.x, x + 1), Gd.Maxf(hi.y, z + 1));
                    }
                }
            }
            if (lo.x == Gd.INF)
            {
                return new GArray<Vector2>();
            }
            return new GArray<Vector2> { lo, hi };
        }
        // How far the centre of mass hangs past the box, per axis (0 inside it).

        public Vector2 _Overhang(Vector2 com, Vector2 lo, Vector2 hi)
        {
            return new Vector2((com.x > hi.x ? com.x - hi.x : ((com.x < lo.x ? com.x - lo.x : 0.0))), (com.y > hi.y ? com.y - hi.y : ((com.y < lo.y ? com.y - lo.y : 0.0))));
        }
        // The part from `level` up, tipping over the box's edge on the side the centre hangs out of.

        public GDict _Topple(long level, Vector2 com, GArray<Vector2> held, Vector2 over)
        {
            var lo = held[0];
            var hi = held[1];
            var dir = new Vector2i(Gd.Signi(Gd.Roundi(over.x * 100.0)), 0);
            if (Gd.Absf(over.y) > Gd.Absf(over.x))
            {
                dir = new Vector2i(0, Gd.Signi(Gd.Roundi(over.y * 100.0)));
            }
            var pivot = new Vector3((dir.x > 0 ? hi.x : ((dir.x < 0 ? lo.x : com.x))), level, (dir.y > 0 ? hi.y : ((dir.y < 0 ? lo.y : com.y))));
            GArray<Vector3i> cells = new GArray<Vector3i>();
            foreach (long y in Gd.Range(level, h))
            {
                foreach (long x in Gd.Range(w))
                {
                    foreach (long z in Gd.Range(d))
                    {
                        if (Alive(new Vector3i(x, y, z)))
                        {
                            cells.Append(new Vector3i(x, y, z));
                        }
                    }
                }
            }
            return new GDict { { "cells", cells }, { "kind", "topple" }, { "pivot", pivot }, { "dir", dir } };
        }

        void _InitFields()
        {
        }
    }
}
