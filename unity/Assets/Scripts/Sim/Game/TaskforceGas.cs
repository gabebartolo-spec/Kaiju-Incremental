// Generated from sim/taskforce_gas.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class TaskforceGas : RefCounted
    {
        public static implicit operator TaskforceGas(Variant v) => (TaskforceGas)v.Obj;

        // The Taskforce's gas grenades (D-143, D-145, D-152): a gas soldier throws one at the kaiju's feet
        // and a blue-black cloud about one street wide stands where it lands for `seconds`. While the
        // kaiju stands in a cloud his special powers are locked (the signature, the breath and the
        // ultimate cannot be pressed and a running Thunder Beam stops); the dash and every physical
        // attack still work, and the cloud does no damage. Part of Taskforce; pure. Events: gas_launched,
        // gas_cloud, gas_cleared,
        // gas_lock (on: true / false).
        public RampageSim sim;
        public GDict cfg = new GDict();
        // Clouds standing: [seconds left, centre (x, z)].
        public GArray<GArray<Variant>> clouds = new GArray<GArray<Variant>>();
        // Grenades in the air: [seconds left, where it lands (x, z)].
        public GArray<GArray<Variant>> grenades = new GArray<GArray<Variant>>();
        // Whether the kaiju stood in a cloud at the last step (his specials are locked).
        public bool locked = false;

        public TaskforceGas(RampageSim pSim, GDict pCfg)
        {
            _InitFields();
            sim = pSim;
            cfg = pCfg;
        }
        // Whether the kaiju is within a thrower's range (`dist` from the agent, ground plane).

        public bool Reaches(double dist)
        {
            return dist <= Num.F(cfg["range"]);
        }
        // A cloud's radius: `streets` street widths across.

        public double Radius()
        {
            return Num.F(sim.city["street_width"]) * Num.F(cfg["streets"]) * 0.5;
        }
        // An agent at `from` throws a gas grenade at the kaiju's feet now.

        public void Launch(long agent, Vector3 from)
        {
            var feet = sim.kaijuPos;
            grenades.Append(Gd.Arr(Num.F(cfg["flight_s"]), feet));
            sim.events.Append(new GDict { { "type", "gas_launched" }, { "agent", agent }, { "from", from }, { "x", feet.x }, { "z", feet.y } });
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
                    Vector2 landed = grenade[1];
                    _Cloud(landed);
                }
            }
            grenades = flying;
            GArray<GArray<Variant>> standing = new GArray<GArray<Variant>>();
            foreach (GArray<Variant> cloud in clouds)
            {
                cloud[0] = Num.F(cloud[0]) - dt;
                if (Num.F(cloud[0]) > 0.0)
                {
                    standing.Append(cloud);
                }
                else
                {
                    Vector2 at = cloud[1];
                    sim.events.Append(new GDict { { "type", "gas_cleared" }, { "x", at.x }, { "z", at.y } });
                }
            }
            clouds = standing;
            _Lock();
        }
        // Whether ground point `p` is inside a standing cloud.

        public bool Inside(Vector2 p)
        {
            foreach (GArray<Variant> cloud in clouds)
            {
                Vector2 at = cloud[1];
                if (at.DistanceTo(p) <= Radius())
                {
                    return true;
                }
            }
            return false;
        }

        public void _Cloud(Vector2 at)
        {
            clouds.Append(Gd.Arr(Num.F(cfg["seconds"]), at));
            sim.events.Append(new GDict { { "type", "gas_cloud" }, { "x", at.x }, { "z", at.y }, { "radius", Radius() }, { "seconds", cfg["seconds"] } });
        }
        // In a cloud the specials stay a moment from ready (`hold` seconds, so no press gets through and
        // no cooldown is spent) and the Thunder Beam's stream stops.

        public void _Lock()
        {
            var now = Inside(sim.kaijuPos);
            if (now != locked)
            {
                locked = now;
                sim.events.Append(new GDict { { "type", "gas_lock" }, { "on", now } });
            }
            if (!now)
            {
                return;
            }
            double hold = Num.F(cfg["hold"]);
            sim.abilityReadyIn = Gd.Maxf(sim.abilityReadyIn, hold);
            sim.ultimateReadyIn = Gd.Maxf(sim.ultimateReadyIn, hold);
            // the croc's own breath button (D-401)
            sim.breathReadyIn = Gd.Maxf(sim.breathReadyIn, hold);
            if (sim.powers.beamLeft > 0.0)
            {
                sim.powers.beamLeft = 0.0;
                sim.events.Append(new GDict { { "type", "beam_end" } });
            }
        }

        void _InitFields()
        {
        }
    }
}
