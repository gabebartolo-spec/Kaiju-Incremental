using System;
using System.Collections.Generic;
using S = Kaiju.Sim;

// The far rampage's schedule (scenes/skyline_rampage_plan.gd, skyline_rampage.gd _ready): from the run's seeded
// stream, the beast's start on its path, which far towers fall and when (its own blows first, then a few
// aftershocks beside its path), where fires burn (every ruin and a few towers left standing), and the lights'
// and smoke's own draws, in Godot's order. Pure data, Godot axes: nothing is drawn here.
public sealed class SkylineRampagePlan
{
    const double PLAN_S = 900.0;  // tower falls are planned this far ahead (longer than any rampage)
    const double PLAN_STEP = 0.1;
    const double MIN_TALL = 12.0;  // lower boxes never fall on their own
    public const double GROUND_Y = 0.8;  // the far shore's concrete top (CitySkyline.FarShore)
    const double AFTER_MIN = 2.0, AFTER_MAX = 10.0;  // a nearby tower goes this long after the beast passes
    const double STANDING_FROM = -60.0, STANDING_TO = 25.0;  // when the fires on standing towers caught
    const double FLAME_AT_FALL = 0.6;  // share of a fall after which its ruins burn
    const double FLAME_MIN = 4.0, FLAME_MAX = 8.0;  // a ruin's flame size, least and most
    const double STANDING_FLAME = 0.7, STANDING_SIDE = 0.3, STANDING_LOW = -0.15, STANDING_FRONT = 0.6;
    const double DUST_SIZE = 1.2;  // a ruin's dust puff, in flame sizes
    const double RUIN_SIDE = 0.2, RUIN_UP = 1.5, CORRIDOR_NEAR = 3.0, START_SPREAD = 0.35;

    // One far skyline box (CitySkyline.far_boxes): its size and centre, and the tower it crowns or -1.
    public struct Box
    {
        public S.Vector3 size, at;
        public int crownOf;
    }

    public sealed class Fall
    {
        public int index;
        public List<int> crowns;
        public double at, dir;
        public bool smash;
    }

    public sealed class Fire
    {
        public S.Vector3 pos;
        public double size, start, fall, seed;
        public bool dust;
    }

    // One smoke or dust puff (horizon_smoke custom): its column's base and size, slot (0..1 up its column, or the
    // dust's angle draw), when it starts (s), dust or smoke, its own seed.
    public struct Puff
    {
        public S.Vector3 pos;
        public double size, slot, start, seed;
        public bool dust;
    }

    public readonly List<Fall> falls = new List<Fall>();
    public readonly List<Fire> fires = new List<Fire>();
    public readonly List<Puff> puffs = new List<Puff>();
    public readonly double phase0, omega, pathZ;
    readonly S.GDict cfg;
    readonly IReadOnlyList<Box> boxes;
    readonly S.RandomNumberGenerator rng;
    readonly Dictionary<int, List<int>> crowns = new Dictionary<int, List<int>>();

    double F(string key) => S.Num.F(cfg[key]);

    // `cfg` tuning skyline_rampage, `boxes` the far skyline's, `shore` its quay's edge (coast - bay_width), `rng`
    // the rampage's stream (Seeds.Derive(fx, 16)); `puffSize` is skyline_rampage.gd PUFF.
    public SkylineRampagePlan(S.GDict cfg, IReadOnlyList<Box> boxes, double shore, S.RandomNumberGenerator rng, double puffSize)
    {
        this.cfg = cfg;
        this.boxes = boxes;
        this.rng = rng;
        omega = F("speed") / F("swing");
        // At the run's start it is mid-skyline (within START_SPREAD of the centre), heading either way.
        double u = Math.Asin(rng.RandfRange(-START_SPREAD, START_SPREAD));
        phase0 = (rng.Randf() < 0.5 ? u : Math.PI - u) - omega * F("start_s");
        pathZ = shore - F("path_depth");
        PlanFalls();
        PlanFires();
        foreach (Fire f in fires) f.seed = rng.Randf();
        Smoke(puffSize);
    }

    // The beast's x along its path at time t: it paces the skyline, slowing to turn at each end.
    public double BeastX(double t) => F("centre_x") + F("swing") * Math.Sin(omega * t + phase0);

    public double Velocity(double t) => F("speed") * Math.Cos(omega * t + phase0);

    void PlanFalls()
    {
        double corridor = F("corridor"), reach = F("reach");
        MapCrowns();
        var nearby = new List<int>();
        for (int i = 0; i < boxes.Count; i++)
        {
            S.Vector3 size = boxes[i].size, at = boxes[i].at;
            if (boxes[i].crownOf >= 0 || size.y < MIN_TALL) continue;
            double dz = Math.Abs(at.z - pathZ) - size.z * 0.5;
            if (dz < corridor)  // in the beast's way: its blow drops the tower
            {
                double t = Reached(at.x, reach + size.x * 0.5);
                if (t >= 0.0) falls.Add(MakeFall(i, t, at.x - BeastX(t), true));
            }
            else if (dz < corridor * CORRIDOR_NEAR)
                nearby.Add(i);
        }
        Aftershocks(nearby, reach);
        // A stable sort: Godot's sort_custom leaves equal times in an order of its own (two towers struck in one step).
        var order = new List<(Fall f, int n)>();
        for (int n = 0; n < falls.Count; n++) order.Add((falls[n], n));
        order.Sort((a, b) => a.f.at != b.f.at ? a.f.at.CompareTo(b.f.at) : a.n.CompareTo(b.n));
        falls.Clear();
        foreach ((Fall f, int _) in order) falls.Add(f);
        StandingFires(nearby);
    }

    void MapCrowns()
    {
        for (int i = 0; i < boxes.Count; i++)
        {
            if (boxes[i].crownOf < 0) continue;
            if (!crowns.TryGetValue(boxes[i].crownOf, out List<int> list)) crowns[boxes[i].crownOf] = list = new List<int>();
            list.Add(i);
        }
    }

    int PopAt(List<int> list)
    {
        int k = (int)rng.RandiRange(0, list.Count - 1);
        int i = list[k];
        list.RemoveAt(k);
        return i;
    }

    // A few towers beside its path fall late (aftershocks).
    void Aftershocks(List<int> nearby, double reach)
    {
        for (long n = 0; n < S.Num.I(cfg["extra_falls"]); n++)
        {
            if (nearby.Count == 0) break;
            int i = PopAt(nearby);
            double t = Reached(boxes[i].at.x, reach * 2.0);
            if (t < 0.0) continue;
            t += rng.RandfRange(AFTER_MIN, AFTER_MAX);
            falls.Add(MakeFall(i, t, rng.RandfRange(-1.0, 1.0), false));
        }
    }

    // A few of the towers still standing burn.
    void StandingFires(List<int> nearby)
    {
        for (long n = 0; n < S.Num.I(cfg["standing_fires"]); n++)
        {
            if (nearby.Count == 0) break;
            Box box = boxes[PopAt(nearby)];
            double x = box.at.x + rng.RandfRange(-STANDING_SIDE, STANDING_SIDE) * box.size.x;
            double y = box.at.y + box.size.y * rng.RandfRange(STANDING_LOW, STANDING_SIDE);
            var pos = new S.Vector3(x, y, box.at.z + box.size.z * 0.5 + STANDING_FRONT);
            double start = rng.RandfRange(STANDING_FROM, STANDING_TO);
            double flame = rng.RandfRange(FLAME_MIN * STANDING_FLAME, FLAME_MAX * STANDING_FLAME);
            fires.Add(new Fire { pos = pos, size = flame, start = start, dust = false });
        }
    }

    // The first time the beast comes within `within` of x, or -1 if it never does.
    double Reached(double x, double within)
    {
        for (double t = 0.0; t < PLAN_S; t += PLAN_STEP)
            if (Math.Abs(BeastX(t) - x) < within) return t;
        return -1.0;
    }

    Fall MakeFall(int i, double t, double away, bool smash)
    {
        crowns.TryGetValue(i, out List<int> list);
        return new Fall { index = i, crowns = list ?? new List<int>(), at = t, dir = away != 0.0 ? Math.Sign(away) : 1.0, smash = smash };
    }

    // Every fall leaves a burning ruin and a cloud of dust.
    void PlanFires()
    {
        double fallS = F("fall_s");
        foreach (Fall fall in falls)
        {
            Box box = boxes[fall.index];
            double start = fall.at + fallS * FLAME_AT_FALL;
            var pos = new S.Vector3(box.at.x + rng.RandfRange(-RUIN_SIDE, RUIN_SIDE) * box.size.x, GROUND_Y + RUIN_UP, box.at.z);
            double w = Math.Clamp(box.size.x * 0.5, FLAME_MIN, FLAME_MAX);
            fires.Add(new Fire { pos = pos, size = w, start = start, dust = true, fall = fall.at });
        }
    }

    // skyline_rampage.gd _build_smoke's draws: every fire's column, then each ruin's dust cloud.
    void Smoke(double puffSize)
    {
        long count = S.Num.I(cfg["puffs"]);
        foreach (Fire spot in fires)
        {
            for (long k = 0; k < count; k++)
                puffs.Add(new Puff { pos = spot.pos, size = puffSize, slot = (double)k / count, start = spot.start, seed = rng.Randf() });
            if (!spot.dust) continue;
            for (long k = 0; k < count; k++)
            {
                double slot = rng.Randf();
                puffs.Add(new Puff { pos = spot.pos, size = spot.size * DUST_SIZE, slot = slot, start = spot.fall, seed = rng.Randf(), dust = true });
            }
        }
    }
}
