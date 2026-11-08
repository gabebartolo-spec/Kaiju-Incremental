// Generated from sim/body_turn_pace.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class BodyTurnPace : RefCounted
    {
        public static implicit operator BodyTurnPace(Variant v) => (BodyTurnPace)v.Obj;

        // How fast the kaiju's body may turn (BodyContact.steer): a stepped turn's pace, its top yaw
        // rate and its time.
        // True when this turn is made in steps: a real turn (begun at smooth_below or more, kept until it
        // is made) by a body that turns in steps; a smaller course correction turns smoothly (D-130).

        public static bool StepsThisTurn(BodyContact b)
        {
            if (Gd.Absf(b.turnLeft) >= Num.F(b.cfg["smooth_below"]))
            {
                b._realTurn = true;
                b._landing = false;
            }
            else if (b._realTurn && Gd.Absf(b.turnLeft) <= Num.F(b.cfg["turn_min"]))
            {
                // the turn is made: the next small one is a correction
                b._realTurn = false;
                b._landing = b._spin != 0.0;
            }
            if (b._landing && ((b._spin == 0.0 || Gd.Absf(b.turnLeft) > 2.0 * Num.F(b.cfg["turn_min"]))))
            {
                b._landing = false;
            }
            return b.TurnsInSteps() && ((b._realTurn || b._landing));
        }
        // How fast the body may turn now, Vector2(top rad/s, rad/s^2); eases in a stepped turn's cadence.

        public static Vector2 Pace(BodyContact b, double dt, bool stepped)
        {
            double top = Gd.Lerpf(b._Rate("turn_rate_still"), b._Rate("turn_rate"), b.stride);
            double accel = Num.F(b.cfg["turn_accel"]);
            // the beam follows the stick at its own pace, whatever the size
            if (b.sim.powers.beamLeft > 0.0)
            {
                top = Gd.Maxf(top, b.sim.powers.BeamTurnRate());
            }
            double cadence = 0.0;
            if (stepped && b._uturnS > 0.0)
            {
                top = TurnPeak(b);
                // up to speed in the ramp's share
                accel = top / (Num.F(b.cfg["turn_ramp"]) * TurnTime(b));
                if (Gd.Absf(b.turnLeft) > Num.F(b.cfg["turn_min"]))
                {
                    cadence = b._turnSteps / b._uturnS;
                }
            }
            b._cadence = Gd.MoveToward(b._cadence, cadence, Num.F(b.cfg["cadence_ease"]) * dt);
            return new Vector2(top, accel);
        }
        // A stepped turn's top yaw rate (rad/s): the U-turn's half circle in turn_time() as a trapezoid
        // (speeding up and slowing over turn_ramp of it each), so 1 / (1 - turn_ramp) of the mean rate.

        public static double TurnPeak(BodyContact b)
        {
            return Gd.PI / (TurnTime(b) * (1.0 - Num.F(b.cfg["turn_ramp"])));
        }
        // Seconds a U-turn takes until the body is exactly on the new way: uturn_s is the time to come
        // within turn_land_deg of it (what a player sees as turned); the slowing ramp takes a bit more.

        public static double TurnTime(BodyContact b)
        {
            double ramp = Num.F(b.cfg["turn_ramp"]);
            double land = Gd.DegToRad(Num.F(b.cfg["turn_land_deg"]));
            return b._uturnS / (1.0 - Gd.Sqrt(2.0 * land * ramp * (1.0 - ramp) / Gd.PI));
        }

        void _InitFields()
        {
        }
        public BodyTurnPace() { _InitFields(); }
    }
}
