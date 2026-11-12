using System;
using System.Collections.Generic;
using S = Kaiju.Sim;

// The Tripo street props (scenes/street_props.gd, D-266, city.street_props): where they stand. Pavement furniture
// along every playable street, Tripo cars among the parked and stopped ones, a traffic light at every lit crossing
// and the lamp model on every streetlight, each turned a quarter at a time to face its street. Seeded off the
// decor's own seed, so the decor's draws are unchanged. StreetDecor asks, then draws what was placed.
// No UnityEngine here: unity/SimTests compiles this file (StreetPropsCheck). Presentation only.
public sealed class StreetProps
{
    const string DIR = "res://assets/street_props/", TYPE = ".kvox";
    // A draw of this id is the decor's own voxel car.
    const string CODE = "code";
    const int QUARTERS = 4;

    public struct Placed
    {
        public string id;
        public int turns;  // quarter turns about y; one turn takes -Z to -X
        public S.Vector2 at;
    }

    public readonly List<Placed> placed = new List<Placed>();
    // id -> how many stand in this city (the fixture, the stats line).
    public readonly Dictionary<string, int> counts = new Dictionary<string, int>();
    public readonly double voxel;

    readonly S.GDict cfg;
    readonly S.RandomNumberGenerator rng;
    readonly Dictionary<string, bool> known = new Dictionary<string, bool>();

    public StreetProps(S.GDict city, long decorSeed)
    {
        cfg = city["street_props"];
        voxel = S.Num.F(cfg["voxel"]);
        rng = new S.RandomNumberGenerator();
        rng.seed = S.GodotHash.Array(S.GodotHash.Int(decorSeed), S.GodotHash.String("street_props"));
    }

    public static string File(string id) => DIR + id + TYPE;

    public string Lamps => S.Gd.Str(cfg["lamps"]);
    public string Signals => S.Gd.Str(cfg["signals"]);

    // Whether `id` has its baked model: without it nothing is placed and the decor's own shape stands.
    bool Has(string id)
    {
        if (!known.TryGetValue(id, out bool has)) known[id] = has = S.FileAccess.FileExists(File(id));
        return has;
    }

    // Places `id` with its base at `at`, its front (-Z, turned by the model's yaw) toward `face`.
    public bool Put(string id, S.Vector2 at, S.Vector2 face)
    {
        if (!Has(id)) return false;
        S.GDict models = cfg["models"];
        S.GDict model = models[id];
        int turns = (Quarter(face) + (int)S.Num.I(model["yaw"])) % QUARTERS;
        placed.Add(new Placed { id = id, turns = turns, at = at });
        counts[id] = counts.TryGetValue(id, out int n) ? n + 1 : 1;
        return true;
    }

    // A model id drawn from `weights` (id -> weight), or "code" for the decor's own voxel car.
    public string Pick(S.GDict weights)
    {
        double total = 0.0;
        foreach (S.Variant id in weights.Keys()) total += S.Num.F(weights[id]);
        double roll = rng.Randf() * total;
        foreach (S.Variant id in weights.Keys())
        {
            roll -= S.Num.F(weights[id]);
            if (roll < 0.0) return S.Gd.Str(id);
        }
        return CODE;
    }

    // A car at p along its street: a Tripo car by city.street_props.parked (stopped in the lane: .lane, with the
    // big vehicles); false when the draw is the decor's own car.
    public bool Vehicle(S.Vector2 p, S.Vector2 dir, bool lane)
    {
        string id = Pick(cfg[lane ? "lane" : "parked"]);
        if (id == CODE) return false;
        return Put(id, p, rng.Randf() < 0.5 ? dir : dir * -1.0);
    }

    // Pavement props along both kerbs of the street a..b, every kerb.gap, inset from the kerb, facing the road;
    // none where `clearOf` says the ground is taken (a building, the water, a lamp), none crowding another.
    public void Kerb(S.Vector2 a, S.Vector2 b, double width, Func<S.Vector2, double, bool> clearOf)
    {
        S.GDict kerb = cfg["kerb"];
        S.GArray<S.Variant> gap = kerb["gap"];
        double from = S.Num.F(gap[0]), to = S.Num.F(gap[1]);
        double clear = S.Num.F(kerb["clear"]), inset = S.Num.F(kerb["inset"]);
        S.GDict weights = kerb["weights"];
        S.Vector2 dir = (b - a).Normalized();
        var side = new S.Vector2(-dir.y, dir.x);
        double length = a.DistanceTo(b);
        for (int k = 0; k < 2; k++)
        {
            double kerbSide = k == 0 ? -1.0 : 1.0;
            double t = rng.RandfRange(from, to) * 0.5 + clear;
            while (t < length - clear)
            {
                S.Vector2 p = a + dir * t + side * (kerbSide * (width * 0.5 + inset));
                string id = Pick(weights);
                if (clearOf(p, clear) && !Crowded(p, clear)) Put(id, p, side * -kerbSide);
                t += rng.RandfRange(from, to);
            }
        }
    }

    bool Crowded(S.Vector2 p, double apart)
    {
        foreach (Placed q in placed)
            if (p.DistanceTo(q.at) < apart) return true;
        return false;
    }

    // Which quarter turn (0-3) brings -Z nearest `face` on the ground (x, z).
    public static int Quarter(S.Vector2 face)
    {
        if (Math.Abs(face.x) > Math.Abs(face.y)) return face.x < 0.0 ? 1 : 3;
        return face.y < 0.0 ? 0 : 2;
    }

    // A cell's x and z after `turns` quarters about y (a turn takes -Z to -X).
    public static void Turn(ref int x, ref int z, int turns)
    {
        for (int i = 0; i < turns; i++)
        {
            int was = x;
            x = z;
            z = -was;
        }
    }
}
