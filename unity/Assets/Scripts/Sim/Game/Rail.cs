// Generated from sim/rail.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class Rail : RefCounted
    {
        public static implicit operator Rail(Variant v) => (Rail)v.Obj;

        // The city's elevated railway (the director 2026-10-21 #63 "train stations + tracks with trains on
        // them", #69 "Derail and smash"; research in the 022 result): a two-track viaduct up the avenue
        // nearest the city's middle, crossing the river on its own deck, with one station. Trains (a
        // locomotive and its carriages, coupled at a fixed spacing) run on a schedule: they speed up,
        // cruise, brake into the station, dwell and go on, one each way. A hit strong enough (a stomp,
        // tail, breath, sweep: RampageSim.hit_area) on a car derails its train: the hit car is kicked
        // sideways, the cars behind fold the other way and back again (the jackknife), all slide on with
        // their momentum against friction, roll, and any car off the deck falls to the street; the
        // couplers are gone, a car that runs into the one ahead shares its speed (the concertina). The
        // viaduct and the station are voxel structures among the city's buildings (RailLayout, `pieces`):
        // the kaiju's body, its blows and toppled towers carve them, and they settle and fall, by the
        // rules every building does (Carving, Collapse; the director 2026-10-25 "destroyed with the same
        // logic as all other buildings"). The track is broken wherever the deck under it is gone: a
        // train over it derails, a train behind stops short of it, or ploughs in if it cannot. Pure and
        // seeded: positions are on the ground plane (x, z) with a height y; the presentation reads them.
        // Every number: tuning "rail".
        public const string RUN = "run";
        public const string DWELL = "dwell";
        public const string STOPPED = "stopped";
        public const string WRECK = "wreck";
        public static GDict _xCache = new GDict();

        public class Car : RefCounted
        {
            public static implicit operator Car(Variant v) => (Car)v.Obj;

            public Vector2 pos = Vector2.ZERO;
            public double y = 0.0;
            public double yaw = 0.0;
            public double roll = 0.0;
            public Vector2 vel = Vector2.ZERO;
            public double vy = 0.0;
            public double yawRate = 0.0;
            public double rollRate = 0.0;
            public bool loco = false;

            void _InitFields()
            {
            }
            public Car() { _InitFields(); }
        }

        public class Train : RefCounted
        {
            public static implicit operator Train(Variant v) => (Train)v.Obj;

            public long id = 0;
            // +1 runs north to south (z rising) on the west track, -1 back on the east track.
            public long dir = 1;
            // The lead car's front along the line (0..length, from the train's own start).
            public double s = 0.0;
            public double v = 0.0;
            public string state = RUN;
            public double dwell = 0.0;
            public bool dwelled = false;
            public GArray<Rail.Car> cars = new GArray<Rail.Car>();

            void _InitFields()
            {
            }
            public Train() { _InitFields(); }
        }
        public GDict cfg = new GDict();
        public GArray<Rail.Train> trains = new GArray<Rail.Train>();
        public double length = 0.0;
        public double deckY = 0.0;
        public long derailed = 0;
        // The viaduct's pieces: their indices in the sim's buildings (RailLayout), north to south.
        public GArray<long> pieces = new GArray<long>();
        // The station stands while the deck under it does.
        public bool stationStanding = true;
        public RampageSim _sim;
        public RandomNumberGenerator _rng;
        public double _x = 0.0;
        public double _z0 = 0.0;
        // station_span, from the north end
        public Vector2 _station = Vector2.ZERO;
        public double _next = 0.0;
        public long _nextId = 0;
        public long _dir = 1;
        // Broken track: along-line positions measured from the north end.
        public GArray<double> _breaks = new GArray<double>();
        // Piece index -> its standing chunks when last read.
        public GDict _aliveSeen = new GDict();
        public RailWreck _wreck;

        public Rail(RampageSim sim, GDict tuning, RandomNumberGenerator rng)
        {
            _InitFields();
            _sim = sim;
            cfg = tuning["rail"];
            _rng = rng;
            var line = RailLayout.Ends(sim.city, cfg);
            _z0 = line.x;
            length = line.y - line.x;
            var st = RailLayout.StationZ(sim.city, cfg);
            _station = new Vector2(st.x - _z0, st.y - _z0);
            deckY = Num.F(cfg["deck_y"]);
            _x = AvenueX(sim.city);
            _next = Num.F(cfg["first_s"]);
        }
        // The x of the north-south avenue nearest the city's middle (not the ring), from the street plan
        // (none: the middle). The fixed front (D-381) spans the whole width north of the back street, so
        // every avenue ends there and the line with it (RailLayout.ends), short of the beach.

        public static double AvenueX(GDict city)
        {
            var key = Gd.Format("%s:%s", Gd.Arr(city["map_seed"], city["half"]));
            if (_xCache.Has(key))
            {
                return Num.F(_xCache[key]);
            }
            double half = CityGen.HalfExtent(city);
            GDict plan = CityGen.Map(city);
            GArray<Variant> nodes = plan["nodes"];
            double best = Gd.INF;
            foreach (GDict street in Gd.Iter(plan["streets"]))
            {
                Vector2 a = nodes[Num.I(street["from"])];
                Vector2 b = nodes[Num.I(street["to"])];
                if ((Gd.Str(street["kind"]) != CityGen.AVENUE || Gd.Absf(a.x - b.x) > 0.01))
                {
                    continue;
                }
                if (Gd.Absf(a.x) < half - 1.0 && Gd.Absf(a.x) < Gd.Absf(best))
                {
                    best = a.x;
                }
            }
            if (best == Gd.INF)
            {
                best = 0.0;
            }
            _xCache[key] = best;
            return best;
        }
        // The x of the track a train running `dir` uses.

        public double TrackX(long dir)
        {
            return _x - dir * Num.F(cfg["track_gap"]) * 0.5;
        }
        // The ground point at `s` along the line for a train running `dir`.

        public Vector2 Point(double s, long dir)
        {
            double z = (dir > 0 ? _z0 + s : _z0 + length - s);
            return new Vector2(TrackX(dir), z);
        }
        // The station's place along the line for a train running `dir`: its platforms' middle.

        public double StationS(long dir)
        {
            var st = StationSpan();
            double at = (st.x + st.y) * 0.5;
            return (dir > 0 ? at : length - at);
        }

        public void Step(double dt)
        {
            _next -= dt;
            if (_next <= 0.0 && _Running() < Num.I(cfg["max_trains"]))
            {
                _Spawn();
                _next = Num.F(cfg["headway_s"]);
            }
            foreach (Rail.Train train in trains.Duplicate())
            {
                if (train.state == WRECK)
                {
                    _wreck.Slide(train, dt);
                }
                else
                {
                    _Drive(train, dt);
                    if (train.s - _Tail(train) > length)
                    {
                        trains.Erase(train);
                    }
                }
            }
            _BodyContact();
            _ReadDeck();
        }

        public long _Running()
        {
            long n = 0;
            foreach (Rail.Train train in trains)
            {
                n += Gd.Int(train.state != WRECK);
            }
            return n;
        }

        public void _Spawn()
        {
            var train = new Train();
            train.id = _nextId;
            _nextId += 1;
            train.dir = _dir;
            _dir = -_dir;
            foreach (long i in Gd.Range(Num.I(cfg["cars"])))
            {
                var car = new Car();
                car.loco = i == 0;
                car.y = deckY;
                train.cars.Append(car);
            }
            train.v = Num.F(cfg["cruise"]) * Num.F(cfg["enter_share"]);
            trains.Append(train);
            _Place(train);
            _sim.events.Append(new GDict { { "type", "train_spawned" }, { "train", train.id } });
        }
        // The length from the lead car's front to the last car's back.

        public double _Tail(Rail.Train train)
        {
            long n = train.cars.Size();
            return n * Num.F(cfg["car_length"]) + (n - 1) * Num.F(cfg["coupler_gap"]);
        }
        // Puts every car on the track behind the lead car's front.

        public void _Place(Rail.Train train)
        {
            double pitch = Num.F(cfg["car_length"]) + Num.F(cfg["coupler_gap"]);
            foreach (long i in Gd.Range(train.cars.Size()))
            {
                var car = train.cars[i];
                car.pos = Point(train.s - Num.F(cfg["car_length"]) * 0.5 - i * pitch, train.dir);
                car.yaw = (train.dir > 0 ? 0.0 : Gd.PI);
            }
        }
        // Speeds up to cruise, brakes for the station and for anything ahead on its track.

        public void _Drive(Rail.Train train, double dt)
        {
            if (train.state == DWELL)
            {
                train.dwell -= dt;
                if (train.dwell <= 0.0)
                {
                    train.state = RUN;
                }
                return;
            }
            double stop = _StopAhead(train);
            double room = stop - train.s;
            double brake = Num.F(cfg["brake"]);
            if (train.v * train.v / (2.0 * brake) >= room - 0.05)
            {
                double hard = (room < _StationRoom(train) ? Num.F(cfg["emergency"]) : brake);
                train.v = Gd.Maxf(0.0, train.v - hard * dt);
            }
            else
            {
                train.v = Gd.Minf(Num.F(cfg["cruise"]), train.v + Num.F(cfg["accel"]) * dt);
            }
            train.s = Gd.Minf(train.s + train.v * dt, stop);
            if (train.v <= 0.0 && room < 0.5)
            {
                _Arrive(train, stop);
            }
            _Place(train);
            if (_Blocked(train))
            {
                Derail(train, 0, Vector2.ZERO);
            }
        }
        // Where the train must stop next: the station it has not served, the broken track or the
        // wreck ahead on its line, else far beyond the line's end.

        public double _StopAhead(Rail.Train train)
        {
            double stop = Gd.INF;
            if (!train.dwelled)
            {
                stop = (train.s <= StationS(train.dir) ? StationS(train.dir) : Gd.INF);
            }
            foreach (double at in _breaks)
            {
                double s = (train.dir > 0 ? at : length - at);
                if (s > train.s && s - Num.F(cfg["stop_short"]) < stop)
                {
                    stop = s - Num.F(cfg["stop_short"]);
                }
            }
            return stop;
        }

        public double _StationRoom(Rail.Train train)
        {
            return (train.dwelled ? Gd.INF : StationS(train.dir) - train.s + 0.01);
        }

        public void _Arrive(Rail.Train train, double stop)
        {
            if (!train.dwelled && Gd.Absf(stop - StationS(train.dir)) < 0.01)
            {
                train.dwelled = true;
                train.state = DWELL;
                train.dwell = Num.F(cfg["dwell_s"]);
                _sim.events.Append(new GDict { { "type", "train_station" }, { "train", train.id } });
            }
            else
            {
                train.state = STOPPED;
            }
        }
        // A running train that reached broken track it could not stop for.

        public bool _Blocked(Rail.Train train)
        {
            foreach (double at in _breaks)
            {
                double s = (train.dir > 0 ? at : length - at);
                if (train.s >= s && train.s - _Tail(train) < s && train.v > Num.F(cfg["crash_speed"]))
                {
                    return true;
                }
            }
            return false;
        }
        // Breaks both tracks at `at` along the line (from the north end); a train over it derails.

        public void BreakTrack(double at)
        {
            foreach (double s in _breaks)
            {
                if (Gd.Absf(s - at) < Num.F(cfg["car_length"]))
                {
                    return;
                }
            }
            _breaks.Append(at);
            _sim.events.Append(new GDict { { "type", "track_broken" }, { "at", Point(at, 1) }, { "s", at } });
            var st = StationSpan();
            // the station goes with the deck under it
            if (stationStanding && at > st.x && at < st.y)
            {
                stationStanding = false;
                _sim.events.Append(new GDict { { "type", "station_broken" }, { "at", Point(StationS(1), 1) } });
            }
            double pitch = Num.F(cfg["car_length"]) + Num.F(cfg["coupler_gap"]);
            foreach (Rail.Train train in trains.Duplicate())
            {
                if (train.state == WRECK)
                {
                    continue;
                }
                double s = (train.dir > 0 ? at : length - at);
                if (train.s >= s && train.s - _Tail(train) <= s)
                {
                    Derail(train, Gd.Clampi(Gd.Floori((train.s - s) / pitch), 0, train.cars.Size() - 1), Vector2.ZERO);
                }
            }
        }

        public GArray<double> Broken()
        {
            return _breaks.Duplicate();
        }
        // A hit (RampageSim.hit_area's force and damage): any car it hits hard enough derails its
        // train. The viaduct under it is carved by the same hit, as a building (RampageSim.hit_area).

        public void Hit(Callable force, double damage)
        {
            double need = Num.F(cfg["derail_damage"]);
            foreach (Rail.Train train in trains)
            {
                if (train.state == WRECK)
                {
                    continue;
                }
                foreach (long i in Gd.Range(train.cars.Size()))
                {
                    double k = force.Call(train.cars[i].pos, Num.F(cfg["car_radius"]));
                    if (damage * k >= need)
                    {
                        Derail(train, i, train.cars[i].pos);
                        break;
                    }
                }
            }
        }
        // The pieces that lost a chunk since the last step are read again: the track breaks wherever
        // the deck under it is gone (RailLayout.deck_gaps).

        public void _ReadDeck()
        {
            foreach (long n in pieces)
            {
                long alive = _sim.buildings[n].frame.aliveCount;
                if (Num.I(_aliveSeen[n]) != alive)
                {
                    _aliveSeen[n] = alive;
                    foreach (double at in RailLayout.DeckGaps(_sim.buildings[n], this))
                    {
                        BreakTrack(at);
                    }
                }
            }
        }
        // Building n is a piece of the line (RampageSim builds them from RailLayout).

        public void AddPiece(long n)
        {
            pieces.Append(n);
            _aliveSeen[n] = _sim.buildings[n].frame.aliveCount;
        }
        // The viaduct's x centre (the deck and the station are built round it).

        public double CentreX()
        {
            return (TrackX(1) + TrackX(-1)) * 0.5;
        }
        // The station's span along the line (from the north end): its platforms (RailLayout).

        public Vector2 StationSpan()
        {
            return _station;
        }
        // The kaiju's body walking into a train (when it stands tall enough to reach the deck).

        public void _BodyContact()
        {
            if (_sim.ReachHeight() < deckY)
            {
                return;
            }
            double r = _sim.StompRadius() * Num.F(cfg["body_share"]);
            foreach (Rail.Train train in trains)
            {
                if (train.state == WRECK)
                {
                    continue;
                }
                foreach (long i in Gd.Range(train.cars.Size()))
                {
                    if (train.cars[i].pos.DistanceTo(_sim.kaijuPos) < r)
                    {
                        Derail(train, i, _sim.kaijuPos);
                        break;
                    }
                }
            }
        }
        // Derails `train` at car `hit_index`, struck from `from` (ZERO: ran into broken track).

        public void Derail(Rail.Train train, long hitIndex, Vector2 from)
        {
            train.state = WRECK;
            derailed += 1;
            var ahead = new Vector2(0.0, train.dir);
            var side = new Vector2(1.0, 0.0);
            var car = train.cars[hitIndex];
            double away = (from == Vector2.ZERO ? 1.0 : Gd.Signf(car.pos.x - from.x));
            if (away == 0.0)
            {
                away = (_rng.Randf() < 0.5 ? 1.0 : -1.0);
            }
            double kick = Num.F(cfg["kick"]);
            foreach (long i in Gd.Range(train.cars.Size()))
            {
                var c = train.cars[i];
                double fold = away * (((i - hitIndex) % 2 == 0 ? 1.0 : -1.0));
                double near = 1.0 / (1.0 + Gd.Absf(i - hitIndex));
                c.vel = ahead * train.v + side * fold * kick * near * _rng.RandfRange(0.7, 1.2);
                c.yawRate = fold * Num.F(cfg["yaw_rate"]) * _rng.RandfRange(0.6, 1.3);
                c.rollRate = fold * Num.F(cfg["roll_rate"]) * _rng.RandfRange(0.3, 1.2) * near;
            }
            // Each car pays like a vehicle, and the derailment a big one-off bonus on top (the director's
            // answer, 022 update: "well above a car").
            double pay = Num.F(_sim.army["tank_rubble"]) * Num.F(cfg["rubble_share"]) * train.cars.Size();
            pay += Num.F(cfg["derail_bonus"]);
            _sim.rubble += pay * _sim.Stat("rubble_mult");
            train.v = 0.0;
            if (from != Vector2.ZERO)
            {
                BreakTrack(_Along(car.pos));
            }
            _sim.events.Append(new GDict { { "type", "train_derailed" }, { "train", train.id }, { "x", car.pos.x }, { "z", car.pos.y }, { "rubble", pay } });
        }
        // The along-line position (from the north end) nearest `at`.

        public double _Along(Vector2 at)
        {
            return Gd.Clampf(at.y - _z0, 0.0, length);
        }

        void _InitFields()
        {
            _wreck = new RailWreck(this);
        }
    }
}
