// The graphics presets reach what the game draws (GameLogic/GraphicsPreset.cs, after autoload/graphics_presets.gd;
// D-478): a player-effect fixture, potato against max. For every row of data/tuning.json the mapping returns the
// row's own values; potato and max differ in every key the two rows differ in; an unknown enum value or a missing
// key is an error; the counts freeze at a rampage start, so a level change mid-run reaches Cap only after EndRun; and
// the headless readers (WeatherLook rain, StreetPeople civilians) draw less on potato than on max. CityFx, Bursts and
// Fires read the same Cap but need UnityEngine, so they stay out of this fixture.
using System;
using System.IO;
using Kaiju.Game;
using S = Kaiju.Sim;
using Opt = Kaiju.Game.PlayerSettings;

static class GraphicsPresetCheck
{
    static int checks, failed;

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("  FAIL graphics preset: " + what);
    }

    public static int Run(string repoRoot)
    {
        checks = 0;
        failed = 0;
        S.FileAccess.Root = repoRoot;
        S.GDict tuning = S.JSON.ParseString(File.ReadAllText(Path.Combine(repoRoot, "data", "tuning.json")));
        S.GDict table = (S.GDict)((S.GDict)tuning["display"])["graphics"];
        foreach (S.Variant level in table.Keys()) RowValues(S.Gd.Str(level), (S.GDict)table[level]);
        PotatoAgainstMax((S.GDict)table["potato"], (S.GDict)table["max"]);
        SsgiHighUp((S.GDict)table["medium"], (S.GDict)table["high"]);
        Rejects((S.GDict)table["high"]);
        Freezes();
        Readers((S.GDict)tuning["rain"], (S.GDict)table["potato"]);
        Console.WriteLine($"graphics preset: {checks} checks, {failed} failed");
        return failed;
    }

    // Each key of the row comes back as the row holds it, its enum names mapped by the tables.
    static void RowValues(string level, S.GDict row)
    {
        GraphicsPreset p = GraphicsPreset.Of(level, row);
        string at = level + ": ";
        Check(p.scale == S.Num.F(row["scale"]), at + "scale");
        Check(p.scalerName == S.Gd.Str(row["scaler"]) && p.upscaler.ToString().ToLowerInvariant() == p.scalerName, at + $"scaler {p.upscaler}");
        Check(p.fsrSharpness == S.Num.F(row["fsr_sharpness"]), at + "fsr_sharpness");
        Check(p.msaa == S.Num.I(row["msaa"]) && p.msaaSamples == (p.msaa == 0 ? 1 : 2 << (p.msaa - 1)), at + $"msaa {p.msaa} = {p.msaaSamples} samples");
        Check(p.screenAa.ToString().ToLowerInvariant() == S.Gd.Str(row["screen_aa"]), at + $"screen_aa {p.screenAa}");
        bool wantsAa = p.msaa > 0 || p.screenAa != ScreenAa.None;
        Check((p.aa != CameraAa.None) == wantsAa, at + $"camera aa {p.aa} with msaa {p.msaa}, screen_aa {p.screenAa}");
        Check(p.shadowSize == S.Num.I(row["shadow_size"]), at + "shadow_size");
        Check(p.shadowDistance == S.Num.F(row["shadow_distance"]), at + "shadow_distance");
        Check(p.filterName == S.Gd.Str(row["shadow_filter"]), at + "shadow_filter");
        string splits = S.Gd.Str(row["sun_splits"]);
        int cascades = splits == "orthogonal" ? 1 : splits == "pssm2" ? 2 : 4;
        Check(p.cascades == cascades, at + $"sun_splits {splits} = {p.cascades} cascades");
        Check(p.cascadeSize == (cascades == 1 ? p.shadowSize : p.shadowSize / 2), at + $"cascade size {p.cascadeSize} of atlas {p.shadowSize}");
        Check(p.sunAngular == S.Num.F(row["sun_angular"]), at + "sun_angular");
        Check(p.ssao == (bool)row["ssao"] && p.ssgi == (bool)row["ssgi"], at + "ssao, ssgi");
        Check((p.farBlur == GraphicsPreset.OFF) == (S.Gd.Str(row["far_blur"]) == "off"), at + "far_blur");
        foreach (string key in GraphicsPreset.CAPS) Check(p.counts[key] == S.Num.F(row[key]), at + key);
        Check(p.Line().Contains("cascades " + p.cascades), at + "the log line carries the cascades");
    }

    // SSGI is high and max only (D-481): medium keeps SSAO but not the bounce light.
    static void SsgiHighUp(S.GDict mediumRow, S.GDict highRow)
    {
        GraphicsPreset mid = GraphicsPreset.Of("medium", mediumRow), high = GraphicsPreset.Of("high", highRow);
        Check(mid.ssao && !mid.ssgi && high.ssgi, $"ssgi medium {mid.ssgi}, high {high.ssgi}");
    }

    // The fixture: every mapped look field and every count comes out lower on potato than on max.
    static void PotatoAgainstMax(S.GDict potatoRow, S.GDict maxRow)
    {
        GraphicsPreset lo = GraphicsPreset.Of("potato", potatoRow), hi = GraphicsPreset.Of("max", maxRow);
        Check(lo.scale < hi.scale, $"render scale potato {lo.scale} < max {hi.scale}");
        Check(lo.msaaSamples < hi.msaaSamples && lo.aa == CameraAa.None && hi.aa == CameraAa.Smaa && hi.smaaTier == GraphicsPreset.TIER_HIGH,
            $"aa potato {lo.aa} x{lo.msaaSamples}, max {hi.aa} tier {hi.smaaTier} x{hi.msaaSamples}");
        Check(lo.cascadeSize < hi.cascadeSize && lo.shadowSize < hi.shadowSize, $"shadow potato {lo.cascadeSize}, max {hi.cascadeSize}");
        Check(lo.shadowDistance < hi.shadowDistance, "shadow distance");
        Check(lo.cascades == 1 && hi.cascades == 4, $"cascades potato {lo.cascades}, max {hi.cascades}");
        Check(lo.filterTier == GraphicsPreset.TIER_LOW && hi.filterTier == GraphicsPreset.TIER_HIGH, $"filter tier potato {lo.filterTier}, max {hi.filterTier}");
        Check(lo.sunAngular < hi.sunAngular, "sun angular");
        Check(!lo.ssao && hi.ssao && !lo.ssgi && hi.ssgi, "ssao and ssgi off on potato, on on max");
        Check(lo.farBlur == GraphicsPreset.OFF && hi.farBlur == GraphicsPreset.TIER_HIGH, $"far blur potato {lo.farBlur}, max {hi.farBlur}");
        foreach (string key in GraphicsPreset.CAPS) Check(lo.counts[key] < hi.counts[key], $"{key} potato {lo.counts[key]} < max {hi.counts[key]}");
    }

    // An unknown name or a missing key throws instead of falling back.
    static void Rejects(S.GDict good)
    {
        foreach (string key in new[] { "scaler", "screen_aa", "shadow_filter", "sun_splits", "far_blur" })
        {
            S.GDict bad = good.Duplicate();
            bad[key] = "ultra_mega";
            Check(Throws(() => GraphicsPreset.Of("bad", bad)), $"unknown {key} is rejected");
        }
        S.GDict odd = good.Duplicate();
        odd["msaa"] = 3L;
        Check(Throws(() => GraphicsPreset.Of("bad", odd)), "msaa 3 is rejected");
        S.GDict missing = good.Duplicate();
        missing.Erase("particles");
        Check(Throws(() => GraphicsPreset.Of("bad", missing)), "a missing count is rejected");
    }

    static bool Throws(Action a)
    {
        try { a(); }
        catch (ArgumentException) { return true; }
        return false;
    }

    // StartRun freezes the counts; a level change mid-run changes Cap only after EndRun.
    static void Freezes()
    {
        string old = Opt.Graphics;
        try
        {
            GraphicsPreset.EndRun();
            Opt.Graphics = "potato";
            double potato = GraphicsPreset.Cap("civilians");
            GraphicsPreset.StartRun(GraphicsPreset.Current());
            Opt.Graphics = "max";
            Check(GraphicsPreset.Cap("civilians") == potato && GraphicsPreset.Cap("particles") < 1.0, "a level change mid-run leaves the run's caps alone");
            Check(GraphicsPreset.InRun && GraphicsPreset.CapsLine().StartsWith("debris_pool "), "the run caps line");
            GraphicsPreset.EndRun();
            Check(GraphicsPreset.Cap("civilians") > potato, "after EndRun Cap reads the level in use");
        }
        finally
        {
            GraphicsPreset.EndRun();
            Opt.Graphics = old;
        }
    }

    // On vs off where the game reads the counts: rain layers and civilians per lot follow the level outside a run,
    // and inside a run started on potato they stay potato while the player's level is max.
    static void Readers(S.GDict rain, S.GDict potatoRow)
    {
        string old = Opt.Graphics;
        try
        {
            GraphicsPreset.EndRun();
            Opt.Graphics = "potato";
            (double ratio, int drops, int perLot) lo = Drawn(rain);
            Opt.Graphics = "max";
            (double ratio, int drops, int perLot) hi = Drawn(rain);
            Check(lo.ratio < hi.ratio, $"rain particles ratio potato {lo.ratio} < max {hi.ratio}");
            Check(lo.drops < hi.drops, $"rain streaks potato {lo.drops} < max {hi.drops}");
            Check(lo.perLot < hi.perLot, $"civilians per lot potato {lo.perLot} < max {hi.perLot}");
            Opt.Graphics = "potato";
            GraphicsPreset.StartRun(GraphicsPreset.Current());
            Opt.Graphics = "max";
            Check(Drawn(rain) == lo, "a run started on potato keeps potato's rain and civilians with the level at max");
            foreach (string key in GraphicsPreset.CAPS)
                Check(GraphicsPreset.Cap(key) == S.Num.F(potatoRow[key]), $"in a potato run with the level at max, Cap({key}) is potato's");
        }
        finally
        {
            GraphicsPreset.EndRun();
            Opt.Graphics = old;
        }
    }

    static (double, int, int) Drawn(S.GDict rain)
    {
        double ratio = WeatherLook.ParticlesRatio();
        int drops = 0;
        foreach (RainLayer layer in WeatherLook.Layers(rain, ratio, 0.0, 0.0)) drops += layer.count;
        return (ratio, drops, StreetPeople.PerLot());
    }
}
