using System.Collections.Generic;
using S = Kaiju.Sim;

// scenes/wreck_survivors.gd: survivors crawling out of a derailed train and fleeing (the director's answer, 022
// update 2026-10-25: "After a derail, survivors crawl out of the wreck and flee, using the game's existing crowd
// people"): new street people at the wreck, already running, on the pavement line nearest it. scenes/rail_view.gd
// _crawl_out: each car of a wreck lets rail_look "survivors_per_car" out once the wreck has had "crawl_s" to come to
// rest. Godot axes. Presentation only.
public sealed class WreckSurvivors
{
    // wreck_survivors.gd spill: how far round the car a survivor starts, and how fast they run.
    const double SPREAD = 0.8, PACE_MIN = 1.1, PACE_MAX = 1.4;

    readonly S.RampageSim sim;
    readonly StreetPeople street;
    readonly S.RandomNumberGenerator rng = S.Seeds.Make("wreck_survivors", 0);
    readonly double crawl;
    readonly int perCar;
    // rail_view.gd _pending: a wrecked train and the seconds until its survivors crawl out.
    readonly List<(S.Rail.Train train, double left)> pending = new List<(S.Rail.Train, double)>();

    public int Spilled { get; private set; }

    public WreckSurvivors(S.RampageSim sim, StreetPeople street)
    {
        this.sim = sim;
        this.street = street;
        S.GDict look = S.Content.Section("rail_look");
        crawl = S.Num.F(look["crawl_s"]);
        perCar = (int)S.Num.I(look["survivors_per_car"]);
    }

    // rail_view.gd on_event "train_derailed": the derailed train's survivors wait crawl_s.
    public void Derailed(long trainId)
    {
        foreach (S.Rail.Train train in sim.rail.trains)
            if (train.id == trainId) pending.Add((train, crawl));
    }

    // rail_view.gd _crawl_out, oldest wreck first; how many crawled out now.
    public int Step(double dt)
    {
        int had = Spilled;
        for (int k = 0; k < pending.Count; k++)
        {
            (S.Rail.Train train, double left) = pending[k];
            pending[k] = (train, left - dt);
            if (left - dt > 0.0) continue;
            foreach (S.Rail.Car car in train.cars) Spill(car.pos, perCar);
        }
        pending.RemoveAll(w => w.left <= 0.0);
        return Spilled - had;
    }

    // wreck_survivors.gd spill: `count` fleeing people round `at`. As Godot does, the nearest ring corner's index in
    // the ring list is the node they set off from.
    void Spill(S.Vector2 at, int count)
    {
        List<S.Vector2> nodes = street.RingNodes();
        if (nodes.Count == 0) return;
        int near = 0;
        for (int n = 0; n < nodes.Count; n++)
            if (nodes[n].DistanceSquaredTo(at) < nodes[near].DistanceSquaredTo(at)) near = n;
        for (int k = 0; k < count; k++)
        {
            int i = street.AddPerson();
            StreetPeople.Person p = street.people[i];
            var off = new S.Vector2(rng.RandfRange(-SPREAD, SPREAD), rng.RandfRange(-SPREAD, SPREAD));
            p.pos = at + off;
            p.from = near;
            p.to = (near & ~3) + ((near + 1) & 3);
            p.heading = off != S.Vector2.ZERO ? off.Normalized() : new S.Vector2(0, 1);
            p.outfit = (int)rng.RandiRange(0, StreetPeople.COP - 1);
            p.phase = rng.Randf();
            p.pace = rng.RandfRange(PACE_MIN, PACE_MAX);
            p.fleeing = true;
            street.people[i] = p;
            Spilled++;
        }
    }
}
