// Generated from sim/arcs.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class Arcs : RefCounted
    {
        public static implicit operator Arcs(Variant v) => (Arcs)v.Obj;

        // A ring-shaped landmark's arcs (the stadium): its plan is cut into sectors round its middle,
        // in two bands, the rim (outer wall and roof) and the stands inside it. The first chunk an arc
        // loses brings down everything of it above a stub of `stub` floors as one toppling section, the
        // rim outward and the stands inward, so a breach reads as a section of wall failing and lands as
        // a rubble strip (Collapse), not as scattered holes. Part of Structure.settle(). Pure sim.
        public long stub = 0;
        public long _w = 0;
        // Plan column (x + z * w) -> arc, or -1 (the pitch, and the corner masts outside the ring).
        public PackedInt32Array _of = new PackedInt32Array();
        public GArray<Vector2i> _dirs = new GArray<Vector2i>();
        // Standing chunks per arc when it last shed (or at the start).
        public PackedInt32Array _whole = new PackedInt32Array();
        // cfg: {"sectors", "stub" (floors that stay standing), "rim" (normalised radius where the rim
        // starts: 0 is the middle, 1 the footprint's inscribed ellipse), "outer" (the wall's outermost
        // chunks reach past 1; the corner masts beyond it belong to no arc)}. Only columns that rise
        // above the stub belong to an arc: the pitch never does.

        public static Arcs Build(Structure frame, GDict cfg)
        {
            var a = new Arcs();
            long sectors = Num.I(cfg["sectors"]);
            double rim = Num.F(cfg["rim"]);
            double outer = Num.F(cfg["outer"]);
            a.stub = Num.I(cfg["stub"]);
            a._w = frame.w;
            a._of.Resize(frame.w * frame.d);
            a._of.Fill(-1);
            foreach (long x in Gd.Range(frame.w))
            {
                foreach (long z in Gd.Range(frame.d))
                {
                    var at = new Vector2((x + 0.5) / (frame.w * 0.5) - 1.0, (z + 0.5) / (frame.d * 0.5) - 1.0);
                    if ((at.Length() > outer || frame.TopBelow(x, z, frame.h) < a.stub))
                    {
                        continue;
                    }
                    long band = (at.Length() >= rim ? 1 : 0);
                    long s = Gd.Posmod(Gd.Floori((at.Angle() + Gd.PI) / Gd.TAU * sectors), sectors);
                    a._of[x + z * frame.w] = band * sectors + s;
                }
            }
            foreach (long band in Gd.Range(2))
            {
                foreach (long s in Gd.Range(sectors))
                {
                    var @out = Vector2.FromAngle((s + 0.5) / sectors * Gd.TAU - Gd.PI);
                    var dir = new Vector2i(Gd.Signi(Gd.Roundi(@out.x * 10.0)), 0);
                    if (Gd.Absf(@out.y) > Gd.Absf(@out.x))
                    {
                        dir = new Vector2i(0, Gd.Signi(Gd.Roundi(@out.y * 10.0)));
                    }
                    a._dirs.Append((band == 1 ? dir : -dir));
                }
            }
            a._whole = a._Count(frame);
            return a;
        }
        // The sections to bring down now: for each arc that lost a chunk since it last shed, every
        // chunk of it still standing above the stub, as {"cells", "kind": "topple", "pivot", "dir"}.
        // The caller removes them.

        public GArray<GDict> Shed(Structure frame)
        {
            var now = _Count(frame);
            GArray<GDict> @out = new GArray<GDict>();
            var hp = frame.Standing();
            long plan = frame.w * frame.d;
            foreach (long g in Gd.Range(now.Size()))
            {
                if (now[g] >= _whole[g])
                {
                    continue;
                }
                GArray<Vector3i> cells = new GArray<Vector3i>();
                foreach (long y in Gd.Range(stub, frame.h))
                {
                    foreach (long z in Gd.Range(frame.d))
                    {
                        foreach (long x in Gd.Range(frame.w))
                        {
                            if (_of[x + z * _w] == g && hp[x + z * _w + y * plan] > 0.0)
                            {
                                cells.Append(new Vector3i(x, y, z));
                            }
                        }
                    }
                }
                _whole[g] = now[g] - cells.Size();
                if (!cells.IsEmpty())
                {
                    @out.Append(new GDict { { "cells", cells }, { "kind", "topple" }, { "pivot", _Pivot(cells, _dirs[g]) }, { "dir", _dirs[g] } });
                }
            }
            return @out;
        }
        // The direction arc g falls toward (the rim outward, the stands inward).

        public Vector2i DirOf(long g)
        {
            return _dirs[g];
        }
        // How many arcs there are.

        public long ArcCount()
        {
            return _dirs.Size();
        }
        // The arc plan column (x, z) belongs to, or -1.

        public long ArcAt(long x, long z)
        {
            return _of[x + z * _w];
        }
        // Standing chunks per arc, read straight off the chunk strengths (Structure.standing()).

        public PackedInt32Array _Count(Structure frame)
        {
            var @out = new PackedInt32Array();
            @out.Resize(_dirs.Size());
            var hp = frame.Standing();
            long plan = _of.Size();
            foreach (long i in Gd.Range(hp.Size()))
            {
                long g = _of[i % plan];
                if (g >= 0 && hp[i] > 0.0)
                {
                    @out[g] += 1;
                }
            }
            return @out;
        }
        // The edge it tips over: the section's far side toward `dir`, at the top of the stub.

        public Vector3 _Pivot(GArray<Vector3i> cells, Vector2i dir)
        {
            var lo = new Vector2(Gd.INF, Gd.INF);
            var hi = new Vector2(-Gd.INF, -Gd.INF);
            var sum = Vector2.ZERO;
            foreach (Vector3i c in cells)
            {
                lo = new Vector2(Gd.Minf(lo.x, c.x), Gd.Minf(lo.y, c.z));
                hi = new Vector2(Gd.Maxf(hi.x, c.x + 1), Gd.Maxf(hi.y, c.z + 1));
                sum += new Vector2(c.x + 0.5, c.z + 0.5);
            }
            var mid = sum / cells.Size();
            double px = (dir.x > 0 ? hi.x : ((dir.x < 0 ? lo.x : mid.x)));
            double pz = (dir.y > 0 ? hi.y : ((dir.y < 0 ? lo.y : mid.y)));
            return new Vector3(px, stub, pz);
        }

        void _InitFields()
        {
        }
        public Arcs() { _InitFields(); }
    }
}
