// Generated from sim/strikes.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class Strikes : RefCounted
    {
        public static implicit operator Strikes(Variant v) => (Strikes)v.Obj;

        // Damage lands on impact (D-166, D-175): the reptilian's big attacks wreck when the jaws or the
        // foot land, a beat after the press, not on it. The breath's cone is read at the strike (where he
        // faces then); the Thunder Beam's stream starts at the strike (its walk slow from the press); a
        // standing stomp lands `stomp_standing` seconds after its tick (on the foot RampageStomp chose), a
        // walking one on its tick (the view syncs it to the footfall); the dash is instant. Cooldowns
        // count from the press. A strike waits in `pending` until its time is up and lands nothing if
        // the size tier changed meanwhile (he evolved); a rampage that ends stops stepping, so nothing
        // lands either. Delays in data/tuning.json "strike". Part of RampageSim; pure, no randomness.
        public const string BREATH = "breath";
        public const string BEAM = "beam";
        public const string STOMP = "stomp";
        public RampageSim sim;
        public GDict cfg = new GDict();
        // Strikes still to land: {"kind", "left": seconds, "tier": the size tier at the press}.
        public GArray<GDict> pending = new GArray<GDict>();

        public Strikes(RampageSim pSim, GDict pCfg)
        {
            _InitFields();
            sim = pSim;
            cfg = pCfg;
        }
        // Seconds from the breath's press to its strike at this size tier (young, Behemoth, Colossus).

        public double BreathDelay()
        {
            GArray<Variant> byTier = cfg["breath"];
            return Num.F(byTier[Gd.Clampi(sim.SizeTier() - 1, 0, byTier.Size() - 1)]);
        }
        // Seconds from the Thunder Beam's press to its stream.

        public double BeamDelay()
        {
            return Num.F(cfg["beam"]);
        }
        // The breath is pressed: the cone burns at the strike.

        public void Breath()
        {
            _Begin(BREATH, BreathDelay());
        }
        // The Thunder Beam is pressed: the stream starts at the strike.

        public void Beam()
        {
            _Begin(BEAM, BeamDelay());
        }
        // Seconds from a stomp's tick to its damage: the reptilian's standing stomp lifts and plants a
        // foot (`stomp_standing`); a walking stomp, and every other body's, lands on its tick.

        public double StompDelay(bool onFoot)
        {
            // the croc (its signature is the lash)
            if ((onFoot || sim.abilityType != "lash"))
            {
                return 0.0;
            }
            return Num.F(cfg["stomp_standing"]);
        }
        // A stomp's foot comes down on `centre` after `wait` seconds (at once when 0).

        public void Stomp(Vector2 centre, double wait, long blows = 1)
        {
            _Begin(STOMP, wait, centre, blows);
        }
        // Whether a strike of this kind is still to land.

        public bool Winding(string kind)
        {
            foreach (GDict strike in pending)
            {
                if (strike["kind"] == kind)
                {
                    return true;
                }
            }
            return false;
        }
        // Counts the waiting strikes down and lands the ones that are due, in the order they were pressed.

        public void Step(double dt)
        {
            GArray<GDict> due = new GArray<GDict>();
            foreach (GDict strike in pending)
            {
                strike["left"] = Num.F(strike["left"]) - dt;
                if (Num.F(strike["left"]) <= 0.0)
                {
                    due.Append(strike);
                }
            }
            foreach (GDict strike in due)
            {
                pending.Erase(strike);
                if (Num.I(strike["tier"]) == sim.SizeTier())
                {
                    Vector2 centre = strike.Get("centre", Vector2.ZERO);
                    _Land(Gd.Str(strike["kind"]), centre, Num.I(strike.Get("blows", 1)));
                }
            }
        }

        public void _Begin(string kind, double wait, Vector2 centre, long blows)
        {
            if (wait <= 0.0)
            {
                _Land(kind, centre, blows);
                return;
            }
            pending.Append(new GDict { { "kind", kind }, { "left", wait }, { "tier", sim.SizeTier() }, { "centre", centre }, { "blows", blows } });
            // the stomp event itself carries its time
            if (kind != STOMP)
            {
                sim.events.Append(new GDict { { "type", "strike_windup" }, { "kind", kind }, { "strike_in", wait } });
            }
        }
        public void _Begin(string kind, double wait, Vector2 centre) => _Begin(kind, wait, centre, 1);
        public void _Begin(string kind, double wait) => _Begin(kind, wait, Vector2.ZERO, 1);

        public void _Land(string kind, Vector2 centre, long blows)
        {
            var matched1 = kind;
            if (matched1 == BREATH)
            {
                BreathCone.Breathe(sim, sim.AbilityReach(), sim.Stat("ability_damage"));
            }
            else if (matched1 == BEAM)
            {
                sim.powers.StartBeam();
            }
            else if (matched1 == STOMP)
            {
                _LandStomp(centre, blows);
            }
        }
        // The foot comes down with `blows` stomps' force: full within the stomp radius, fading to
        // nothing at twice it.

        public void _LandStomp(Vector2 centre, long blows)
        {
            if (sim.airborne)
            {
                return;
            }
            double radius = sim.StompRadius();
            sim.HitArea(new Callable(a_ =>
            {
                Vector2 p = a_[0];
                double r = a_[1];
                return RampageSim.Falloff(p.DistanceTo(centre) - r, radius);
            }), sim.Stat("stomp_damage") * sim.powers.HitMult() * blows, Gd.Maxi(0, Gd.Floori(sim.standY) - Num.I(sim.powersCfg["climb_dig"])), Gd.Ceili(sim.ReachTop()));
        }

        void _InitFields()
        {
        }
    }
}
