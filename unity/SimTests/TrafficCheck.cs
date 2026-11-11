// Moving traffic (Rampage/Traffic.cs, TrafficNet.cs, TankKeepOut.cs and DiagonalParking.cs, after scenes/traffic.gd,
// traffic_net.gd, tank_keep_out.gd and diagonal_parking.gd) is plain seeded maths, so it is held here on a real city:
// the city fills with cars that drive their lanes (and stand still when no time passes), one-way streets alternate
// and avenues carry two lanes, cars flee a kaiju near and not one far (on vs off), the same seed drives the same
// cars, a stomp flattens a car and leaves the rest driving (on vs off), cars queue behind a live car and give up at
// a wreck, a tank in the lane turns a car round and none does not (on vs off), a tank's hull over a car flattens it
// only when the tank has a facing, police cruisers arrive, cap and pull back from a tank, and the diagonal has its
// parked row clear of the grid streets.
using System;
using System.Collections.Generic;
using Kaiju.Sim;

static class TrafficCheck
{
    const double Dt = 1.0 / 60.0;
    const long Tier = 3, Seed = 0;
    const double Far = 1.0e6;
    const int Steps600 = 600;

    static int failed;
    static GDict cfg;

    public static int Run(string repoRoot)
    {
        failed = 0;
        Kaiju.Sim.FileAccess.Root = repoRoot;
        cfg = Content.Section("street");
        RampageSim sim = MakeSim();
        Traffic filled = Make(sim);
        int moving = 0, parked = 0;
        foreach (Traffic.Car c in filled.cars)
            if (c.parked) parked++; else moving++;
        Check(moving > 20, $"the city fills with moving cars: {moving}");
        Lanes(sim, filled);
        Drives(sim);
        int fled = Flees(sim);
        SameSeed();
        Crush(sim);
        Jams(sim);
        KeepOut(sim);
        RunOver(sim);
        Police(sim);
        Parked(sim, filled);
        sim.kaijuPos = new Vector2(Far, Far);
        Console.WriteLine(failed == 0
            ? $"traffic: ok ({moving} moving cars, {parked} parked, {fled} fled the kaiju)"
            : $"traffic: {failed} failed");
        return failed;
    }

    static RampageSim MakeSim()
    {
        GDict stats = UpgradeTree.RunStats(Content.Section("kaiju"), Content.SpeciesDef("reptilian"), new UpgradeTree(Content.Upgrades()));
        GArray<GDict> layout = CityGrowth.Layout(Content.Tuning(), Tier, Seeds.Make("city", Seed));
        return new RampageSim(stats, CityGrowth.TuningFor(Content.Tuning(), Tier), layout, Seeds.Make("army", Seed));
    }

    static Traffic Make(RampageSim sim, RandomNumberGenerator rng = null)
    {
        var t = new Traffic(sim, rng ?? Seeds.Make("traffic", 0));
        t.Populate(new List<Vector2>());
        return t;
    }

    static void Check(bool ok, string what)
    {
        if (ok) return;
        failed++;
        Console.WriteLine("FAIL traffic: " + what);
    }

    static double F(string key) => Num.F(cfg[key]);

    static TankKeepOut.Poses Tanks(List<Vector2> pos, List<Vector2> front, RampageSim sim)
    {
        GDict convoy = sim.army["convoy"];
        GArray<Variant> hull = convoy["hull"];
        return new TankKeepOut.Poses(cfg, Num.F(hull[0]), Num.F(hull[1]), pos, front);
    }

    static TankKeepOut.Poses NoTanks(RampageSim sim) => Tanks(new List<Vector2>(), new List<Vector2>(), sim);

    static Traffic.Car FirstMoving(Traffic t)
    {
        foreach (Traffic.Car c in t.cars)
            if (!c.parked && !c.police) return c;
        return null;
    }

    static void StepAll(Traffic t, int count, double dt = Dt)
    {
        for (int n = 0; n < count; n++) t.Step(dt);
    }

    // 2: side streets one-way with neighbouring lines opposite, avenues and the diagonal two lanes, alleys none.
    static void Lanes(RampageSim sim, Traffic t)
    {
        GDict plan = CityGen.Map(sim.city);
        GArray<double> xs = plan["xs"], zs = plan["zs"];
        GArray<GDict> streets = plan["streets"];
        var signs = new Dictionary<(bool, long), HashSet<bool>>();
        int bad = 0, oneWay = 0, twoWay = 0;
        double two = F("car_two_way_lane");
        foreach (GDict street in streets)
        {
            string kind = Gd.Str(street["kind"]);
            int a = (int)Num.I(street["from"]), b = (int)Num.I(street["to"]);
            if (!(t.net.Inside(t.net.nodes[a]) && t.net.Inside(t.net.nodes[b]))) continue;
            List<TrafficNet.Lane> ab = LanesTo(t, a, b), ba = LanesTo(t, b, a);
            if (kind == CityGen.ALLEY)
            {
                if (ab.Count + ba.Count != 0) bad++;
                continue;
            }
            if (kind != CityGen.STREET)
            {
                twoWay++;
                if (ab.Count != 1 || ba.Count != 1 || ab[0].lane != two || ba[0].lane != two) bad++;
                continue;
            }
            oneWay++;
            if (ab.Count + ba.Count != 1 || (ab.Count == 1 ? ab[0].lane : ba[0].lane) != 0.0) { bad++; continue; }
            int from = ab.Count == 1 ? a : b, to = ab.Count == 1 ? b : a;
            Vector2 d = t.net.nodes[to] - t.net.nodes[from];
            bool vertical = Math.Abs(d.y) > Math.Abs(d.x);
            long index = vertical ? xs.Find(t.net.nodes[a].x) : zs.Find(t.net.nodes[a].y);
            if (!signs.TryGetValue((vertical, index), out HashSet<bool> set)) signs[(vertical, index)] = set = new HashSet<bool>();
            set.Add((vertical ? d.y : d.x) > 0.0);
        }
        int same = 0, pairs = 0;
        foreach (KeyValuePair<(bool, long), HashSet<bool>> line in signs)
        {
            if (line.Value.Count != 1) bad++;
            if (!signs.TryGetValue((line.Key.Item1, line.Key.Item2 + 1), out HashSet<bool> next)) continue;
            pairs++;
            if (next.SetEquals(line.Value)) same++;
        }
        Check(bad == 0 && oneWay > 0 && twoWay > 0, $"lanes as the plan says: {bad} wrong of {oneWay} one-way and {twoWay} two-way");
        Check(pairs > 0 && same == 0, $"neighbouring one-way streets run opposite ways: {same} of {pairs} pairs alike");
    }

    static List<TrafficNet.Lane> LanesTo(Traffic t, int a, int b)
    {
        var output = new List<TrafficNet.Lane>();
        foreach (TrafficNet.Lane lane in t.net.lanes[a])
            if (lane.to == b) output.Add(lane);
        return output;
    }

    // 3: with the kaiju far, cars drive along their lanes; with no time passing they stand (off).
    static void Drives(RampageSim sim)
    {
        sim.kaijuPos = new Vector2(Far, Far);
        Traffic t = Make(sim);
        var start = new Dictionary<Traffic.Car, Vector2>();
        foreach (Traffic.Car c in t.cars) start[c] = c.pos;
        StepAll(t, 60, 0.0);
        int stirred = 0;
        foreach (Traffic.Car c in t.cars)
            if (c.pos != start[c]) stirred++;
        Check(stirred == 0, $"no car moves when no time passes: {stirred} did");
        int offLane = 0;
        for (int n = 0; n < Steps600; n++)
        {
            t.Step(Dt);
            foreach (Traffic.Car c in t.cars)
            {
                if (c.parked || c.crushed || c.arriveT >= 0.0) continue;
                Vector2 want = c.line + new Vector2(-c.dir.y, c.dir.x) * c.lane;
                Vector2 onSeg = Geometry2D.GetClosestPointToSegment(c.line, t.net.nodes[c.from], t.net.nodes[c.node]);
                if (c.pos.DistanceTo(want) > 1e-4 || onSeg.DistanceTo(c.line) > 1e-3) offLane++;
            }
        }
        int still = 0, live = 0;
        foreach (Traffic.Car c in t.cars)
        {
            if (c.parked || c.crushed) continue;
            live++;
            if (c.pos.DistanceTo(start[c]) <= 1.0) still++;
        }
        Check(offLane == 0, $"cars keep to their lanes: {offLane} car-steps off");
        Check(still == 0, $"every live car drives off in 10 s: {still} of {live} did not");
        Check(t.fled == 0, $"no car flees a kaiju far away: {t.fled} fled");
    }

    // 4: the kaiju on a moving car: cars near it flee, at flee speed, and get further away (on; 3 is off).
    static int Flees(RampageSim sim)
    {
        Traffic t = Make(sim);
        Vector2 at = FirstMoving(t).pos;
        sim.kaijuPos = at;
        var near = new List<Traffic.Car>();
        double before = 0.0;
        foreach (Traffic.Car c in t.cars)
        {
            if (c.parked || c.pos.DistanceTo(at) >= F("panic_radius")) continue;
            near.Add(c);
            before += c.pos.DistanceTo(at);
        }
        double fastest = 0.0;
        for (int n = 0; n < Steps600; n++)
        {
            t.Step(Dt);
            foreach (Traffic.Car c in t.cars)
                if (c.fleeing) fastest = Math.Max(fastest, c.speed);
        }
        double after = 0.0;
        foreach (Traffic.Car c in near) after += c.pos.DistanceTo(at);
        sim.kaijuPos = new Vector2(Far, Far);
        Check(t.fled > 0, $"cars flee the kaiju: {t.fled}");
        Check(Math.Abs(fastest - F("flee_speed")) < 1e-9, $"fleeing cars reach flee_speed: {fastest}");
        Check(near.Count > 0 && after > before, $"the cars near it end further away: {before / Math.Max(1, near.Count):0.0} m to {after / Math.Max(1, near.Count):0.0} m");
        return t.fled;
    }

    // 5: two traffics from the same seed on fresh sims drive the same.
    static void SameSeed()
    {
        RandomNumberGenerator ra = Seeds.Make("traffic", 0), rb = Seeds.Make("traffic", 0);
        RampageSim sa = MakeSim(), sb = MakeSim();
        Traffic a = Make(sa, ra), b = Make(sb, rb);
        for (int n = 0; n < Steps600; n++)
        {
            var kaiju = new Vector2(n * 0.05 - 15.0, n * 0.03);
            sa.kaijuPos = kaiju;
            sb.kaijuPos = kaiju;
            a.Step(Dt);
            b.Step(Dt);
        }
        int differ = a.cars.Count == b.cars.Count ? 0 : 1;
        for (int i = 0; i < a.cars.Count && i < b.cars.Count; i++)
        {
            Traffic.Car x = a.cars[i], y = b.cars[i];
            if (x.pos != y.pos || x.dir != y.dir || x.lane != y.lane || x.yaw != y.yaw || x.mesh != y.mesh) differ++;
        }
        Check(differ == 0, $"the same seed drives the same cars: {differ} differ");
        Check(ra.state == rb.state && a.fled == b.fled, "the same seed leaves the same stream and fled count");
    }

    // 6: a stomp on a car flattens it where it stands; cars outside the stomp drive on (off).
    static void Crush(RampageSim sim)
    {
        sim.kaijuPos = new Vector2(Far, Far);
        Traffic t = Make(sim);
        Traffic.Car hit = FirstMoving(t);
        Vector2 at = hit.pos;
        t.Crush(at, 0.0);
        Check(hit.crushed && hit.speed == 0.0 && hit.arriveT == -1.0, "a stomp on a car flattens and stops it");
        int touched = 0;
        Traffic.Car control = null;
        foreach (Traffic.Car c in t.cars)
        {
            if (c.pos.DistanceTo(at) <= F("car_crush_margin")) continue;
            if (c.crushed) touched++;
            if (control == null && !c.parked) control = c;
        }
        Check(touched == 0, $"cars outside the stomp are not flattened: {touched} were");
        Vector2 was = control.pos;
        StepAll(t, 300);
        Check(hit.pos == at, "a flattened car stays where it was");
        Check(control.pos != was, "a car outside the stomp drives on");
    }

    // 7: behind a live car a car queues for jam_queue_s; behind a wreck it gives up after jam_wreck_s; with
    // nothing ahead it drives on (flow_street.gd jams_hold).
    static void Jams(RampageSim sim)
    {
        Traffic t = Make(sim);
        t.tanksOverride = NoTanks(sim);
        var me = new Traffic.Car { pos = new Vector2(-500, -500), dir = new Vector2(0, -1) };
        var ahead = new Traffic.Car { pos = me.pos + me.dir * F("car_gap") * 0.5 };
        t.cars = new List<Traffic.Car> { me, ahead };
        t.FrameIndex(0.0);
        double queue = t.Blocked(me);
        ahead.crushed = true;
        double wreck = t.Blocked(me);
        t.cars = new List<Traffic.Car> { me };
        t.FrameIndex(0.0);
        double clear = t.Blocked(me);
        Check(queue == F("jam_queue_s") && wreck == F("jam_wreck_s") && queue > wreck,
            $"a car queues behind a live car ({queue} s) and turns round at a wreck ({wreck} s)");
        Check(clear == -1.0, $"with nothing ahead a car drives on: {clear}");
    }

    // 8: a tank 4 m ahead in a car's lane turns it round at once; without one the car drives on (off).
    static void KeepOut(RampageSim sim)
    {
        sim.kaijuPos = new Vector2(Far, Far);
        Traffic t = Make(sim);
        Traffic.Car car = FirstMoving(t);
        t.cars = new List<Traffic.Car> { car };
        t.tanksOverride = NoTanks(sim);
        t.FrameIndex(Dt);
        double none = t.Blocked(car);
        Vector2 dir = car.dir;
        t.tanksOverride = Tanks(new List<Vector2> { car.pos + dir * 4.0 }, new List<Vector2> { dir }, sim);
        t.FrameIndex(Dt);
        double tank = t.Blocked(car);
        int cameFrom = car.from;
        t.Step(Dt);
        Check(none == -1.0, $"no tank: the lane is clear ({none})");
        Check(tank == 0.0, $"a tank ahead in the lane: no waiting ({tank})");
        // As Godot: _drive measures what is left of the street with the dir from before the U-turn, so the
        // turned car finishes at the crossing it came from and takes another street.
        Check(!car.crushed && car.dir != dir && car.line == t.net.nodes[cameFrom] && car.from == cameFrom,
            "the car turns round short of the tank, back to the crossing it came from");
    }

    // 9: a tank's hull over a car flattens it when the tank has a facing; a tank with none yet does not.
    static void RunOver(RampageSim sim)
    {
        sim.kaijuPos = new Vector2(Far, Far);
        foreach (bool facing in new[] { true, false })
        {
            Traffic t = Make(sim);
            Traffic.Car car = FirstMoving(t);
            Vector2 front = facing ? car.dir : Vector2.ZERO;
            t.tanksOverride = Tanks(new List<Vector2> { car.pos }, new List<Vector2> { front }, sim);
            t.Step(Dt);
            Check(car.crushed == facing, facing ? "a tank driving over a car flattens it" : "a tank with no facing yet flattens nothing");
        }
    }

    // 10: nine cruisers leave the newest eight; one arrives and parks; a tank near sends it back along its street,
    // away from the tank.
    static void Police(RampageSim sim)
    {
        Traffic t = Make(sim);
        t.tanksOverride = NoTanks(sim);
        var first = new List<Traffic.Car>();
        for (int i = 0; i < 9; i++)
        {
            var from = new Vector2(-400 + i * 20, -400);
            t.AddPolice(from, from + new Vector2(0, 10), new Vector2(1, 0));
            if (i == 0) first.Add(t.cars[t.cars.Count - 1]);
        }
        int police = 0;
        foreach (Traffic.Car c in t.cars)
            if (c.police) police++;
        Check(police == (int)F("max_police_cars") && !t.cars.Contains(first[0]), $"the oldest cruiser goes past the cap: {police} left");
        Traffic.Car car = t.cars[t.cars.Count - 1];
        StepAll(t, (int)Math.Ceiling(F("police_arrive_s") / Dt) + 1);
        Check(car.parked && car.arriveT == -1.0 && car.pos == car.arriveTo, "a cruiser drives in and parks");
        Vector2 street = car.arriveFacing.Orthogonal().Normalized();
        Vector2 tankAt = car.pos - street * 3.0 + new Vector2(1, 0);
        t.tanksOverride = Tanks(new List<Vector2> { tankAt }, new List<Vector2> { Vector2.ZERO }, sim);
        t.Step(Dt);
        Vector2 back = car.arriveTo - car.arriveFrom;
        Check(!car.parked && car.arriveT > 0.0 && Math.Abs(back.Length() - F("police_pull_back")) < 1e-3
            && back.Dot(car.arriveFrom - tankAt) > 0.0, "a tank near sends the cruiser back along its street, away from it");
    }

    // 11: the diagonal's parked row is there and clear of every grid street.
    static void Parked(RampageSim sim, Traffic t)
    {
        GDict plan = CityGen.Map(sim.city);
        GArray<Vector2> nodes = plan["nodes"];
        GArray<GDict> streets = plan["streets"];
        bool diagonal = false;
        foreach (GDict s in streets)
            if (Gd.Str(s["kind"]) == CityGen.DIAGONAL) diagonal = true;
        int parked = 0, inStreet = 0;
        foreach (Traffic.Car c in t.cars)
        {
            if (!c.parked || c.police) continue;
            parked++;
            foreach (GDict s in streets)
            {
                if (Gd.Str(s["kind"]) == CityGen.DIAGONAL) continue;
                Vector2 q = Geometry2D.GetClosestPointToSegment(c.pos, nodes[Num.I(s["from"])], nodes[Num.I(s["to"])]);
                if (q.DistanceTo(c.pos) < Num.F(s["width"]) * 0.5 + DiagonalParking.CAR_HALF_ACROSS) inStreet++;
            }
        }
        Check(diagonal, "the test city has a diagonal avenue");
        Check(parked > 0, $"the diagonal has its parked row: {parked}");
        Check(inStreet == 0, $"no parked car in a grid street: {inStreet}");
    }
}
