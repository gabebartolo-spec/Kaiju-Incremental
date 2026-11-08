// Generated from sim/rampage_stomp.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class RampageStomp : RefCounted
    {
        public static implicit operator RampageStomp(Variant v) => (RampageStomp)v.Obj;

        // The kaiju's stomp (D-166): a blow every stomp_interval that hurts what is under the foot that
        // comes down. A standing body stomps at once, feet alternating; a walking body (one with a step
        // clock) lets it fall on the footfall, on the foot that lands, and every blow that came due while
        // the foot was up falls with it (D-302: a longer, slower step clears as much per metre). Part of
        // RampageSim.
        public RampageSim sim;
        public double _timer = 0.0;
        // blows come due since the last stomp: a walking body lets them fall on a footfall
        public long _due = 0;

        public RampageStomp(RampageSim pSim)
        {
            _InitFields();
            sim = pSim;
        }
        // Advances the stomp timer: a stomp comes due every stomp_interval, and falls when a walking
        // body's foot lands (a standing body stomps at once).

        public void Step(double dt)
        {
            _timer -= dt;
            if (_timer <= 0.0)
            {
                _timer += Gd.Maxf(0.1, sim.Stat("stomp_interval"));
                _due = (sim.airborne ? 0 : _due + 1);
            }
            // no stomp through a leap, crouch to recovery (sim review of #225)
            if (sim.body.dash.On())
            {
                _due = 0;
            }
            if (_due > 0 && ((sim.body.footfallNow || !sim.body.Walking())))
            {
                long blows = _due;
                _due = 0;
                _Land(blows);
            }
        }
        // The foot comes down with `blows` stomps' force (those come due since the last).

        public void _Land(long blows)
        {
            var body = sim.body;
            double radius = sim.StompRadius();
            // a walking stomp falls on the landing foot
            var onFoot = body.Walking() && body.footfallNow;
            var left = (onFoot ? body.LandedLeft() : body.stomps % 2 == 0);
            var centre = (onFoot ? body.LandedFoot() : body.StompFoot(left));
            body.stomps += 1;
            // the croc's standing stomp lands with the foot
            double wait = sim.strikes.StompDelay(onFoot);
            sim.events.Append(new GDict { { "type", "stomp" }, { "radius", radius }, { "lift", sim.standY }, { "at", centre }, { "side", (left ? "left" : "right") }, { "on_foot", onFoot }, { "strike_in", wait }, { "blows", blows } });
            sim.strikes.Stomp(centre, wait, blows);
        }

        void _InitFields()
        {
        }
    }
}
