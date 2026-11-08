// Generated from sim/rampage_sim.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class RampageSim : RefCounted
    {
        public static implicit operator RampageSim(Variant v) => (RampageSim)v.Obj;

        // One rampage, as pure simulation: the kaiju, the city's buildings as real structures
        // (Structure: chunks that fall when unsupported and towers that topple), the army.
        // Presentation feeds input to step() and draws the events it returns; it never decides an
        // outcome. Ground-plane coordinates are Vector2(x, z); chunk centres are world Vector3.

        public class Building : RefCounted
        {
            public static implicit operator Building(Variant v) => (Building)v.Obj;

            public double x;
            public double z;
            public long w;
            public long d;
            public long height;
            public long tier;
            public long style;
            public Structure frame;
            // A landmark's id (data/landmarks.json) or ""; rubble_bonus multiplies what its chunks pay.
            public string landmark = "";
            public double rubbleBonus = 1.0;
            // A pool building's model id (data/city_buildings.json, D-256) or "": drawn and carved from
            // its baked model like a landmark, but otherwise an ordinary building. variant: ModelVariant's
            // facing, mirror and stretch; palette: which of its district's shifts it is drawn in.
            public string model = "";
            public GDict variant = new GDict();
            public long palette = 0;
            // an explosive site's kind (CityHazards), or ""
            public string hazard = "";
            // False past the arena's edge (CityBand): it breaks and pays, but never counts to the fall.
            public bool inArena = true;
            // What its chunks pay, as a share of a smash: a burnt-out building's (FireSpread) is less.
            public double payShare = 1.0;
            // A piece of the railway's viaduct or station (RailLayout: {"piece", "station"}), else empty.
            public GDict rail = new GDict();
            // A piece of a river bridge (BridgeLayout: {"piece", "of", "x", "z"}), else empty.
            public GDict bridge = new GDict();
            // World floor of its local floor 0: a bridge piece stands on the riverbed, under the street.
            public long @base = 0;
            // Chunks it stood with when the rampage began (RunTally reads a landmark's against it).
            public long startChunks = 0;

            public bool IsRail()
            {
                return !rail.IsEmpty();
            }

            public bool IsBridge()
            {
                return !bridge.IsEmpty();
            }
            // Over a street or the river, on no lot: a railway or a bridge piece.

            public bool IsSpan()
            {
                return (IsRail() || IsBridge());
            }
            // Kept meshed wherever the kaiju is (BuildingStream): a landmark, the railway, a bridge.

            public bool IsHeld()
            {
                return (landmark != "" || IsSpan());
            }
            // Its local floors for world floors (lo, past hi): a blow that reaches the street reaches a
            // bridge piece down to its riverbed.

            public Vector2i LocalFloors(Vector2i world)
            {
                return new Vector2i((world.x <= 0 ? 0 : world.x - @base), world.y - @base);
            }
            // World centre of chunk c.

            public Vector3 ChunkWorld(Vector3i c)
            {
                return new Vector3(x - w * 0.5 + c.x + 0.5, c.y + 0.5 + @base, z - d * 0.5 + c.z + 0.5);
            }
            // World position of a local frame point (e.g. a pivot edge).

            public Vector3 LocalToWorld(Vector3 p)
            {
                return new Vector3(x - w * 0.5 + p.x, p.y + @base, z - d * 0.5 + p.z);
            }

            void _InitFields()
            {
            }
            public Building() { _InitFields(); }
        }
        // A beam's footprint: a strip from origin along dir, `length` long and `half` to each side.

        public class Beam : RefCounted
        {
            public static implicit operator Beam(Variant v) => (Beam)v.Obj;

            public Vector2 origin;
            public Vector2 dir;
            public double length;
            public double half;

            public Beam(Vector2 o, Vector2 d, double l, double h)
            {
                _InitFields();
                origin = o;
                dir = d;
                length = l;
                half = h;
            }
            // 1 where a disc of radius r at p touches the strip, else 0.

            public double Reaches(Vector2 p, double r)
            {
                var rel = p - origin;
                double t = rel.Dot(dir);
                double side = Gd.Absf(rel.Dot(new Vector2(-dir.y, dir.x)));
                return (t >= -r && t <= length + r && side <= half + r ? 1.0 : 0.0);
            }

            void _InitFields()
            {
            }
        }
        // A part of a building on its way down: dropping straight, or toppling over an edge.

        public class Fall : RefCounted
        {
            public static implicit operator Fall(Variant v) => (Fall)v.Obj;

            public long id;
            public long building;
            public GArray<Vector3i> cells = new GArray<Vector3i>();
            public string kind = "";
            public Vector3 pivot;
            public Vector2 dir;
            public double drop;
            public double height;
            // across a topple, sim units (a carved part's; < 0: from its chunks)
            public double width = -1.0;
            public double t = 0.0;
            public double duration;
            // What it broke up against before it came down (FallContact): "", "building" or "kaiju".
            public string contact = "";

            void _InitFields()
            {
            }
            public Fall() { _InitFields(); }
        }

        public class Tank : RefCounted
        {
            public static implicit operator Tank(Variant v) => (Tank)v.Obj;

            public long id;
            public Vector2 pos;
            public double cooldown;
            // Out of the fight for good: no hit points (D-437); Army.clear_dead clears it.
            public bool wrecked = false;
            // The last blow that threw it (damage x force; SimDamage.throw).
            public double lastBlow = 0.0;
            // Sent flying (TankFlight): height over the street, velocity (y up), bounces taken, and how
            // deep in a Domino chain it is. A tank at rest on a roof keeps its height.
            public bool flying = false;
            public double height = 0.0;
            public Vector3 vel = Vector3.ZERO;
            public long bounces = 0;
            public long gen = 0;
            // its tumble (TankFlight): off upright, on top of its heading
            public Basis tilt = Basis.IDENTITY;
            // axis x rad/s
            public Vector3 spin = Vector3.ZERO;
            // landed on its side or roof: out of the fight for good
            public bool toppled = false;

            void _InitFields()
            {
            }
            public Tank() { _InitFields(); }
        }
        // step() button flags.
        public const long HELD = 1;
        public const long ULTIMATE = 2;
        // The breath's own button (D-280: the lash took the signature; Q / pad X).
        public const long BREATH = 8;
        // A tank's footprint radius for area hits.
        public const double TANK_RADIUS = 0.6;
        public GDict stats = new GDict();
        public GDict army = new GDict();
        public GDict city = new GDict();
        // RunNews.alert_chunks: where the city's threat level starts the army
        public long alertChunks = 0;
        public string abilityType = "ring";
        public GArray<RampageSim.Building> buildings = new GArray<RampageSim.Building>();
        // The buildings filed by ground cell, for questions about one spot (BuildingGrid).
        public BuildingGrid grid;
        public GArray<RampageSim.Tank> tanks = new GArray<RampageSim.Tank>();
        public Vector2 kaijuPos = Vector2.ZERO;
        public Vector2 facing = new Vector2(0, -1);
        public double hp;
        public double maxHp;
        public double timeLeft;
        public double rubble = 0.0;
        // The elevated railway and its trains (Rail).
        public Rail rail;
        public long chunksDestroyed = 0;
        public long chunksTotal = 0;
        public GArray<RampageSim.Fall> falls = new GArray<RampageSim.Fall>();
        public long tanksDestroyed = 0;
        public double abilityReadyIn = 0.0;
        // The breath's cooldown when it has its own button (a lash species).
        public double breathReadyIn = 0.0;
        public bool over = false;
        public string endReason = "";
        // Seconds the rampage has run, and the demo's Endless mode (Endless), null in a normal run.
        public double elapsed = 0.0;
        public Endless endless;
        public double arenaHalf;
        public long nextFallId = 0;
        public Collapse collapse;
        // The fine destruction grid (Carving): buildings carved cell by cell once first hit.
        public Carving carving;
        // The tanks' behaviour (Army); the tanks themselves are in `tanks`. Explosives: the red barrels.
        public Army armyUnits;
        // tanks the reptilian sends flying
        public TankFlight flight;
        public Explosives explosives;
        // Species powers (SpeciesPowers) and the helicopters (AirWing).
        public SpeciesPowers powers;
        public AirWing air;
        // the leader's escape helicopter (D-149), beside the air wing
        public VipHeli vip;
        public RampageStomp stomp;
        // the reptilian's big attacks, a beat after the press (D-166)
        public Strikes strikes;
        // the rise from the river that starts a game's run (D-083)
        public Emergence emerge;
        // the bay and the river as a liquid the body and its blows push about
        public WaterSim water;
        // how he dies: stagger, stone, shatter
        public DeathOverload death;
        // The body as a solid that breaks what it walks into; it steers the facing with weight.
        public BodyContact body;
        // the swinging tail: breaks every building it touches, whatever its size
        public TailTouch tail;
        // the big moments (threat level, landmarks, tower totals) as HUD events
        public RunNews news;
        public GDict powersCfg = new GDict();
        // How high the kaiju stands (floors): 0 on the street, more on a roof it climbed.
        public double standY = 0.0;
        // gliding: no stomps, no blocking
        public bool airborne = false;
        public double ultimateReadyIn = 0.0;
        // While set, every chunk and unit _hit_area damages is coated: {"kind", "dps", "seconds"}.
        public GDict hitCoat = new GDict();
        // While true, _hit_area also reaches helicopters whatever the kaiju's height.
        public bool hitAir = false;
        // While set, _hit_area's force is this beam's shape, which Carving samples without a Callable.
        public RampageSim.Beam hitBeam = null;
        // Events of the current step (Collapse appends here too).
        public GArray<GDict> events
        {
            get
            {
                return _events;
            }
        }
        public RandomNumberGenerator _rng;
        public GArray<GDict> _events = new GArray<GDict>();
        // Set ability_type ("lash", "cone", "leap" or "ring") before the first step.

        public RampageSim(GDict pStats, GDict tuning, GArray<GDict> layout, RandomNumberGenerator rng)
        {
            _InitFields();
            // a run that drops it without dispose() is cut at the exit
            SimTeardown.Note(this);
            stats = Growth.StageStats(pStats, tuning);
            army = tuning["army"];
            city = tuning["city"];
            powersCfg = tuning["powers"];
            _rng = rng;
            hp = Stat("hp");
            maxHp = hp;
            timeLeft = Stat("run_seconds");
            arenaHalf = CityGen.HalfExtent(city) + Num.F(city["arena_margin"]);
            foreach (GDict entry in layout)
            {
                var b = Landmarks.Building(entry, Num.F(city["chunk_hp"]));
                b.inArena = CityBand.Touches(b.x, b.z, new Vector2(b.w, b.d), arenaHalf);
                b.startChunks = b.frame.aliveCount;
                buildings.Append(b);
                chunksTotal += (b.inArena ? b.frame.aliveCount : 0);
            }
            GDict railCfg = tuning["rail"];
            long railFrom = RailLayout.AddPieces(buildings, city, railCfg);
            GDict bridgeCfg = tuning["bridge"];
            long bridgesFrom = BridgeLayout.AddPieces(buildings, city, bridgeCfg);
            // after the rail's and bridges' pieces: buildings too
            grid = new BuildingGrid(buildings);
            // on the ring avenue, at the south edge
            kaijuPos = new Vector2(0.0, CityGen.HalfExtent(city));
            RampageSimParts.Make(this, tuning, rng, new Vector2i(railFrom, bridgesFrom));
        }
        // The buildings that stand on lots: all but the railway's and the bridges' pieces (is_span).

        public GArray<RampageSim.Building> LotBuildings()
        {
            return buildings.Filter(new Callable(a_ =>
            {
                RampageSim.Building b = a_[0];
                return !b.IsSpan();
            }));
        }

        public double Stat(string statName)
        {
            return Num.F(stats.Get(statName, 0.0));
        }

        public long SizeTier()
        {
            return Num.I(Stat("size"));
        }
        // How big the kaiju is drawn and how far its attacks reach (Growth.body_scale).

        public double BodyScale()
        {
            return Growth.BodyScale(stats, city);
        }

        public double StompRadius()
        {
            return Stat("stomp_radius") * BodyScale();
        }

        public double AbilityReach()
        {
            return Stat("ability_range") * BodyScale();
        }
        // How high the kaiju can strike: a young one only reaches the lower floors.

        public double ReachHeight()
        {
            return Num.F(city["kaiju_height"]) * BodyScale();
        }
        // The highest point it can strike from where it stands (a climbed roof adds its height).

        public double ReachTop()
        {
            return standY + ReachHeight();
        }
        // Chunks' worth of army alert: the city's starting level (D-437), the city fallen, and Endless.

        public long Escalation()
        {
            return alertChunks + chunksDestroyed + Endless.Escalation(this);
        }

        public double Destruction()
        {
            return Num.F(chunksDestroyed) / Gd.Maxf(1.0, Num.F(chunksTotal));
        }
        // What the rampage did, for the results screen and the save's bests (RunTally.result).

        public GDict Result()
        {
            GDict @out = RunTally.Result(this);
            @out.Merge(vip.Summary());
            return @out;
        }
        // Advances the rampage by dt (move, signature pressed, buttons HELD/ULTIMATE/BREATH/Dash.BUTTON).

        public GArray<GDict> Step(double dt, Vector2 move, bool signaturePressed, long buttons = 0)
        {
            _events = new GArray<GDict>();
            // the liquid moves under every frame, the rise and death too
            water.Step(this, dt, _events);
            if ((death.Holds(dt) || emerge.Step(this, dt)))
            {
                return _events;
            }
            timeLeft -= dt;
            elapsed += dt;
            hp = Gd.Minf(maxHp, hp + Stat("regen") * dt);
            var oldFacing = facing;
            // a leap takes no stick
            var moving = move.Length() > 0.05 && !body.dash.On();
            // a stick at rest: zero
            double stride = body.Steer(dt, move.LimitLength(1.0) * Gd.Float(moving));
            // along the body's heading as it turns (BodyContact.steer): a turn walks an arc
            if (moving)
            {
                double speed = Stat("speed") * powers.SpeedMult() * stride;
                kaijuPos = _Ashore(kaijuPos, ClampToArena(kaijuPos + body.heading * speed * dt));
                body.Walked(speed * dt, dt);
            }
            powers.AfterMove(dt, oldFacing, moving);
            body.Step(dt, (buttons & Dash.BUTTON) != 0);
            tail.Step(dt);
            strikes.Step(dt);
            stomp.Step(dt);
            SignatureStrike.StepButtons(this, dt, signaturePressed, buttons);
            powers.Step(dt);
            collapse.Step(dt);
            explosives.Step(dt);
            _StepGround(dt);
            _StepSky(dt);
            rail.Step(dt);
            Endless.Step(this, dt);
            news.Step(_events);
            var why = Endless.OverReason(this);
            if (why != "")
            {
                End(why);
            }
            return _events;
        }
        // Lets go of the rings between the sim and its parts (SimTeardown, D-179) so a dropped sim is
        // freed: Godot never frees objects that count each other (a rampage kept 240 MB, tools/pacing.gd).
        // Call it when the rampage is over for good, after result() is read; it cannot be stepped again.

        public void Dispose()
        {
            SimTeardown.Cut(this);
        }
        // Ends the rampage for `reason` (also the pause menu's End Rampage, "ended"); earnings are kept.
        // A death plays his overload first (DeathOverload ends it with now = true); `now` ends it at once.

        public void End(string reason, bool now = false)
        {
            if (!now && death.Begin(reason))
            {
                return;
            }
            over = true;
            endReason = reason;
            hp = Gd.Maxf(0.0, hp);
            _events.Append(new GDict { { "type", "run_over" }, { "reason", reason } });
        }

        public Vector2 ClampToArena(Vector2 pos)
        {
            return pos.Clamp(new Vector2(-arenaHalf, -arenaHalf), new Vector2(arenaHalf, arenaHalf));
        }
        // A step from `from` to `to` kept out of the sea bay's water (Emergence.wet): into it, the step
        // slides along the shore on whichever axis stays dry, else it stands.

        public Vector2 _Ashore(Vector2 from, Vector2 to)
        {
            foreach (Vector2 p in Gd.Arr(to, new Vector2(to.x, from.y), new Vector2(from.x, to.y)))
            {
                if (!emerge.Wet(p))
                {
                    return p;
                }
            }
            return from;
        }
        // The tanks: the flung ones fly (TankFlight), then the army drives and fires the rest.

        public void _StepGround(double dt)
        {
            flight.Step(dt);
            armyUnits.Step(dt);
        }
        // The helicopters: the air wing's gunships, then the leader's escape (D-149).

        public void _StepSky(double dt)
        {
            air.Step(dt);
            vip.Step(dt);
        }
        // Full force within `radius`, fading to nothing at twice the radius: a harder blow breaks a
        // wider crater, because more of the fading edge still beats what a chunk can take.

        public static double Falloff(double distance, double radius)
        {
            if (distance <= radius)
            {
                return 1.0;
            }
            return Gd.Clampf(1.0 - (distance - radius) / radius, 0.0, 1.0);
        }
        // An area blow on chunks, tanks, squads and helicopters (SimDamage.area).

        public void HitArea(Callable force, double damage, long yLo = 0, long yHi = -1)
        {
            SimDamage.Area(this, force, damage, yLo, yHi);
        }
        // Nearest standing ground-floor chunk in the arena to `from` (an attacker's goal), or INF.

        public Vector2 NearestStanding(Vector2 from)
        {
            return StandingChunks.Nearest(this, from);
        }
        // Damages chunks of one building by the same amount each.

        public long DamageChunks(long index, GArray<Vector3i> cells, double amount)
        {
            var amounts = new PackedFloat32Array();
            amounts.Resize(cells.Size());
            amounts.Fill(amount);
            return DamageCells(index, cells, amounts);
        }
        // Damages chunks of one building, each by its own amount (SimDamage.cells). Returns chunks broken.

        public long DamageCells(long index, GArray<Vector3i> cells, PackedFloat32Array amounts)
        {
            return SimDamage.Cells(this, index, cells, amounts);
        }

        public void Pay(RampageSim.Building b, long chunks, double bonus)
        {
            chunksDestroyed += (b.inArena ? chunks : 0);
            double mult = bonus * b.rubbleBonus * b.payShare * Stat("rubble_mult");
            rubble += chunks * b.tier * Num.F(city["chunk_rubble"]) * mult;
        }

        void _InitFields()
        {
        }
    }
}
