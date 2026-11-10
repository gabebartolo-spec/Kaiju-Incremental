// The street's people and the beach crowd (Rampage/Pavements.cs, StreetPeople.cs, BeachLayout.cs, after
// scenes/pavements.gd, street_life.gd, street_steps.gd and beach_crowd.gd) are plain seeded maths, so they are held
// here on a real city: the pavement graph is sound, the same seed walks the same people, the kaiju near makes them
// run and the kaiju far does not (on vs off), a crush removes and counts them, a brace holds them in place, and the
// beach stands still until the kaiju has risen.
using System;
using System.Collections.Generic;
using Kaiju.Sim;

static class StreetCheck
{
    const double Dt = 1.0 / 60.0;
    const long Tier = 3, Seed = 0;
    const int PerLot = 2;
    const double Far = 1.0e6, Scale = 1.0;

    static int failed;

    public static int Run(string repoRoot)
    {
        failed = 0;
        Kaiju.Sim.FileAccess.Root = repoRoot;
        GDict stats = UpgradeTree.RunStats(Content.Section("kaiju"), Content.SpeciesDef("reptilian"), new UpgradeTree(Content.Upgrades()));
        GArray<GDict> layout = CityGrowth.Layout(Content.Tuning(), Tier, Seeds.Make("city", Seed));
        RampageSim sim = new RampageSim(stats, CityGrowth.TuningFor(Content.Tuning(), Tier), layout, Seeds.Make("army", Seed));
        Graph(sim);
        SameSeed(sim);
        Panic(sim);
        Crush(sim);
        Brace(sim);
        Beach(sim);
        Console.WriteLine(failed == 0 ? "street and beach: ok" : $"street and beach: {failed} failed");
        return failed;
    }

    static void Check(bool ok, string what)
    {
        if (ok) return;
        failed++;
        Console.WriteLine("FAIL street: " + what);
    }

    static StreetPeople Make(RampageSim sim) => new StreetPeople(sim, Seeds.Make("civilians", 0), PerLot);

    static void Steps(StreetPeople people, int count, Vector2 kaiju, bool risen)
    {
        for (int n = 0; n < count; n++) people.Step(Dt, kaiju, Scale, risen);
    }

    static void Graph(RampageSim sim)
    {
        var p = new Pavements(sim);
        Check(p.nodes.Count > 0 && p.nodes.Count % 4 == 0, $"four corners a block: {p.nodes.Count} nodes");
        Check(p.RingNodes().Count > 0, "some corners can be walked");
        int oneWay = 0, roadLinks = 0, selfLinks = 0;
        for (int a = 0; a < p.nodes.Count; a++)
        {
            if (p.inRoad[a] && p.links[a].Count > 0) roadLinks++;
            foreach (int b in p.links[a])
            {
                if (b == a) selfLinks++;
                if (!p.links[b].Contains(a)) oneWay++;
            }
        }
        Check(oneWay == 0, $"every pavement link goes both ways: {oneWay} do not");
        Check(roadLinks == 0, $"no corner in the avenue's road is linked: {roadLinks} are");
        Check(selfLinks == 0, $"no corner links to itself: {selfLinks} do");
    }

    static void SameSeed(RampageSim sim)
    {
        StreetPeople a = Make(sim), b = Make(sim);
        Check(a.Civilians() > 0, "the city has people");
        Check(a.Civilians() == PerLot * sim.LotBuildings().Size() + a.beachPeople, $"{PerLot} people a lot plus the beach: {a.Civilians()}");
        for (int n = 0; n < 600; n++)
        {
            var kaiju = new Vector2(n * 0.05 - 15.0, n * 0.03);
            a.Step(Dt, kaiju, Scale, true);
            b.Step(Dt, kaiju, Scale, true);
        }
        int differ = a.Civilians() == b.Civilians() ? 0 : 1;
        for (int i = 0; i < a.Civilians() && i < b.Civilians(); i++)
            if (a.people[i].pos != b.people[i].pos || a.people[i].to != b.people[i].to || a.Pose(i) != b.Pose(i)) differ++;
        Check(differ == 0, $"the same seed walks the same people: {differ} differ");
        Check(a.fled == b.fled, "the same seed counts the same fled");
    }

    // On vs off: the kaiju among them, and the kaiju nowhere near.
    static void Panic(RampageSim sim)
    {
        StreetPeople near = Make(sim), far = Make(sim);
        Vector2 at = near.people[0].pos;
        Steps(near, 1, at, true);
        Check(near.fled > 0, "people the kaiju comes near are startled");
        Check(near.Panicking() == near.fled, "each startled person is counted once");
        Check(near.Pose(0) == StreetPeople.WALK_A, "a startled person stands and stares first");
        Vector2 stood = near.people[0].pos;
        Steps(near, 30, at, true);
        Check(near.people[0].pos == stood, "it stares where it stood through the gawk");
        Steps(near, 150, at, true);
        Check(near.people[0].pos != stood, "then it runs");
        Check(near.Pose(0) >= StreetPeople.RUN_A, "in a running pose");
        Check(near.people[0].pos.DistanceTo(at) > stood.DistanceTo(at), "away from the kaiju");
        Steps(far, 181, new Vector2(Far, Far), true);
        Check(far.fled == 0 && far.Panicking() == 0, $"nobody runs from a kaiju far away: {far.fled} fled");
    }

    static void Crush(RampageSim sim)
    {
        StreetPeople people = Make(sim);
        int puffs = 0;
        people.Puffed = where => puffs++;
        int had = people.Civilians();
        Vector2 at = people.people[0].pos;
        int dead = people.Crush(at.x, at.y, 2.0);
        Check(dead >= 1, "a stomp on a person crushes it");
        Check(people.Civilians() == had - dead && people.killed == dead && people.KaijuKilled() == dead, "and counts it as the kaiju's");
        Check(puffs == 1, $"one puff a crush: {puffs}");
        foreach (StreetPeople.Person p in people.people)
            if (p.pos.DistanceTo(at) <= 2.0) Check(false, "nobody is left inside the crushed disc");
        at = people.people[0].pos;
        int rolled = people.Crush(at.x, at.y, 1.0, true);
        Check(rolled >= 1 && people.runOver == rolled && people.KaijuKilled() == dead, "a tank's run-over is not the kaiju's kill");
        at = people.people[0].pos;
        int killed = people.killed;
        int stray = people.Crush(at.x, at.y, 1.0, false, true);
        Check(stray >= 1 && people.armyKilled == stray && people.killed == killed, "a stray shell's dead are the army's");
        Check(people.Crush(Far, Far, 5.0) == 0, "a crush on empty ground kills nobody");
    }

    static void Brace(RampageSim sim)
    {
        StreetPeople people = Make(sim);
        Vector2 at = people.people[0].pos;
        int pinned = people.Brace(at, at, 1.0, 1.0);
        Check(pinned >= 1, "people under a falling section are held");
        Steps(people, 60, new Vector2(Far, Far), true);
        Check(people.people[0].pos == at, "and stand there until it lands");
        Steps(people, 60, new Vector2(Far, Far), true);
        Check(people.people[0].pos != at, "then walk on");
    }

    static void Beach(RampageSim sim)
    {
        GDict plan = CityGen.Map(sim.city);
        Check(plan.Has("harbour"), "the city has its beach");
        if (!plan.Has("harbour")) return;
        List<Vector2> spots = BeachLayout.Spots(plan, sim.arenaHalf + Num.F(sim.city["view_beyond"]));
        List<Vector2> courts = BeachLayout.Courts(plan);
        Check(spots.Count > 0 && courts.Count > 0, $"umbrellas and courts on the sand: {spots.Count}, {courts.Count}");
        StreetPeople people = Make(sim);
        Check(people.beachPeople > 0, "the beach has people");
        Check(people.Held() == people.beachPeople, "all of them held at the start");
        int first = people.Civilians() - people.beachPeople;
        Vector2 stood = people.people[first].pos;
        Steps(people, 120, new Vector2(Far, Far), false);
        Check(people.Held() == people.beachPeople && people.people[first].pos == stood, "they stand while the kaiju is under the water");
        Steps(people, 1, new Vector2(Far, Far), true);
        Check(people.Held() == 0, "its rising frees every one");
        GDict harbour = sim.city["harbour"];
        GDict props = harbour["props"];
        GDict crowd = props["crowd"];
        double release = Num.F(crowd["release"]);
        int late = 0;
        for (int i = first; i < people.Civilians(); i++)
            if (people.people[i].pinnedUntil > people.Clock + release) late++;
        Check(late == 0, $"each within {release} s: {late} later");
        Steps(people, 120, new Vector2(Far, Far), true);
        int still = 0;
        for (int i = first; i < people.Civilians(); i++)
            if (people.people[i].pinnedUntil > people.Clock) still++;
        Check(still == 0, $"none still held two seconds on: {still}");
        Check(people.people[first].pos != stood, "and they walk off the sand");
    }
}
