// Generated from sim/emergence.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class Emergence : RefCounted
    {
        public static implicit operator Emergence(Variant v) => (Emergence)v.Obj;

        // The start of a run (D-083, director 2026-10-19: "a city caught unaware"; 2026-10-26: "deploy
        // the kaiju from the bay rather than the river", "Sea bay, real beach"): the kaiju waits
        // submerged in the city's sea bay (CityHarbour) for "emerge" "hold_seconds" (the water ripples
        // and founts over it), rises onto the sea floor over "rise_seconds", wades up the beach onto the
        // promenade (inside the arena) over "wade_seconds", and
        // then the run begins: the sim emits "kaiju_emerged" (the army's alert ramp starts from it).
        // Until then nothing else happens: no clock, no stomps, no army. The whole start fits the run
        // intro's 3 s (director 2026-10-20 #11: "the entire scene should run for no longer than 3
        // seconds"; R 20.1). Only a run the game starts (Rampage.setup) emerges; a RampageSim built on
        // its own starts on land. The start never takes longer than "emerge" "max_seconds": past it the
        // kaiju steps onto the bank point at once, so nothing (a bank point in the water, a wade that
        // cannot finish) can stall a run before it begins.
        // A body with a keyed rise clip (D-270, D-199: the adult's "rise_bay"; Rampage passes its length)
        // rises by the clip instead: it crouches on the sea floor from the first tick, nothing lifts it,
        // the clip plays at its own speed and the head breaks the water "keyed_surface_seconds" in; the
        // wade follows the clip (the start, and its cap, run longer by the clip's extra length).
        public bool active = false;
        // Where it rose (x, z), once start() has placed it; the run intro's shot is set about it.
        public Vector2 riseAt = Vector2.ZERO;
        // Whether its head has broken the water's surface yet (the "surface_break" event; the intro
        // roars on it, R 20.3).
        public bool surfaced = false;
        // Whether this start rises by the body's keyed clip (start's `keyed`), not by lifting it.
        public bool keyedRise = false;
        public double _t = 0.0;
        public double _hold;
        public double _rise;
        public double _depth;
        public double _wade;
        public double _startY = 0.0;
        // where the wade began (the rise point), once it has
        public Vector2 _wadeFrom = Vector2.INF;
        public double _cap;
        // the sea's surface (CityHarbour.sea)
        public double _sea;
        public Vector2 _spawn;
        public Vector2 _bank;
        // the city's street plan (CityGen.map): its sea bay and beach
        public GDict _plan = new GDict();
        public GDict _city = new GDict();
        public GDict _cfg = new GDict();

        public Emergence(GDict city, GDict tuning)
        {
            _InitFields();
            _cfg = tuning["emerge"];
            _depth = Num.F(_cfg["depth"]);
            _wade = Num.F(_cfg["wade_seconds"]);
            _Time(0.0);
            _sea = CityHarbour.Sea(city);
            _city = city;
            _plan = CityGen.Map(city);
            _spawn = _plan.Get("rise_spawn", new Vector2(Gd.INF, Gd.INF));
            _bank = _plan.Get("rise_bank", _spawn);
        }
        // Puts the kaiju under the sea bay's surface; the run waits until it has risen. A city without
        // a bay starts on land at once. `keyed`: seconds of the body's keyed rise clip (0: none).

        public void Start(RampageSim sim, double keyed = 0.0)
        {
            if (_spawn.x == Gd.INF)
            {
                return;
            }
            _Time(keyed);
            active = true;
            _t = 0.0;
            surfaced = false;
            _wadeFrom = Vector2.INF;
            sim.kaijuPos = _RisePoint(sim);
            riseAt = sim.kaijuPos;
            // Wholly under the water at first, its top "depth" (per body scale) below the surface, so the
            // water ripples and founts before anything shows (#11).
            _startY = _sea - sim.ReachHeight() - _depth * sim.BodyScale();
            // crouched on the sea floor: the clip rises it (city "harbour" "crouch_back")
            if (keyedRise)
            {
                _startY = GroundAt(riseAt);
            }
            sim.standY = _startY;
            // It rises already facing the city, the way it will walk out (director 2026-10-21 #17: "have
            // him emerging facing the city so he can walk straight in"), in the bay, wide enough for its
            // whole body (director 2026-10-20: "emerging from the water, not from the asphalt").
            sim.facing = _Ahead();
            sim.body.heading = sim.facing;
            sim.carving.PrepareAlong(riseAt, sim.ClampToArena(_bank));
        }
        // The start's timing: the data's, or a keyed rise of `keyed` seconds in place of its hold and rise.

        public void _Time(double keyed)
        {
            keyedRise = keyed > 0.0;
            _hold = (keyedRise ? 0.0 : Num.F(_cfg["hold_seconds"]));
            _rise = (keyedRise ? keyed : Num.F(_cfg["rise_seconds"]));
            _cap = Num.F(_cfg["max_seconds"]) + Late();
        }
        // Seconds a keyed rise adds to the data's hold and rise (0 without one; the intro's pull-out).

        public double Late()
        {
            return _hold + _rise - Num.F(_cfg["hold_seconds"]) - Num.F(_cfg["rise_seconds"]);
        }
        // How far through its rise the kaiju is, 0 (under, still holding) to 1 (on the sea floor).

        public double Risen()
        {
            return (active ? Gd.Clampf((_t - _hold) / _rise, 0.0, 1.0) : 1.0);
        }
        // How far through the whole start (hold, rise and wade) it is, 0 to 1; 1 once it has emerged.

        public double Progress()
        {
            return (active ? Gd.Clampf(_t / Total(), 0.0, 1.0) : 1.0);
        }
        // Seconds the whole start lasts when nothing stalls it.

        public double Total()
        {
            return _hold + _rise + _wade;
        }
        // How high the ground stands at p (CityHarbour.floor_at: the street, the beach's slope, the sea
        // floor); the run intro keeps its low camera over it.

        public double GroundAt(Vector2 p)
        {
            return CityHarbour.FloorAt(_plan, _city, p);
        }
        // Whether p lies in the sea bay's water (CityHarbour.holds): once risen, the kaiju never walks
        // or lands there (director 2026-10-31: it walked on the water, cracking it).

        public bool Wet(Vector2 p)
        {
            return CityHarbour.Holds(_plan, p);
        }
        // The sea's surface (world y) the kaiju rises through.

        public double WaterY()
        {
            return _sea;
        }
        // Seconds into the start the head breaks the surface (the intro's short cut starts near it).

        public double BreakAt(RampageSim sim)
        {
            if (keyedRise)
            {
                return Num.F(_cfg["keyed_surface_seconds"]);
            }
            double floorY = GroundAt(riseAt);
            double up = (_sea - sim.ReachHeight() - _startY) / Gd.Maxf(0.001, floorY - _startY);
            // smoothstep's inverse, by bisection (the rise eases in and out)
            double lo = 0.0;
            double hi = 1.0;
            foreach (long _i in Gd.Range(20))
            {
                double mid = (lo + hi) * 0.5;
                if (Gd.Smoothstep(0.0, 1.0, mid) < up)
                {
                    lo = mid;
                }
                else
                {
                    hi = mid;
                }
            }
            return _hold + hi * _rise;
        }
        // Advances the rise; true while it holds the rest of the sim back. While it does, the
        // buildings around the kaiju get their fine grids ready (Carving.warm), so its first blows
        // land on warm ones.

        public bool Step(RampageSim sim, double dt)
        {
            if (!active)
            {
                return false;
            }
            sim.carving.Warm(true);
            return _Advance(sim, dt);
        }

        public bool _Advance(RampageSim sim, double dt)
        {
            _t += dt;
            // never stalls: out on the bank, on its feet
            if (_t >= _cap)
            {
                sim.standY = 0.0;
                _Land(sim, sim.ClampToArena(_bank));
                return true;
            }
            if (_t < _hold)
            {
                // still under: the water ripples over it
                return true;
            }
            if (_t < _hold + _rise)
            {
                double up = (keyedRise ? 0.0 : Gd.Smoothstep(0.0, 1.0, (_t - _hold) / _rise));
                // up onto the sea floor
                sim.standY = Gd.Lerpf(_startY, GroundAt(riseAt), up);
                _Surface(sim);
                return true;
            }
            _Surface(sim);
            var bank = sim.ClampToArena(_bank);
            // The wade takes "wade_seconds" whatever the body's size, so the start's length never grows
            // with the stage (a Behemoth wades further, in proportion to its body). It eases in from the
            // rise and out onto the bank (smoothstep), so the body (and the camera on it) never jolts.
            if (_wadeFrom.x == Gd.INF)
            {
                _wadeFrom = sim.kaijuPos;
            }
            double left = Gd.Maxf(1.0, Gd.Roundf((Total() - _t) / dt) + 1.0);
            double u = Gd.Clampf((_t - _hold - _rise) / Gd.Maxf(0.001, _wade), 0.0, 1.0);
            double stride = sim.kaijuPos.DistanceTo(_wadeFrom.Lerp(bank, Gd.Smoothstep(0.0, 1.0, u)));
            double floorY = GroundAt(sim.kaijuPos);
            double climb = Gd.Maxf(stride, Gd.Absf(floorY - sim.standY) / left);
            // climbs the beach
            sim.standY = Gd.MoveToward(sim.standY, floorY, climb);
            if ((sim.kaijuPos.DistanceTo(bank) > stride || sim.standY < 0.0))
            {
                // straight ahead: it never turns
                sim.kaijuPos = sim.kaijuPos.MoveToward(bank, stride);
                return true;
            }
            _Land(sim, bank);
            return true;
        }
        // The tick its top clears the water: "surface_break" (the intro roars on it).

        public void _Surface(RampageSim sim)
        {
            double top = sim.standY + sim.ReachHeight();
            var up = (keyedRise ? _t >= BreakAt(sim) : top >= _sea);
            if (!surfaced && up)
            {
                surfaced = true;
                sim.events.Append(new GDict { { "type", "surface_break" } });
            }
        }

        public void _Land(RampageSim sim, Vector2 bank)
        {
            sim.kaijuPos = bank;
            active = false;
            sim.carving.promoter.DropReady();
            sim.events.Append(new GDict { { "type", "kaiju_emerged" } });
        }
        // Where it rises: in the bay on its centre line, its nose city "harbour" "nose_gap" short of the
        // foot of the beach (so the whole body is in open water over the sea floor); the plan's rise
        // point for a bare sim with no body yet.

        public Vector2 _RisePoint(RampageSim sim)
        {
            double nose = 0.0;
            foreach (GArray<Variant> d in sim.body.Discs())
            {
                nose = Gd.Maxf(nose, Num.F(d[0]) + Num.F(d[1]));
            }
            if ((nose <= 0.0 || !_plan.Has("harbour")))
            {
                return _spawn;
            }
            GDict h = _city["harbour"];
            double foot = Num.F(_plan["harbour"]["apex"]) - Num.F(h["beach"]);
            return new Vector2(_spawn.x, foot - nose * sim.BodyScale() - Num.F(h["nose_gap"]));
        }
        // The body's footprint now: its discs' bounds, grown by city "harbour" "fit_margin" (tests: the
        // rise stays clear of the railway).

        public Rect2 Footprint(RampageSim sim)
        {
            double s = sim.BodyScale();
            var foot = new Rect2();
            foreach (GArray<Variant> d in sim.body.Discs())
            {
                var c = sim.kaijuPos + sim.facing * Num.F(d[0]) * s;
                double r = Num.F(d[1]) * s;
                var disc = new Rect2(c - new Vector2(r, r), new Vector2(r, r) * 2.0);
                foot = (!foot.HasArea() ? disc : foot.Merge(disc));
            }
            if (!foot.HasArea())
            {
                return foot;
            }
            GDict bay = _city.Get("harbour", new GDict());
            return foot.Grow(Num.F(bay.Get("fit_margin", 0.0)));
        }
        // From the rise point to the bank point it wades to: into the city.

        public Vector2 _Ahead()
        {
            return (_spawn != _bank ? _spawn.DirectionTo(_bank) : new Vector2(0, -1));
        }

        void _InitFields()
        {
        }
    }
}
