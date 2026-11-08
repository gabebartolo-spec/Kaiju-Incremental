// Generated from sim/body_volume.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class BodyVolume : RefCounted
    {
        public static implicit operator BodyVolume(Variant v) => (BodyVolume)v.Obj;

        // The kaiju's body volume (BodyContact's discs) asked where it touches the city: how far it
        // reaches, which standing buildings it can touch along a move, and every standing chunk inside it
        // at a pose. Part of BodyContact; pure, no randomness.
        // A chunk is one sim unit across: its centre is this far from its faces.
        public const double CHUNK_HALF = 0.5;
        // The discs at body scale 1, in design units: [forward offset, radius, bottom, top].
        public GArray<Variant> discs = Gd.Arr();
        public RampageSim sim;
        public GDict cfg = new GDict();
        // Seconds the sweep in hand covers (a building that dwarfs the kaiju is chewed at bite_dps x it).
        public double stepS = 0.0;
        // How far the body is lifted off where it stands (world units): a leap's flight (Dash.height).
        public double lift = 0.0;

        public BodyVolume(RampageSim pSim, GDict pCfg)
        {
            _InitFields();
            sim = pSim;
            cfg = pCfg;
        }
        // How far the body reaches from its position, world units.

        public double Reach()
        {
            double reach = 0.0;
            foreach (GArray<Variant> d in discs)
            {
                reach = Gd.Maxf(reach, Gd.Absf(Num.F(d[0])) + Num.F(d[1]));
            }
            return reach * sim.BodyScale();
        }
        // Standing buildings the body can touch moving from `from` to `to`: one pass over the city.

        public GArray<long> Near(Vector2 from, Vector2 to, double reach)
        {
            var lo = new Vector2(Gd.Minf(from.x, to.x), Gd.Minf(from.y, to.y)) - Vector2.ONE * reach;
            var hi = new Vector2(Gd.Maxf(from.x, to.x), Gd.Maxf(from.y, to.y)) + Vector2.ONE * reach;
            GArray<long> @out = new GArray<long>();
            foreach (long i in sim.grid.InRect(lo, hi))
            {
                var b = sim.buildings[i];
                if (b.frame.aliveCount == 0)
                {
                    continue;
                }
                if ((b.x + b.w * 0.5 < lo.x || b.x - b.w * 0.5 > hi.x))
                {
                    continue;
                }
                if ((b.z + b.d * 0.5 < lo.y || b.z - b.d * 0.5 > hi.y))
                {
                    continue;
                }
                @out.Append(i);
            }
            return @out;
        }

        public void Collect(Vector2 pos, Vector2 facing, GDict into, GArray<long> near)
        {
            double s = sim.BodyScale();
            double skin = Num.F(cfg["skin"]);
            foreach (GArray<Variant> d in discs)
            {
                var centre = pos + facing * Num.F(d[0]) * s;
                double r = Num.F(d[1]) * s - skin;
                if (r <= 0.0)
                {
                    continue;
                }
                double yLo = sim.standY + lift + Num.F(d[2]) * s + skin;
                double yHi = sim.standY + lift + Num.F(d[3]) * s - skin;
                foreach (long i in near)
                {
                    var b = sim.buildings[i];
                    if ((Gd.Absf(b.x - centre.x) > b.w * 0.5 + r || Gd.Absf(b.z - centre.y) > b.d * 0.5 + r))
                    {
                        continue;
                    }
                    // Local cell ranges the disc's square can touch.
                    long x0 = Gd.Maxi(0, Gd.Floori(centre.x - r - (b.x - b.w * 0.5)));
                    long x1 = Gd.Mini(b.w - 1, Gd.Floori(centre.x + r - (b.x - b.w * 0.5)));
                    long z0 = Gd.Maxi(0, Gd.Floori(centre.y - r - (b.z - b.d * 0.5)));
                    long z1 = Gd.Mini(b.d - 1, Gd.Floori(centre.y + r - (b.z - b.d * 0.5)));
                    // local: a bridge piece is under the street
                    long y0 = Gd.Maxi(0, Gd.Floori(yLo) - b.@base);
                    long y1 = Gd.Mini(b.height - 1, Gd.Ceili(yHi) - 1 - b.@base);
                    foreach (long x in Gd.Range(x0, x1 + 1))
                    {
                        foreach (long z in Gd.Range(z0, z1 + 1))
                        {
                            var p = b.ChunkWorld(new Vector3i(x, 0, z));
                            var gap = new Vector2(Gd.Maxf(Gd.Absf(p.x - centre.x) - CHUNK_HALF, 0.0), Gd.Maxf(Gd.Absf(p.z - centre.y) - CHUNK_HALF, 0.0));
                            if (gap.Length() >= r)
                            {
                                continue;
                            }
                            foreach (long y in Gd.Range(y0, y1 + 1))
                            {
                                var c = new Vector3i(x, y, z);
                                if (b.frame.Alive(c))
                                {
                                    if (!into.Has(i))
                                    {
                                        into[i] = new GDict();
                                    }
                                    GDict cells = into[i];
                                    cells[c] = true;
                                }
                            }
                        }
                    }
                }
            }
        }
        // Breaks every standing chunk the body touches moving and turning from one pose to the other in
        // `step_s` seconds (a building that dwarfs the kaiju is chewed at bite_dps x step_s instead of
        // broken outright, D-091, unless he crashes through it); returns the chunks broken. A slam
        // (Momentum.slam) breaks only its dent and stops the body where it was.

        public long Sweep(Vector2 from, Vector2 fromHeading, Vector2 to, Vector2 toHeading)
        {
            GDict hits = Touched(from, fromHeading, to, toHeading);
            var run = sim.powers.run;
            if (run.Touch(hits, from.DistanceTo(to), Reach()))
            {
                sim.kaijuPos = from;
                return 0;
            }
            long broken = 0;
            foreach (long index in hits)
            {
                GArray<Vector3i> cells = new GArray<Vector3i>();
                foreach (Vector3i c in Gd.Iter(hits[index]))
                {
                    cells.Append(c);
                }
                double before = sim.rubble;
                long first = sim.events.Size();
                var b = sim.buildings[index];
                var crash = run.Crashes(b, cells);
                var dwarfs = !crash && Growth.DwarfMult(sim.SizeTier(), b.tier, sim.city) < 1.0;
                long n = sim.DamageChunks(index, cells, (dwarfs ? Num.F(cfg["bite_dps"]) * stepS : Gd.INF));
                double pay = (dwarfs ? 1.0 : Num.F(cfg["pay_mult"]));
                // what the body breaks outright pays a share (pacing); chewed and falls in full
                if (n > 0)
                {
                    sim.rubble = before + (sim.rubble - before) * pay;
                    sim.events[first]["pay"] = pay;
                }
                broken += n;
            }
            return broken;
        }
        // Every standing chunk the body touches moving and turning from one pose to the other:
        // {building index: {Vector3i: true}}.

        public GDict Touched(Vector2 from, Vector2 fromHeading, Vector2 to, Vector2 toHeading)
        {
            GDict hits = new GDict();
            double span = Reach();
            var close = Near(from, to, span);
            if (close.IsEmpty())
            {
                return hits;
            }
            double turn = fromHeading.AngleTo(toHeading);
            double travel = from.DistanceTo(to) + Gd.Absf(turn) * span;
            long samples = Gd.Maxi(1, Gd.Ceili(travel / Gd.Maxf(0.05, Num.F(cfg["sample"]))));
            foreach (long n in Gd.Range(1, samples + 1))
            {
                GArray<Variant> pose = SweepPose(from, fromHeading, to, toHeading, Gd.Float(n) / samples);
                Vector2 at = pose[0];
                Vector2 facing = pose[1];
                Collect(at, facing, hits, close);
            }
            return hits;
        }
        // The body's pose a fraction `t` along a sweep: [position, heading]. The last sample (t = 1) is
        // exactly the end pose, the one the hold test reads, so a rounding error in the turn can never
        // leave a chunk the sweep missed but the hold sees.

        public static GArray<Variant> SweepPose(Vector2 from, Vector2 fromHeading, Vector2 to, Vector2 toHeading, double t)
        {
            if (t >= 1.0)
            {
                return Gd.Arr(to, toHeading);
            }
            return Gd.Arr(from.Lerp(to, t), fromHeading.Rotated(fromHeading.AngleTo(toHeading) * t));
        }

        void _InitFields()
        {
        }
    }
}
