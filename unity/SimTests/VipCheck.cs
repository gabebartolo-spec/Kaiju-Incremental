// The leader's helicopter as VipView reads it (Assets/Scripts/Rampage/VipView.cs): the paint rule of
// scenes/helicopter_model.gd _paint (VipPaint), and the order and fields of the sim's vip events over whole
// seeded rampages with an idle kaiju. A fixed 1/60 delta, no clock.
using System;
using Kaiju.Sim;

static class VipCheck
{
    const double FRAME = 1.0 / 60.0;
    // Seconds stepped past the run's own length, for the rise from the bay, which holds the run's clock.
    const double SPARE_SECONDS = 120.0;
    const double KILL_AFTER = 2.0;
    const double EPS = 1e-6;
    static readonly long[] SEEDS = { 1, 2, 3 };

    static int failed;

    public static int Run(string repoRoot)
    {
        FileAccess.Root = repoRoot;
        failed = 0;
        Paint();
        int spawned = 0;
        for (int i = 0; i < SEEDS.Length; i++)
            if (Flight(SEEDS[i], i == SEEDS.Length - 1)) spawned++;
        Check(spawned > 0, "no seed lifted the leader off, so the flight checks proved nothing");
        Console.WriteLine($"vip: {failed} failed");
        return failed;
    }

    static void Check(bool ok, string what)
    {
        if (ok) return;
        failed++;
        Console.WriteLine("FAIL vip: " + what);
    }

    // Eleven voxels in a column, y 0..10: mid grey but one near-black (glass) and one bright.
    static void Paint()
    {
        const int WHITE = 0xf2efe6, GOLD = 0xd8a53a, GREY = 0x808080, GLASS = 0x101010, BRIGHT = 0xffffff;
        var xyz = new int[33];
        var rgb = new int[11];
        for (int i = 0; i < 11; i++)
        {
            xyz[i * 3 + 1] = i;
            rgb[i] = GREY;
        }
        rgb[0] = GLASS;
        rgb[10] = BRIGHT;
        float mean = 0f;
        for (int i = 0; i < 11; i++) mean += VipPaint.Luminance(rgb[i]) / 11f;
        float grey = Math.Clamp(VipPaint.Luminance(GREY) / mean, 0.8f, 1.15f);
        // band 0.25..0.5 of the height: y 2.5..5, so 3 and 5 (its own top edge) are in, 2 and 6 out
        bool[] glow = VipPaint.Paint(xyz, rgb, WHITE, GOLD, 0.25f, 0.25f, 0.5f);
        Check(rgb[0] == GLASS && !glow[0], "dark glass was painted or glows");
        Check(rgb[3] == Shade(GOLD, grey) && rgb[5] == Shade(GOLD, grey), "the band (y 3 and its top edge 5 of 0..10) is not gold");
        Check(rgb[2] == Shade(WHITE, grey) && rgb[6] == Shade(WHITE, grey), "the voxels beside the band are not white");
        Check(rgb[10] == Shade(WHITE, 1.15f), "a bright voxel's shade is not held to 1.15");
        for (int i = 1; i < 11; i++) Check(glow[i], $"painted voxel {i} does not glow");
        // A rotor: all gold, nothing spared.
        var blade = new int[] { GLASS, GREY };
        bool[] lit = VipPaint.Paint(new int[6], blade, GOLD, GOLD, 0f, 0.3f, 0.4f);
        Check(lit[0] && lit[1] && blade[0] == Shade(GOLD, 0.8f), "a rotor's dark voxel is not gold");
        Check(VipPaint.Paint(new int[0], new int[0], GOLD, GOLD, 0f, 0f, 1f).Length == 0, "an empty part");
    }

    static int Shade(int rgb, float lit)
    {
        int r = Math.Min(255, (int)(((rgb >> 16) & 255) * lit + 0.5f));
        int g = Math.Min(255, (int)(((rgb >> 8) & 255) * lit + 0.5f));
        int b = Math.Min(255, (int)((rgb & 255) * lit + 0.5f));
        return r << 16 | g << 8 | b;
    }

    // Sim/Verify/SimLog.cs Start: the first city, the croc, no upgrades.
    static RampageSim Start(long seed)
    {
        GDict species = Content.SpeciesDef("reptilian");
        GDict stats = UpgradeTree.RunStats(Content.Section("kaiju"), species, new UpgradeTree(Content.Upgrades()));
        GArray<GDict> layout = CityGrowth.Layout(Content.Tuning(), 1, Seeds.Make("city", seed));
        RampageSim sim = new RampageSim(stats, CityGrowth.TuningFor(Content.Tuning(), 1), layout, Seeds.Make("army", seed));
        GDict ability = species["ability"];
        sim.abilityType = Gd.Str(ability["type"]);
        sim.emerge.Start(sim);
        return sim;
    }

    // One rampage; true when the leader lifted off. `kill` swats it KILL_AFTER seconds into its flight.
    static bool Flight(long seed, bool kill)
    {
        RampageSim sim = Start(seed);
        GDict cfg = Content.Section("vip");
        double cruise = Num.F(cfg["altitude"]);
        double edge = sim.arenaHalf + Num.F(cfg["exit_margin"]);
        double longest = Num.F(cfg["window_seconds"]) * Num.F(cfg["escape_cap"]);
        long ticks = (long)((sim.Stat("run_seconds") + SPARE_SECONDS) / FRAME);
        int spawns = 0, downs = 0, kills = 0, escapes = 0, crashes = 0;
        double lastAltitude = double.NegativeInfinity;
        string tag = $"seed {seed}: ";
        for (long t = 0; t < ticks && !sim.over; t++)
        {
            GArray<GDict> events = sim.Step(FRAME, Vector2.ZERO, false);
            // The idle kaiju is kept whole, so the army cannot end the rampage before the lift-off.
            sim.hp = sim.maxHp;
            Read(sim, events, tag, cruise, edge, longest, ref spawns, ref downs, ref kills, ref escapes, ref crashes);
            if (sim.vip.Flying())
            {
                Check(sim.vip.Altitude() >= lastAltitude - EPS, tag + "the leader sank while flying");
                Check(sim.vip.Altitude() <= cruise + EPS, tag + "the leader flew above its cruise height");
                lastAltitude = sim.vip.Altitude();
                if (kill && sim.vip.flightT >= KILL_AFTER)
                {
                    // Outside a step, so its two events are read here: the next step starts a new list.
                    int before = (int)sim.events.Size();
                    sim.vip.Down("blow");
                    var own = new GArray<GDict>();
                    for (int i = before; i < sim.events.Size(); i++) own.Append(sim.events[i]);
                    Check(own.Size() == 2, tag + $"a kill made {own.Size()} events, not vip_down then vip_killed");
                    Read(sim, own, tag, cruise, edge, longest, ref spawns, ref downs, ref kills, ref escapes, ref crashes);
                }
            }
            if (escapes > 0 || crashes > 0) break;
        }
        Check(spawns <= 1, tag + $"{spawns} lift-offs in one rampage");
        Check(downs == kills, tag + $"{downs} vip_down for {kills} vip_killed");
        Check(downs + escapes <= 1, tag + $"{downs} kills and {escapes} escapes in one rampage");
        Check(crashes <= downs, tag + "a crash without a kill");
        Check(spawns == 0 || sim.vip.state != "waiting", tag + "lifted off yet still waiting");
        if (kill && spawns == 1) Check(downs == 1 && sim.vip.state == "killed", tag + "the swatted leader is not killed");
        if (spawns == 1 && !sim.over) Check(downs + escapes == 1, tag + "the leader neither fell nor escaped before the run's end");
        return spawns > 0;
    }

    static void Read(RampageSim sim, GArray<GDict> events, string tag, double cruise, double edge, double longest,
        ref int spawns, ref int downs, ref int kills, ref int escapes, ref int crashes)
    {
        for (int i = 0; i < events.Size(); i++)
        {
            GDict e = events[i];
            string type = Gd.Str(e["type"]);
            if (type == "vip_spawned")
            {
                spawns++;
                Check(Num.I(e["heli"]) == VipHeli.ID, tag + "vip_spawned names another helicopter");
                Check(sim.vip.Flying(), tag + "not flying at vip_spawned");
                Check(Gd.Str(e["rank"]) == sim.vip.rank && sim.vip.rank != "", tag + "vip_spawned has no rank");
                Check(Math.Abs(Num.F(e["x"]) - sim.vip.pos.x) < EPS && Math.Abs(Num.F(e["z"]) - sim.vip.pos.y) < EPS, tag + "vip_spawned is not at the leader's place");
                Check(Math.Abs(sim.vip.Altitude() - sim.vip._roof) < EPS, tag + "lift-off is not from the roof");
                Check(sim.vip._roof <= cruise - 1.0 + EPS, tag + "the pad's roof is above the cruise height");
            }
            else if (type == "vip_down")
            {
                downs++;
                Check(Num.I(e["heli"]) == VipHeli.ID, tag + "vip_down names another helicopter");
                Check(e.Has("x") && e.Has("z") && e.Has("y") && e.Has("fate"), tag + "vip_down lacks x, z, y or fate");
                string fate = e.Has("fate") ? Gd.Str(e["fate"]) : "";
                Check(fate == "burst" || fate == "spin", tag + $"vip_down fate '{fate}'");
                if (fate == "spin")
                    Check(e.Has("seconds") && e.Has("dx") && e.Has("dz") && Num.F(e["seconds"]) > 0.0, tag + "a spinning fall lacks seconds, dx or dz");
                bool next = i + 1 < events.Size() && Gd.Str(events[i + 1]["type"]) == "vip_killed";
                Check(next, tag + "vip_down is not followed at once by vip_killed");
            }
            else if (type == "vip_killed")
            {
                kills++;
                Check(Gd.Str(e["rank"]) == sim.vip.rank, tag + "vip_killed has another rank");
                Check(Num.F(e["payout"]) > 0.0 && e.Has("by"), tag + "vip_killed pays nothing or names no cause");
            }
            else if (type == "vip_escaped")
            {
                escapes++;
                Check(Num.I(e["heli"]) == VipHeli.ID, tag + "vip_escaped names another helicopter");
                Check(sim.vip.state == "escaped", tag + "vip_escaped without the escaped state");
                bool out_ = Math.Abs(sim.vip.pos.x) >= edge - EPS || Math.Abs(sim.vip.pos.y) >= edge - EPS;
                Check(out_ || sim.vip.flightT >= longest - EPS, tag + "escaped inside the map and inside its time");
            }
            else if (type == "heli_crashed" && Num.I(e["heli"]) == VipHeli.ID)
            {
                crashes++;
                Check(downs == 1, tag + "the leader's wreck landed without a vip_down");
            }
        }
    }
}
