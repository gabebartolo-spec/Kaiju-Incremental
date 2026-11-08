// Generated from sim/leap_arc.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class LeapArc : RefCounted
    {
        public static implicit operator LeapArc(Variant v) => (LeapArc)v.Obj;

        // The height of the croc's leap through its flight (director 2026-10-26, "High arc, lands on roof":
        // he springs high over the street and comes down on top of the target building). One parabola from
        // the street at take-off to `land_y` (the target's roof, or the street) whose top clears, by
        // `clear`, every building the body passes over on the way (its discs' footprints, each disc's
        // bottom held above the roof), so the body never clips through a building in flight; a target
        // taken in its side (`carve`, D-361) is not cleared: the arc ends at its facade and the body
        // carves into it. Planned once at the press from the standing city; Dash reads at(). Part of
        // Dash; pure, no randomness.
        // The height it lands at (world units above the street) and the top of the arc.
        public double landY = 0.0;
        public double top = 0.0;
        // Buildings the planned path still passes through at the arc's height (0 when it clears them all).
        public long blocked = 0;
        // The building the leap takes in its side (D-361), set before plan(); -1 for none.
        public long carve = -1;
        public double _a = 0.0;
        public double _b = 0.0;
        public RampageSim _sim;
        public GArray<Variant> _discs = Gd.Arr();

        public LeapArc(RampageSim sim)
        {
            _InitFields();
            _sim = sim;
        }
        // Height (world units) at `f` of the flight, 0..1: 0 at take-off, land_y at the contact.

        public double At(double f)
        {
            return -_a * f * f + _b * f;
        }
        // Plans the arc of a leap from `start` to `land` along `ahead` (kaiju_pos both; the body's discs at
        // body scale 1), landing at `p_land_y`: samples the path every `step` units, then raises the top
        // by `clear` at a time (at most `tries` times) until every sample clears what it passes over.
        // Buildings the body already overlaps at take-off are skipped (it stands among them), and so is
        // `carve`, a building the leap takes in its side (D-361): the arc ends at its facade and the body
        // carves into it rather than clearing it.

        public void Plan(GArray<Variant> discs, PackedVector2Array ends, Vector2 ahead, Vector4 numbers)
        {
            _discs = discs;
            var start = ends[0];
            var land = ends[1];
            landY = numbers.x;
            double clear = numbers.y;
            GDict skip = _Overlaps(start, ahead);
            if (carve >= 0)
            {
                skip[carve] = true;
            }
            double span = start.DistanceTo(land);
            long count = Gd.Maxi(1, Gd.Ceili(span / Gd.Maxf(numbers.z, 0.01)));
            var needs = new PackedVector2Array();
            top = landY;
            foreach (long i in Gd.Range(1, count + 1))
            {
                double f = Gd.Float(i) / count;
                double need = _Need(start.Lerp(land, f), ahead, skip);
                needs.Append(new Vector2(f, need));
                top = Gd.Maxf(top, need);
            }
            top += clear;
            foreach (long _n in Gd.Range(Num.I(numbers.w)))
            {
                _Fit();
                blocked = 0;
                foreach (Vector2 need in needs)
                {
                    blocked += (At(need.x) < need.y ? 1 : 0);
                }
                if (blocked == 0)
                {
                    return;
                }
                top += clear;
            }
        }
        // The first standing building (in path order) the body's discs pass over on the way from `ends[0]`
        // to `ends[1]` along `ahead` that stands taller than `numbers.x` (world units), sampling every
        // `numbers.y` units; buildings it overlaps at take-off are skipped. -1 for none. A leap never
        // clears such a building: it takes it in its side (Dash.aim_at; director 2026-11-03, D-361).

        public long Wall(GArray<Variant> discs, PackedVector2Array ends, Vector2 ahead, Vector2 numbers)
        {
            _discs = discs;
            double s = _sim.BodyScale();
            var tall = _TallNear(ends, numbers.x);
            if (tall.IsEmpty())
            {
                return -1;
            }
            GDict skip = _Overlaps(ends[0], ahead, tall);
            var near = new PackedInt32Array();
            foreach (long i in tall)
            {
                if (!skip.Has(i))
                {
                    near.Append(i);
                }
            }
            if (near.IsEmpty())
            {
                return -1;
            }
            long count = Gd.Maxi(1, Gd.Ceili(ends[0].DistanceTo(ends[1]) / Gd.Maxf(numbers.y, 0.01)));
            foreach (long n in Gd.Range(1, count + 1))
            {
                var pose = ends[0].Lerp(ends[1], Gd.Float(n) / count);
                foreach (GArray<Variant> d in _discs)
                {
                    var c = pose + ahead * Num.F(d[0]) * s;
                    double r = Num.F(d[1]) * s;
                    foreach (long i in near)
                    {
                        var b = _sim.buildings[i];
                        var gap = new Vector2(Gd.Maxf(Gd.Absf(c.x - b.x) - b.w * 0.5, 0.0), Gd.Maxf(Gd.Absf(c.y - b.z) - b.d * 0.5, 0.0));
                        if (gap.Length() < r)
                        {
                            return i;
                        }
                    }
                }
            }
            return -1;
        }
        // The standing buildings taller than `limit` whose footprints may come within the body's reach
        // of the segment `ends` (BuildingGrid, padded by the farthest disc's edge).

        public PackedInt32Array _TallNear(PackedVector2Array ends, double limit)
        {
            double pad = 0.0;
            foreach (GArray<Variant> d in _discs)
            {
                pad = Gd.Maxf(pad, Gd.Absf(Num.F(d[0])) + Num.F(d[1]));
            }
            pad *= _sim.BodyScale();
            var lo = new Vector2(Gd.Minf(ends[0].x, ends[1].x), Gd.Minf(ends[0].y, ends[1].y)) - Vector2.ONE * pad;
            var hi = new Vector2(Gd.Maxf(ends[0].x, ends[1].x), Gd.Maxf(ends[0].y, ends[1].y)) + Vector2.ONE * pad;
            var @out = new PackedInt32Array();
            foreach (long i in _sim.grid.InRect(lo, hi))
            {
                var b = _sim.buildings[i];
                if (b.frame.aliveCount > 0 && Gd.Float(b.height) > limit)
                {
                    @out.Append(i);
                }
            }
            return @out;
        }
        // The parabola through (0, 0) and (1, land_y) peaking at `top`.

        public void _Fit()
        {
            double peak = Gd.Maxf(top, Gd.Maxf(landY, 0.001));
            _b = 2.0 * peak + 2.0 * Gd.Sqrt(Gd.Maxf(0.0, peak * (peak - landY)));
            _a = _b - landY;
        }
        // How high the body must be lifted at `pose` to pass over every standing building its discs
        // overlap there (but those in `skip`): a building's height less the disc's bottom.

        public double _Need(Vector2 pose, Vector2 ahead, GDict skip)
        {
            double s = _sim.BodyScale();
            double need = 0.0;
            foreach (GArray<Variant> d in _discs)
            {
                var c = pose + ahead * Num.F(d[0]) * s;
                double r = Num.F(d[1]) * s;
                foreach (long i in Gd.Range(_sim.buildings.Size()))
                {
                    var b = _sim.buildings[i];
                    if ((b.frame.aliveCount == 0 || skip.Has(i)))
                    {
                        continue;
                    }
                    var gap = new Vector2(Gd.Maxf(Gd.Absf(c.x - b.x) - b.w * 0.5, 0.0), Gd.Maxf(Gd.Absf(c.y - b.z) - b.d * 0.5, 0.0));
                    if (gap.Length() < r)
                    {
                        need = Gd.Maxf(need, b.height - Num.F(d[2]) * s);
                    }
                }
            }
            return need;
        }
        // The standing buildings the discs overlap at `pose`: {index: true}. Only those in `among`
        // when given (LeapArc.wall's tall candidates), else every building.

        public GDict _Overlaps(Vector2 pose, Vector2 ahead, PackedInt32Array among)
        {
            double s = _sim.BodyScale();
            GDict @out = new GDict();
            Variant pool = (!among.IsEmpty() ? among : Gd.Range(_sim.buildings.Size()));
            foreach (GArray<Variant> d in _discs)
            {
                var c = pose + ahead * Num.F(d[0]) * s;
                double r = Num.F(d[1]) * s;
                foreach (long i in Gd.Iter(pool))
                {
                    var b = _sim.buildings[i];
                    var gap = new Vector2(Gd.Maxf(Gd.Absf(c.x - b.x) - b.w * 0.5, 0.0), Gd.Maxf(Gd.Absf(c.y - b.z) - b.d * 0.5, 0.0));
                    if (b.frame.aliveCount > 0 && gap.Length() < r)
                    {
                        @out[i] = true;
                    }
                }
            }
            return @out;
        }
        public GDict _Overlaps(Vector2 pose, Vector2 ahead) => _Overlaps(pose, ahead, new PackedInt32Array());

        void _InitFields()
        {
        }
    }
}
