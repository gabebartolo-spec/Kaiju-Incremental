// Generated from sim/species_powers.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class SpeciesPowers : RefCounted
    {
        public static implicit operator SpeciesPowers(Variant v) => (SpeciesPowers)v.Obj;

        // The species branches of the upgrade tree as simulation (docs/SPECIES.md): each power is
        // off until its node is bought (its stat is 0) and grows with every level. Part of
        // RampageSim; split out to keep files small. Pure and seeded.
        // Reptilian: the tail lash on the signature (D-280, D-328), the automatic tail sweep (D-459),
        // Atomic Beam; momentum is always
        // on (Momentum, D-337).
        // Shared: buildings block the body (slow it) unless a power says otherwise, and coatings
        // (beam fire) that eat chunks and units over time.
        // A chunk is one sim unit across: its centre is this far from its faces.
        public const double CHUNK_HALF = 0.5;
        public RampageSim sim;
        public GDict cfg = new GDict();
        // 0..1: how much run the titan has built (Momentum).
        public double momentum
        {
            get
            {
                return run.value;
            }
            set
            {
                run.value = value;
            }
        }
        // The titan's run (D-337): momentum, crashing through what is under it, the slam.
        public Momentum run;
        public double beamLeft = 0.0;
        // Coated chunks, worn each step (CoatWear).
        public CoatWear coats = new CoatWear();
        public long tailSweeps = 0;
        // The reptilian's automatic tail sweep (D-459; it replaced the claw rake, D-095).
        public TailSweep sweep;
        // Fire that spreads building to building once City Ablaze is owned (D-126).
        public FireSpread fire;
        // Chunks broken by tail sweeps themselves (not what falls after).
        public long tailCut = 0;
        public RandomNumberGenerator _rng;
        public double _ramCd = 0.0;
        // the river's channels (CityRiver), found on first need
        public Variant _channels = default;
        // seconds until a wound-up lash strikes; < 0: none
        public double _lashWait = -1.0;

        public SpeciesPowers(RampageSim pSim, RandomNumberGenerator rng)
        {
            _InitFields();
            sim = pSim;
            cfg = sim.powersCfg;
            _rng = rng;
            GDict runCfg = cfg["momentum"];
            run = new Momentum(sim, runCfg);
            sweep = new TailSweep(sim, cfg);
            GDict fireCfg = cfg["fire"];
            fire = new FireSpread(sim, fireCfg, Seeds.Derive(rng, 0xF12EL));
        }

        public double _Bs()
        {
            return sim.BodyScale();
        }
        // The species the sim plays (BodyContact.use_species): its titan's momentum entry.

        public void UseSpecies(string speciesId)
        {
            run.UseSpecies(speciesId);
        }
        // --- Movement: blocking, momentum, wading ----------------------------------------------
        // Speed multiplier this step: momentum speeds the walk; buildings in the way slow the body, except
        // when it leaps over them or crashes through them.

        public double SpeedMult()
        {
            // ice on the legs slows it
            return _GroundMult() * sim.armyUnits.taskforce.frost.Mult();
        }

        public double _GroundMult()
        {
            // slowed from the press (D-166)
            if ((beamLeft > 0.0 || sim.strikes.Winding(Strikes.BEAM)))
            {
                return Num.F(cfg["beam_move_mult"]);
            }
            if (sim.airborne)
            {
                return Num.F(cfg["glide_speed_mult"]);
            }
            double mult = run.SpeedMult();
            if (Blocked(sim.kaijuPos, BlockRadius()))
            {
                mult *= Num.F(cfg["block_slow"]);
            }
            return mult;
        }
        // The body's footprint for being held up by buildings. It does not grow with the kaiju, and
        // it stays narrower than a street (block_street_margin inside half its width): a grown kaiju
        // strides down any street and only the walls it walks into hold it back. It is wider than
        // an alley, so alleys hold it.

        public double BlockRadius()
        {
            double street = Num.F(sim.city["street_width"]) * 0.5 - Num.F(cfg["block_street_margin"]);
            return Gd.Minf(Num.F(cfg["block_radius"]), street);
        }
        // Any standing street-level chunk whose square the circle (pos, radius) overlaps (one a crash
        // takes, Momentum.crashes_column, does not hold the body).

        public bool Blocked(Vector2 pos, double radius)
        {
            foreach (long i in sim.grid.Around(pos, radius))
            {
                var b = sim.buildings[i];
                if (b.frame.aliveCount == 0)
                {
                    continue;
                }
                if ((Gd.Absf(b.x - pos.x) > b.w * 0.5 + radius || Gd.Absf(b.z - pos.y) > b.d * 0.5 + radius))
                {
                    continue;
                }
                foreach (long x in Gd.Range(b.w))
                {
                    foreach (long z in Gd.Range(b.d))
                    {
                        var c = new Vector3i(x, 0, z);
                        if (b.frame.Alive(c) && !run.CrashesColumn(b, x, z))
                        {
                            var p = b.ChunkWorld(c);
                            var gap = new Vector2(Gd.Maxf(Gd.Absf(p.x - pos.x) - CHUNK_HALF, 0.0), Gd.Maxf(Gd.Absf(p.z - pos.y) - CHUNK_HALF, 0.0));
                            if (gap.Length() < radius)
                            {
                                return true;
                            }
                        }
                    }
                }
            }
            return false;
        }
        // How fast the beam follows the stick, rad/s (the body turns at least this fast while it is on).

        public double BeamTurnRate()
        {
            return Num.F(cfg["beam_turn_speed"]) * Gd.TAU;
        }
        // The beam turns the kaiju slowly (steering the beam); otherwise it faces where it moves.

        public Vector2 TurnToward(Vector2 from, Vector2 to, double dt)
        {
            if (beamLeft <= 0.0)
            {
                return to;
            }
            double angle = from.AngleTo(to);
            double most = BeamTurnRate() * dt;
            return from.Rotated(Gd.Clampf(angle, -most, most));
        }

        public void AfterMove(double dt, Vector2 oldFacing, bool moving)
        {
            double turn = (moving ? Gd.Absf(oldFacing.AngleTo(sim.facing)) : 0.0);
            run.Build(dt, turn, moving);
            sim.standY = _Wade(dt);
            _Ram(dt);
            sweep.Step(dt);
            if (_lashWait >= 0.0)
            {
                _lashWait -= dt;
                if (_lashWait < 0.0)
                {
                    Lash();
                }
            }
        }
        // Stomp (and ram) damage multiplier from momentum: the momentum node makes it hit harder.

        public double HitMult()
        {
            return 1.0 + sim.Stat("momentum") * momentum;
        }
        // The signature pressed: the tail winds up (the keyed curl, director 2026-10-31 "Full windup"),
        // and lash() strikes powers.lash_windup later, when the keyed tail crosses behind him.

        public void WindLash()
        {
            if (_lashWait >= 0.0)
            {
                return;
            }
            sim.events.Append(new GDict { { "type", "tail_windup" }, { "side", (tailSweeps % 2 == 0 ? 1.0 : -1.0) } });
            _lashWait = Num.F(cfg["lash_windup"]);
            if (_lashWait <= 0.0)
            {
                _lashWait = -1.0;
                Lash();
            }
        }
        // The tail lash (D-280): mid-stride, the tail whips through the half ring behind and beside
        // the body (D-329: "Behind-and-around"), flattening the street and the floors up to the cut at
        // full force (no falloff): what stands above the cut drops. The tail nodes upgrade it (D-328).
        // Lashes alternate sides so the whip reads left, then right. D-459: the lash also carries the
        // removed claw rake's share, lash_sweep_share x the sweep_damage stat.

        public void Lash()
        {
            double side = (tailSweeps % 2 == 0 ? 1.0 : -1.0);
            tailSweeps += 1;
            double reach = (Num.F(cfg["tail_reach"]) + sim.Stat("tail_reach")) * _Bs();
            var centre = sim.kaijuPos;
            var ahead = sim.facing;
            long lo = Num.I(cfg["tail_floor_lo"]);
            double perScale = Num.F(cfg["tail_floors_per_scale"]);
            long floors = Gd.Ceili((Num.F(cfg["tail_floors"]) + sim.Stat("tail_floors")) * _Bs() * perScale);
            double arc = Num.F(cfg["tail_arc_dot"]);
            sim.events.Append(new GDict { { "type", "tail_sweep" }, { "side", side }, { "reach", reach } });
            long before = sim.chunksDestroyed;
            SimDamage.Area(sim, new Callable(a_ =>
            {
                Vector2 p = a_[0];
                double r = a_[1];
                var to = p - centre;
                if (to.Length() > reach + r)
                {
                    return 0.0;
                }
                return ((to.Length() <= r || ahead.Dot(to.Normalized()) <= arc) ? 1.0 : 0.0);
            }), LashDamage(), lo, lo + floors, true);
            // the lash throws tanks (D-437)
            tailCut += sim.chunksDestroyed - before;
        }
        // The lash's damage: its base, the tail nodes, and the rake's old share (D-459).

        public double LashDamage()
        {
            double share = Num.F(cfg["lash_sweep_share"]) * sim.Stat("sweep_damage");
            return Num.F(cfg["lash_damage"]) + sim.Stat("tail_damage") + share;
        }
        // With the momentum node the reptilian rams what is in front of it and knocks tanks flying
        // (TankFlight), to land knockback x momentum ahead.

        public void _Ram(double dt)
        {
            _ramCd -= dt;
            if ((sim.Stat("momentum") <= 0.0 || momentum < Num.F(cfg["ram_min"]) || _ramCd > 0.0))
            {
                return;
            }
            _ramCd = Num.F(cfg["ram_interval"]);
            var centre = sim.kaijuPos;
            var ahead = sim.facing;
            double radius = Num.F(cfg["body_radius"]) * _Bs() + Num.F(cfg["ram_reach_extra"]);
            var front = new Callable(a_ =>
            {
                Vector2 p = a_[0];
                double r = a_[1];
                var to = p - centre;
                return (to.Length() <= radius + r && to.Dot(ahead) >= -r ? 1.0 : 0.0);
            });
            foreach (RampageSim.Tank tank in sim.tanks)
            {
                if (!tank.flying && front.Call(tank.pos, RampageSim.TANK_RADIUS) > 0.0)
                {
                    sim.flight.Launch(tank, ahead, Num.F(cfg["knockback"]) * momentum);
                }
            }
            sim.HitArea(front, sim.Stat("stomp_damage") * sim.Stat("momentum") * momentum);
        }
        // Where he stands: on the street, or in the river's channels on the wading floor,
        // city "wade_depth" under the river's water (director 2026-10-31: "the baby kaiju should be like
        // half submerged in the river"), stepping down into it and up out of it at "wade_speed" m/s.

        public double _Wade(double dt)
        {
            GDict city = sim.city;
            if (Gd.IsNull(_channels))
            {
                _channels = (city.Has("wade_depth") ? CityRiver.Channels(CityGen.Map(city), city) : Gd.Arr());
            }
            double ground = 0.0;
            foreach (Rect2 channel in Gd.Iter(_channels))
            {
                if (channel.HasPoint(sim.kaijuPos))
                {
                    ground = -Num.F(city["river_depth"]) - Num.F(city["wade_depth"]);
                    break;
                }
            }
            if (ground >= 0.0 && sim.standY >= 0.0)
            {
                return 0.0;
            }
            return Gd.MoveToward(sim.standY, ground, Num.F(city["wade_speed"]) * dt);
        }
        // Height (floors) of the standing top of the building column at pos, 0 on the street.

        public double ColumnTop(Vector2 pos)
        {
            foreach (long i in sim.grid.Around(pos, 0.0))
            {
                var b = sim.buildings[i];
                long lx = Gd.Floori(pos.x - (b.x - b.w * 0.5));
                long lz = Gd.Floori(pos.y - (b.z - b.d * 0.5));
                if (lx >= 0 && lz >= 0 && lx < b.w && lz < b.d)
                {
                    return Gd.Float(Gd.Maxi(0, b.frame.TopBelow(lx, lz, b.height) + 1 + b.@base));
                }
            }
            return 0.0;
        }
        // --- Signature follow-ups and ultimates ------------------------------------------------

        public bool HasUltimate()
        {
            return sim.Stat("beam_dps") > 0.0;
        }

        public void Ultimate()
        {
            // the view roars (D-145)
            sim.events.Append(new GDict { { "type", "ultimate" } });
            if (sim.Stat("beam_dps") > 0.0)
            {
                // the stream starts at the strike, the jaws open (D-166)
                sim.strikes.Beam();
            }
        }
        // The jaws open: the Thunder Beam's stream starts (Strikes, after the wind-up).

        public void StartBeam()
        {
            beamLeft = Num.F(cfg["beam_seconds"]);
            sim.events.Append(new GDict { { "type", "beam_start" }, { "seconds", beamLeft } });
        }

        public void Step(double dt)
        {
            _Beam(dt);
            coats.Step(sim, dt);
            fire.Step(dt);
        }

        public void _Beam(double dt)
        {
            if (beamLeft <= 0.0)
            {
                return;
            }
            beamLeft -= dt;
            var origin = sim.kaijuPos;
            var dir = sim.facing;
            double length = Num.F(cfg["beam_range"]) * _Bs();
            double half = Num.F(cfg["beam_half_width"]) * _Bs();
            sim.hitCoat = new GDict { { "kind", "burn" }, { "dps", Num.F(cfg["burn_dps"]) }, { "seconds", cfg["burn_seconds"] } };
            sim.hitAir = true;
            var beam = new RampageSim.Beam(origin, dir, length, half);
            sim.hitBeam = beam;
            sim.HitArea(new Callable(a_ => beam.Reaches(a_[0], a_[1])), sim.Stat("beam_dps") * dt, 0, Gd.Ceili(sim.ReachTop() * Num.F(cfg["coat_reach_mult"])));
            sim.hitCoat = new GDict();
            sim.hitAir = false;
            sim.hitBeam = null;
            if (beamLeft <= 0.0)
            {
                sim.events.Append(new GDict { { "type", "beam_end" } });
            }
        }
        // --- Coatings: beam fire eats what it covers -------------------------------------------
        // Coats chunks of building `index` with sim.hit_coat (refreshing an existing coat).

        public void Coat(long index, GArray<Vector3i> cells)
        {
            if (cells.IsEmpty())
            {
                return;
            }
            var b = sim.buildings[index];
            GArray<Vector3i> fresh = new GArray<Vector3i>();
            double seconds = Num.F(sim.hitCoat["seconds"]);
            double dps = Num.F(sim.hitCoat["dps"]);
            foreach (Vector3i c in cells)
            {
                long key = index * CoatWear.KEY_SPAN + b.frame.Index(c);
                if (!coats.Has(key))
                {
                    fresh.Append(c);
                }
                coats.Put(key, c, seconds, dps);
            }
            if (!fresh.IsEmpty())
            {
                sim.events.Append(new GDict { { "type", "coated" }, { "building", index }, { "cells", fresh }, { "kind", sim.hitCoat["kind"] } });
            }
            if (Gd.Str(sim.hitCoat["kind"]) == "burn")
            {
                fire.Ignite(index);
            }
        }

        void _InitFields()
        {
        }
    }
}
