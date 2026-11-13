using System;
using System.Collections.Generic;
using S = Kaiju.Sim;

// Boats on the water (scenes/boat_view.gd, D-404, director 2026-10-31: "boats don't rock or capsize, and don't flee
// his wake"): the Tripo harbour mix (trawler, tug, yacht, launch; assets/boats/*.kvox) moored along the port's
// piers, out in the bay he rises from and on the river. Each rocks on the swell; the kaiju's wake (his body within
// wake_radius) rocks it harder and pushes it away, and one he wades into (capsize_radius) rolls over and sinks.
// Pure spectacle: it reads the kaiju's position and decides nothing. Seeded (Seeds "boats"). Numbers: data/tuning.json
// "boats". No UnityEngine here: unity/SimTests compiles this file (BoatCheck); BoatView draws what it poses.
public sealed class Boats
{
    const string DIR = "res://assets/boats/", TYPE = ".kvox";
    const int TRIES = 20;  // draws per boat wanted before the bay or river gives up
    const double STILL = 0.01, PITCH_RATE = 0.7, PITCH_SHIFT = 1.3, PITCH_SHARE = 0.4, BOB_RATE = 1.3, WAKE_BOB = 3.0;

    public sealed class Boat
    {
        public string id, where;
        public S.Vector2 pos, vel;
        public double yaw, y, draft, height, phase, hz, wake, flip;
        public bool sunk, sea;
        public S.GArray<S.Rect2> water;
        // The pose _pose gives the node: position (Godot axes), basis, and whether it is still drawn.
        public S.Vector3 at;
        public S.Basis basis;
        public bool visible = true;
    }

    // Boats rolled over so far.
    public int capsized;
    public readonly List<Boat> boats = new List<Boat>();
    readonly S.GDict cfg, city, plan;
    readonly S.RandomNumberGenerator rng;
    readonly Dictionary<string, bool> known = new Dictionary<string, bool>();
    double t;

    // Moors the boats on `city` (the sim's city config).
    public Boats(S.GDict city)
    {
        this.city = city;
        cfg = S.Content.Section("boats");
        rng = S.Seeds.Make("boats", 0);
        plan = S.CityGen.Map(city);
        MoorPiers();
        MoorBay();
        MoorRiver();
    }

    public static string File(string id) => DIR + id + TYPE;

    double F(string key) => S.Num.F(cfg[key]);

    // Advances every boat `delta` seconds with the kaiju at `kaiju` (ground plane).
    public void Step(double delta, S.Vector2 kaiju)
    {
        t += delta;
        double wakeR = F("wake_radius"), push = F("flee_push"), drag = F("drag");
        foreach (Boat boat in boats)
        {
            if (boat.sunk) continue;
            S.Vector2 pos = boat.pos;
            S.Vector2 away = pos - kaiju;
            double d = away.Length();
            double wake = S.Gd.Clampf(1.0 - d / wakeR, 0.0, 1.0);
            boat.wake = Math.Max(boat.wake - delta / F("wake_fade_s"), wake);
            if (boat.flip <= 0.0 && d < F("capsize_radius"))
            {
                boat.flip = delta;
                capsized += 1;
            }
            S.Vector2 vel = boat.vel;
            if (wake > 0.0 && d > STILL) vel += away / d * push * wake * delta;
            vel *= Math.Max(0.0, 1.0 - drag * delta);
            S.Vector2 next = pos + vel * delta;
            if (Wet(boat, next)) boat.pos = next;
            else vel = S.Vector2.ZERO;
            boat.vel = vel;
            Pose(boat, delta);
        }
    }

    // Whether `boat` may float at p (its own water: the bay's or the river's).
    bool Wet(Boat boat, S.Vector2 p)
    {
        foreach (S.Rect2 r in boat.water)
            if (r.HasPoint(p)) return true;
        return boat.sea && S.CityHarbour.Holds(plan, p);
    }

    void Pose(Boat boat, double delta)
    {
        double phase = boat.phase + t * S.Gd.TAU * boat.hz;
        double rock = S.Gd.DegToRad(F("rock_deg") + F("wake_rock_deg") * boat.wake);
        double roll = Math.Sin(phase) * rock;
        double pitch = Math.Sin(phase * PITCH_RATE + PITCH_SHIFT) * rock * PITCH_SHARE;
        double sink = 0.0;
        if (boat.flip > 0.0)
        {
            boat.flip += delta;
            double over = S.Gd.Clampf(boat.flip / F("capsize_s"), 0.0, 1.0);
            roll = S.Gd.Lerpf(roll, S.Gd.PI, over * over * (3.0 - 2.0 * over));
            sink = Math.Max(0.0, boat.flip - F("capsize_s")) / F("sink_s");
            if (sink >= 1.0)
            {
                boat.sunk = true;
                boat.visible = false;
                return;
            }
        }
        double bob = Math.Sin(phase * BOB_RATE) * F("bob") * (1.0 + WAKE_BOB * boat.wake);
        boat.at = new S.Vector3(boat.pos.x, boat.y + bob - sink * boat.height, boat.pos.y);
        var turn = new S.Basis(S.Vector3.UP, boat.yaw);
        boat.basis = turn * new S.Basis(new S.Vector3(0f, 0f, 1f), roll) * new S.Basis(S.Vector3.RIGHT, pitch);
    }

    // Boats moored alongside the port's finger piers, bow along the pier.
    void MoorPiers()
    {
        if (!plan.Has("harbour")) return;
        S.GArray<S.Rect2> piers = plan["harbour"]["piers"];
        foreach (S.Rect2 pier in piers)
        {
            bool alongZ = pier.size.y > pier.size.x;
            double length = alongZ ? pier.size.y : pier.size.x;
            int n = (int)(length / F("pier_spacing"));
            for (int i = 0; i < n; i++)
                for (int k = 0; k < 2; k++)
                    MoorAtPier(pier, alongZ, length, (i + 0.5) / n, k == 0 ? -1.0 : 1.0);
        }
    }

    void MoorAtPier(S.Rect2 pier, bool alongZ, double length, double u, double side)
    {
        if (rng.Randf() > F("pier_fill")) return;
        double gap = F("pier_gap");
        S.Vector2 c = pier.GetCenter();
        S.Vector2 p = alongZ
            ? new S.Vector2(c.x + side * (pier.size.x * 0.5 + gap), pier.position.y + u * length)
            : new S.Vector2(pier.position.x + u * length, c.y + side * (pier.size.y * 0.5 + gap));
        if (S.CityHarbour.Holds(plan, p)) Add(Pick(), p, alongZ ? 0.0 : S.Gd.PI * 0.5, true, new S.GArray<S.Rect2>()).where = "pier";
    }

    // Boats at anchor out in the bay he rises from, headings at random.
    void MoorBay()
    {
        S.GArray<S.Rect2> basin = S.CityHarbour.Basin(plan);
        if (basin.IsEmpty()) return;
        S.Rect2 rect = basin[0];
        long want = S.Num.I(cfg["bay"]);
        long tries = want * TRIES;
        for (long attempt = 0; attempt < tries; attempt++)
        {
            if (want == 0) break;
            S.Vector2 p = rect.position + new S.Vector2(rng.Randf(), rng.Randf()) * rect.size;
            if (!S.CityHarbour.Holds(plan, p) || !Clear(p)) continue;
            Add(Pick(), p, rng.Randf() * S.Gd.TAU, true, new S.GArray<S.Rect2>()).where = "bay";
            want -= 1;
        }
    }

    // Boats moored along the river, bow along its flow.
    void MoorRiver()
    {
        S.GArray<S.Rect2> channels = S.CityRiver.Channels(plan, city);
        if (channels.IsEmpty()) return;
        S.Rect2 river = channels[0];
        double y = -S.Num.F(city.Get("river_depth", 0.0));
        long want = S.Num.I(cfg["river"]);
        long tries = want * TRIES;
        for (long attempt = 0; attempt < tries; attempt++)
        {
            if (want == 0) break;
            double side = rng.Randf() < 0.5 ? -1.0 : 1.0;
            var p = new S.Vector2(river.position.x + rng.Randf() * river.size.x, river.GetCenter().y + side * river.size.y * F("river_bank"));
            if (!Clear(p)) continue;
            double yaw = rng.Randf() < 0.5 ? S.Gd.PI * 0.5 : -S.Gd.PI * 0.5;
            Boat b = Add(Pick(), p, yaw, false, channels);
            b.y = y - b.draft;
            b.where = "river";
            want -= 1;
        }
    }

    // Whether p is far enough from every boat already moored.
    bool Clear(S.Vector2 p)
    {
        double space = F("spacing");
        foreach (Boat b in boats)
            if (p.DistanceTo(b.pos) <= space) return false;
        return true;
    }

    // A model id drawn from the harbour mix.
    string Pick()
    {
        S.GDict mix = cfg["mix"];
        double total = 0.0;
        foreach (S.Variant id in mix.Keys()) total += S.Num.F(mix[id]);
        double roll = rng.Randf() * total;
        foreach (S.Variant id in mix.Keys())
        {
            roll -= S.Num.F(mix[id]);
            if (roll < 0.0) return S.Gd.Str(id);
        }
        return S.Gd.Str(mix.Keys()[0]);
    }

    // Whether model `id` has its baked voxels (Godot: a boat without them is drawn with no height).
    bool Has(string id)
    {
        if (!known.TryGetValue(id, out bool has)) known[id] = has = S.FileAccess.FileExists(File(id));
        return has;
    }

    // A boat of model `id` at p heading `yaw`; `sea`: held by the harbour; `water`: the rects it may also float in.
    Boat Add(string id, S.Vector2 p, double yaw, bool sea, S.GArray<S.Rect2> water)
    {
        S.GDict models = cfg["models"];
        S.GDict row = models[id];
        double height = Has(id) ? S.Num.F(row["metres_tall"]) / F("metres_per_unit") : 0.0;
        double draft = height * S.Num.F(row["draft"]);
        S.GArray<S.Variant> hz = cfg["rock_hz"];
        var boat = new Boat
        {
            id = id, pos = p, vel = S.Vector2.ZERO, yaw = yaw, y = S.CityHarbour.Sea(city) - draft, draft = draft, height = height,
            phase = rng.Randf() * S.Gd.TAU, hz = rng.RandfRange((float)S.Num.F(hz[0]), (float)S.Num.F(hz[1])), sea = sea, water = water,
        };
        boats.Add(boat);
        Pose(boat, 0.0);
        return boat;
    }
}
