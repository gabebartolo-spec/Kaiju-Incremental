// Generated from sim/momentum.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class Momentum : RefCounted
    {
        public static implicit operator Momentum(Variant v) => (Momentum)v.Obj;

        // The titan's run (D-337, "momentum based, at high momentum he can crash right through smaller
        // buildings, and collide with a bang into bigger ones"). From the first rampage it builds while he
        // walks on open ground (to full in build_seconds; the momentum node builds it faster), never while
        // his body is at a building he is not crashing through (it holds there: slam and stop, momentum
        // spent until open ground), and bleeds as he turns (turn_bleed a radian) or stands (idle_decay a
        // second); it adds speed_bonus x itself to his walk.
        // At crash_min he crashes through what stands under his crash height without slowing or spending
        // it; at slam_min his first touch of anything taller is a slam: one "slam" event, a dent, momentum
        // 0 and the body stopped where it was (then it is held as any wall holds it). Each titan reads its
        // own entry (powers.momentum.titans, by creation.titans id): a species with none has no momentum.
        // Part of SpeciesPowers; pure, no randomness.
        public RampageSim sim;
        // 0..1: how much run the titan has built.
        public double value = 0.0;
        // Slams so far this rampage.
        public long slams = 0;
        // This titan's entry in powers.momentum.titans (empty: no momentum).
        public GDict titan = new GDict();
        public GDict _cfg = new GDict();
        // what the body touched last step: a slam is a new touch
        public GDict _touching = new GDict();
        // Ground walked since the body last touched a building it is not crashing through, and whether
        // that is his body's reach or more (open ground: the run builds).
        public double _clear = Gd.INF;
        public bool _open = true;
        // cfg: the tuning's powers.momentum section.

        public Momentum(RampageSim pSim, GDict cfg)
        {
            _InitFields();
            sim = pSim;
            _cfg = cfg;
        }
        // Picks the entry of the titan that plays `species_id` (creation.titans); none: no momentum.

        public void UseSpecies(string speciesId)
        {
            titan = new GDict();
            GDict titans = _cfg["titans"];
            GArray<Variant> rack = Content.Section("creation")["titans"];
            foreach (GDict t in rack)
            {
                var id = Gd.Str(t["id"]);
                if (speciesId != "" && Gd.Str(t["species"]) == speciesId && titans.Has(id))
                {
                    titan = titans[id];
                    return;
                }
            }
        }

        public bool Active()
        {
            return !titan.IsEmpty();
        }
        // One step's build or bleed: `turn` radians turned this step while `moving` (the stick pushed).

        public void Build(double dt, double turn, bool moving)
        {
            if (!Active())
            {
                return;
            }
            if (moving)
            {
                double boost = 1.0 + sim.Stat("momentum") * Num.F(titan["node_build"]);
                double gain = (_open ? dt * boost / Num.F(titan["build_seconds"]) : 0.0);
                value += gain - turn * Num.F(titan["turn_bleed"]);
            }
            else
            {
                value -= dt * Num.F(titan["idle_decay"]);
            }
            value = Gd.Clampf(value, 0.0, 1.0);
        }
        // The walk's speed multiplier from momentum.

        public double SpeedMult()
        {
            return (Active() ? 1.0 + value * Num.F(titan["speed_bonus"]) : 1.0);
        }
        // 0..1 for the drawn walk-to-run blend (D-335, the keyed run): the momentum, only while it speeds
        // the walk (speed_bonus > 0). With no speed bonus he walks at walk speed, so the run take stays
        // off (director 2026-10-31: the run at walk speed read as a stomp every step).

        public double Blend()
        {
            return (Active() && Num.F(titan["speed_bonus"]) > 0.0 ? value : 0.0);
        }
        // Whether he has the momentum to crash through what stands under his crash height.

        public bool Crashing()
        {
            return Active() && value >= Num.F(titan["crash_min"]);
        }
        // His crash height now, world units over the ground: his shoulder (by stage) or his body's top.

        public double CrashHeight()
        {
            if (Gd.Str(titan["crash_height"]) == "body")
            {
                double top = 0.0;
                foreach (GArray<Variant> d in sim.body.Discs())
                {
                    top = Gd.Maxf(top, Num.F(d[3]));
                }
                return top * sim.BodyScale();
            }
            GArray<Variant> byStage = titan["shoulder"];
            return Num.F(byStage[Gd.Clampi(sim.SizeTier() - 1, 0, byStage.Size() - 1)]) * sim.BodyScale();
        }
        // Whether a crash takes column (x, z) of building b now: he has the momentum and it stands under
        // his crash height.

        public bool CrashesColumn(RampageSim.Building b, long x, long z)
        {
            return Crashing() && b.frame.TopBelow(x, z, b.height) + 1 + b.@base < CrashHeight();
        }
        // Whether he crashes through building b where the body touches `cells`.

        public bool Crashes(RampageSim.Building b, GArray<Vector3i> cells)
        {
            return Crashing() && Standing(b, cells) < CrashHeight();
        }
        // How many floors building b stands over the columns of `cells`.

        public static long Standing(RampageSim.Building b, GArray<Vector3i> cells)
        {
            long top = 0;
            foreach (Vector3i c in cells)
            {
                top = Gd.Maxi(top, b.frame.TopBelow(c.x, c.z, b.height) + 1 + b.@base);
            }
            return top;
        }
        // The body's sweep this step: it moved `travel` and touched `hits` ({building: {cell: true}});
        // `reach` is its own. At slam_min the first touch of a building at or over his crash height is a
        // slam (never in a leap's flight); a touch of one he is not crashing through, or a slam, puts
        // him off open ground until he has walked his reach clear of it. Returns whether he slammed: the
        // caller stops the body where it was.

        public bool Touch(GDict hits, double travel, double reach)
        {
            if ((!Active() || sim.body.dash.On()))
            {
                _touching = hits;
                return false;
            }
            var slammed = Slam(hits);
            var at = slammed;
            foreach (long index in hits)
            {
                GDict touched = hits[index];
                GArray<Vector3i> cells = new GArray<Vector3i>();
                cells.Assign(touched.Keys());
                at = (at || !Crashes(sim.buildings[index], cells));
            }
            _clear = (at ? 0.0 : _clear + travel);
            _open = _clear >= reach;
            return slammed;
        }
        // At slam_min the first touch (`hits`, this step's) of a building at or over his crash height is
        // a slam. Returns whether he slammed.

        public bool Slam(GDict hits)
        {
            GDict was = _touching;
            _touching = hits;
            if ((titan["slams"] != true || value < Num.F(titan["slam_min"])))
            {
                return false;
            }
            double height = CrashHeight();
            foreach (long index in hits)
            {
                GDict touched = hits[index];
                GArray<Vector3i> cells = new GArray<Vector3i>();
                cells.Assign(touched.Keys());
                if (!was.Has(index) && Standing(sim.buildings[index], cells) >= height)
                {
                    _Hit(index, cells);
                    return true;
                }
            }
            return false;
        }
        // The slam on building `index` where the body touched `cells`: the event (where, how hard), the
        // dent, momentum spent.

        public void _Hit(long index, GArray<Vector3i> cells)
        {
            var b = sim.buildings[index];
            double strength = value * Num.F(titan["hit"]);
            var mid = Vector3.ZERO;
            foreach (Vector3i c in cells)
            {
                mid += b.ChunkWorld(c);
            }
            mid /= Gd.Float(cells.Size());
            slams += 1;
            value = 0.0;
            sim.events.Append(new GDict { { "type", "slam" }, { "building", index }, { "at", mid }, { "strength", strength } });
            sim.DamageChunks(index, _Dent(b, mid, cells, strength), Gd.INF);
        }
        // The chunks of b a slam of `strength` breaks: within dent_radius x body scale x strength of the
        // contact across the ground, on the floors the body touched (`cells`).

        public GArray<Vector3i> _Dent(RampageSim.Building b, Vector3 mid, GArray<Vector3i> cells, double strength)
        {
            double radius = Num.F(_cfg["dent_radius"]) * sim.BodyScale() * strength;
            long lo = b.height;
            long hi = 0;
            foreach (Vector3i c in cells)
            {
                lo = Gd.Mini(lo, c.y);
                hi = Gd.Maxi(hi, c.y);
            }
            GArray<Vector3i> @out = new GArray<Vector3i>();
            foreach (long x in Gd.Range(b.w))
            {
                foreach (long z in Gd.Range(b.d))
                {
                    var p = b.ChunkWorld(new Vector3i(x, 0, z));
                    if (new Vector2(p.x - mid.x, p.z - mid.z).Length() > radius)
                    {
                        continue;
                    }
                    foreach (long y in Gd.Range(lo, hi + 1))
                    {
                        if (b.frame.Alive(new Vector3i(x, y, z)))
                        {
                            @out.Append(new Vector3i(x, y, z));
                        }
                    }
                }
            }
            return @out;
        }

        void _InitFields()
        {
        }
    }
}
