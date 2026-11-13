using System;
using System.Collections.Generic;
using S = Kaiju.Sim;

// Sky and sea life (scenes/wildlife_view.gd; DESIGN atmosphere; director comments 63, 66, 71): gulls wheel over the
// water, pigeons sit in flocks on rooftops, and both burst up and away from a roar (the dash's leap, an ultimate, an
// ability) or a section of a tower hitting the ground; gulls settle back into their circles, pigeons stay up wheeling
// over the roof they left. The whale surfaces a few times a run out in the bay, spouts, and dives at once on a roar.
// Pure spectacle: it reads the sim's events and decides nothing, and the kaiju can't touch it. Seeded (Seeds
// "wildlife"). Numbers: data/tuning.json "wildlife". No UnityEngine here: unity/SimTests compiles this file
// (WildlifeCheck); WildlifeView draws what it poses, in Godot axes.
public sealed partial class Wildlife
{
    const double JITTER = 4.0;          // a gull's centre, this far round its flock's
    const double SEAT = 0.4;            // a pigeon's seat, this share of its roof either side of the middle
    const double FLEE_TURN = 0.5;       // radians either side of straight away
    const double FLEE_STILL = 0.01, MOVED = 0.001, TILT = 0.5;

    public sealed class Bird
    {
        // Home: where it circles (centre, radius, height, angle, spin) and, a pigeon, the seat it starts on.
        public S.Vector3 centre, seat;
        public double radius, height, angle, spin;
        public S.Vector3 pos, vel, facing;
        public double scared, phase;
        public bool perched;
        // The pose _move_flock gives its instance: basis columns (Godot axes).
        public S.Vector3 x, y, z;
    }

    public sealed class Flock
    {
        public string kind;
        public readonly List<Bird> birds = new List<Bird>();
    }

    // Birds put to flight so far.
    public int scattered;
    public readonly List<Flock> flocks = new List<Flock>();
    readonly S.GDict cfg;
    readonly S.RampageSim sim;
    readonly S.RandomNumberGenerator rng;
    readonly double sea;

    // The wildlife of `sim`'s city: gulls, then pigeons, then the whale (wildlife_view.gd _ready).
    public Wildlife(S.RampageSim sim)
    {
        this.sim = sim;
        cfg = S.Content.Section("wildlife");
        rng = S.Seeds.Make("wildlife", 0);
        sea = S.CityHarbour.Sea(sim.city);
        BuildGulls();
        BuildPigeons();
        BuildWhale();
    }

    // wildlife_view.gd _process.
    public void Step(double delta)
    {
        foreach (Flock flock in flocks) MoveFlock(flock, delta);
        MoveWhale(delta);
    }

    // A sim event: a roar scatters every bird near the kaiju (at, Godot axes) and sends the whale down; a falling
    // section scatters the birds near where it lands.
    public void OnEvent(S.GDict e, S.Vector3 kaijuAt)
    {
        switch (S.Gd.Str(e["type"]))
        {
            case "leap":
            case "ultimate":
            case "ability":
                Startle(kaijuAt, S.Num.F(cfg["roar_radius"]));
                Dive();
                break;
            case "fall_land":
                S.RampageSim.Building b = sim.buildings[S.Num.I(e["building"])];
                Startle(new S.Vector3(b.x, 0.0, b.z), S.Num.F(cfg["fall_radius"]));
                break;
        }
    }

    // Every bird within `radius` (on the ground plane) of `at` bursts up and away from it.
    public void Startle(S.Vector3 at, double radius)
    {
        S.GArray<S.Variant> speed = cfg["flee_speed"], up = cfg["flee_up"], seconds = cfg["flee_seconds"];
        foreach (Flock flock in flocks)
            foreach (Bird bird in flock.birds)
            {
                var flat = new S.Vector2(bird.pos.x - at.x, bird.pos.z - at.z);
                if (flat.Length() > radius || bird.scared > 0.0) continue;
                S.Vector2 away = flat.Length() > FLEE_STILL ? flat.Normalized() : S.Vector2.RIGHT.Rotated(rng.Randf() * S.Gd.TAU);
                away = away.Rotated(rng.RandfRange(-FLEE_TURN, FLEE_TURN));
                double v = Range(speed);
                bird.vel = new S.Vector3(away.x * v, Range(up), away.y * v);
                bird.scared = Range(seconds);
                bird.perched = false;
                scattered += 1;
            }
    }

    void BuildGulls()
    {
        S.GDict g = cfg["gull"];
        double coast = S.Num.F(sim.city["coast_z"]);
        var flock = new Flock { kind = "gull" };
        for (long f = 0; f < S.Num.I(g["flocks"]); f++)
        {
            double cx = Range(g["area_x"]);
            var centre = new S.Vector3(cx, 0.0, coast + Range(g["area_z"]));
            for (long n = 0; n < S.Num.I(g["per_flock"]); n++)
            {
                double jx = rng.RandfRange(-JITTER, JITTER);
                var bird = new Bird { centre = centre + new S.Vector3(jx, 0.0, rng.RandfRange(-JITTER, JITTER)) };
                bird.radius = Range(g["radius"]);
                bird.height = sea + Range(g["height"]);
                bird.angle = rng.Randf() * S.Gd.TAU;
                bird.spin = Range(g["speed"]) * (f % 2 == 0 ? 1.0 : -1.0);
                flock.birds.Add(Fly(bird, false));
            }
        }
        AddFlock(flock);
    }

    void BuildPigeons()
    {
        S.GDict p = cfg["pigeon"];
        var roofs = new List<int>();
        for (int i = 0; i < sim.buildings.Size(); i++)
        {
            S.RampageSim.Building b = sim.buildings[i];
            if (b.height >= S.Num.I(p["min_height"]) && b.landmark == "") roofs.Add(i);
        }
        var flock = new Flock { kind = "pigeon" };
        for (long f = 0; f < Math.Min(S.Num.I(p["flocks"]), roofs.Count); f++)
        {
            S.RampageSim.Building b = sim.buildings[roofs[(int)rng.RandiRange(0, roofs.Count - 1)]];
            var wheel = new S.Vector3(b.x, b.height + Range(p["wheel_lift"]), b.z);
            double radius = Range(p["radius"]);
            for (long n = 0; n < S.Num.I(p["per_flock"]); n++)
            {
                double sx = b.x + rng.RandfRange(-SEAT, SEAT) * b.w;
                var seat = new S.Vector3(sx, (double)b.height, b.z + rng.RandfRange(-SEAT, SEAT) * b.d);
                var bird = new Bird { seat = seat, centre = wheel, radius = radius, height = wheel.y };
                bird.angle = rng.Randf() * S.Gd.TAU;
                bird.spin = Range(p["speed"]);
                flock.birds.Add(Fly(bird, true));
            }
        }
        AddFlock(flock);
    }

    // wildlife_view.gd _bird: the rest of a bird whose home is set.
    Bird Fly(Bird bird, bool perched)
    {
        bird.pos = perched ? bird.seat : Circle(bird);
        bird.vel = S.Vector3.ZERO;
        bird.perched = perched;
        bird.phase = rng.Randf();
        double fx = rng.RandfRange(-1.0, 1.0);
        bird.facing = new S.Vector3(fx, 0.0, rng.RandfRange(-1.0, 1.0));
        return bird;
    }

    void AddFlock(Flock flock)
    {
        flocks.Add(flock);
        MoveFlock(flock, 0.0);
    }

    void MoveFlock(Flock flock, double delta)
    {
        double settle = S.Num.F(cfg["settle"]);
        foreach (Bird bird in flock.birds)
        {
            S.Vector3 pos = bird.pos, before = pos;
            if (bird.scared > 0.0)
            {
                pos += bird.vel * delta;
                bird.scared -= delta;
            }
            else if (!bird.perched)
            {
                bird.angle += bird.spin * delta;
                pos = pos.Lerp(Circle(bird), 1.0 - S.Gd.Exp(-settle * delta));
            }
            bird.pos = pos;
            S.Vector3 step = pos - before;
            if (step.Length() > MOVED) bird.facing = step;
            S.Vector3 facing = bird.facing;
            var flat = new S.Vector3(facing.x, S.Gd.Clampf(facing.y, -TILT, TILT), facing.z);
            LookAt(bird, flat.Length() > MOVED ? flat.Normalized() : new S.Vector3(0f, 0f, -1f));
        }
    }

    // Basis.looking_at(target) with up +Y: its columns (Godot: no change and an error when they are parallel).
    static void LookAt(Bird bird, S.Vector3 target)
    {
        S.Vector3 z = -target.Normalized();
        S.Vector3 x = S.Vector3.UP.Cross(z);
        if (x.IsZeroApprox())
        {
            bird.x = S.Vector3.RIGHT;
            bird.y = S.Vector3.UP;
            bird.z = new S.Vector3(0f, 0f, 1f);
            return;
        }
        x = x.Normalized();
        bird.x = x;
        bird.y = z.Cross(x);
        bird.z = z;
    }

    static S.Vector3 Circle(Bird bird) =>
        new S.Vector3(bird.centre.x + Math.Cos(bird.angle) * bird.radius, bird.height, bird.centre.z + Math.Sin(bird.angle) * bird.radius);

    double Range(S.GArray<S.Variant> pair) => rng.RandfRange(S.Num.F(pair[0]), S.Num.F(pair[1]));
}
