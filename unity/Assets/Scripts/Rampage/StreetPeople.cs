using System;
using System.Collections.Generic;
using S = Kaiju.Sim;

// The people in the streets and on the sand (scenes/street_life.gd, street_steps.gd, street_brace.gd and
// beach_crowd.gd): civilians walk the pavement round every block and cross at the corners; when the kaiju comes near
// they stare a moment, then run from it. Stomps, falling sections and tank tracks crush them. Presentation only: the
// sim never knows any of them exist. No UnityEngine here: unity/SimTests compiles this file (StreetCheck).
// Not ported yet: police, traffic, the stadium match, and the far people's slower step (StreetLod).
public sealed class StreetPeople
{
    // scenes/street_life.gd SIDE_STEP, PACE_SPREAD, WALK_HZ, RUN_HZ, MAX_PUFFS_PER_CRUSH.
    const double SIDE_STEP = 0.2, PACE_SPREAD = 0.2, WALK_HZ = 3.0, RUN_HZ = 6.0;
    const int MAX_PUFFS_PER_CRUSH = 1;
    // scenes/voxel_person.gd COP (the civilian outfits come before it) and Pose.
    public const int OUTFITS = 6, POSES = 4, WALK_A = 0, RUN_A = 2;
    // scenes/beach_crowd.gd HELD: pinned until the beach is released.
    const double HELD = 1.0e9;
    // scenes/city_falls.gd DROP_REACH: a dropped section crushes people this far out from its walls.
    const double DROP_REACH = 0.8;

    public struct Person
    {
        public S.Vector2 pos, heading;
        public int outfit, from, to;
        public double phase, side, pace, pinnedUntil;
        public bool fleeing, hasFled;
    }

    public readonly List<Person> people = new List<Person>();
    public readonly Pavements pavements;
    // Running totals: fled counts each person once; killed is the kaiju's and the tanks' (runOver of them); the
    // army's own stray shells are counted apart (scenes/army_toll.gd).
    public int fled, killed, runOver, armyKilled, beachPeople;
    // Called where a crushed person's dust puff goes (Godot axes, x and z).
    public Action<S.Vector2> Puffed;

    readonly S.GDict cfg;
    readonly S.GDict city;
    readonly S.RandomNumberGenerator rng;
    readonly S.RandomNumberGenerator beachRng = S.Seeds.Make("beach_crowd", 0);
    readonly double panicRadius, panicPerScale, calmRadius, waryRadius, gawk, run, walk, fallSpill;
    double clock;
    bool beachHeld = true;

    public double Clock => clock;
    public double FallSpill => fallSpill;
    public double StompCatch => S.Num.F(cfg["stomp_catch"]);

    // perLot: civilians per lot building (display graphics "civilians" in Godot).
    public StreetPeople(S.RampageSim sim, S.RandomNumberGenerator rng, int perLot)
    {
        this.rng = rng;
        cfg = S.Content.Section("street");
        city = sim.city;
        panicRadius = S.Num.F(cfg["panic_radius"]);
        panicPerScale = S.Num.F(cfg["panic_per_scale"]);
        calmRadius = S.Num.F(cfg["calm_radius"]);
        waryRadius = S.Num.F(cfg["wary_radius"]);
        gawk = S.Num.F(cfg["panic_gawk"]);
        run = S.Num.F(cfg["run_speed"]);
        walk = S.Num.F(cfg["walk_speed"]);
        fallSpill = S.Num.F(cfg["fall_spill"]);
        pavements = new Pavements(sim);
        pavements.rng = rng;
        int blocks = pavements.nodes.Count >> 2;
        if (blocks == 0) return;
        long total = perLot * sim.LotBuildings().Size();
        for (long n = 0; n < total; n++) SpawnCivilian((int)(n % blocks));
        int streetPeople = people.Count;
        Gather(S.CityGen.Map(city), sim.arenaHalf + S.Num.F(city["view_beyond"]));
        beachPeople = people.Count - streetPeople;
    }

    // Civilians per lot building at Godot's medium graphics preset (Unity has no presets).
    public static int PerLot()
    {
        S.GDict display = S.Content.Section("display");
        S.GDict graphics = display["graphics"];
        S.GDict medium = graphics["medium"];
        return (int)S.Num.I(medium["civilians"]);
    }

    // One more person at the end of the list, standing at the origin; returns its index.
    public int AddPerson()
    {
        people.Add(new Person { pos = S.Vector2.ZERO, heading = new S.Vector2(0, -1), pace = 1.0, pinnedUntil = -1.0 });
        return people.Count - 1;
    }

    public List<S.Vector2> RingNodes() => pavements.RingNodes();

    public int Civilians() => people.Count;

    // People the kaiju itself crushed (stomps, falls, tail): not the tanks' run-overs.
    public int KaijuKilled() => killed - runOver;

    // How many are running from the kaiju now.
    public int Panicking()
    {
        int n = 0;
        foreach (Person p in people)
            if (p.fleeing) n++;
        return n;
    }

    // How many beach people still wait for the kaiju to surface.
    public int Held()
    {
        int n = 0;
        foreach (Person p in people)
            if (p.pinnedUntil >= HELD) n++;
        return n;
    }

    void SpawnCivilian(int lot)
    {
        List<S.Vector2> nodes = pavements.nodes;
        int i = AddPerson();
        Person p = people[i];
        p.from = pavements.LineStart(lot, (int)rng.RandiRange(0, 3));
        p.to = (p.from & ~3) + ((p.from + 1) & 3);
        p.pos = nodes[p.from] + (nodes[p.to] - nodes[p.from]) * rng.Randf();
        p.heading = (nodes[p.to] - nodes[p.from]).Normalized();
        p.outfit = (int)rng.RandiRange(0, OUTFITS - 1);
        p.phase = rng.Randf();
        p.side = rng.RandfRange(-SIDE_STEP, SIDE_STEP);
        p.pace = rng.RandfRange(1.0 - PACE_SPREAD, 1.0 + PACE_SPREAD);
        people[i] = p;
    }

    // ---------- The beach (scenes/beach_crowd.gd) ----------

    // Some by each umbrella, seaward of it facing the sea, and four on each court, two a side facing the net.
    void Gather(S.GDict plan, double view)
    {
        if (!plan.Has("harbour")) return;
        List<S.Vector2> nodes = RingNodes();
        if (nodes.Count == 0) return;
        S.GDict b = plan["harbour"];
        S.GDict h = b["h"];
        S.GDict props = h["props"];
        S.GDict crowd = props["crowd"];
        double share = S.Num.F(crowd["per_umbrella"]);
        S.GArray<S.Variant> stand = crowd["stand"];
        double near = S.Num.F(stand[0]), far = S.Num.F(stand[1]);
        double spread = S.Num.F(crowd["spread"]);
        foreach (S.Vector2 at in BeachLayout.Spots(plan, view))
        {
            if (beachRng.Randf() < share)
            {
                double along = beachRng.RandfRange(-spread, spread);
                double sea = beachRng.RandfRange(near, far);
                Place(nodes, at + new S.Vector2(along, -sea), new S.Vector2(0, -1));
            }
        }
        S.GArray<S.Variant> court = props["court"];
        var quarter = new S.Vector2(S.Num.F(court[0]) * 0.25, S.Num.F(court[1]) * 0.25);
        foreach (S.Vector2 at in BeachLayout.Courts(plan))
        {
            if (Math.Abs(at.x) > view) continue;
            for (int cx = -1; cx <= 1; cx += 2)
                for (int cz = -1; cz <= 1; cz += 2)
                    Place(nodes, at + new S.Vector2(cx, cz) * quarter, new S.Vector2(-cx, 0));
        }
    }

    // As Godot does: the nearest ring corner's index in the ring list is used as the node it walks to.
    void Place(List<S.Vector2> nodes, S.Vector2 at, S.Vector2 facing)
    {
        int near = 0;
        for (int n = 0; n < nodes.Count; n++)
            if (nodes[n].DistanceSquaredTo(at) < nodes[near].DistanceSquaredTo(at)) near = n;
        int i = AddPerson();
        Person p = people[i];
        p.pos = at;
        p.heading = facing;
        p.from = (near & ~3) + ((near + 3) & 3);
        p.to = near;
        p.outfit = (int)beachRng.RandiRange(0, OUTFITS - 1);
        p.phase = beachRng.Randf();
        p.pace = beachRng.RandfRange(1.0 - PACE_SPREAD, 1.0 + PACE_SPREAD);
        p.pinnedUntil = HELD;
        people[i] = p;
    }

    // Every beach person still held walks free, each at most crowd "release" seconds from now.
    void Release()
    {
        S.GDict h = city["harbour"];
        S.GDict props = h["props"];
        S.GDict crowd = props["crowd"];
        double after = S.Num.F(crowd["release"]);
        for (int i = 0; i < people.Count; i++)
        {
            Person p = people[i];
            if (p.pinnedUntil < HELD) continue;
            p.pinnedUntil = clock + beachRng.RandfRange(0.0, after);
            people[i] = p;
        }
    }

    // ---------- The walk (scenes/street_steps.gd) ----------

    // Everyone's step this frame, last first. risen: the kaiju's head is out of the water (or it never rose from
    // the sea), which frees the beach.
    public void Step(double dt, S.Vector2 kaiju, double bodyScale, bool risen)
    {
        clock += dt;
        if (beachHeld && risen)
        {
            beachHeld = false;
            if (beachPeople > 0) Release();
        }
        double panic = Math.Min(panicRadius, panicPerScale * bodyScale);
        double calm = panic * calmRadius / panicRadius;
        pavements.wary = panic * waryRadius / panicRadius;
        List<S.Vector2> nodes = pavements.nodes;
        for (int i = people.Count - 1; i >= 0; i--)
        {
            Person p = people[i];
            if (p.pinnedUntil > clock) continue;
            S.Vector2 at = p.pos;
            if (UpdateFlee(ref p, at, kaiju, panic, calm))
            {
                people[i] = p;  // startled: this frame it stands facing the kaiju
                continue;
            }
            S.Vector2 to = nodes[p.to] - at;
            double step = (p.fleeing ? run : walk) * p.pace * dt;
            if (to.Length() > step)
            {
                S.Vector2 dir = to.Normalized();
                p.heading = dir;
                p.pos = at + dir * step;
                people[i] = p;
                continue;
            }
            p.pos = nodes[p.to];
            int next = pavements.NextCorner(p.to, p.from, kaiju, p.fleeing);
            p.from = p.to;
            p.to = next;
            people[i] = p;
        }
    }

    // Startle inside the panic radius, calm past the calm radius, and a runner whose corner lies toward the kaiju
    // turns back (D-450). True when the person was startled this frame.
    bool UpdateFlee(ref Person p, S.Vector2 at, S.Vector2 kaiju, double panic, double calm)
    {
        double d = at.DistanceTo(kaiju);
        if (!p.fleeing)
        {
            if (d < panic)
            {
                p.fleeing = true;
                if (!p.hasFled)
                {
                    p.hasFled = true;
                    fled++;
                }
                p.pinnedUntil = clock + gawk;
                p.heading = (kaiju - at).Normalized();
                if ((pavements.nodes[p.to] - at).Dot(kaiju - at) > 0.0) Reverse(ref p);
                return true;
            }
        }
        else if (d > calm) p.fleeing = false;
        else if ((pavements.nodes[p.to] - at).Dot(kaiju - at) > 0.0) Reverse(ref p);
        return false;
    }

    static void Reverse(ref Person p)
    {
        int swap = p.from;
        p.from = p.to;
        p.to = swap;
    }

    // A person's pose: standing (gawking, frozen or held), running arms up, else a stride (street_life.gd pose).
    public int Pose(int i)
    {
        Person p = people[i];
        if (p.pinnedUntil > clock) return WALK_A;
        if (p.fleeing) return RUN_A + (int)(clock * RUN_HZ + p.phase * 2.0) % 2;
        return WALK_A + (int)(clock * WALK_HZ + p.phase * 2.0) % 2;
    }

    // ---------- Crushing ----------

    // Everyone within `radius` of (x, z) is crushed. byTank: a tank rolled over them; byArmy: a stray shell.
    public int Crush(double x, double z, double radius, bool byTank = false, bool byArmy = false)
    {
        one.Clear();
        one.Add(new S.Vector3(x, z, radius));
        return CrushAll(one, byTank, byArmy);
    }

    readonly List<S.Vector3> one = new List<S.Vector3>();

    // Everyone within any of `spots` (x, z, radius) is crushed in one pass over the people; one puff per spot.
    // Returns how many died.
    public int CrushAll(List<S.Vector3> spots, bool byTank = false, bool byArmy = false)
    {
        if (spots.Count == 0) return 0;
        double loX = double.PositiveInfinity, loY = double.PositiveInfinity, hiX = double.NegativeInfinity, hiY = double.NegativeInfinity;
        foreach (S.Vector3 s in spots)
        {
            loX = Math.Min(loX, s.x - s.z);
            loY = Math.Min(loY, s.y - s.z);
            hiX = Math.Max(hiX, s.x + s.z);
            hiY = Math.Max(hiY, s.y + s.z);
        }
        var puffs = new int[spots.Count];
        int dead = 0;
        for (int i = people.Count - 1; i >= 0; i--)
        {
            S.Vector2 at = people[i].pos;
            if (at.x < loX || at.y < loY || at.x > hiX || at.y > hiY) continue;
            for (int k = 0; k < spots.Count; k++)
            {
                S.Vector3 s = spots[k];
                if (at.DistanceTo(new S.Vector2(s.x, s.y)) > s.z) continue;
                if (puffs[k] < MAX_PUFFS_PER_CRUSH)
                {
                    puffs[k]++;
                    if (Puffed != null) Puffed(at);
                }
                Remove(i);
                dead++;
                if (byArmy) armyKilled++;
                else
                {
                    killed++;
                    if (byTank) runOver++;
                }
                break;
            }
        }
        return dead;
    }

    // Person i leaves the street: the last one moves in.
    void Remove(int i)
    {
        int last = people.Count - 1;
        people[i] = people[last];
        people.RemoveAt(last);
    }

    // A falling section will land along from..to (a point for a drop) within `radius` in `seconds`: the people
    // under it freeze there, so its landing crushes them (street_life.gd brace).
    public int Brace(S.Vector2 from, S.Vector2 to, double radius, double seconds)
    {
        int pinned = 0;
        for (int i = 0; i < people.Count; i++)
        {
            Person p = people[i];
            S.Vector2 q = S.Geometry2D.GetClosestPointToSegment(p.pos, from, to);
            if (p.pos.DistanceTo(q) > radius) continue;
            p.pinnedUntil = clock + seconds + 0.5;
            people[i] = p;
            pinned++;
        }
        return pinned;
    }

    // A fall_start event: the people under the section freeze (scenes/street_brace.gd fall).
    public void FallStart(S.RampageSim sim, S.GDict e)
    {
        S.RampageSim.Building b = sim.buildings[S.Num.I(e["building"])];
        if (e["cells"].IsEmpty()) return;  // a carved scrap smashes nothing
        double seconds = S.Num.F(e["duration"]);
        if (S.Gd.Str(e["kind"]) == "topple" && e.Has("to"))
        {
            S.Vector3 pivot = e["pivot"];
            S.Vector2 to = e["to"];
            Brace(new S.Vector2(pivot.x, pivot.z), to, S.Num.F(e["width"]) * 0.6 + fallSpill, seconds);
        }
        else if (b.landmark == "")
        {
            var at = new S.Vector2(b.x, b.z);
            Brace(at, at, Math.Max(b.w, b.d) * 0.5 + DROP_REACH + fallSpill, seconds);
        }
    }

    // A fall_land event's crush spots (x, z, radius), as scenes/city_falls.gd lands a section on the street: a
    // section that broke up on the way (contact) crushes only where it started and ended; a topple its whole strip,
    // a spot every 1.5 m; a drop a disc round its building. A landmark's section crushes nobody; a scrap nothing.
    public List<S.Vector3> FallLandSpots(S.RampageSim sim, S.GDict e)
    {
        var o = new List<S.Vector3>();
        if (e.Has("scrap") && (bool)e["scrap"]) return o;
        S.RampageSim.Building b = sim.buildings[S.Num.I(e["building"])];
        bool topple = S.Gd.Str(e["kind"]) == "topple" && e.Has("from") && e.Has("to");
        if (e.Has("contact"))
        {
            if (!topple) return o;
            S.Vector2 a = e["from"], c = e["to"];
            double r = S.Num.F(e["width"]) * 0.6;
            o.Add(new S.Vector3(a.x, a.y, r));
            o.Add(new S.Vector3(c.x, c.y, r));
            return o;
        }
        if (b.landmark != "") return o;
        if (topple)
        {
            S.Vector2 from = e["from"], to = e["to"];
            double r = S.Num.F(e["width"]) * 0.6 + fallSpill;
            int steps = Math.Max(1, (int)Math.Ceiling(from.DistanceTo(to) / FALL_STEP));
            for (int k = 0; k <= steps; k++)
            {
                S.Vector2 at = from + (to - from) * ((double)k / steps);
                o.Add(new S.Vector3(at.x, at.y, r));
            }
            return o;
        }
        o.Add(new S.Vector3(b.x, b.z, Math.Max(b.w, b.d) * 0.5 + DROP_REACH + fallSpill));
        return o;
    }

    // scenes/city_falls.gd: a toppled strip is crushed a spot every 1.5 m.
    const double FALL_STEP = 1.5;
}
