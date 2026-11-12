using System;
using System.Collections.Generic;
using S = Kaiju.Sim;

// The stadium's crowd (scenes/stadium_crowd.gd and crowd_cells.gd, D-078): a fan on nearly every seat of the baked
// model, in the two teams' colours and street clothes. When the match panics every fan is on their feet at once
// and each after its own moment runs straight out up the stands to the back and steps down out of sight through
// the exits. They die like any civilian, and never vanish: under a blow where they are running (Crush), or with
// the stand under them; a fan whose stand has gone falls to what still stands below, lies there a few seconds and
// is gone under the dust. Once the stadium carves on cells (D-388) a fan stands on the fine cell under its feet,
// not on its chunk. Where each fan is drawn is CrowdPose's; this says who is where, who falls and who is in view.
// No UnityEngine here: unity/SimTests compiles this file (StadiumCheck). Presentation only (a fan's death feeds
// no biomass); tuning in data/tuning.json "crowd".
public sealed class StadiumCrowd
{
    public enum State { SEATED, UP, DYING, GONE }

    // Each fan's own beat, from its slot: the share of the flee delay (crowd.gdshader's hash).
    const double GOLDEN = 0.6180339887;
    // A body takes this long to go over once it lands.
    public const double TOPPLE = 0.25;
    // Graves are kept in buckets of this many seconds, counted once their time has passed.
    const double BUCKET = 0.25;
    // Metres under a fan's feet a cell of the stand must be within for the fan to be standing on it.
    const double FOOT = 1.0;
    const double PUFF_UP = 0.15;

    public sealed class Fan
    {
        public S.Vector3 pos;
        public int outfit, slot;
        public State state = State.SEATED;
        public double leaves;  // seconds after the panic it starts running
        public double run;  // metres from its seat to the back of the stands
        public double outAt;  // seconds after the panic it is through an exit
        public double goneAt;  // crowd time its body is out of sight, once it falls
        public long under = -1;  // the fine cell its seat stands on, once the stadium carves (else -1)
        // Its fall, set once when it dies: the crowd time it began, the flee time then (-1 before the panic), the
        // height it lands at, how long it lies there.
        public double fellAt, frozen = -1.0, land, stay;

        // Killed, or falling, or lying among the debris, or gone.
        public bool IsDead() => state == State.DYING || state == State.GONE;
        public double Beat() => slot * GOLDEN % 1.0;
    }

    public readonly List<Fan> fans;
    public readonly List<CrowdBuild.Outfit> outfits;
    public bool fleeing;
    // For the dust puff where fans die (StadiumMatch sets it); null in fixtures that draw none.
    public Action<S.Vector3> puff;
    // Running totals (the fixture and the stats line read them).
    public int fallen, escaped, killed;
    public readonly S.GDict cfg;
    public readonly S.Vector2 centre, half;
    public readonly double gravity, shrink;
    public double since = -1.0, clock;

    readonly S.RampageSim sim;
    readonly int index;
    readonly S.RandomNumberGenerator rng;
    readonly S.Vector2 corner;
    readonly double reach, lingerMin, lingerMax;
    // The stadium's chunks as built: a chunk standing then and gone now has fallen.
    readonly S.PackedFloat32Array built;
    // Chunk index -> the fans seated in it, until it goes (in the order Godot's dictionary keeps).
    readonly Dictionary<long, List<Fan>> hosts = new Dictionary<long, List<Fan>>();
    readonly List<long> hostOrder = new List<long>();
    // Fans on the run, checked a slice a frame against the chunks (see Sweep).
    readonly List<Fan> runners = new List<Fan>();
    List<Fan> byLeave = new List<Fan>(), queue = new List<Fan>();
    // Bodies by the bucket of the time they are out of sight.
    readonly Dictionary<long, List<Fan>> graves = new Dictionary<long, List<Fan>>();
    readonly long whole;
    int left, dying, started, sweepAt, puffs, next;
    long alive = -1, graveNext, fineAlive = -1;
    // The stadium's fine grid once it carves (Carving), else null; the seated fans by the chunk that owns the cell
    // under them, and each chunk's cells left when last looked.
    S.Carving.Grid cells;
    readonly Dictionary<long, List<Fan>> onCells = new Dictionary<long, List<Fan>>();
    readonly List<long> cellOrder = new List<long>();
    S.PackedInt32Array live;

    // index: the stadium's building. kits: the match's two kits. rng: the run's presentation stream.
    public StadiumCrowd(S.RampageSim sim, int index, S.GArray<S.Variant> kits, S.RandomNumberGenerator rng, int max)
    {
        this.sim = sim;
        this.index = index;
        this.rng = rng;
        cfg = S.Content.Section("crowd");
        gravity = S.Num.F(sim.city["fall_gravity"]);
        S.GArray<S.Variant> linger = cfg["linger"];
        lingerMin = S.Num.F(linger[0]);
        lingerMax = S.Num.F(linger[1]);
        shrink = S.Num.F(cfg["shrink"]);
        S.RampageSim.Building b = sim.buildings[index];
        centre = new S.Vector2(b.x, b.z);
        half = new S.Vector2(b.w, b.d) * 0.5;
        corner = centre - half;
        reach = half.Length();
        outfits = CrowdBuild.Outfits(kits, cfg["neutral"]);
        fans = CrowdBuild.Sit(b, kits.Size(), cfg, rng, max);
        Host(b.frame);
        built = b.frame.Standing().Duplicate();
        whole = b.frame.aliveCount;
        left = fans.Count;
        var per = new int[outfits.Count];
        foreach (Fan fan in fans) fan.slot = per[fan.outfit]++;
    }

    // The fans seated in each chunk of `frame`, by chunk index, until it goes.
    void Host(S.Structure frame)
    {
        foreach (Fan fan in fans)
        {
            S.Vector3i c = CrowdBuild.Chunk(fan.pos, corner);
            if (!frame.Inside(c)) continue;
            Seat(hosts, hostOrder, frame.Index(c), fan);
        }
    }

    static void Seat(Dictionary<long, List<Fan>> by, List<long> order, long key, Fan fan)
    {
        if (!by.TryGetValue(key, out List<Fan> seated))
        {
            by[key] = seated = new List<Fan>();
            order.Add(key);
        }
        seated.Add(fan);
    }

    // Fans still in view: seated, standing, on their way out, falling or lying among the debris.
    public int InStands() => left;

    // Fans on their feet: everyone not yet dead once the match panics.
    public int Running() => fleeing ? left - dying : 0;

    // Fans falling or lying in the wreck of a stand or under a blow, not yet out of sight.
    public int Dying() => dying;

    // The wall gave: every fan stands at once and runs for the exits at the back on its own beat.
    public void Panic()
    {
        fleeing = true;
        since = 0.0;
        List<Fan> risen = CrowdBuild.Rise(fans, cfg, centre, half);
        byLeave = Sorted(risen, fan => fan.leaves);
        queue = Sorted(risen, fan => fan.outAt);
    }

    // By `key`, in the order Godot's own sort leaves fans of the same key (its sort is not stable, and the order
    // decides which frame each runner is checked).
    static List<Fan> Sorted(List<Fan> fans, Func<Fan, double> key)
    {
        Fan[] sorted = fans.ToArray();
        S.GodotSort.Sort(sorted, sorted.Length, (a, b) => key(a) < key(b));
        return new List<Fan>(sorted);
    }

    // Where a fan's feet are now: its seat, or as far along its run as it is drawn.
    public S.Vector3 RunningAt(Fan fan)
    {
        if (fan.state != State.UP) return fan.pos;
        double moved = S.Num.F(cfg["flee_speed"]) * Math.Max(0.0, since - fan.leaves);
        double along = Math.Min(moved, fan.run);
        double down = Math.Max(0.0, moved - fan.run);
        S.Vector2 dir = (new S.Vector2(fan.pos.x, fan.pos.z) - centre).Normalized();
        double slope = S.Num.F(cfg["flee_slope"]);
        return fan.pos + new S.Vector3(dir.x * along, along * slope - down, dir.y * along);
    }

    // Every fan within `radius` of `at` (in plan), where it is now, is crushed. Returns how many.
    public int Crush(S.Vector3 at, double radius)
    {
        var c = new S.Vector2(at.x, at.z);
        if (c.DistanceTo(centre) > reach + radius) return 0;
        int dead = 0;
        puffs = 0;
        foreach (Fan fan in fans)
        {
            if (fan.IsDead()) continue;
            S.Vector3 p = RunningAt(fan);
            if (new S.Vector2(p.x, p.z).DistanceTo(c) > radius) continue;
            Die(fan, p, p.y);
            dead++;
        }
        killed += dead;
        return dead;
    }

    public void Step(double delta)
    {
        clock += delta;
        S.Structure frame = sim.buildings[index].frame;
        LoseCells();
        if (frame.aliveCount != alive)
        {
            alive = frame.aliveCount;
            puffs = 0;
            LoseSeats(frame);
        }
        if (fleeing)
        {
            since += delta;
            Leave();
            for (; next < queue.Count && queue[next].outAt <= since; next++)
            {
                Fan fan = queue[next];
                if (fan.state != State.UP) continue;
                fan.state = State.GONE;
                left--;
                escaped++;
            }
            if (alive < whole || cells != null) Sweep(frame);
        }
        Bury();
    }

    // Whether a fan still stands where it sat: seated, or up and its moment to run not yet come.
    bool OnSeat(Fan fan) => fan.state == State.SEATED || (fan.state == State.UP && since <= fan.leaves);

    // Chunks went: every fan still on its seat over a chunk that has gone falls with it, the frame it went (the
    // seats are indexed by chunk, so nobody is left standing on nothing).
    void LoseSeats(S.Structure frame)
    {
        S.PackedFloat32Array hp = frame.Standing();
        foreach (long at in new List<long>(hostOrder))
        {
            if (built[at] <= 0.0 || hp[at] > 0.0) continue;
            foreach (Fan fan in hosts[at])
                if (OnSeat(fan)) Down(frame, hp, fan, fan.pos);
            hosts.Remove(at);
            hostOrder.Remove(at);
        }
    }

    // The stadium carves: on its first look each seated fan is put on the fine cell under its seat; after that,
    // whenever the grid loses cells, every seated fan in a chunk that lost some whose cell has gone falls (the
    // frame it went, as with chunks).
    void LoseCells()
    {
        if (cells == null)
        {
            if (!sim.carving.Promoted(index)) return;
            cells = sim.carving.grids[index];
            SeatOnCells();
        }
        S.VoxelFrame f = cells.frame;
        if (f.aliveCount == fineAlive) return;
        fineAlive = f.aliveCount;
        puffs = 0;
        foreach (long ch in new List<long>(cellOrder))
        {
            if (cells.live[ch] == live[ch]) continue;
            live[ch] = cells.live[ch];
            var stay = new List<Fan>();
            foreach (Fan fan in onCells[ch])
            {
                if (!OnSeat(fan)) continue;
                if (f.cells[fan.under] == S.VoxelFrame.EMPTY) FallToCells(fan, fan.pos);
                else stay.Add(fan);
            }
            onCells[ch] = stay;
            if (stay.Count > 0) continue;
            onCells.Remove(ch);
            cellOrder.Remove(ch);
        }
    }

    void SeatOnCells()
    {
        live = cells.live.Duplicate();
        foreach (Fan fan in fans)
        {
            if (fan.IsDead()) continue;
            fan.under = CrowdBuild.Under(cells.frame, fan.pos, corner, FOOT);
            if (fan.under >= 0) Seat(onCells, cellOrder, cells.Chunk(fan.under), fan);
        }
    }

    // A fan whose cell has gone from under it at `at` falls to the cells still below, or the ground.
    void FallToCells(Fan fan, S.Vector3 at)
    {
        S.VoxelFrame f = cells.frame;
        long below = CrowdBuild.Under(f, at, corner, at.y + 1.0);
        double land = below >= 0 ? (double)(below / (f.w * f.d) + 1 + f.offset.y) / f.res : 0.0;
        Die(fan, at, Math.Min(land, at.y));
        fallen++;
    }

    // Fans whose moment has come take to the stands: from now they are checked against the chunks.
    void Leave()
    {
        for (; started < byLeave.Count && byLeave[started].leaves <= since; started++) runners.Add(byLeave[started]);
    }

    // Fans running up the stands, a slice of them a frame (every one is checked within "check_slices" frames):
    // one that is over a chunk that has gone falls. Only while the stadium has lost a chunk at all.
    void Sweep(S.Structure frame)
    {
        S.PackedFloat32Array hp = frame.Standing();
        long n = S.Gd.Ceili((double)runners.Count / S.Num.I(cfg["check_slices"]));
        int i = sweepAt;
        for (; n > 0 && runners.Count > 0; n--)
        {
            if (i >= runners.Count) i = 0;
            Fan fan = runners[i];
            if (fan.state != State.UP)
            {
                runners[i] = runners[runners.Count - 1];
                runners.RemoveAt(runners.Count - 1);
                continue;
            }
            i++;
            Check(frame, hp, fan);
        }
        sweepAt = i;
    }

    // One runner against what stands under it now.
    void Check(S.Structure frame, S.PackedFloat32Array hp, Fan fan)
    {
        S.Vector3 p = RunningAt(fan);
        if (new S.Vector2(p.x - fan.pos.x, p.z - fan.pos.z).Length() >= fan.run) return;  // stepping down the exit
        if (cells != null && fan.under >= 0 && CrowdBuild.Under(cells.frame, p, corner, FOOT) < 0)
        {
            FallToCells(fan, p);
            return;
        }
        S.Vector3i c = CrowdBuild.Chunk(p, corner);
        if (!frame.Inside(c)) return;
        long at = frame.Index(c);
        if (built[at] > 0.0 && hp[at] <= 0.0) Down(frame, hp, fan, p);
    }

    // A fan's stand has gone from under it at `at`: it falls to what stands below, or the ground.
    void Down(S.Structure frame, S.PackedFloat32Array hp, Fan fan, S.Vector3 at)
    {
        long land = CrowdBuild.Land(frame, hp, CrowdBuild.Chunk(at, corner));
        Die(fan, at, Math.Min((double)land, at.y));
        fallen++;
    }

    // Dead where it stood, or falling to `land`: a body that goes over and lies there a few seconds, and a puff of
    // dust (a few per blow or fall, not one per fan).
    void Die(Fan fan, S.Vector3 at, double land)
    {
        if (puff != null && puffs < S.Num.I(cfg["max_puffs"]))
        {
            puffs++;
            puff(at + new S.Vector3(0, PUFF_UP, 0));
        }
        if (fan.state == State.UP && new S.Vector2(at.x - fan.pos.x, at.z - fan.pos.z).Length() >= fan.run)
        {
            Gone(fan);  // already stepping down the exit, out of sight
            return;
        }
        double air = Math.Max(0.0, at.y - land);
        double lie = Math.Sqrt(2.0 * air / gravity) + TOPPLE;
        fan.stay = rng.RandfRange(lingerMin, lingerMax);
        fan.state = State.DYING;
        fan.goneAt = clock + lie + fan.stay + shrink;
        fan.fellAt = clock;
        fan.frozen = fleeing ? since : -1.0;
        fan.land = land;
        dying++;
        long key = S.Gd.Floori(fan.goneAt / BUCKET);
        if (!graves.TryGetValue(key, out List<Fan> bodies)) graves[key] = bodies = new List<Fan>();
        bodies.Add(fan);
    }

    // Bodies whose time has passed are out of sight: hidden and no longer counted.
    void Bury()
    {
        long now = S.Gd.Floori(clock / BUCKET);
        for (; graveNext < now; graveNext++)
        {
            if (!graves.TryGetValue(graveNext, out List<Fan> bodies)) continue;
            foreach (Fan fan in bodies) Gone(fan);
            graves.Remove(graveNext);
        }
    }

    void Gone(Fan fan)
    {
        if (fan.state == State.DYING) dying--;
        fan.state = State.GONE;
        left--;
    }
}
