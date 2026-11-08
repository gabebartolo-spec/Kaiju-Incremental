// Generated from sim/dash.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class Dash : RefCounted
    {
        public static implicit operator Dash(Variant v) => (Dash)v.Obj;

        // The dash button (Shift / pad B). Its move is the croc's leap (D-259, "a leap that lands on a
        // building and crushes it with a shockwave (replaces the dash)"): the body crouches, flies a fixed
        // time along its facing to the standing building ahead in reach (else the full reach), and lands:
        // the landing is one blow through the carve path (RampageSim.hit_area, D-253) that crushes what is
        // under it and sends a shockwave ring through units and buildings around it, flinging tanks
        // outward (b2-9); damage lands on the contact, never on the press (D-166). Then it settles and
        // recovers, standing, before it walks again. Phase times, reach, ring, damage and cooldown are per
        // stage in data/tuning.json contact.leap (times from the reader's bars, C:/kt/croc_kit/reference.md
        // L1). Only a species listed there with a body volume leaps; the old charge is gone (no species
        // keeps it). Part of RampageSim (BodyContact owns it); pure, no randomness.
        // The step() button flag for the dash button, beside RampageSim.HELD and ULTIMATE.
        public const long BUTTON = 4;
        // The leap's phases, in order; "" when no leap is under way.
        public static readonly GArray<string> PHASES = new GArray<string> { "crouch", "flight", "settle", "recover" };
        public RampageSim sim;
        public BodyContact body;
        // data/tuning.json contact.leap (aim, and the stages per species).
        public GDict cfg = new GDict();
        // Seconds until the button is ready again (from the press).
        public double readyIn = 0.0;
        // Presses that started a leap this rampage (the Taskforce's frost reads it: a leap shatters ice).
        public long dashes = 0;
        // Leaps that landed this rampage.
        public long landings = 0;
        // Where the leap under way sets off and lands (kaiju_pos), and the building it aims at (-1: none).
        public Vector2 from = Vector2.ZERO;
        public Vector2 to = Vector2.ZERO;
        public long target = -1;
        public Vector2 dir = Vector2.ZERO;
        // The flight's height (LeapArc): high over the street, down on the target's roof.
        public LeapArc arc;
        public GArray<Variant> _stages = Gd.Arr();
        public GDict _stage = new GDict();
        // index into PHASES; -1: no leap
        public long _phase = -1;
        // seconds into the current phase
        public double _t = 0.0;
        // contact: tuning "contact"; the leap reads its "leap" sub-object.

        public Dash(BodyContact pBody, GDict contact)
        {
            _InitFields();
            body = pBody;
            sim = body.sim;
            cfg = contact.Get("leap", new GDict());
            arc = new LeapArc(sim);
        }
        // Picks the species' stages (none: this species has no leap).

        public void UseSpecies(string speciesId)
        {
            GDict bySpecies = cfg.Get("stages", new GDict());
            _stages = bySpecies.Get(speciesId, Gd.Arr());
        }
        // A leap is under way (any phase): the body takes no stick and holds its facing.

        public bool On()
        {
            return _phase >= 0;
        }

        public bool Available()
        {
            return body.Active() && !_stages.IsEmpty();
        }
        // The cooldown of the stage the kaiju is at (seconds, press to ready).

        public double Cooldown()
        {
            return Num.F(_Now().Get("cooldown", 0.0));
        }
        // The phase under way ("crouch", "flight", "settle", "recover"), "" with no leap.

        public string Phase()
        {
            return (_phase >= 0 ? PHASES[_phase] : "");
        }
        // How far through its phase the leap is, 0..1.

        public double PhaseT()
        {
            return (_phase >= 0 ? Gd.Clampf(_t / Gd.Maxf(0.001, _PhaseS(_phase)), 0.0, 1.0) : 0.0);
        }
        // The phase's seconds at the kaiju's stage (presentation holds its poses on them).

        public double PhaseSeconds(string phaseName)
        {
            return _PhaseS(PHASES.Find(phaseName));
        }
        // How high the body is above the street (world units): the arc through the flight; through the
        // settle it sinks from the roof it landed on to the street as the building breaks under it (the
        // body's sweep breaks what it sinks into); zero otherwise.

        public double Height()
        {
            var matched1 = Phase();
            if (matched1 == "flight")
            {
                return arc.At(PhaseT());
            }
            else if (matched1 == "settle")
            {
                return arc.landY * (1.0 - PhaseT() * PhaseT());
            }
            return 0.0;
        }
        // Starts a leap when pressed and ready, then carries it through its phases. Before the sweep.

        public void Step(double dt, bool pressed)
        {
            readyIn = Gd.Maxf(0.0, readyIn - dt);
            if (pressed && CanLeap())
            {
                _Start(AimAt(sim.kaijuPos, sim.facing));
                return;
            }
            if (_phase < 0)
            {
                return;
            }
            sim.facing = dir;
            _t += dt;
            while (_phase >= 0 && _t >= _PhaseS(_phase))
            {
                _t -= _PhaseS(_phase);
                _Next();
            }
            if (Phase() == "flight")
            {
                sim.kaijuPos = from.Lerp(to, PhaseT());
            }
        }
        // True when a press now would leap: ready, idle, on the ground, and with somewhere to land other
        // than where it stands (at the arena's edge, or against a tower it may not land on, it has none).

        public bool CanLeap()
        {
            if ((readyIn > 0.0 || _phase >= 0 || !Available() || sim.airborne))
            {
                return false;
            }
            GDict aim = AimAt(sim.kaijuPos, sim.facing);
            // within a landing step of where it stands: nowhere to go
            Vector2 toPos = aim["to"];
            return toPos.DistanceTo(sim.kaijuPos) >= Num.F(cfg["landing_step"]);
        }
        // The building a press now would land on (-1 for none, or when it would not leap): the pacing
        // bot presses only for one.

        public long TargetAhead()
        {
            return (CanLeap() ? Num.I(AimAt(sim.kaijuPos, sim.facing)["building"]) : -1);
        }
        // The leap to `aim` (aim_at's) begins: the crouch, the cooldown.

        public void _Start(GDict aim)
        {
            _stage = _Now();
            readyIn = Num.F(_stage["cooldown"]);
            dashes += 1;
            dir = sim.facing;
            from = sim.kaijuPos;
            target = Num.I(aim["building"]);
            to = aim["to"];
            var numbers = new Vector4(Num.F(aim["roof"]), Num.F(_stage["clear"]) * sim.BodyScale(), Num.F(cfg["landing_step"]), Num.F(cfg["arc_tries"]));
            bool side = aim["side"];
            arc.carve = (side ? target : -1);
            arc.Plan(body.Discs(), new PackedVector2Array(Gd.Arr(from, to)), dir, numbers);
            _phase = 0;
            _t = 0.0;
            GDict leap = new GDict { { "type", "leap" }, { "from", from }, { "to", to }, { "building", target }, { "dir", dir } };
            leap["side"] = side;
            foreach (long n in Gd.Range(PHASES.Size()))
            {
                leap[PHASES[n]] = _PhaseS(n);
            }
            leap["apex"] = arc.top;
            leap["roof"] = arc.landY;
            sim.events.Append(leap);
        }
        // Where a leap from `at` along `ahead` lands: {"building": index or -1, "to": kaiju_pos there,
        // "roof": the height it lands at, "side": whether it takes the target in its side}. The feet come
        // down on the roof of the nearest standing building in the arena whose centre lies within the aim
        // cone and between min_reach and reach of them; with none, on the street at the full reach along
        // `ahead`. A building that dwarfs the body (D-091), or a landing whose body would sit in one, is
        // not landed on: the body comes down on the street before it, clear of it, and the blow chews its
        // wall. A roof above his shoulder (D-361) is not landed on either: the leap takes the building in
        // its side, the feet on the street at its foot and the body carving into it; nor is it leapt over:
        // the first building on the flight path above his shoulder becomes the target, taken in its side
        // (director 2026-11-03: he leapt onto the tops of extremely tall buildings).

        public GDict AimAt(Vector2 at, Vector2 ahead)
        {
            GDict aim = _Target(at, ahead);
            long best = Num.I(aim["building"]);
            Vector2 to = aim["to"];
            double roof = Num.F(aim["roof"]);
            double step = Num.F(cfg["landing_step"]);
            var side = false;
            if (best >= 0 && ((_Dwarfs(best) || _InTower(to, ahead, roof))))
            {
                roof = 0.0;
                while (to != at && _InTower(to, ahead, 0.0))
                {
                    to = to.MoveToward(at, step);
                }
            }
            else if (best >= 0 && roof > ShoulderY())
            {
                roof = 0.0;
                side = true;
                while (to != at && _FeetIn(best, to, ahead))
                {
                    to = to.MoveToward(at, step);
                }
            }
            return new GDict { { "building", best }, { "to", to }, { "roof", roof }, { "side", side } };
        }
        // The leap's target before D-091 and D-361 move its landing: {"building", "to", "roof"}. The
        // nearest building ahead in reach (_nearest_ahead), else the street at the full reach; then the
        // first building on the flight path above his shoulder (LeapArc.wall), if any, in its place.

        public GDict _Target(Vector2 at, Vector2 ahead)
        {
            var feet = at + ahead * body.FeetAhead();
            long best = _NearestAhead(feet, ahead);
            var land = feet + ahead * Num.F(_Now()["reach"]) * sim.BodyScale();
            if (best >= 0)
            {
                land = _Centre(best);
            }
            double step = Num.F(cfg["landing_step"]);
            var to = _Dry(sim.ClampToArena(land - ahead * body.FeetAhead()), at, step);
            var ends = new PackedVector2Array(Gd.Arr(at, to));
            long wall = arc.Wall(body.Discs(), ends, ahead, new Vector2(ShoulderY(), step));
            // a tower in the way: the leap takes it, never clears it
            if (wall >= 0 && wall != best)
            {
                best = wall;
                to = _Dry(sim.ClampToArena(_Centre(best) - ahead * body.FeetAhead()), at, step);
            }
            double roof = (best >= 0 ? Gd.Float(sim.buildings[best].height) : 0.0);
            return new GDict { { "building", best }, { "to", to }, { "roof", roof } };
        }

        public Vector2 _Centre(long index)
        {
            return new Vector2(sim.buildings[index].x, sim.buildings[index].z);
        }
        // `to` pulled back toward `at` by `step` until it is out of the sea bay's water (Emergence.wet): a
        // leap never lands in the bay, only short of it on dry land.

        public Vector2 _Dry(Vector2 to, Vector2 at, double step)
        {
            while (to != at && sim.emerge.Wet(to))
            {
                to = to.MoveToward(at, step);
            }
            return to;
        }
        // The highest roof a leap lands on (world units above the street): the shoulder of the body at
        // the kaiju's stage, its share of the drawn height (data, measured from the model, D-361).

        public double ShoulderY()
        {
            return Num.F(_Now()["shoulder"]) * sim.ReachHeight();
        }
        // Whether the feet of the body at `pose` along `ahead` stand inside building `index`'s footprint.

        public bool _FeetIn(long index, Vector2 pose, Vector2 ahead)
        {
            var b = sim.buildings[index];
            var f = pose + ahead * body.FeetAhead();
            return Gd.Absf(f.x - b.x) < b.w * 0.5 && Gd.Absf(f.y - b.z) < b.d * 0.5;
        }
        // The nearest standing building in the arena whose centre is in the aim cone along `ahead` and
        // between min_reach and reach of `feet`; -1 for none.

        public long _NearestAhead(Vector2 feet, Vector2 ahead)
        {
            double s = sim.BodyScale();
            double reach = Num.F(_Now()["reach"]) * s;
            double near = Num.F(_Now()["min_reach"]) * s;
            double cone = Gd.Cos(Gd.DegToRad(Num.F(cfg["aim_half_angle_deg"])));
            long best = -1;
            double bestD = Gd.INF;
            foreach (long i in Gd.Range(sim.buildings.Size()))
            {
                var b = sim.buildings[i];
                var off = new Vector2(b.x, b.z) - feet;
                double d = off.Length();
                if ((b.frame.aliveCount == 0 || !b.inArena || d < near || d > reach || d >= bestD))
                {
                    continue;
                }
                if (off.Normalized().Dot(ahead) >= cone)
                {
                    best = i;
                    bestD = d;
                }
            }
            return best;
        }

        public bool _Dwarfs(long index)
        {
            return Growth.DwarfMult(sim.SizeTier(), sim.buildings[index].tier, sim.city) < 1.0;
        }
        // Whether the body at `pose`, lifted `lift`, overlaps a standing building that dwarfs it.

        public bool _InTower(Vector2 pose, Vector2 ahead, double lift)
        {
            body.SetLift(lift);
            GDict inside = body.Inside(pose, ahead);
            body.SetLift(Height());
            foreach (long index in inside)
            {
                if (_Dwarfs(index))
                {
                    return true;
                }
            }
            return false;
        }

        public void _Next()
        {
            var matched2 = Phase();
            if (matched2 == "crouch")
            {
                // stomps, tail sweeps and the body's sweep wait for the landing
                sim.airborne = true;
                sim.events.Append(new GDict { { "type", "leap_off" }, { "at", from } });
            }
            else if (matched2 == "flight")
            {
                sim.kaijuPos = to;
                sim.airborne = false;
                _Land();
            }
            _phase += 1;
            if (_phase >= PHASES.Size())
            {
                _phase = -1;
                _t = 0.0;
            }
        }
        // The contact: tanks in the ring are flung outward, then one blow crushes what is under the feet
        // at full force within the ring, fading to nothing at twice its radius (RampageSim.falloff).

        public void _Land()
        {
            landings += 1;
            double s = sim.BodyScale();
            double ring = Num.F(_stage["ring"]) * s;
            var centre = to + dir * body.FeetAhead();
            sim.events.Append(new GDict { { "type", "leap_land" }, { "at", centre }, { "radius", ring }, { "building", target }, { "damage", Num.F(_stage["damage"]) } });
            var force = new Callable(a_ =>
            {
                Vector2 p = a_[0];
                double r = a_[1];
                return RampageSim.Falloff(p.DistanceTo(centre) - r, ring);
            });
            _Fling(centre, force, Num.F(_stage["fling"]) * s);
            // landed on a roof: all of it
            long top = Gd.Maxi(Gd.Ceili(sim.ReachTop()), Gd.Ceili(arc.landY) + 1);
            sim.HitArea(force, Num.F(_stage["damage"]) * sim.powers.HitMult(), 0, top);
        }
        // Every tank the ring reaches is sent flying (TankFlight) outward from the centre, to land `fling`
        // x its force out (a tank under the feet goes straight along the leap).

        public void _Fling(Vector2 centre, Callable force, double fling)
        {
            foreach (RampageSim.Tank tank in sim.tanks)
            {
                double k = Num.F(force.Call(tank.pos, RampageSim.TANK_RADIUS));
                if ((k <= 0.0 || tank.flying))
                {
                    continue;
                }
                var @out = tank.pos - centre;
                @out = (@out.Length() < 0.01 ? dir : @out.Normalized());
                sim.events.Append(new GDict { { "type", "tank_flung" }, { "tank", tank.id }, { "from", tank.pos } });
                sim.flight.Launch(tank, @out, fling * k);
            }
        }
        // The stage's leap numbers (the kaiju's size tier; empty with no leap).

        public GDict _Now()
        {
            if (_stages.IsEmpty())
            {
                return new GDict();
            }
            return _stages[Gd.Clampi(sim.SizeTier() - 1, 0, _stages.Size() - 1)];
        }
        // A phase's seconds: the leap under way's, else the stage's now.

        public double _PhaseS(long index)
        {
            GDict stage = (_phase >= 0 ? _stage : _Now());
            if ((index < 0 || stage.IsEmpty()))
            {
                return 0.0;
            }
            return Num.F(stage[PHASES[index] + "_s"]);
        }

        void _InitFields()
        {
        }
    }
}
