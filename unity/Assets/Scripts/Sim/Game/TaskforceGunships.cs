// Generated from sim/taskforce_gunships.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class TaskforceGunships : RefCounted
    {
        public static implicit operator TaskforceGunships(Variant v) => (TaskforceGunships)v.Obj;

        // The Taskforce's gunships (D-143, D-145, D-152), adult city only: up to 2 at once, beside the
        // city's own helicopters (which keep coming, D-143). They fly as the military helicopters do
        // (AirFlight: a stand-off ring, glides, strafing passes) and fire a blue laser cannon on the
        // helicopters' own cadence and damage (tuning "air"); like any helicopter, a blow that reaches
        // the air downs one (no hit points, D-437) and pays a helicopter's rubble. Only the cap is the
        // Taskforce's own number (tuning "taskforce" "gunships"). It dies as a helicopter does (D-458,
        // AirWing's fates and numbers): a blow of `burst_blow` blows it apart in the air, a lighter one
        // sends it spinning down along AirWing's own falling wrecks, which crash it on the street or on
        // the first roof it meets (never through one), smashing floors, crushing the army below and
        // setting the building burning. Its wreck's id is WRECK_ID + its id. Part of Taskforce; pure
        // and seeded. Events: gunship_spawned, gunship_laser (from, to), gunship_destroyed (fate, heli,
        // y; then AirWing's heli_crashed).
        // its wreck's id among AirWing's falling (beside VipHeli.ID)
        public const long WRECK_ID = 2000000;
        public RampageSim sim;
        public GDict cfg = new GDict();
        // made on first use: the Army (and so this) is built before the air wing
        public AirFlight flight;
        public GArray<AirWing.Heli> ships = new GArray<AirWing.Heli>();
        public long kills = 0;
        public RandomNumberGenerator _rng;
        // its own stream: spawns draw exactly as before deaths fell
        public RandomNumberGenerator _fallRng;
        public double _timer = 0.0;
        public long _nextId = 0;

        public TaskforceGunships(RampageSim pSim, GDict pCfg, RandomNumberGenerator rng)
        {
            _InitFields();
            sim = pSim;
            cfg = pCfg;
            _rng = rng;
            _fallRng = Seeds.Derive(rng, 0x6FA1L);
        }
        // How many may fly at once in this city (none before the adult city).

        public long Cap()
        {
            GArray<Variant> byTier = cfg["max_by_tier"];
            return Num.I(byTier[Gd.Clampi(sim.SizeTier() - 1, 0, byTier.Size() - 1)]);
        }
        // `open`: the Taskforce has joined this rampage. A downed gunship is replaced after the
        // helicopters' own call-in `interval`.

        public void Step(double dt, bool open)
        {
            if (open && ships.Size() < Cap())
            {
                _timer -= dt;
                if (_timer <= 0.0)
                {
                    _timer = Num.F(_Air()["interval"]);
                    Spawn();
                }
            }
            _Flight().Step(ships, dt);
            GDict air = _Air();
            foreach (AirWing.Heli ship in ships)
            {
                ship.cooldown -= dt;
                if (ship.cooldown > 0.0)
                {
                    continue;
                }
                ship.cooldown = Num.F(air["fire_interval"]);
                double hurt = Num.F(air["damage"]) - sim.Stat("armor");
                sim.hp -= Gd.Maxf(Num.F(sim.army["min_damage"]), hurt);
                var from = new Vector3(ship.pos.x, Altitude(), ship.pos.y);
                var to = new Vector3(sim.kaijuPos.x, sim.standY, sim.kaijuPos.y);
                sim.events.Append(new GDict { { "type", "gunship_laser" }, { "ship", ship.id }, { "from", from }, { "to", to } });
            }
        }
        // A gunship flying in from beyond its ring on the far side from the camera.

        public AirWing.Heli Spawn()
        {
            var ship = new AirWing.Heli();
            ship.id = _nextId;
            _nextId += 1;
            _Flight().Place(ship);
            ship.cooldown = Num.F(_Air()["fire_interval"]) * Num.F(_Air()["first_burst_delay"]);
            ships.Append(ship);
            sim.events.Append(new GDict { { "type", "gunship_spawned" }, { "ship", ship.id } });
            return ship;
        }

        public double Altitude()
        {
            return Num.F(_Air()["altitude"]);
        }
        // An area blow downs every gunship it reaches, when it reaches the air (as AirWing.hit), and it
        // falls as AirWing's helicopters do. A wreck's own impact never reaches the sky.

        public void Hit(Callable force, double damage, bool reachesAir)
        {
            if ((!reachesAir || damage <= 0.0 || sim.air._crashing))
            {
                return;
            }
            GArray<AirWing.Heli> alive = new GArray<AirWing.Heli>();
            foreach (AirWing.Heli ship in ships)
            {
                double k = Num.F(force.Call(ship.pos, Num.F(_Air()["heli_radius"])));
                if (k <= 0.0)
                {
                    alive.Append(ship);
                    continue;
                }
                kills += 1;
                sim.rubble += Num.F(_Air()["rubble"]) * sim.Stat("rubble_mult");
                sim.events.Append(_Down(ship, damage * k));
            }
            ships = alive;
        }
        // The gunship's death event: blown apart, or spinning down as one of AirWing's falling wrecks.

        public GDict _Down(AirWing.Heli ship, double blow)
        {
            GDict @event = new GDict { { "type", "gunship_destroyed" }, { "ship", ship.id }, { "heli", WRECK_ID + ship.id }, { "x", ship.pos.x }, { "z", ship.pos.y }, { "y", Altitude() } };
            if (blow >= Num.F(_Air()["burst_blow"]))
            {
                @event["fate"] = "burst";
                return @event;
            }
            @event.Merge(sim.air._SpinDown(ship, _fallRng));
            AirWing.Falling down = sim.air.falling.Back();
            down.id = WRECK_ID + ship.id;
            down.roofs = true;
            down.alt = Altitude();
            return @event;
        }

        public AirFlight _Flight()
        {
            if (flight == null)
            {
                flight = new AirFlight(sim, _Air(), _rng);
            }
            return flight;
        }

        public GDict _Air()
        {
            return sim.air.cfg;
        }

        void _InitFields()
        {
        }
    }
}
