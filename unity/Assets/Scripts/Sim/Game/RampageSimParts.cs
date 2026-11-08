// Generated from sim/rampage_sim_parts.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class RampageSimParts : RefCounted
    {
        public static implicit operator RampageSimParts(Variant v) => (RampageSimParts)v.Obj;

        // Builds the run's parts on a new RampageSim, in order (each may read the ones before it): the
        // collapse, carving, army, powers, air wing, body, rail, news, death and strikes. Each takes its
        // own seed from the run's rng (Seeds.derive), so a run replays exactly.
        // pieces: the railway's own pieces in s.buildings, x to y (RailLayout.add_pieces).

        public static void Make(RampageSim s, GDict tuning, RandomNumberGenerator rng, Vector2i pieces)
        {
            s.collapse = new Collapse(s, tuning, Seeds.Derive(rng, 0xFA11L));
            s.carving = new Carving(s, tuning);
            s.armyUnits = new Army(s, rng);
            GDict flightCfg = s.army["flight"];
            s.flight = new TankFlight(s, flightCfg, Seeds.Derive(rng, 0xF117L));
            s.explosives = new Explosives(s, tuning, Seeds.Derive(rng, 0xE7L));
            s.powers = new SpeciesPowers(s, Seeds.Derive(rng, 0x5EEDL));
            GDict airCfg = tuning["air"];
            s.air = new AirWing(s, airCfg, Seeds.Derive(rng, 0xA1L));
            GDict vipCfg = tuning["vip"];
            s.vip = new VipHeli(s, vipCfg, Seeds.Derive(rng, 0x71BL));
            s.stomp = new RampageStomp(s);
            s.emerge = new Emergence(s.city, tuning);
            s.water = new WaterSim(s.city, tuning);
            s.body = new BodyContact(s, tuning);
            s.tail = new TailTouch(s, s.body.cfg);
            s.rail = new Rail(s, tuning, Seeds.Derive(rng, 0x7A11L));
            foreach (long n in Gd.Range(pieces.x, pieces.y))
            {
                s.rail.AddPiece(n);
            }
            s.alertChunks = RunNews.AlertChunks(s.army, tuning);
            s.news = new RunNews(s, tuning);
            s.death = new DeathOverload(s, tuning, Seeds.Derive(rng, 0xDEADL));
            GDict strikeCfg = tuning["strike"];
            s.strikes = new Strikes(s, strikeCfg);
        }

        void _InitFields()
        {
        }
        public RampageSimParts() { _InitFields(); }
    }
}
