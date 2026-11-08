// Generated from sim/taskforce_frost.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class TaskforceFrost : RefCounted
    {
        public static implicit operator TaskforceFrost(Variant v) => (TaskforceFrost)v.Obj;

        // The Taskforce's frost grenades (D-137, D-139, D-145): an agent launches one at street level at
        // the kaiju's feet (never its head); if the kaiju still stands there when it lands, ice crusts
        // its legs and slows it for `seconds`. Another grenade refreshes the same ice and never stacks
        // (one slow, one clock); a leap shatters it early; otherwise it thaws and cracks off.
        // Part of Taskforce; pure. Events: frost_launched, frost_hit, frost_cracked.
        public RampageSim sim;
        public GDict cfg = new GDict();
        // Seconds of ice left on the legs (0: none); the view crusts the legs by frost_left / seconds.
        public double frostLeft = 0.0;
        // Grenades in the air: [seconds left, where it lands (x, z)].
        public GArray<GArray<Variant>> grenades = new GArray<GArray<Variant>>();
        // dashes the kaiju had made when last looked at
        public long _dashes = 0;

        public TaskforceFrost(RampageSim pSim, GDict pCfg)
        {
            _InitFields();
            sim = pSim;
            cfg = pCfg;
        }
        // Whether the kaiju is within a launcher's range (`dist` from the agent, ground plane).

        public bool Reaches(double dist)
        {
            return dist <= Num.F(cfg["range"]);
        }
        // The speed multiplier the ice puts on the kaiju: the same slow however many grenades landed.

        public double Mult()
        {
            return (frostLeft > 0.0 ? Num.F(cfg["slow_mult"]) : 1.0);
        }
        // An agent at `from` throws a grenade at the kaiju's feet now.

        public void Launch(long agent, Vector3 from)
        {
            var feet = sim.kaijuPos;
            grenades.Append(Gd.Arr(Num.F(cfg["flight_s"]), feet));
            sim.events.Append(new GDict { { "type", "frost_launched" }, { "agent", agent }, { "from", from }, { "x", feet.x }, { "z", feet.y } });
        }

        public void Step(double dt)
        {
            GArray<GArray<Variant>> flying = new GArray<GArray<Variant>>();
            foreach (GArray<Variant> grenade in grenades)
            {
                grenade[0] = Num.F(grenade[0]) - dt;
                if (Num.F(grenade[0]) > 0.0)
                {
                    flying.Append(grenade);
                }
                else
                {
                    Vector2 at = grenade[1];
                    _Land(at);
                }
            }
            grenades = flying;
            var dash = sim.body.dash;
            // a leap under way shatters it
            var dashed = (dash.dashes != _dashes || dash.On());
            _dashes = dash.dashes;
            if (frostLeft <= 0.0)
            {
                return;
            }
            if (dashed)
            {
                _Crack("dash");
                return;
            }
            frostLeft -= dt;
            if (frostLeft <= 0.0)
            {
                _Crack("thaw");
            }
        }
        // A grenade lands: it freezes the kaiju only if it still stands within `radius` of the spot; the
        // ice is always the full `seconds`, never longer for a second grenade.

        public void _Land(Vector2 at)
        {
            if (sim.kaijuPos.DistanceTo(at) > Num.F(cfg["radius"]))
            {
                return;
            }
            sim.events.Append(new GDict { { "type", "frost_hit" }, { "x", at.x }, { "z", at.y }, { "refreshed", frostLeft > 0.0 } });
            frostLeft = Num.F(cfg["seconds"]);
        }

        public void _Crack(string why)
        {
            frostLeft = 0.0;
            sim.events.Append(new GDict { { "type", "frost_cracked" }, { "why", why } });
        }

        void _InitFields()
        {
        }
    }
}
