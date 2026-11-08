// Generated from sim/body_contact.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class BodyContact : RefCounted
    {
        public static implicit operator BodyContact(Variant v) => (BodyContact)v.Obj;

        // The kaiju's body as a solid (playtest note 2): a chain of discs along the body's heading,
        // sized per life stage to the drawn model (data/tuning.json "contact"), breaks every standing
        // chunk it overlaps as it walks or turns, so the model never passes through an intact wall. The
        // path between two steps is swept in samples, so a fast move or a quick turn of the long snout
        // or tail leaves nothing standing inside the body. A building that dwarfs the kaiju (D-091) is
        // chewed at bite_dps x Growth.dwarf_mult instead of broken outright, and holds the body at its
        // wall until its chunks give. Part of RampageSim; pure, no randomness.
        public RampageSim sim;
        public GDict cfg = new GDict();
        // Where the drawn body faces (the model reads it): sim.facing, which steer() turns with weight;
        // a facing set from outside (the rise from the river, a test) is turned to at turn_rate_still.
        public Vector2 heading = new Vector2(0, -1);
        // The stride, 0..1 of full speed: it eases toward the stick's push, less the harder the turn.
        public double stride = 0.0;
        // The turn still to make (rad, signed as Vector2.angle_to): the head looks ahead by it.
        public double turnLeft = 0.0;
        // Chunks the body itself has broken this rampage.
        public long broken = 0;
        // True on a step a wall that has not given yet held the body back.
        public bool held = false;
        // The longest unbroken time a wall has held the body this rampage, seconds.
        public double longestHold = 0.0;
        // The snout tip's forward offset from kaiju_pos at body scale 1, design units ("snout").
        public double snout = 0.0;
        // The dash button's leap (Dash): the body crouches, flies and lands on what is ahead.
        public Dash dash;
        // Steps walked so far (0 at the first step; an integer is a footfall, even the left foot, odd the
        // right): the sim's step clock, which the legs follow (ClipGait) and which opens the yaw slices.
        public double phase = 0.0;
        // How much of a full step's length each step takes now, 0..1: a turn's quick steps are short ones
        // (the legs scale the clip's foot travel by it: a planted foot is passed at the body's pace).
        public double stepRatio = 1.0;
        // Stomps the sim has made (it counts them): they alternate feet, the left first.
        public long stomps = 0;
        // True on a step a foot came down (the step clock passed a whole number): `landed_foot`'s.
        public bool footfallNow = false;
        // The discs at body scale 1, in design units: [forward offset, radius, bottom, top]; empty
        // for a species without a body volume (then the body only slows in walls, as before).
        public GArray<Variant> _discs = Gd.Arr();
        public BodyVolume _volume;
        public Vector2 _lastPos = new Vector2(Gd.INF, Gd.INF);
        public Vector2 _lastHeading = new Vector2(0, -1);
        public double _holdS = 0.0;
        // how fast the body turns now (rad/s, signed as turn_left)
        public double _spin = 0.0;
        // The feet at body scale 1: (how far ahead of kaiju_pos a foot lands in a full step, half gap).
        public Vector2 _pivot = Vector2.ZERO;
        // Where a stomp's foot comes down at body scale 1: (ahead of kaiju_pos along the heading, out to
        // the left foot's side); zero for a body with no entry (its stomp is centred on kaiju_pos).
        public Vector2 _stompFoot = Vector2.ZERO;
        // the stage's own entry in contact.bodies (empty: none)
        public GDict _stage = new GDict();
        // The last two feet to land (world, newest first) stand until they lift: the body turns about them.
        public GArray<Vector2> _feet = new GArray<Vector2> { Vector2.ZERO, Vector2.ZERO };
        // steps/s the turn adds to the step clock now (eases up in a turn)
        public double _cadence = 0.0;
        // the stick was zero last step: the next step sets off on a footfall
        public bool _standing = true;
        // a turn begun at smooth_below or more is under way: it steps to its end
        public bool _realTurn = false;
        // a real turn near its end keeps its slow landing, not a correction's pace
        public bool _landing = false;
        // seconds since the body set off from a stand
        public double _walkedS = 0.0;
        // one step's length at body scale 1: the stage's own (contact.bodies)
        public double _stepLen = 0.0;
        // seconds a set-off ramps to full stride: the stage's own (D-355)
        public double _walkOffS = 0.0;
        // seconds a stepped U-turn takes: the stage's own (D-187), 0 if smooth
        public double _uturnS = 0.0;
        // steps a stepped U-turn is made in: the stage's own
        public double _turnSteps = 0.0;
        // the stride at an about-face (share of full): the stage's own
        public double _turnSlow = 0.0;
        // tuning: the rampage's whole tuning; the body reads its "contact" section.

        public BodyContact(RampageSim pSim, GDict tuning)
        {
            _InitFields();
            sim = pSim;
            cfg = tuning["contact"];
            heading = sim.facing;
            _lastHeading = heading;
            _stepLen = Num.F(cfg["step_len"]);
            _turnSlow = Num.F(cfg["turn_slow"]);
            // a sim with no species body keeps the default
            _walkOffS = Num.F(cfg["walk_off_s"]);
            dash = new Dash(this, cfg);
            _volume = new BodyVolume(sim, cfg);
        }
        // Picks the body volume for a species at the sim's size tier (call after setting the species).

        public void UseSpecies(string speciesId)
        {
            // its titan's momentum (Momentum)
            sim.powers.UseSpecies(speciesId);
            GDict bodies = cfg.Get("bodies", new GDict());
            GArray<Variant> stages = bodies.Get(speciesId, Gd.Arr());
            dash.UseSpecies(speciesId);
            _discs = Gd.Arr();
            _volume.discs = _discs;
            // a body without an entry stomps at kaiju_pos, never a stale foot
            _stompFoot = Vector2.ZERO;
            _stage = new GDict();
            if (!stages.IsEmpty())
            {
                _stage = stages[Gd.Clampi(sim.SizeTier() - 1, 0, stages.Size() - 1)];
                _discs = _stage["discs"];
                _volume.discs = _discs;
                snout = Num.F(_stage["snout"]);
                _stepLen = Num.F(_stage.Get("step_len", cfg["step_len"]));
                _uturnS = Num.F(_stage.Get("uturn_s", 0.0));
                _turnSteps = Num.F(_stage.Get("turn_steps", 0.0));
                _turnSlow = Num.F(_stage.Get("turn_slow", cfg["turn_slow"]));
                GArray<Variant> pivot = _stage.Get("pivot", Gd.Arr(0.0, 0.0));
                _pivot = new Vector2(Num.F(pivot[0]), Num.F(pivot[1]));
                GArray<Variant> foot = _stage.Get("stomp_foot", Gd.Arr(0.0, 0.0));
                _stompFoot = new Vector2(Num.F(foot[0]), Num.F(foot[1]));
            }
            _walkOffS = Num.F(_stage.Get("walk_off_s", cfg["walk_off_s"]));
        }

        public bool Active()
        {
            return !_discs.IsEmpty();
        }
        // The discs at body scale 1: [forward offset, radius, bottom, top] each.

        public GArray<Variant> Discs()
        {
            return _discs;
        }
        // Snout to tail tip, world units.

        public double Length()
        {
            double front = 0.0;
            double back = 0.0;
            foreach (GArray<Variant> d in _discs)
            {
                front = Gd.Maxf(front, Num.F(d[0]) + Num.F(d[1]));
                back = Gd.Minf(back, Num.F(d[0]) - Num.F(d[1]));
            }
            return (front - back) * sim.BodyScale();
        }
        // Turns sim.facing toward `want` (the stick, length 0..1; zero: standing) with weight
        // (director comments #16, "lumbering and unstoppable"): the turn gathers speed at turn_accel up
        // to turn_rate (turn_rate_still at a standstill; both slower for a bigger body, _rate) and slows
        // before it lands, never overshooting, while the stride eases down in a hard turn (to turn_slow at
        // an about-face; a stage's turn_slow_pow under 1 keeps it down until the spin eases) and back up.
        // A body with planted feet (stepping) makes a real turn in steps instead (director 2026-10-21 #3,
        // "rather than swivelling on the spot like a plastic toy"), heavy and slow (D-187): a U-turn takes
        // the stage's uturn_s whatever the pace it set off at, the yaw rate rising and falling over
        // turn_ramp of it and even between (_turn_peak), so each of the turn_steps takes the same slice
        // (the head leads by turn_left); the body swings about its planted feet. A turn under smooth_below
        // turns smoothly (D-130), over the planted foot: a held curve never drags the feet (D-177).
        // Returns the stride; RampageSim moves the kaiju along the heading by it, never sideways.

        public double Steer(double dt, Vector2 want)
        {
            footfallNow = false;
            if (want == Vector2.ZERO)
            {
                _Stand(dt);
                return 0.0;
            }
            if (_standing)
            {
                // sets off on a footfall: both feet down
                phase = Gd.Roundf(phase);
                stepRatio = 1.0;
                _PlantBoth();
                _standing = false;
            }
            turnLeft = sim.facing.AngleTo(want);
            var stepped = BodyTurnPace.StepsThisTurn(this);
            double slowPow = Num.F(_stage.Get("turn_slow_pow", 1.0));
            double keep = Gd.Lerpf(1.0, _turnSlow, Gd.Pow(Gd.Absf(turnLeft) / Gd.PI, (stepped ? slowPow : 1.0)));
            // Sets off over the stage's walk_off_s (motion critic 10-22; grown ~1.3 s, D-355), then eases.
            _walkedS += dt;
            var launching = _walkedS < _walkOffS;
            double ease = (launching ? 1.0 : Gd.Minf(1.0, Num.F(cfg["stride_ease"]) * dt));
            stride = Gd.Minf(Gd.Lerpf(stride, want.Length() * keep, ease), stride + dt / _walkOffS);
            // (top turn speed, its acceleration)
            var pace = BodyTurnPace.Pace(this, dt, stepped);
            double aim = Gd.Signf(turnLeft) * Gd.Minf(pace.x, Gd.Sqrt(2.0 * pace.y * Gd.Absf(turnLeft)));
            _spin = Gd.MoveToward(_spin, aim, pace.y * dt);
            double turn = _spin * dt;
            if (Gd.Signf(turn) == Gd.Signf(turnLeft) && Gd.Absf(turn) >= Gd.Absf(turnLeft))
            {
                // lands on the new way exactly
                turn = turnLeft;
                _spin = 0.0;
            }
            sim.facing = sim.powers.TurnToward(sim.facing, sim.facing.Rotated(turn), dt);
            var was = heading;
            _Face(dt);
            // a turn too is made over the planted foot (D-177)
            if (TurnsInSteps() && !dash.On())
            {
                _Swing(was, Gd.Absf(turn));
            }
            return stride;
        }
        // The stick is at rest: the body stands, and the next push sets off on a footfall.

        public void _Stand(double dt)
        {
            stride = 0.0;
            turnLeft = 0.0;
            _spin = 0.0;
            _cadence = 0.0;
            _standing = true;
            _walkedS = 0.0;
            _realTurn = false;
            _landing = false;
            _Face(dt);
        }
        // Both feet down where they stand when the body sets off (or after a dash or leap).

        public void _PlantBoth()
        {
            _feet = new GArray<Vector2> { _FootAt(_pivot.x, 1.0), _FootAt(_pivot.x - _stepLen, -1.0) };
        }
        // A turn swings the body about the foot that is down (since `was`): that foot stays put. Only the
        // `most` the stick turned this step swings it: a larger catch-up of the heading (the hand-over from
        // the river, where the body lies along the water) stays about the middle.

        public void _Swing(Vector2 was, double most)
        {
            // the old foot is not up yet
            var both = Gd.Fposmod(phase, 1.0) < Num.F(cfg["support_both"]);
            var at = (both ? (_feet[0] + _feet[1]) * 0.5 : _feet[0]);
            // a dash or leap left them
            if (at.DistanceTo(sim.kaijuPos) > 3.0 * _pivot.x * sim.BodyScale())
            {
                _PlantBoth();
                at = _feet[0];
            }
            sim.kaijuPos = at + (sim.kaijuPos - at).Rotated(Gd.Clampf(was.AngleTo(heading), -most, most));
        }
        // The ground point a stomp lands on (world): the left foot's (or the right's) spot ahead of
        // kaiju_pos on the body's heading, so the damage is where the drawn ring is, not at the tail base.

        public Vector2 StompFoot(bool left)
        {
            var across = heading.Orthogonal() * _stompFoot.y * ((left ? 1.0 : -1.0));
            return sim.kaijuPos + (heading * _stompFoot.x + across) * sim.BodyScale();
        }
        // Lifts the body volume off the ground (world units) for what it overlaps: a leap's arc.

        public void SetLift(double lift)
        {
            _volume.lift = lift;
        }
        // How far ahead of kaiju_pos the feet come down (world units): a leap aims them at its target.

        public double FeetAhead()
        {
            return _stompFoot.x * sim.BodyScale();
        }
        // True when the body walks by its step clock (it has planted feet and the stick is pushed).

        public bool Walking()
        {
            return Stepping() && !_standing;
        }
        // The foot that came down on the latest footfall (world), and whether it is the left: an even step
        // is the left foot's (the step clock and the legs agree). Read on a step `footfall_now` is true.

        public Vector2 LandedFoot()
        {
            return _feet[0];
        }

        public bool LandedLeft()
        {
            return Gd.Int(Gd.Floorf(phase)) % 2 == 0;
        }
        // True when the stomp's next foot is on `target` (within half a stomp's reach): a scripted player
        // stops when this holds, so the foot that comes down next lands on the building, as a person aims
        // it (D-166). Every measuring player (tests, pacing, captures, autoplay) walks by this rule.

        public bool StompReaches(Vector2 target)
        {
            return StompFoot(stomps % 2 == 0).DistanceTo(target) <= sim.StompRadius() * 0.5;
        }
        // Where the landing foot comes down (world): `ahead` of kaiju_pos (body units, scale 1), `side` 1
        // on its own side of the middle, -1 on the other.

        public Vector2 _FootAt(double ahead, double side)
        {
            // an even step: left
            double lateral = ((Gd.Int(Gd.Floorf(phase)) % 2 == 0 ? -1.0 : 1.0)) * side;
            var across = heading.Rotated(Gd.PI * 0.5) * _pivot.y * lateral;
            return sim.kaijuPos + (heading * ahead + across) * sim.BodyScale();
        }
        // True when this body walks by steps (it has planted feet): the stepped turn and the step clock.

        public bool Stepping()
        {
            return _pivot.x > 0.0;
        }
        // True when the turn is made in steps: a body with planted feet, except while the beam is on,
        // which is swept smoothly by the stick (its own turn speed, SpeciesPowers.turn_toward).

        public bool TurnsInSteps()
        {
            return Stepping() && sim.powers.beamLeft <= 0.0;
        }
        // The step clock for the legs to follow (steps walked), INF for a body that does not step.

        public double StepClock()
        {
            return (Stepping() ? phase : Gd.INF);
        }
        // The kaiju has walked `distance` world units in dt (a stride): the step clock follows,
        // at least as fast as a turn's cadence (a turn takes short quick steps).

        public void Walked(double distance, double dt)
        {
            if (Stepping())
            {
                double before = Gd.Floorf(phase);
                double steps = distance / (_stepLen * sim.BodyScale());
                double moved = Gd.Maxf(steps, _cadence * dt);
                phase += moved;
                if (moved > 0.0)
                {
                    stepRatio = Gd.Maxf(steps / moved, Num.F(cfg["step_ratio_min"]));
                }
                // a footfall: that foot comes down short of a full step
                if (Gd.Floorf(phase) != before)
                {
                    double @short = 0.5 * _stepLen * (1.0 - stepRatio);
                    _feet = new GArray<Vector2> { _FootAt(_pivot.x - @short, 1.0), _feet[0] };
                    footfallNow = true;
                }
            }
        }
        // Carries a leap (dash_pressed: this step's button), faces sim.facing, breaks what it hit.

        public void Step(double dt, bool dashPressed = false)
        {
            dash.Step(dt, dashPressed);
            _Face(dt);
            // a leap's flight breaks what its body passes through
            _volume.lift = dash.Height();
            if ((!Active() || (sim.airborne && !dash.On())))
            {
                _lastPos = new Vector2(Gd.INF, Gd.INF);
                return;
            }
            var from = (_lastPos.x == Gd.INF ? sim.kaijuPos : _lastPos);
            var fromHeading = (_lastPos.x == Gd.INF ? heading : _lastHeading);
            _volume.stepS = dt;
            broken += _volume.Sweep(from, fromHeading, sim.kaijuPos, heading);
            held = !(Inside(sim.kaijuPos, heading).IsEmpty());
            _holdS = (held ? _holdS + dt : 0.0);
            longestHold = Gd.Maxf(longestHold, _holdS);
            if (held)
            {
                _Hold(from, fromHeading);
            }
            _lastPos = sim.kaijuPos;
            _lastHeading = heading;
        }
        // A wall that has not given yet: the body slides along it if it can, else stays where it was.

        public void _Hold(Vector2 from, Vector2 fromHeading)
        {
            var to = sim.kaijuPos;
            GArray<GArray<Variant>> poses = new GArray<GArray<Variant>> { Gd.Arr(new Vector2(to.x, from.y), heading), Gd.Arr(new Vector2(from.x, to.y), heading), Gd.Arr(from, heading) };
            foreach (GArray<Variant> pose in poses)
            {
                Vector2 at = pose[0];
                if (Inside(at, heading).IsEmpty())
                {
                    sim.kaijuPos = at;
                    return;
                }
            }
            sim.kaijuPos = from;
            heading = fromHeading;
            // the body could not turn here: neither does what it aims
            sim.facing = fromHeading;
            _spin = 0.0;
        }
        // The heading turns to sim.facing, at most turn_rate_still: steer() turns the facing no faster,
        // so the two stay one; only a facing set from outside is caught up with.

        public void _Face(double dt)
        {
            double most = _Rate("turn_rate_still");
            if (TurnsInSteps() && _uturnS > 0.0)
            {
                // as quick as the stepped turn the facing is making
                most = Gd.Maxf(most, BodyTurnPace.TurnPeak(this));
            }
            heading = heading.Rotated(Gd.Clampf(heading.AngleTo(sim.facing), -most * dt, most * dt));
        }
        // A turn rate (rad/s) for this body: bigger is slower, by body scale to the turn_size_exp
        // ("bigger = slower but not TOO slow, lumbering within reason", director 2026-10-21). A body that
        // steps its turns reads its own rates (step_turn_*); one that does not, the baby, turns smoothly
        // at the plain ones (D-131, "Baby turns smoothly"); a stage may set its own (the Colossus, D-302).

        public double _Rate(string key)
        {
            var pre = (Stepping() ? "step_" : "");
            double @base = Num.F(_stage.Get(pre + key, cfg[pre + key]));
            return @base / Gd.Pow(Gd.Maxf(sim.BodyScale(), 0.01), Num.F(cfg[pre + "turn_size_exp"]));
        }
        // Whether the body overlaps building `index`'s footprint now (never without a body volume).

        public bool Over(long index)
        {
            var b = sim.buildings[index];
            double s = sim.BodyScale();
            foreach (GArray<Variant> d in _discs)
            {
                var c = sim.kaijuPos + heading * Num.F(d[0]) * s;
                var gap = new Vector2(Gd.Maxf(Gd.Absf(c.x - b.x) - b.w * 0.5, 0.0), Gd.Maxf(Gd.Absf(c.y - b.z) - b.d * 0.5, 0.0));
                if (gap.Length() < Num.F(d[1]) * s)
                {
                    return true;
                }
            }
            return false;
        }
        // Every standing chunk inside the body at a pose: {building index: {Vector3i: true}}.

        public GDict Inside(Vector2 pos, Vector2 facing)
        {
            GDict @out = new GDict();
            _volume.Collect(pos, facing, @out, _volume.Near(pos, pos, _volume.Reach()));
            return @out;
        }

        void _InitFields()
        {
        }
    }
}
