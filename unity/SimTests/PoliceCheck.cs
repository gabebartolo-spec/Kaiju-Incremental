// Police waves (Rampage/Police.cs and StreetPeople's officer hooks, after scenes/police.gd, street_life.gd and
// street_steps.gd) are plain seeded maths, so they are held here on a real city: a wave comes at a crossing ahead of
// the kaiju and none comes when it faces away, is out of range or a tank holds the crossing (on vs off); two cruisers
// race in from behind the crossing and park nose to nose; four officers get out, walk to their posts behind the
// cruisers, aim and fire (and none fire without a wave); they scatter when the kaiju comes close and run off; a stomp
// on the holding officers ends the blockade; there are never more blockades or cruisers than the caps; the same seeds
// give the same wave, and the civilians walk the same with or without police.
using System;
using System.Collections.Generic;
using Kaiju.Sim;

static class PoliceCheck
{
    const double Dt = 1.0 / 60.0;
    const long Tier = 3, Seed = 0;
    const double Aim20 = 20.0, Aim40 = 40.0, TankNear = 5.0, Inward = -0.9;
    const int PerLot = 2;

    static int failed, checks;
    static GDict cfg;

    sealed class World
    {
        public RampageSim sim;
        public StreetPeople people;
        public Traffic traffic;
        public Police police;
        public int c;  // the crossing the kaiju is aimed at
        public Vector2 u;  // the street from the kaiju to it

        public void Frame(bool withPolice = true)
        {
            traffic.Step(Dt);
            if (withPolice) police.Update(Dt, sim.kaijuPos);
            people.Step(Dt, sim.kaijuPos, 1.0, true);
        }

        public void Run(double seconds, bool withPolice = true)
        {
            int n = (int)Math.Ceiling(seconds / Dt);
            for (int k = 0; k < n; k++) Frame(withPolice);
        }

        public int PoliceCars()
        {
            int n = 0;
            foreach (Traffic.Car car in traffic.cars)
                if (car.police) n++;
            return n;
        }

        public List<Police.Officer> Officers()
        {
            var o = new List<Police.Officer>();
            foreach (StreetPeople.Person p in people.people)
                if (p.officer != null) o.Add(p.officer);
            return o;
        }
    }

    public static int Run(string repoRoot)
    {
        failed = 0;
        checks = 0;
        Kaiju.Sim.FileAccess.Root = repoRoot;
        cfg = Content.Section("street");
        (int made, int shots) = Comes();
        int fled = Scatter();
        Crush();
        Caps();
        SameSeed();
        Console.WriteLine($"police: {checks} checks, {failed} failed (on: blockades {made} shots {shots} fled {fled}; off: 0 / 0)");
        return failed;
    }

    static double F(string key) => Num.F(cfg[key]);

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("FAIL police: " + what);
    }

    static RampageSim MakeSim()
    {
        GDict stats = UpgradeTree.RunStats(Content.Section("kaiju"), Content.SpeciesDef("reptilian"), new UpgradeTree(Content.Upgrades()));
        GArray<GDict> layout = CityGrowth.Layout(Content.Tuning(), Tier, Seeds.Make("city", Seed));
        return new RampageSim(stats, CityGrowth.TuningFor(Content.Tuning(), Tier), layout, Seeds.Make("army", Seed));
    }

    // StreetView's set-up: the people, the traffic, then the police on their own streams.
    static World Make(bool police = true)
    {
        var w = new World { sim = MakeSim() };
        w.sim.tanks.Clear();
        w.people = new StreetPeople(w.sim, Seeds.Make("civilians", 0), PerLot);
        w.traffic = new Traffic(w.sim, Seeds.Make("traffic", 0));
        w.traffic.Populate(new List<Vector2>());
        w.police = new Police(w.people, w.traffic, Seeds.Make("police", 0));
        if (police) w.people.police = w.police;
        return w;
    }

    // The kaiju `dist` outside the city's east edge, facing in along a street to an edge crossing c: nothing lies
    // behind it, so facing out leaves no crossing ahead.
    static void Aim(World w, double dist)
    {
        TrafficNet net = w.traffic.net;
        w.c = -1;
        foreach (int n in net.Crossings())
        {
            Vector2 at = net.Crossing(n);
            bool inward = false;
            foreach (Vector2 d in net.StreetDirs(n))
                if (d.x < Inward) inward = true;
            if (!inward) continue;
            if (w.c < 0 || at.x > net.Crossing(w.c).x || (at.x == net.Crossing(w.c).x && Math.Abs(at.y) < Math.Abs(net.Crossing(w.c).y)))
                w.c = n;
        }
        foreach (Vector2 d in net.StreetDirs(w.c))
            if (d.x < Inward) w.u = d;
        w.sim.facing = w.u;
        w.sim.kaijuPos = net.Crossing(w.c) - w.u * dist;
    }

    static double FirstWave() => F("blockade_interval") * 0.5 + 0.1;

    // 1-3: a wave comes ahead (on) and not behind, out of range or at a taken crossing (off); the cruisers race in
    // and park nose to nose; the officers get out, take their posts, aim and fire. Returns (blockades, shots).
    static (int, int) Comes()
    {
        World w = Make();
        Aim(w, Aim20);
        int civilians = w.people.Civilians();
        int before = w.PoliceCars();
        int frames = 0;
        while (w.police.blockadesMade == 0 && frames < (int)Math.Ceiling(FirstWave() / Dt))
        {
            w.Frame();
            frames++;
        }
        Check(w.police.blockadesMade == 1 && w.police.blockades.Count == 1, $"a wave comes at {FirstWave()} s: {w.police.blockadesMade}");
        if (w.police.blockades.Count == 0) return (0, 0);
        Police.Blockade b = w.police.blockades[0];
        double dist = b.at.DistanceTo(w.sim.kaijuPos);
        double dot = (b.at - w.sim.kaijuPos).Normalized().Dot(w.sim.facing);
        Check(b.at == w.traffic.net.Crossing(w.c), "the blockade is at the crossing ahead at blockade_distance");
        Check(dist >= F("blockade_spot_min") && dist <= F("blockade_spot_max") && dot >= F("blockade_ahead"),
            $"the blockade is in range and ahead: {dist:0.0} m, cos {dot:0.00}");
        Vector2 v = (w.sim.kaijuPos - b.at).Normalized();
        bool nearest = w.traffic.net.StreetDirs(w.c).Contains(b.toward) && b.across == new Vector2(-b.toward.y, b.toward.x);
        foreach (Vector2 d in w.traffic.net.StreetDirs(w.c)) nearest &= d.Dot(v) <= b.toward.Dot(v);
        Check(nearest, "the blocked street is the one leading most nearly toward the kaiju");
        Cruisers(w, b, before);
        Officers(w, b, civilians);
        int shots = w.police.shots;

        World far = Make();
        Aim(far, Aim40);
        far.Run(FirstWave());
        Check(far.police.blockadesMade == 0, $"no wave with the nearest crossing {Aim40} m off: {far.police.blockadesMade}");
        World back = Make();
        Aim(back, Aim20);
        back.sim.facing = -back.u;
        back.Run(FirstWave());
        Check(back.police.blockadesMade == 0 && back.PoliceCars() == 0, $"no wave with the kaiju facing away: {back.police.blockadesMade}");
        back.Run(F("blockade_interval") * 2.0);
        Check(back.police.blockadesMade == 0 && back.police.shots == 0, $"no wave and no shot in 20 s facing away: {back.police.shots}");
        Taken();
        return (w.police.blockadesMade, shots);
    }

    // 1 off C: a tank by the crossing holds it (and every crossing in range is held the same way); with the same
    // tanks far behind the kaiju the wave comes (on).
    static void Taken()
    {
        foreach (bool near in new[] { true, false })
        {
            World w = Make();
            Aim(w, Aim20);
            GDict convoy = w.sim.army["convoy"];
            GArray<Variant> hull = convoy["hull"];
            w.traffic.tanksOverride = new TankKeepOut.Poses(cfg, Num.F(hull[0]), Num.F(hull[1]), new List<Vector2>(), new List<Vector2>());
            Vector2 behind = w.sim.kaijuPos - w.u * Aim40;
            foreach (int n in w.traffic.net.Crossings())
            {
                Vector2 at = w.traffic.net.Crossing(n);
                double d = at.DistanceTo(w.sim.kaijuPos);
                if (d < F("blockade_spot_min") || d > F("blockade_spot_max")) continue;
                var tank = new RampageSim.Tank { pos = near ? at + new Vector2(0, TankNear) : behind };
                w.sim.tanks.Append(tank);
            }
            w.Run(FirstWave());
            Check(w.police.blockadesMade == (near ? 0 : 1),
                near ? $"a tank by the crossing holds it: {w.police.blockadesMade} waves" : $"tanks well off the crossing leave it free: {w.police.blockadesMade}");
        }
    }

    // 2: two new cruisers drive in from behind the crossing and park nose to nose across the street.
    static void Cruisers(World w, Police.Blockade b, int before)
    {
        var cars = new List<Traffic.Car>();
        foreach (Traffic.Car car in w.traffic.cars)
            if (car.police) cars.Add(car);
        Check(cars.Count - before == 2, $"two cruisers come: {cars.Count - before}");
        if (cars.Count < 2) return;
        Vector2 kaiju = w.sim.kaijuPos;
        bool behind = true;
        foreach (Traffic.Car car in cars)
        {
            behind &= car.arriveT >= 0.0 && car.arriveT < 1.0;
            behind &= Math.Abs(car.arriveFrom.DistanceTo(b.at) - Math.Sqrt(F("cruiser_from") * F("cruiser_from") + F("cruiser_from_across") * F("cruiser_from_across"))) < 1e-3;
            behind &= car.arriveFrom.DistanceTo(kaiju) > b.at.DistanceTo(kaiju);
        }
        Check(behind, "the cruisers set off from behind the crossing");
        w.Run(F("police_arrive_s") + 0.1);
        Vector2 line = w.police.Line(b);
        bool parked = true;
        foreach (Traffic.Car car in cars)
        {
            parked &= car.parked;
            double slot = Math.Min(car.pos.DistanceTo(line + b.across * F("cruiser_slot")), car.pos.DistanceTo(line - b.across * F("cruiser_slot")));
            parked &= slot < 1e-3;
        }
        Check(parked, "both cruisers park across the street at the barrier line");
        Check(cars[0].arriveFacing.Dot(cars[1].arriveFacing) < -Math.Cos(2.0 * F("cruiser_angle")), "the cruisers face each other");
    }

    // 3: the officers get out as the cruisers park, walk to their posts behind them, aim and fire.
    static void Officers(World w, Police.Blockade b, int civilians)
    {
        int cops = (int)Num.I(cfg["cops_per_blockade"]);
        Check(b.isOut && w.people.Officers() == cops && b.holding == cops, $"{cops} officers get out: {w.people.Officers()}, holding {b.holding}");
        Check(w.people.Civilians() == civilians, $"the civilians are as they were: {w.people.Civilians()} of {civilians}");
        bool outfits = true;
        foreach (StreetPeople.Person p in w.people.people)
            outfits &= p.officer != null ? p.outfit == StreetPeople.COP : p.outfit < StreetPeople.COP;
        Check(outfits, "officers wear the police outfit and no civilian does");
        bool walking = true;
        int frames = 0;
        while (frames < (int)Math.Ceiling(2.0 / Dt))
        {
            bool all = true;
            for (int i = 0; i < w.people.people.Count; i++)
            {
                Police.Officer o = w.people.people[i].officer;
                if (o == null) continue;
                int pose = w.people.Pose(i);
                if (o.state == 0) walking &= pose == StreetPeople.WALK_A || pose == StreetPeople.WALK_A + 1;
                all &= o.state == 1;
            }
            if (all) break;
            w.Frame();
            frames++;
        }
        Check(walking, "officers on the way to their posts walk");
        bool posted = true;
        for (int i = 0; i < w.people.people.Count; i++)
        {
            Police.Officer o = w.people.people[i].officer;
            if (o == null) continue;
            double along = (o.post - b.at).Dot(b.toward);
            posted &= o.state == 1 && o.pos == o.post && w.people.Pose(i) == StreetPeople.AIM;
            posted &= Math.Abs(along - F("police_post")) < 1e-5 && along < F("police_barrier");
        }
        Check(posted && frames * Dt < 2.0, $"within 2 s every officer aims from its post behind the cruisers ({frames * Dt:0.00} s)");
        int lit = 0;
        bool capped = true;
        for (int n = 0; n < (int)Math.Ceiling(3.0 / Dt); n++)
        {
            w.Frame();
            lit = Math.Max(lit, w.police.shown.Count);
            capped &= w.police.flashes.Count <= (int)Num.I(cfg["muzzle_max"]) && w.police.shown.Count <= w.police.flashes.Count;
        }
        Check(w.police.shots > 0 && lit > 0 && capped, $"holding officers fire: {w.police.shots} shots, up to {lit} flashes shown");
    }

    // 4: the kaiju on the crossing: every officer scatters at once, the blockade ends, the cruisers stay, and the
    // officers run off and are gone after cop_flee_s. Returns how many fled.
    static int Scatter()
    {
        World w = Make();
        Aim(w, Aim20);
        w.Run(FirstWave() + F("police_arrive_s") + 2.0);
        Police.Blockade b = w.police.blockades.Count > 0 ? w.police.blockades[0] : null;
        List<Police.Officer> officers = w.Officers();
        Check(b != null && officers.Count == b.holding && officers.TrueForAll(o => o.state == 1), "the officers hold the blockade");
        if (b == null) return 0;
        int fled = w.people.fled, civiliansFled = CiviliansFled(w);
        w.sim.kaijuPos = b.at;
        var start = new List<Vector2>();
        foreach (Police.Officer o in officers) start.Add(o.pos);
        w.Frame();
        int cops = w.people.fled - fled - (CiviliansFled(w) - civiliansFled);
        Check(officers.TrueForAll(o => o.state == 2) && cops == officers.Count && b.holding == 0,
            $"every officer scatters when the kaiju is on the crossing: {cops} fled");
        w.Frame();
        int cars = w.PoliceCars();
        bool parked = true;
        foreach (Traffic.Car car in w.traffic.cars)
            if (car.police) parked &= car.parked;
        Check(w.police.blockades.Count == 0 && cars == 2 && parked, $"the blockade ends and the cruisers stay parked: {cars}");
        // A fleeing officer crushed no longer counts against the blockade.
        Police.Officer last = officers[officers.Count - 1];
        w.people.Crush(last.pos.x, last.pos.y, 0.0);
        Check(b.holding == 0, $"a fleeing officer crushed leaves the count alone: {b.holding}");
        w.Run(F("cop_flee_s") + 0.1);
        bool ran = officers.Count > 1;
        double run = F("run_speed") * F("cop_flee_s");
        for (int i = 0; i < officers.Count - 1; i++)
        {
            ran &= officers[i].pos.DistanceTo(start[i]) >= run * 0.99;  // the whole cop_flee_s at run_speed
            ran &= officers[i].pos.DistanceTo(b.at) > start[i].DistanceTo(b.at) + run * 0.8;
        }
        int left = 0;  // the next wave's officers are not these
        foreach (Police.Officer o in w.Officers())
            if (officers.Contains(o)) left++;
        Check(left == 0 && ran, $"the officers run off from the kaiju and are gone: {left} left");
        return cops;
    }

    static int CiviliansFled(World w)
    {
        int n = 0;
        foreach (StreetPeople.Person p in w.people.people)
            if (p.officer == null && p.hasFled) n++;
        return n;
    }

    // 5: a stomp on a holding officer takes it out of the blockade; with all four crushed the blockade ends.
    static void Crush()
    {
        World w = Make();
        Aim(w, Aim20);
        w.Run(FirstWave() + F("police_arrive_s") + 2.0);
        if (w.police.blockades.Count == 0)
        {
            Check(false, "a blockade to crush");
            return;
        }
        Police.Blockade b = w.police.blockades[0];
        List<Police.Officer> officers = w.Officers();
        int killed = w.people.killed, fled = w.people.fled, cops = officers.Count;
        double r = F("cop_out_across") * 0.25;
        w.people.Crush(officers[0].post.x, officers[0].post.y, r);
        Check(w.people.killed == killed + 1 && b.holding == cops - 1 && w.police.blockades.Contains(b),
            $"a stomp on one officer: {w.people.killed - killed} killed, {b.holding} holding, the blockade stands");
        for (int i = 1; i < officers.Count; i++) w.people.Crush(officers[i].post.x, officers[i].post.y, r);
        Check(b.holding == 0 && w.people.Officers() == 0, $"every officer crushed: {b.holding} holding");
        w.Frame();
        Check(!w.police.blockades.Contains(b) && w.people.killed == killed + cops && w.people.fled == fled,
            $"the blockade ends: {w.people.killed - killed} killed, {w.people.fled - fled} fled");
    }

    // 6: with the kaiju held facing the city for 30 s the caps hold: max_blockades, max_police_cars, and no two
    // blockades at one crossing.
    static void Caps()
    {
        World w = Make();
        Aim(w, Aim20);
        bool ok = true;
        int most = 0;
        for (int n = 0; n < (int)Math.Ceiling(30.0 / Dt); n++)
        {
            w.Frame();
            List<Police.Blockade> bs = w.police.blockades;
            most = Math.Max(most, bs.Count);
            ok &= bs.Count <= (int)Num.I(cfg["max_blockades"]) && w.PoliceCars() <= (int)Num.I(cfg["max_police_cars"]);
            for (int i = 0; i < bs.Count; i++)
                for (int j = i + 1; j < bs.Count; j++)
                    ok &= bs[i].at.DistanceTo(bs[j].at) >= F("blockade_taken");
        }
        Check(ok && most == (int)Num.I(cfg["max_blockades"]) && w.police.blockadesMade == most,
            $"the caps hold over 30 s: {w.police.blockadesMade} made, {most} at once, {w.PoliceCars()} cruisers");
    }

    // 7: the same seeds give the same wave, bit for bit; the civilians walk the same with police and without.
    static void SameSeed()
    {
        World a = Make(), b = Make(), none = Make(false);
        foreach (World w in new[] { a, b, none }) Aim(w, Aim20);
        int half = (int)Math.Ceiling(10.0 / Dt);
        for (int n = 0; n < half * 2; n++)
        {
            if (n == half)
                foreach (World w in new[] { a, b, none })
                    w.sim.kaijuPos = w.traffic.net.Crossing(w.c);
            a.Frame();
            b.Frame();
            none.Frame(false);
        }
        List<Police.Officer> oa = a.Officers(), ob = b.Officers();
        bool same = a.police.Rng.state == b.police.Rng.state && a.police.shots == b.police.shots
            && a.police.blockadesMade == b.police.blockadesMade && oa.Count == ob.Count;
        for (int i = 0; i < oa.Count && i < ob.Count; i++) same &= oa[i].pos == ob[i].pos && oa[i].state == ob[i].state;
        Check(same && a.police.shots > 0, $"the same seeds give the same wave: {a.police.shots} shots, {oa.Count} officers");
        var walkers = new List<Vector2>();
        foreach (StreetPeople.Person p in a.people.people)
            if (p.officer == null) walkers.Add(p.pos);
        int differ = walkers.Count == none.people.people.Count ? 0 : 1;
        for (int i = 0; i < walkers.Count && i < none.people.people.Count; i++)
            if (walkers[i] != none.people.people[i].pos) differ++;
        Check(differ == 0 && none.police.blockadesMade == 0, $"the civilians walk the same with police and without: {differ} differ");
    }
}
