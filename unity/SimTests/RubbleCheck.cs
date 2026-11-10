// The rubble shapes the Unity view lays on the debris heightfield (RubbleShape, after scenes/ruin.gd and
// scenes/landmark_rubble.gd) are plain maths, so they are held here: the same seed gives the same heap, a
// heap stays within its lot's spill and stands higher for a higher tier, a strip stays within the fallen
// tower's length and width, and a foot's press lowers the rubble under it and none beside it (on vs off).
using System;
using System.Collections.Generic;
using Kaiju.Sim;

static class RubbleCheck
{
    const double X = 12.5, Z = -40.0, Width = 6.0, Radius = 1.2, Keep = 0.35;
    const long W = 10, D = 8, Index = 7;

    static int failures;

    static RubbleCfg Cfg() => new RubbleCfg
    {
        cell = 0.25, grain = 0.15, share = 1.0, res = 8.0,
        peakBase = 2.4, peakPerTier = 0.9, spillCells = 2.0, wobble = 0.9, wobbleSwing = 0.1, wobbleJitter = 0.04,
        fallPower = 0.8, heightJitter = 1.5, stripHeight = 1.6, lump = 0.5, blockX = 8.0, blockY = 3.0, blockZ = 6.0,
        pileBack = 2.0, pileReach = 0.6, pileReachMax = 2.0, pilePeak = 1.4,
    };

    static List<RubbleColumn> Heap(RubbleCfg cfg, long tier)
    {
        var columns = new List<RubbleColumn>();
        RubbleShape.Heap(cfg, X, Z, W, D, tier, Seeds.Make("ruin", Index), columns);
        return columns;
    }

    static int Top(List<RubbleColumn> columns)
    {
        int top = 0;
        foreach (RubbleColumn c in columns) top = Math.Max(top, c.grains);
        return top;
    }

    static void Fail(string what)
    {
        failures++;
        Console.WriteLine("RubbleCheck: " + what);
    }

    public static int Run()
    {
        failures = 0;
        RubbleCfg cfg = Cfg();

        List<RubbleColumn> a = Heap(cfg, 1), b = Heap(cfg, 1);
        if (a.Count == 0) Fail("a gone building left no heap");
        if (a.Count != b.Count) Fail($"same seed, heaps of {a.Count} and {b.Count} columns");
        else
            for (int k = 0; k < a.Count; k++)
                if (a[k].x != b[k].x || a[k].z != b[k].z || a[k].grains != b[k].grains || a[k].bx != b[k].bx || a[k].bz != b[k].bz)
                {
                    Fail($"same seed, column {k} differs");
                    break;
                }

        double spill = (cfg.res + cfg.spillCells) / cfg.res;
        foreach (RubbleColumn c in a)
            if (Math.Abs(c.x - X) > W * 0.5 + spill + cfg.cell || Math.Abs(c.z - Z) > D * 0.5 + spill + cfg.cell || c.grains < 1)
            {
                Fail($"heap column at {c.x},{c.z} with {c.grains} grains is outside the lot's spill or empty");
                break;
            }
        int low = Top(a), high = Top(Heap(cfg, 3));
        double ceiling = (cfg.peakBase + cfg.peakPerTier + cfg.heightJitter / cfg.res) / cfg.grain + 1.0;
        if (low > ceiling) Fail($"heap stands {low} grains, over its peak of {ceiling:0.0}");
        if (high <= low) Fail($"a tier 3 heap ({high} grains) is no higher than a tier 1 heap ({low})");

        var strip = new List<RubbleColumn>();
        RubbleShape.Strip(cfg, X, Z, X + 9.0, Z + 12.0, Width, strip);
        if (strip.Count == 0) Fail("a toppled tower left no strip");
        double length = 15.0, dx = 9.0 / length, dz = 12.0 / length, half = Width * 0.5 + 1.0 / cfg.res;
        foreach (RubbleColumn c in strip)
        {
            double t = (c.x - X) * dx + (c.z - Z) * dz, s = -(c.x - X) * dz + (c.z - Z) * dx;
            if (t < 0.0 || t >= length || Math.Abs(s) > half || c.grains < 1)
            {
                Fail($"strip column at {c.x},{c.z} lies outside the fallen tower ({t:0.00} along, {s:0.00} across)");
                break;
            }
        }
        double stripCeiling = (cfg.stripHeight + cfg.lump + 1.0 / cfg.res) / cfg.grain + 1.0;
        if (Top(strip) > stripCeiling) Fail($"strip stands {Top(strip)} grains, over its {stripCeiling:0.0}");

        var pile = new List<RubbleColumn>();
        RubbleShape.Pile(cfg, X, Z, X + 9.0, Z + 12.0, Width, pile);
        if (pile.Count == 0) Fail("a toppled model building left no pile");
        foreach (RubbleColumn c in pile)
        {
            double t = (c.x - X) * dx + (c.z - Z) * dz;
            if (t < -cfg.pileBack - cfg.cell || t > cfg.pileReachMax + cfg.cell)
            {
                Fail($"pile column at {c.x},{c.z} lies {t:0.00} along, past its reach");
                break;
            }
        }

        // The press, on vs off: the foot comes down on the heap's middle.
        long before = 0, after = 0, outsideBefore = 0, outsideAfter = 0;
        int under = 0;
        foreach (RubbleColumn c in a)
        {
            long pressed = RubbleShape.Pressed(c.grains, c.x - X, c.z - Z, Radius, Keep);
            bool inside = (c.x - X) * (c.x - X) + (c.z - Z) * (c.z - Z) <= Radius * Radius;
            if (inside)
            {
                under++;
                before += c.grains;
                after += pressed;
            }
            else
            {
                outsideBefore += c.grains;
                outsideAfter += pressed;
            }
        }
        if (under == 0) Fail("no heap column lies under the foot");
        if (after >= before || after > before * Keep) Fail($"the press left {after} of {before} grains under the foot, keep {Keep}");
        if (outsideAfter != outsideBefore) Fail($"the press changed rubble beside the foot: {outsideBefore} to {outsideAfter}");

        Console.WriteLine($"RubbleCheck: heap {a.Count} columns top {low}, strip {strip.Count}, pile {pile.Count}, press {before} to {after} grains, {failures} failed");
        return failures;
    }
}
