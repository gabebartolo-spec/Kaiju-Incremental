// Generated from sim/explosives.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class Explosives : RefCounted
    {
        public static implicit operator Explosives(Variant v) => (Explosives)v.Obj;

        // The city's red barrels going off (director comments #19). Any damage to a hazard site
        // (CityHazards: the kaiju, its breath, falling rubble, an army shell, another blast) arms it:
        // damage_cells and hit_area report it, and a site that lost a chunk any other way (Carving,
        // Collapse) is caught each step. After a short fuse it explodes through RampageSim.hit_area, so
        // the blast breaks buildings, tanks and rooftop squads in its radius and arms the sites it
        // reaches (a chain, on the shorter chain fuse). Kinds (tuning "explosives"): a fuel silo is one
        // big blast; a fireworks factory throws seeded bursts around that set what they hit burning; a
        // chem lab leaves a toxic cloud that hurts tanks and squads inside it over time. Pure and seeded.
        public const long IDLE = 0;
        public const long ARMED = 1;
        public const long BLOWN = 2;

        public class Site : RefCounted
        {
            public static implicit operator Site(Variant v) => (Site)v.Obj;

            public long building;
            public string kind = "";
            public Vector2 pos;
            public long state = IDLE;
            public double fuse = 0.0;
            public long aliveAtStart = 0;

            void _InitFields()
            {
            }
            public Site() { _InitFields(); }
        }
        public GArray<Explosives.Site> sites = new GArray<Explosives.Site>();
        public GDict cfg = new GDict();
        // Fireworks still to burst: {"t", "pos": Vector2}. Toxic clouds: {"t", "pos", "exposure": {}}.
        public GArray<GDict> bursts = new GArray<GDict>();
        public GArray<GDict> clouds = new GArray<GDict>();
        public RampageSim _sim;
        public RandomNumberGenerator _rng;
        // building index -> Site
        public GDict _of = new GDict();

        public Explosives(RampageSim sim, GDict tuning, RandomNumberGenerator rng)
        {
            _InitFields();
            _sim = sim;
            _rng = rng;
            cfg = tuning.Get("explosives", new GDict());
            foreach (long i in Gd.Range(sim.buildings.Size()))
            {
                var b = sim.buildings[i];
                if ((b.hazard == "" || cfg.IsEmpty()))
                {
                    continue;
                }
                var s = new Site();
                s.building = i;
                s.kind = b.hazard;
                s.pos = new Vector2(b.x, b.z);
                s.aliveAtStart = b.frame.aliveCount;
                sites.Append(s);
                _of[i] = s;
            }
        }
        // Building `index` took damage: a hazard there lights its fuse.

        public void Damaged(long index, bool chained = false)
        {
            Explosives.Site s = _of.Get(index, default(Variant));
            if ((s == null || s.state != IDLE))
            {
                return;
            }
            s.state = ARMED;
            s.fuse = Num.F(cfg[(chained ? "chain_fuse_s" : "fuse_s")]);
            _sim.events.Append(new GDict { { "type", "hazard_armed" }, { "kind", s.kind }, { "building", index }, { "fuse", s.fuse } });
        }

        public void Step(double dt)
        {
            foreach (Explosives.Site s in sites)
            {
                if (s.state == IDLE && _Hurt(s))
                {
                    Damaged(s.building);
                }
                else if (s.state == ARMED)
                {
                    s.fuse -= dt;
                    if (s.fuse <= 0.0)
                    {
                        _Blow(s);
                    }
                }
            }
            _StepBursts(dt);
            _StepClouds(dt);
        }

        public bool _Hurt(Explosives.Site s)
        {
            return ((_sim.buildings[s.building].frame.aliveCount < s.aliveAtStart || _sim.carving.Promoted(s.building)));
        }

        public void _Blow(Explosives.Site s)
        {
            s.state = BLOWN;
            GDict k = cfg[s.kind];
            double radius = Num.F(k["radius"]);
            GDict at = new GDict { { "kind", s.kind }, { "building", s.building }, { "x", s.pos.x }, { "z", s.pos.y } };
            _sim.events.Append(at.Merged(new GDict { { "type", "explosion" }, { "radius", radius } }));
            _Blast(s.pos, radius, Num.F(k["damage"]), Num.I(k["height"]));
            if (s.kind == "fireworks_factory")
            {
                foreach (long n in Gd.Range(Num.I(k["bursts"])))
                {
                    var off = (Vector2.FromAngle(_rng.Randf() * Gd.TAU) * _rng.Randf() * Num.F(k["burst_spread"]));
                    bursts.Append(new GDict { { "t", (n + 1) * Num.F(k["burst_every_s"]) }, { "pos", s.pos + off } });
                }
            }
            else if (s.kind == "chem_lab")
            {
                clouds.Append(new GDict { { "t", Num.F(k["cloud_seconds"]) }, { "pos", s.pos }, { "exposure", new GDict() } });
                _sim.events.Append(new GDict { { "type", "toxic_cloud" }, { "building", s.building }, { "x", s.pos.x }, { "z", s.pos.y }, { "radius", Num.F(k["cloud_radius"]) }, { "seconds", Num.F(k["cloud_seconds"]) } });
            }
        }
        // One blast: full force within `radius`, fading to nothing at twice it (RampageSim.falloff).
        // Sites it reaches are armed on the chain fuse before hit_area's own report can arm them.

        public void _Blast(Vector2 at, double radius, double damage, long height)
        {
            var force = new Callable(a_ =>
            {
                Vector2 p = a_[0];
                double r = a_[1];
                return RampageSim.Falloff(Gd.Maxf(0.0, p.DistanceTo(at) - r), radius);
            });
            foreach (Explosives.Site s in sites)
            {
                var b = _sim.buildings[s.building];
                if (s.state == IDLE && force.Call(s.pos, new Vector2(b.w, b.d).Length() * 0.5) > 0.0)
                {
                    Damaged(s.building, true);
                }
            }
            // a blast throws tanks (D-437)
            SimDamage.Area(_sim, force, damage, 0, height, true);
        }

        public void _StepBursts(double dt)
        {
            if (bursts.IsEmpty())
            {
                return;
            }
            GDict k = cfg["fireworks_factory"];
            GArray<GDict> left = new GArray<GDict>();
            foreach (GDict burst in bursts)
            {
                burst["t"] = Num.F(burst["t"]) - dt;
                if (Num.F(burst["t"]) > 0.0)
                {
                    left.Append(burst);
                    continue;
                }
                Vector2 at = burst["pos"];
                _sim.events.Append(new GDict { { "type", "firework_burst" }, { "x", at.x }, { "z", at.y } });
                GDict coat = _sim.hitCoat;
                _sim.hitCoat = new GDict { { "kind", "burn" }, { "dps", Num.F(k["burn_dps"]) }, { "seconds", Num.F(k["burn_seconds"]) } };
                _Blast(at, Num.F(k["burst_radius"]), Num.F(k["burst_damage"]), Num.I(k["height"]));
                _sim.hitCoat = coat;
            }
            bursts = left;
        }
        // A tank inside a cloud for cloud_tank_seconds is wrecked (its crew gassed); a rooftop squad
        // inside it for cloud_squad_seconds dies.

        public void _StepClouds(double dt)
        {
            if (clouds.IsEmpty())
            {
                return;
            }
            GDict k = cfg["chem_lab"];
            double r = Num.F(k["cloud_radius"]);
            GArray<GDict> left = new GArray<GDict>();
            foreach (GDict cloud in clouds)
            {
                Vector2 at = cloud["pos"];
                GDict exposure = cloud["exposure"];
                foreach (RampageSim.Tank tank in _sim.tanks)
                {
                    if (tank.pos.DistanceTo(at) <= r)
                    {
                        exposure[tank] = Num.F(exposure.Get(tank, 0.0)) + dt;
                        tank.wrecked = ((tank.wrecked || Num.F(exposure[tank]) >= Num.F(k["cloud_tank_seconds"])));
                    }
                }
                foreach (Army.Squad squad in _sim.armyUnits.squads)
                {
                    if (squad.pos.DistanceTo(at) <= r)
                    {
                        exposure[squad] = Num.F(exposure.Get(squad, 0.0)) + dt;
                        squad.dead = (squad.dead || Num.F(exposure[squad]) >= Num.F(k["cloud_squad_seconds"]));
                    }
                }
                cloud["t"] = Num.F(cloud["t"]) - dt;
                if (Num.F(cloud["t"]) > 0.0)
                {
                    left.Append(cloud);
                }
            }
            clouds = left;
            _sim.armyUnits.ClearDead();
        }

        void _InitFields()
        {
        }
    }
}
