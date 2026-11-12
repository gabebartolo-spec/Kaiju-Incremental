using System;
using System.Collections.Generic;
using S = Kaiju.Sim;

// scenes/police.gd, line for line, minus the scene tree: every so often two cruisers race to a crossing ahead of the
// kaiju and park nose to nose across the street, and their officers take up posts behind them and fire their pistols,
// in vain, until the kaiju is almost on them; then they scatter. Officers are StreetPeople people (drawn and crushed
// with everyone else); the cruisers are Traffic cars. Godot's constants are street keys in data/tuning.json (D-482).
// PoliceView draws the muzzle flashes (shown) and each blockade's beacon (Red). Presentation only: reads the sim,
// never writes it. No UnityEngine here: unity/SimTests compiles this file (PoliceCheck).
public sealed class Police
{
    public sealed class Blockade
    {
        public S.Vector2 at = S.Vector2.ZERO;  // the crossing
        public S.Vector2 toward = S.Vector2.ZERO;  // along the street, toward the kaiju
        public S.Vector2 across = S.Vector2.ZERO;
        public double t;
        public bool isOut;  // Godot `out`: the officers are out of the cruisers
        public int holding;  // officers still at (or on the way to) their posts
    }

    // An officer's own state, which Police drives; StreetPeople copies its pos and heading after each step.
    public sealed class Officer
    {
        public S.Vector2 pos = S.Vector2.ZERO;
        public S.Vector2 heading = new S.Vector2(0, -1);
        public double phase;
        public int state;  // 0 to post, 1 holding, 2 fleeing
        public S.Vector2 post = S.Vector2.ZERO;
        public S.Vector2 away = S.Vector2.ZERO;
        public double fireIn, timer;
        public Blockade blockade;
    }

    // A muzzle flash (or a ricochet's glint on the kaiju) in Godot axes, and its seconds left.
    public struct Flash
    {
        public S.Vector3 at;
        public double t;
    }

    public readonly S.RampageSim sim;
    // Running totals (tests and the stats line read them).
    public int shots, blockadesMade;
    public readonly List<Blockade> blockades = new List<Blockade>();
    public readonly List<Flash> flashes = new List<Flash>();
    // The flash spots the last TickFlashes left lit (Godot's MultiMesh instances), oldest first.
    public readonly List<S.Vector3> shown = new List<S.Vector3>();
    // The beacons' colour this frame: red, else blue.
    public bool Red { get; private set; }
    public S.RandomNumberGenerator Rng => rng;

    readonly StreetPeople street;
    readonly Traffic traffic;
    readonly S.RandomNumberGenerator rng;
    readonly S.GDict cfg;
    readonly double voxel, interval, arrive, fleeSeconds, barrier, postAt, spotMin, spotMax, ahead, facingWeight;
    readonly double taken, tankKeep, slot, from, fromAcross, angle, outAcross, outBack, postSpread, fleeJitter;
    readonly double flashSeconds, ricochet, ricochetLife, ricochetSpread, sirenHz;
    readonly double[] firstShot, fireSpread, muzzleTip, ricochetHeight;
    readonly int maxBlockades, maxFlashes;
    double clock, nextBlockade;

    public Police(StreetPeople street, Traffic traffic, S.RandomNumberGenerator rng)
    {
        this.street = street;
        this.traffic = traffic;
        this.rng = rng;
        sim = traffic.sim;
        cfg = S.Content.Section("street");
        voxel = F("person_voxel");
        interval = F("blockade_interval");
        maxBlockades = (int)S.Num.I(cfg["max_blockades"]);
        arrive = F("police_arrive_s");
        fleeSeconds = F("cop_flee_s");
        barrier = F("police_barrier");
        postAt = F("police_post");
        spotMin = F("blockade_spot_min");
        spotMax = F("blockade_spot_max");
        ahead = F("blockade_ahead");
        facingWeight = F("blockade_facing_weight");
        taken = F("blockade_taken");
        tankKeep = F("tank_keep") * F("blockade_tank_keep");
        slot = F("cruiser_slot");
        from = F("cruiser_from");
        fromAcross = F("cruiser_from_across");
        angle = F("cruiser_angle");
        outAcross = F("cop_out_across");
        outBack = F("cop_out_back");
        postSpread = F("cop_post_spread");
        firstShot = Pair("cop_first_shot");
        fireSpread = Pair("cop_fire_spread");
        fleeJitter = F("cop_flee_jitter");
        maxFlashes = (int)S.Num.I(cfg["muzzle_max"]);
        flashSeconds = F("muzzle_s");
        muzzleTip = Pair("muzzle_tip");
        ricochet = F("ricochet_chance");
        ricochetLife = F("ricochet_life");
        ricochetSpread = F("ricochet_spread");
        ricochetHeight = Pair("ricochet_height");
        sirenHz = F("siren_hz");
        nextBlockade = interval * 0.5;
    }

    double F(string key) => S.Num.F(cfg[key]);

    double[] Pair(string key)
    {
        S.GArray<S.Variant> a = cfg[key];
        return new[] { S.Num.F(a[0]), S.Num.F(a[1]) };
    }

    // Where a blockade's cruisers park: across the street, toward the kaiju (the beacon stands here too).
    public S.Vector2 Line(Blockade b) => b.at + b.toward * barrier;

    // An officer's step (police.gd update_cop). True when the officer is gone (ran off).
    public bool UpdateCop(Officer p, double dt, S.Vector2 kaiju)
    {
        double run = F("run_speed");
        switch (p.state)
        {
            case 0:
                S.Vector2 to = p.post - p.pos;
                if (to.Length() <= run * dt)
                {
                    p.pos = p.post;
                    p.state = 1;
                }
                else
                {
                    p.heading = to.Normalized();
                    p.pos += p.heading * run * dt;
                }
                break;
            case 1:
                p.heading = (kaiju - p.pos).Normalized();
                p.fireIn -= dt;
                if (p.fireIn <= 0.0)
                {
                    p.fireIn = F("cop_fire_interval") * rng.RandfRange(fireSpread[0], fireSpread[1]);
                    Shoot(p);
                }
                if (p.pos.DistanceTo(kaiju) < F("cop_hold_radius"))
                    Scatter(p);
                break;
            default:
                p.heading = p.away;
                p.pos += p.away * run * dt;
                p.timer += dt;
                return p.timer > fleeSeconds;
        }
        return false;
    }

    // The kaiju is almost on the officer: it leaves its post and runs, away and a little to one side.
    void Scatter(Officer p)
    {
        p.state = 2;
        p.blockade.holding -= 1;
        S.Vector2 jitter = p.blockade.across * rng.RandfRange(-fleeJitter, fleeJitter);
        p.away = (-p.blockade.toward + jitter).Normalized();
        street.fled += 1;
    }

    void Shoot(Officer p)
    {
        shots += 1;
        var h = new S.Vector3(p.heading.x, 0, p.heading.y);
        S.Vector3 tip = new S.Vector3(p.pos.x, 0, p.pos.y) + h * voxel * muzzleTip[0] + S.Vector3.UP * voxel * muzzleTip[1];
        if (flashes.Count < maxFlashes) flashes.Add(new Flash { at = tip, t = flashSeconds });
        // The odd round glints off the kaiju's hide. The chance is drawn even when there is no room for the glint.
        if (rng.Randf() < ricochet && flashes.Count < maxFlashes)
        {
            var hit = new S.Vector3(sim.kaijuPos.x, 0, sim.kaijuPos.y);
            double x = rng.RandfRange(-ricochetSpread, ricochetSpread);
            double y = rng.RandfRange(ricochetHeight[0], ricochetHeight[1]);
            double z = rng.RandfRange(-ricochetSpread, ricochetSpread);
            var spot = new S.Vector3(x, y, z);
            flashes.Add(new Flash { at = hit + spot * sim.BodyScale(), t = flashSeconds * ricochetLife });
        }
    }

    // police.gd update: a new blockade every blockade_interval (the first at half that), the cruisers' arrival,
    // the officers getting out, a blockade ending when no officer holds it, and the flashes' clock.
    public void Update(double dt, S.Vector2 kaiju)
    {
        clock += dt;
        nextBlockade -= dt;
        if (nextBlockade <= 0.0)
        {
            nextBlockade = interval;
            if (blockades.Count < maxBlockades) StartBlockade(kaiju);
        }
        Red = (long)(clock * sirenHz) % 2 == 0;
        foreach (Blockade b in blockades.ToArray())
        {
            b.t += dt;
            if (!b.isOut && b.t >= arrive)
            {
                b.isOut = true;
                CopsOut(b);
            }
            if (b.isOut && b.holding <= 0) blockades.Remove(b);
        }
        TickFlashes(dt);
    }

    // Picks a crossing ahead of the kaiju and sends two cruisers to block the street there.
    void StartBlockade(S.Vector2 kaiju)
    {
        int best = BlockadeCrossing(kaiju);
        if (best < 0) return;
        var b = new Blockade { at = traffic.net.Crossing(best) };
        // Block the street that leads from the crossing most nearly toward the kaiju.
        S.Vector2 v = (kaiju - b.at).Normalized();
        foreach (S.Vector2 d in traffic.net.StreetDirs(best))
            if (b.toward == S.Vector2.ZERO || d.Dot(v) > b.toward.Dot(v)) b.toward = d;
        b.across = new S.Vector2(-b.toward.y, b.toward.x);
        SendCruisers(b, Line(b));
        blockades.Add(b);
        blockadesMade += 1;
    }

    // The crossing ahead of the kaiju, in range, nearest the blockade distance (a facing crossing wins ties), that no
    // tank or blockade holds; -1 when there is none.
    internal int BlockadeCrossing(S.Vector2 kaiju)
    {
        double want = F("blockade_distance");
        int best = -1;
        double bestScore = double.PositiveInfinity;
        foreach (int n in traffic.net.Crossings())
        {
            S.Vector2 at = traffic.net.Crossing(n);
            S.Vector2 d = at - kaiju;
            double dist = d.Length();
            if (dist < spotMin || dist > spotMax) continue;
            double facing = d.Normalized().Dot(sim.facing);
            if (facing < ahead) continue;
            double score = Math.Abs(dist - want) - facing * facingWeight;
            if (score < bestScore && !CrossingTaken(at))
            {
                bestScore = score;
                best = n;
            }
        }
        return best;
    }

    // Whether a tank's road (never across it) or another blockade already holds the crossing at `at`.
    bool CrossingTaken(S.Vector2 at)
    {
        foreach (S.RampageSim.Tank tank in sim.tanks)
            if (tank.pos.DistanceTo(at) < tankKeep) return true;
        foreach (Blockade other in blockades)
            if (other.at.DistanceTo(at) < taken) return true;
        return false;
    }

    // Two cruisers nose to nose across the road at `line`, each driving in from behind the crossing.
    void SendCruisers(Blockade b, S.Vector2 line)
    {
        foreach (double s in SIDES)
        {
            S.Vector2 to = line + b.across * s * slot;
            S.Vector2 start = b.at - b.toward * from + b.across * s * fromAcross;
            double turn = rng.RandfRange(-angle, angle);
            traffic.AddPolice(start, to, (-b.across * s).Rotated(turn));
        }
    }

    static readonly double[] SIDES = { -1.0, 1.0 };

    void CopsOut(Blockade b)
    {
        long n = S.Num.I(cfg["cops_per_blockade"]);
        S.Vector2 line = Line(b);
        for (long k = 0; k < n; k++)
        {
            double s = ((double)k / Math.Max(1.0, n - 1.0)) * 2.0 - 1.0;  // -1..1 across the road
            var p = new Officer { blockade = b };
            p.phase = rng.Randf();
            p.pos = line + b.across * s * outAcross - b.toward * outBack;
            p.post = b.at + b.toward * postAt + b.across * s * postSpread;
            p.fireIn = rng.RandfRange(firstShot[0], firstShot[1]);
            street.AddCop(p);
            b.holding += 1;
        }
    }

    // The timing half of police.gd _draw_flashes: each flash ages, the spent ones go, the rest are shown.
    void TickFlashes(double dt)
    {
        shown.Clear();
        for (int i = 0; i < flashes.Count; i++)
        {
            Flash f = flashes[i];
            f.t -= dt;
            if (f.t <= 0.0)
            {
                flashes.RemoveAt(i);
                i--;
                continue;
            }
            flashes[i] = f;
            shown.Add(f.at);
        }
    }
}
