// Generated from sim/death_overload.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class DeathOverload : RefCounted
    {
        public static implicit operator DeathOverload(Variant v) => (DeathOverload)v.Obj;

        // The kaiju's death (director 2026-10-26, every kaiju): "overloaded with kaiju energy, crackling
        // up, turning them to stone then exploding into shards". A death (tuning death.reasons: killed,
        // time's up, End rampage) no longer ends the run at once: he staggers (the clip's time), turns to
        // stone, then shatters. The shards are cells of his own body (BodyContact's discs) thrown out on
        // seeded arcs; each smashes what it lands on through RampageSim.hit_area, the normal destruction
        // path (it pays biomass as any blow does). The Death Blast nodes (stat death_blast) add a front
        // that runs out from the body and wrecks every floor in a ring round his body: death_blast x
        // per_node beyond the body's edge (director 2026-10-26, "Smaller: a ring round his body"; node 3
        // about one street block), also through hit_area. Shards first (director 2026-10-27, D-294): his
        // falling stone body smashes buildings, then the blast clears the rest, so the front starts
        // blast_after_s after the last shard lands. The run ends (RampageSim.end) settle_s after the front
        // (or the last shard), so the results wait for the burst. Part of RampageSim; pure: one derived
        // stream, no clock.
        // Time's up runs the jets' final strike first (FinalStrike, D-263), then his death.
        // Events: death_begin {reason}, death_stone, death_shatter {shards, centre, blast}, death_shard
        // {id, x, z}, death_blast {radius, x, z} (the front starts), then run_over.
        public static class Phase
        {
            public const long NONE = 0;
            public const long STRIKE = 1;
            public const long STAGGER = 2;
            public const long STONE = 3;
            public const long SHATTER = 4;
        }
        // One piece of him in the air: from (world), to (ground point), landing `t` s after the shatter.

        public class Shard : RefCounted
        {
            public static implicit operator Shard(Variant v) => (Shard)v.Obj;

            public long id;
            public Vector3 from;
            public Vector2 to;
            public double t;
            public bool landed = false;

            void _InitFields()
            {
            }
            public Shard() { _InitFields(); }
        }
        public RampageSim sim;
        public GDict cfg = new GDict();
        public long phase = Phase.NONE;
        public string reason = "";
        // Seconds since the death began, and since the shatter.
        public double t = 0.0;
        public double sinceShatter = 0.0;
        public GArray<DeathOverload.Shard> shards = new GArray<DeathOverload.Shard>();
        // The blast front's centre, its full radius (0: no node), how far it has run and when it starts
        // (seconds after the shatter: the last shard's landing + blast_after_s, D-294 shards first).
        public Vector2 centre = Vector2.ZERO;
        public double blastRadius = 0.0;
        public double blastFront = 0.0;
        public double blastAt = 0.0;
        public bool blastBegan = false;
        // Seconds after the shatter when the last shard lands.
        public double landingEnd = 0.0;
        // What the shards and the front broke (chunks), for tests and the results.
        public long shardChunks = 0;
        public long blastChunks = 0;
        // The jets' run at time's up.
        public FinalStrike strike;
        public RandomNumberGenerator _rng;

        public DeathOverload(RampageSim pSim, GDict tuning, RandomNumberGenerator rng)
        {
            _InitFields();
            sim = pSim;
            cfg = tuning["death"];
            _rng = rng;
            GDict strikeCfg = cfg["airstrike"];
            strike = new FinalStrike(sim, strikeCfg);
        }
        // True for an ending that is his death (the rest end at once: the city fell).

        public bool IsDeath(string why)
        {
            GArray<Variant> reasons = cfg["reasons"];
            return reasons.Has(why);
        }

        public bool Active()
        {
            return phase != Phase.NONE;
        }
        // He dies of `why`: the stagger starts now. False (nothing happens) for a reason that is no death.

        public bool Begin(string why)
        {
            if (!IsDeath(why))
            {
                return false;
            }
            if (Active())
            {
                return true;
            }
            reason = why;
            if (why == "time")
            {
                phase = Phase.STRIKE;
                strike.Start(_rng);
                return true;
            }
            _Stagger();
            return true;
        }

        public void _Stagger()
        {
            phase = Phase.STAGGER;
            t = 0.0;
            sim.events.Append(new GDict { { "type", "death_begin" }, { "reason", reason } });
        }
        // True when the kaiju takes no step of his own: the run is over, or he is dying and this runs the
        // sequence in place of his step: the world going on without him (falls, blasts, the army, the
        // sky, the trains); no input, no clock (RampageSim.step's early return).

        public bool Holds(double dt)
        {
            if (sim.over)
            {
                return true;
            }
            if (!Active())
            {
                return false;
            }
            Step(dt);
            sim.collapse.Step(dt);
            sim.explosives.Step(dt);
            sim.armyUnits.Step(dt);
            sim.air.Step(dt);
            sim.rail.Step(dt);
            sim.news.Step(sim.events);
            return true;
        }
        // One step of the sequence.

        public void Step(double dt)
        {
            if (phase == Phase.STRIKE)
            {
                if (strike.Step(dt))
                {
                    _Stagger();
                }
                return;
            }
            t += dt;
            double stoneAt = Num.F(cfg["stagger_s"]);
            if (phase == Phase.STAGGER && t >= stoneAt)
            {
                phase = Phase.STONE;
                sim.events.Append(new GDict { { "type", "death_stone" }, { "seconds", Num.F(cfg["stone_s"]) } });
            }
            if (phase == Phase.STONE && t >= stoneAt + Num.F(cfg["stone_s"]))
            {
                _Shatter();
                return;
            }
            if (phase == Phase.SHATTER)
            {
                _StepShatter(dt);
            }
        }
        // After the shatter: shards land as they come down, the blast front runs, then the run ends.

        public void _StepShatter(double dt)
        {
            sinceShatter += dt;
            foreach (DeathOverload.Shard s in shards)
            {
                if (!s.landed && sinceShatter >= s.t)
                {
                    _Land(s);
                }
            }
            _RunFront();
            double done = (blastRadius > 0.0 ? blastAt + Num.F(cfg["blast_s"]) : landingEnd);
            if (sinceShatter >= done + Num.F(cfg["settle_s"]))
            {
                sim.End(reason, true);
            }
        }
        // A shard's size (world units): one body cell at his scale.

        public double CellSize()
        {
            return Num.F(cfg["cell"]) * sim.BodyScale();
        }
        // The blast's full radius for `nodes` Death Blast levels (world units from his centre; 0
        // without one): his body's edge plus nodes x per_node.

        public double RadiusFor(double nodes)
        {
            if (nodes <= 0.0)
            {
                return 0.0;
            }
            return BodyEdge() + nodes * Num.F(cfg["per_node"]);
        }
        // How far his body reaches from where he stands (world units; BodyVolume.reach's rule).

        public double BodyEdge()
        {
            GArray<Variant> discs = (sim.body.Active() ? sim.body.Discs() : Gd.Arr(cfg["fallback_disc"]));
            double reach = 0.0;
            foreach (GArray<Variant> d in discs)
            {
                reach = Gd.Maxf(reach, Gd.Absf(Num.F(d[0])) + Num.F(d[1]));
            }
            return reach * sim.BodyScale();
        }

        public void _Shatter()
        {
            phase = Phase.SHATTER;
            sinceShatter = 0.0;
            centre = sim.kaijuPos;
            blastRadius = RadiusFor(sim.Stat("death_blast"));
            shards = _Throw(_BodyCells(), _rng);
            landingEnd = 0.0;
            foreach (DeathOverload.Shard s in shards)
            {
                landingEnd = Gd.Maxf(landingEnd, s.t);
            }
            blastAt = landingEnd + Num.F(cfg["blast_after_s"]);
            GArray<GDict> @out = new GArray<GDict>();
            foreach (DeathOverload.Shard s in shards)
            {
                @out.Append(new GDict { { "id", s.id }, { "from", s.from }, { "to", s.to }, { "t", s.t } });
            }
            sim.events.Append(new GDict { { "type", "death_shatter" }, { "shards", @out }, { "centre", centre }, { "blast", blastRadius }, { "cell", CellSize() } });
        }
        // Every cell of his body (world centres, one cell apart at his scale), in a fixed scan order.

        public GArray<Vector3> _BodyCells()
        {
            double s = sim.BodyScale();
            double step = Num.F(cfg["cell"]) * s;
            GArray<Variant> discs = (sim.body.Active() ? sim.body.Discs() : Gd.Arr(cfg["fallback_disc"]));
            GDict seen = new GDict();
            GArray<Vector3> @out = new GArray<Vector3>();
            foreach (GArray<Variant> d in discs)
            {
                var c = sim.kaijuPos + sim.facing * Num.F(d[0]) * s;
                double r = Num.F(d[1]) * s;
                long n = Gd.Ceili(r / step);
                long yLo = Gd.Floori((sim.standY + Num.F(d[2]) * s) / step);
                long yHi = Gd.Maxi(yLo + 1, Gd.Ceili((sim.standY + Num.F(d[3]) * s) / step));
                foreach (long gy in Gd.Range(yLo, yHi))
                {
                    foreach (long gx in Gd.Range(-n, n + 1))
                    {
                        foreach (long gz in Gd.Range(-n, n + 1))
                        {
                            var off = new Vector2(gx, gz) * step;
                            var key = new Vector3i(Gd.Roundi((c.x + off.x) / step), gy, Gd.Roundi((c.y + off.y) / step));
                            if (off.Length() <= r && !seen.Has(key))
                            {
                                seen[key] = true;
                                @out.Append(new Vector3(key.x * step, (gy + 0.5) * step, key.z * step));
                            }
                        }
                    }
                }
            }
            return @out;
        }
        // Picks the shards from his cells and throws each out from the body on a seeded arc.

        public GArray<DeathOverload.Shard> _Throw(GArray<Vector3> cells, RandomNumberGenerator rng)
        {
            long count = Gd.Mini(Num.I(cfg["shards"]), cells.Size());
            // a partial Fisher-Yates: the first `count` cells, seeded
            foreach (long i in Gd.Range(count))
            {
                long j = i + rng.RandiRange(0, cells.Size() - 1 - i);
                var keep = cells[i];
                cells[i] = cells[j];
                cells[j] = keep;
            }
            double s = sim.BodyScale();
            GArray<Variant> flight = cfg["flight_s"];
            double jitter = Gd.DegToRad(Num.F(cfg["throw_jitter_deg"]));
            GArray<DeathOverload.Shard> @out = new GArray<DeathOverload.Shard>();
            foreach (long i in Gd.Range(count))
            {
                var shard = new Shard();
                shard.id = i;
                shard.from = cells[i];
                var flat = new Vector2(shard.from.x, shard.from.z) - sim.kaijuPos;
                var dir = ((flat.Length() > 0.01 ? flat.Normalized() : Vector2.FromAngle(rng.Randf() * Gd.TAU)));
                dir = dir.Rotated(rng.RandfRange(-jitter, jitter));
                double reach = rng.RandfRange(Num.F(cfg["throw_min"]), Num.F(cfg["throw_max"])) * s;
                shard.to = sim.ClampToArena(new Vector2(shard.from.x, shard.from.z) + dir * reach);
                shard.t = rng.RandfRange(Num.F(flight[0]), Num.F(flight[1]));
                @out.Append(shard);
            }
            return @out;
        }
        // A shard comes down: a blow on the top floors of whatever stands under it.

        public void _Land(DeathOverload.Shard s)
        {
            s.landed = true;
            sim.events.Append(new GDict { { "type", "death_shard" }, { "id", s.id }, { "x", s.to.x }, { "z", s.to.y } });
            var at = s.to;
            double radius = Num.F(cfg["shard_radius"]);
            long top = _TopAt(at);
            long before = sim.chunksDestroyed;
            sim.HitArea(new Callable(a_ =>
            {
                Vector2 p = a_[0];
                double r = a_[1];
                return RampageSim.Falloff(p.DistanceTo(at) - r, radius);
            }), Num.F(cfg["shard_damage"]), Gd.Maxi(0, top - Num.I(cfg["shard_floors"])), Gd.Maxi(top, Num.I(cfg["shard_floors"])));
            shardChunks += sim.chunksDestroyed - before;
        }
        // The tallest standing building's height (floors) whose footprint holds `p`; 0 on open ground.

        public long _TopAt(Vector2 p)
        {
            return AirWing.TopAt(sim, p);
        }
        // The blast front moves on once the last shard is down (blast_at): everything between where it
        // was and where it is now takes the blow once, every floor (his own power, the one effect that
        // goes big).

        public void _RunFront()
        {
            if ((blastRadius <= 0.0 || blastFront >= blastRadius || sinceShatter < blastAt))
            {
                return;
            }
            if (!blastBegan)
            {
                blastBegan = true;
                sim.events.Append(new GDict { { "type", "death_blast" }, { "radius", blastRadius }, { "x", centre.x }, { "z", centre.y } });
            }
            double was = blastFront;
            double k = Gd.Clampf((sinceShatter - blastAt) / Gd.Maxf(0.001, Num.F(cfg["blast_s"])), 0.0, 1.0);
            blastFront = blastRadius * k;
            double now = blastFront;
            var at = centre;
            long before = sim.chunksDestroyed;
            sim.hitAir = true;
            sim.HitArea(new Callable(a_ =>
            {
                Vector2 p = a_[0];
                double r = a_[1];
                double dist = p.DistanceTo(at);
                return (dist - r < now && dist + r >= was ? 1.0 : 0.0);
            }), Num.F(cfg["blast_damage"]), 0, Num.I(cfg["blast_floors"]));
            sim.hitAir = false;
            blastChunks += sim.chunksDestroyed - before;
        }

        void _InitFields()
        {
        }
    }
}
