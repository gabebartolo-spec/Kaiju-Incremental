// Generated from sim/rail_wreck.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class RailWreck : RefCounted
    {
        public static implicit operator RailWreck(Variant v) => (RailWreck)v.Obj;

        // What a derailed train does after the hit (Rail owns the trains; this is their physics): the cars
        // slide on against friction, slew, roll towards their side, fall off the deck where it is gone, and
        // a car closing on the one ahead shares its speed (the concertina). Every number: tuning "rail".
        public const double GRAVITY = 9.8;
        public Rail _rail;

        public RailWreck(Rail rail)
        {
            _InitFields();
            _rail = rail;
        }
        // A wreck's cars slide on against friction, slew, roll towards their side, fall off the deck.

        public void Slide(Rail.Train train, double dt)
        {
            GDict cfg = _rail.cfg;
            double mu = Num.F(cfg["friction"]) * GRAVITY;
            double halfDeck = Num.F(cfg["deck_width"]) * 0.5;
            foreach (long i in Gd.Range(train.cars.Size()))
            {
                var c = train.cars[i];
                var onDeck = (Gd.Absf(c.pos.x - _rail._x) <= halfDeck && c.y >= _rail.deckY - 0.01 && _DeckUnder(c));
                if ((onDeck || c.y <= 0.0))
                {
                    double speed = c.vel.Length();
                    c.vel = (speed > 0.0 ? c.vel.Normalized() * Gd.Maxf(0.0, speed - mu * dt) : c.vel);
                    c.yawRate = Gd.MoveToward(c.yawRate, 0.0, Num.F(cfg["spin_damp"]) * dt);
                }
                else
                {
                    c.vy -= GRAVITY * dt;
                }
                c.pos += c.vel * dt;
                c.y = Gd.Maxf(0.0, c.y + c.vy * dt);
                if (c.y <= 0.0 && c.vy < 0.0)
                {
                    c.vy = 0.0;
                    c.vel *= Num.F(cfg["land_keep"]);
                }
                c.yaw += c.yawRate * dt;
                c.roll = Gd.Clampf(c.roll + c.rollRate * dt, -Gd.PI * 0.5, Gd.PI * 0.5);
                if (i > 0)
                {
                    _Concertina(train.cars[i - 1], c);
                }
            }
        }
        // Whether the deck still stands under a car's middle (no break within half a car of it).

        public bool _DeckUnder(Rail.Car c)
        {
            double at = _rail._Along(c.pos);
            foreach (double s in _rail._breaks)
            {
                if (Gd.Absf(s - at) < Num.F(_rail.cfg["car_length"]) * 0.5)
                {
                    return false;
                }
            }
            return true;
        }
        // A car closing on the one ahead shares its speed and slews further (the pile-up).

        public void _Concertina(Rail.Car front, Rail.Car back)
        {
            GDict cfg = _rail.cfg;
            if (back.pos.DistanceTo(front.pos) >= Num.F(cfg["car_length"]) * Num.F(cfg["pile_share"]))
            {
                return;
            }
            var shared = (front.vel + back.vel) * 0.5;
            front.vel = shared;
            back.vel = shared;
            back.yawRate += Gd.Signf((back.yawRate != 0.0 ? back.yawRate : 1.0)) * 0.2;
        }

        void _InitFields()
        {
        }
    }
}
