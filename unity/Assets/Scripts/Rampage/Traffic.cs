using System;
using System.Collections.Generic;
using S = Kaiju.Sim;

// Moving cars on the street plan (scenes/traffic.gd, line for line, minus the scene tree). Side streets are one-way
// (the parked rows leave one lane down the middle), alternating direction street by street; avenues and the
// diagonal carry a lane each way. Cars turn at crossings, queue behind the car ahead, and when the kaiju comes near
// they brake, back away and flee (the wrong way down a one-way street if they must). Police cruisers drive in and
// park across a street for a blockade. Crushed cars flatten like parked ones; nothing flips (D-482: as Godot).
// Godot's constants are street.car_* and police_* keys in data/tuning.json. TrafficView draws the cars from
// pos, yaw, mesh and crushed. Presentation only. No UnityEngine here: unity/SimTests compiles this file.
public sealed class Traffic
{
    public sealed class Car
    {
        public S.Vector2 pos = S.Vector2.ZERO;
        public S.Vector2 line = S.Vector2.ZERO;  // its point on the street's centre line (pos is off it by lane)
        public S.Vector2 dir = new S.Vector2(0, -1);
        public int node;  // the crossing it is driving to
        public int from;  // the crossing it came from
        public double lane;  // sideways from the centre line, to the right of dir
        public double speed;
        public bool fleeing, braking, backing, crushed, police, parked;
        public double blocked;
        public double arriveT = -1.0;
        public S.Vector2 arriveFrom = S.Vector2.ZERO, arriveTo = S.Vector2.ZERO, arriveFacing = S.Vector2.ZERO;
        // What Godot kept on the car's node: the mesh (a paint, or a cruiser's light-bar frame) and the turn.
        public int mesh;
        public float yaw;
    }

    public readonly S.RampageSim sim;
    public readonly TrafficNet net;
    public List<Car> cars = new List<Car>();
    // Cars that started fleeing the kaiju (tests read it).
    public int fled;
    // The car paints (city.car_colors): a car's mesh index below this.
    public readonly int paints;

    readonly S.GDict cfg;
    readonly S.RandomNumberGenerator rng;
    readonly double accel, brake, backShare, laneHalf, arriveSeconds, flashHz, laneHop, crushMargin, policeFaceAt, turnRate;
    double clock;
    int lit;
    // Rebuilt each Step: the cars by grid cell (index lists), the cars that may jump further than a cell this frame
    // (every car checks them), the tanks' poses and the street numbers.
    readonly Dictionary<(long, long), List<int>> grid = new Dictionary<(long, long), List<int>>();
    double cell = 1.0;
    readonly List<int> loose = new List<int>();
    readonly List<int> noCars = new List<int>();  // an empty cell
    internal TankKeepOut.Poses tanks;
    // Tests only: tanks placed by hand instead of the sim's.
    internal TankKeepOut.Poses tanksOverride;
    double gap, jamWreck, jamQueue;

    public Traffic(S.RampageSim sim, S.RandomNumberGenerator rng)
    {
        this.sim = sim;
        this.rng = rng;
        cfg = S.Content.Section("street");
        accel = S.Num.F(cfg["car_accel"]);
        brake = S.Num.F(cfg["car_brake"]);
        backShare = S.Num.F(cfg["car_back_share"]);
        laneHalf = S.Num.F(cfg["car_lane_half"]);
        arriveSeconds = S.Num.F(cfg["police_arrive_s"]);
        flashHz = S.Num.F(cfg["police_flash_hz"]);
        laneHop = S.Num.F(cfg["car_lane_hop"]);
        crushMargin = S.Num.F(cfg["car_crush_margin"]);
        policeFaceAt = S.Num.F(cfg["police_face_at"]);
        turnRate = S.Num.F(cfg["car_turn_rate"]);
        S.GDict cityCfg = S.Content.Section("city");
        S.GArray<S.Variant> colors = cityCfg["car_colors"];
        paints = (int)colors.Size();
        net = new TrafficNet(S.CityGen.HalfExtent(sim.city), cfg);
        net.BuildLanes(S.CityGen.Map(sim.city));
    }

    // Godot's _ready: the moving cars, then the diagonal's parked row. `props` are the street decor's prop bases
    // in Godot axes (x, -z of Unity), which the parked row keeps clear of.
    public void Populate(List<S.Vector2> props)
    {
        int tries = 0;
        while (cars.Count < S.Num.I(cfg["cars"]) && tries < S.Num.I(cfg["car_spawn_tries"]))
        {
            tries++;
            SpawnRandom();
        }
        DiagonalParking.Park(this, sim, props ?? new List<S.Vector2>());
    }

    void SpawnRandom()
    {
        if (net.ends.Count == 0) return;
        (int a, int b) end = net.ends[(int)rng.RandiRange(0, net.ends.Count - 1)];
        double length = net.nodes[end.a].DistanceTo(net.nodes[end.b]);
        if (length < S.Num.F(cfg["car_min_street"])) return;
        var probe = new Car();
        Enter(probe, end.a, end.b);
        double endGap = S.Num.F(cfg["car_spawn_end"]);
        probe.line = net.nodes[end.a] + probe.dir * rng.RandfRange(endGap, length - endGap);
        probe.pos = probe.line + Right(probe) * probe.lane;
        foreach (Car other in cars)
            if (other.pos.DistanceTo(probe.pos) < S.Num.F(cfg["car_gap"]) + S.Num.F(cfg["car_spawn_clear"])) return;
        Car car = Make((int)rng.RandiRange(0, paints - 1), false);
        Enter(car, end.a, end.b);
        car.line = probe.line;
        car.pos = probe.pos;
        car.speed = S.Num.F(cfg["drive_speed"]);
        Place(car, 1.0);
    }

    // Puts a car on the lane from crossing a to crossing b.
    void Enter(Car car, int a, int b)
    {
        car.from = a;
        car.node = b;
        car.dir = (net.nodes[b] - net.nodes[a]).Normalized();
        car.lane = 0.0;
        foreach (TrafficNet.Lane lane in net.lanes[a])
            if (lane.to == b) car.lane = lane.lane;
    }

    static S.Vector2 Right(Car car) => new S.Vector2(-car.dir.y, car.dir.x);

    internal Car Make(int mesh, bool police)
    {
        var car = new Car { mesh = mesh, police = police };
        cars.Add(car);
        return car;
    }

    // A police cruiser drives from `from` and parks at `to` facing `facing`. Oldest cruiser goes when there are too
    // many.
    public void AddPolice(S.Vector2 from, S.Vector2 to, S.Vector2 facing)
    {
        var police = new List<Car>();
        foreach (Car c in cars)
            if (c.police) police.Add(c);
        if (police.Count >= S.Num.I(cfg["max_police_cars"])) cars.Remove(police[0]);
        Car car = Make(0, true);
        car.pos = from;
        car.arriveFrom = from;
        car.arriveTo = to;
        car.arriveFacing = facing;
        car.arriveT = 0.0;
        Place(car, 1.0);
    }

    // Flattens every car whose middle is within `radius` (plus half a car) of `at`.
    public void Crush(S.Vector2 at, double radius)
    {
        foreach (Car car in cars)
        {
            if (car.crushed || car.pos.DistanceTo(at) > radius + crushMargin) continue;
            car.crushed = true;
            car.speed = 0.0;
            car.arriveT = -1.0;
        }
    }

    // Godot's update, called each frame with the frame's dt (0 when paused).
    public void Step(double dt)
    {
        clock += dt;
        S.Vector2 kaiju = sim.kaijuPos;
        int now = (int)((long)(clock * flashHz) % 2);
        bool swap = now != lit;
        lit = now;
        FrameIndex(dt);
        foreach (Car car in cars)
        {
            if (car.crushed) continue;
            if (TankKeepOut.RunOver(tanks, car))
            {
                Crush(car.pos, 0.0);  // a tank drives over it: flattened, as by the kaiju
                continue;
            }
            if (car.police && swap) car.mesh = lit;
            if (car.parked) TankKeepOut.MakeWay(tanks, car);
            if (car.arriveT >= 0.0)
                Arrive(car, dt);
            else if (!car.parked)
                Drive(car, dt, kaiju);
            Place(car, dt);
        }
    }

    void Arrive(Car car, double dt)
    {
        car.arriveT = Math.Min(1.0, car.arriveT + dt / arriveSeconds);
        double k = 1.0 - (1.0 - car.arriveT) * (1.0 - car.arriveT);
        car.pos = car.arriveFrom.Lerp(car.arriveTo, k);
        if (car.arriveT < 1.0) return;
        car.arriveT = -1.0;
        car.parked = true;
    }

    // A car's flight starts when the kaiju comes within panic_radius and ends past calm_radius.
    void Scare(Car car, S.Vector2 kaiju)
    {
        double d = car.pos.DistanceTo(kaiju);
        if (!car.fleeing && d < S.Num.F(cfg["panic_radius"]))
        {
            car.fleeing = true;
            fled++;
            car.braking = car.dir.Dot(kaiju - car.pos) > 0.0;  // heading at it: stop, then back away
        }
        else if (car.fleeing && d > S.Num.F(cfg["calm_radius"]))
            car.fleeing = false;
    }

    void Drive(Car car, double dt, S.Vector2 kaiju)
    {
        S.Vector2 dir = car.dir;
        Scare(car, kaiju);
        double target = car.fleeing ? S.Num.F(cfg["flee_speed"]) : S.Num.F(cfg["drive_speed"]);
        if (car.backing) target *= backShare;
        if (car.braking)
        {
            Brake(car, dt, dir);
            return;
        }
        double wait = Blocked(car);
        if (wait >= 0.0)
        {
            target = 0.0;
            car.blocked += dt;
            if (car.blocked > wait) TurnBack(car, false);
        }
        else
            car.blocked = 0.0;
        double rate = target > car.speed ? accel : brake;
        car.speed = S.Gd.MoveToward(car.speed, target, rate * dt);
        double step = car.speed * dt;
        double rest = (net.nodes[car.node] - car.line).Dot(dir);
        if (step < rest)
        {
            car.line += dir * step;
            car.pos = car.line + Right(car) * car.lane;
            return;
        }
        car.line = net.nodes[car.node];
        car.backing = false;
        Enter(car, car.node, NextNode(car, kaiju));
        car.pos = car.line + Right(car) * car.lane;
    }

    // Heading at the kaiju: slow to a stop short of the crossing, then back away.
    void Brake(Car car, double dt, S.Vector2 dir)
    {
        car.speed = S.Gd.MoveToward(car.speed, 0.0, brake * dt);
        double room = Math.Max(0.0, (net.nodes[car.node] - car.line).Dot(dir));
        car.line += dir * Math.Min(car.speed * dt, room);
        car.pos = car.line + Right(car) * car.lane;
        if (car.speed > 0.0) return;
        car.braking = false;
        TurnBack(car, true);
    }

    // Reverses along the street: backing up (still facing the kaiju) or a full U-turn.
    static void TurnBack(Car car, bool backing)
    {
        int was = car.node;
        car.node = car.from;
        car.from = was;
        car.dir = -car.dir;
        if (backing) car.lane = -car.lane;  // the same spot on the road, now reversing
        car.backing = backing;
        car.blocked = 0.0;
    }

    // How long to sit before turning round, or -1 when the lane ahead is clear. Behind a wreck or a parked cruiser a
    // car soon gives up; behind a live car it queues, so jams back up the street.
    internal double Blocked(Car car)
    {
        S.Vector2 dir = car.dir;
        int first = -1;  // the earliest car in `cars` holding this one up, as a plain scan finds it
        long cx = S.Gd.Floori(car.pos.x / cell);
        long cy = S.Gd.Floori(car.pos.y / cell);
        for (long gx = cx - 1; gx < cx + 2; gx++)
            for (long gy = cy - 1; gy < cy + 2; gy++)
                first = Ahead(car, dir, grid.TryGetValue((gx, gy), out List<int> bucket) ? bucket : noCars, first);
        first = Ahead(car, dir, loose, first);
        if (first >= 0)
        {
            Car other = cars[first];
            return other.crushed || other.parked ? jamWreck : jamQueue;
        }
        if (TankKeepOut.InLane(tanks, car, dir)) return 0.0;  // a tank: no waiting it out, turn round at once
        return -1.0;
    }

    // The lowest index of `first` and the cars in `ids` within car_gap ahead in car's lane.
    int Ahead(Car car, S.Vector2 dir, List<int> ids, int first)
    {
        foreach (int i in ids)
        {
            if (first >= 0 && i >= first) continue;
            Car other = cars[i];
            if (other == car) continue;
            S.Vector2 rel = other.pos - car.pos;
            double ahead = rel.Dot(dir);
            if (ahead > 0.0 && ahead < gap && Math.Abs(rel.Cross(dir)) < laneHalf) first = i;
        }
        return first;
    }

    // Buckets the cars for Blocked. A cell is car_gap plus the furthest a driving car moves this frame (its drive
    // and a car_lane_hop), so the 3x3 cells round a car hold every car that can come within car_gap of it.
    // Arriving and parked police cars can jump further, so they go in `loose` and everyone checks them.
    internal void FrameIndex(double dt)
    {
        gap = S.Num.F(cfg["car_gap"]);
        jamWreck = S.Num.F(cfg["jam_wreck_s"]);
        jamQueue = S.Num.F(cfg["jam_queue_s"]);
        tanks = tanksOverride ?? new TankKeepOut.Poses(sim, cfg);
        double fastest = Math.Max(S.Num.F(cfg["flee_speed"]), S.Num.F(cfg["drive_speed"]));
        cell = gap + laneHalf + fastest * dt + laneHop;
        grid.Clear();
        loose.Clear();
        for (int i = 0; i < cars.Count; i++)
        {
            Car car = cars[i];
            if (car.arriveT >= 0.0 || (car.parked && car.police))
            {
                loose.Add(i);
                continue;
            }
            var key = (S.Gd.Floori(car.pos.x / cell), S.Gd.Floori(car.pos.y / cell));
            if (!grid.TryGetValue(key, out List<int> bucket)) grid[key] = bucket = new List<int>();
            bucket.Add(i);
        }
    }

    // The crossing to drive to next from car.node: a legal lane at random, or, fleeing, any street that leads
    // furthest from the kaiju.
    int NextNode(Car car, S.Vector2 kaiju)
    {
        int at = car.node;
        var options = new List<int>();
        foreach (TrafficNet.Lane lane in net.lanes[at])
            if (lane.to != car.from) options.Add(lane.to);
        if (car.fleeing)
            foreach (int other in net.links[at])
                if (other != car.from && !options.Contains(other)) options.Add(other);
        if (options.Count == 0) return car.from;
        if (!car.fleeing) return options[(int)rng.RandiRange(0, options.Count - 1)];
        int best = options[0];
        foreach (int n in options)
            if (net.nodes[n].DistanceTo(kaiju) > net.nodes[best].DistanceTo(kaiju)) best = n;
        return best;
    }

    // Turns the car toward its facing (Godot's view.rotation.y, a float, eased by lerp_angle).
    internal void Place(Car car, double dt)
    {
        S.Vector2 facing = car.backing ? -car.dir : car.dir;
        if (car.arriveT >= 0.0 || car.parked)
        {
            S.Vector2 drive = car.arriveTo - car.arriveFrom;
            facing = car.arriveT > policeFaceAt || car.parked ? car.arriveFacing : drive;
        }
        double yaw = Math.Atan2(-facing.x, -facing.y);
        car.yaw = (float)LerpAngle(car.yaw, yaw, Math.Min(1.0, dt * turnRate));
    }

    // Godot's lerp_angle (Sim/Runtime has none).
    static double LerpAngle(double from, double to, double weight) => from + S.Gd.AngleDifference(from, to) * weight;

    // How many cars are flattened (the stats line).
    public int Crushed()
    {
        int n = 0;
        foreach (Car car in cars)
            if (car.crushed) n++;
        return n;
    }
}
