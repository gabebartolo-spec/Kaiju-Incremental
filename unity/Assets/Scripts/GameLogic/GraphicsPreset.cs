// The graphics presets (autoload/graphics_presets.gd; D-478: Unity's presets map Godot's values one for one), as
// plain C#: Of() reads a row of tuning "display" graphics into the values the HDRP side sets (Game/GraphicsView),
// and StartRun/EndRun/Cap freeze the row's counts at each rampage start, so a change in pause applies next rampage
// and nothing pops mid-run. An enum value this does not know is an error, never a quiet default. unity/SimTests
// GraphicsPresetCheck holds it to data/tuning.json. Presentation only: nothing here reaches the sim.
using System;
using System.Collections.Generic;
using System.Globalization;
using S = Kaiju.Sim;

namespace Kaiju.Game
{
    // graphics_presets.gd ENUMS "scaler".
    public enum Upscaler { Bilinear, Fsr1, Fsr2 }

    // graphics_presets.gd ENUMS "screen_aa".
    public enum ScreenAa { None, Fxaa, Smaa }

    // What a deferred HDRP camera draws for the row's MSAA and screen AA (GraphicsPreset.Aa).
    public enum CameraAa { None, Fxaa, Smaa }

    public sealed class GraphicsPreset
    {
        // Tiers in HDRP's own order (SMAAQualityLevel, HDShadowFilteringQuality, ScalableSettingLevelParameter.Level):
        // low, medium, high. Named here because the rows hold Godot's names, not HDRP's indices.
        public const int TIER_LOW = 0, TIER_MEDIUM = 1, TIER_HIGH = 2;
        public const int OFF = -1;

        static readonly Dictionary<string, Upscaler> SCALERS = new Dictionary<string, Upscaler>
        {
            { "bilinear", Upscaler.Bilinear }, { "fsr1", Upscaler.Fsr1 }, { "fsr2", Upscaler.Fsr2 },
        };
        static readonly Dictionary<string, ScreenAa> SCREEN_AA = new Dictionary<string, ScreenAa>
        {
            { "none", ScreenAa.None }, { "fxaa", ScreenAa.Fxaa }, { "smaa", ScreenAa.Smaa },
        };
        // Godot's six soft-shadow qualities onto HDRP's three directional filtering tiers (high = PCSS).
        static readonly Dictionary<string, int> SHADOW_FILTERS = new Dictionary<string, int>
        {
            { "hard", TIER_LOW }, { "soft_very_low", TIER_LOW }, { "soft_low", TIER_MEDIUM },
            { "soft_medium", TIER_MEDIUM }, { "soft_high", TIER_HIGH }, { "soft_ultra", TIER_HIGH },
        };
        // The sun's shadow mode as HDRP cascades (HDShadowSettings.cascadeShadowSplitCount).
        static readonly Dictionary<string, int> SUN_SPLITS = new Dictionary<string, int>
        {
            { "orthogonal", 1 }, { "pssm2", 2 }, { "pssm4", 4 },
        };
        // Godot's shadow_size is the whole directional atlas the splits share, HDRP's resolution is one cascade's:
        // a split sun lays two tiles along each side of the atlas, so a cascade gets that share of the side.
        static readonly Dictionary<string, int> ATLAS_TILES = new Dictionary<string, int>
        {
            { "orthogonal", 1 }, { "pssm2", 2 }, { "pssm4", 2 },
        };
        // The far blur's DOF quality as HDRP's DepthOfField tier (Godot's very_low has no own tier).
        static readonly Dictionary<string, int> FAR_BLURS = new Dictionary<string, int>
        {
            { "off", OFF }, { "very_low", TIER_LOW }, { "low", TIER_LOW }, { "medium", TIER_MEDIUM }, { "high", TIER_HIGH },
        };
        // Godot's Viewport.MSAA index (0 off, 1 = 2x, 2 = 4x): its samples, and the SMAA tier a deferred HDRP
        // camera (no MSAA without forward shading) draws in its place.
        static readonly int[] MSAA_SAMPLES = { 1, 2, 4 };
        static readonly int[] MSAA_SMAA = { OFF, TIER_MEDIUM, TIER_HIGH };

        // The count keys (graphics_presets.gd CAPS): read once per rampage, never live.
        public static readonly string[] CAPS = { "debris_pool", "max_fires", "debris_live", "debris_static", "particles", "crowd_max", "civilians" };

        public string level;
        public double scale, fsrSharpness, shadowDistance, sunAngular;
        public string scalerName, screenAaName, filterName, splitsName, farBlurName;
        public Upscaler upscaler;
        public ScreenAa screenAa;
        public int msaa, msaaSamples, shadowSize, cascadeSize, cascades, filterTier, farBlur;
        public bool ssao, ssgi;
        public CameraAa aa;
        public int smaaTier;
        public Dictionary<string, double> counts = new Dictionary<string, double>();

        static Dictionary<string, double> runCaps;

        // The row of `level` in tuning "display" graphics, read; throws on a missing key or an unknown value.
        public static GraphicsPreset Of(string level, S.GDict row)
        {
            var p = new GraphicsPreset { level = level };
            p.scale = Number(level, row, "scale");
            p.fsrSharpness = Number(level, row, "fsr_sharpness");
            p.scalerName = Name(level, row, "scaler");
            p.upscaler = Pick(SCALERS, level, "scaler", p.scalerName);
            p.screenAaName = Name(level, row, "screen_aa");
            p.screenAa = Pick(SCREEN_AA, level, "screen_aa", p.screenAaName);
            p.Msaa(level, row);
            p.Shadows(level, row);
            p.ssao = Flag(level, row, "ssao");
            p.ssgi = Flag(level, row, "ssil");
            p.farBlurName = Name(level, row, "far_blur");
            p.farBlur = Pick(FAR_BLURS, level, "far_blur", p.farBlurName);
            foreach (string key in CAPS) p.counts[key] = Number(level, row, key);
            return p;
        }

        // The preset in use: the player's level (PlayerSettings.GraphicsLevel).
        public static GraphicsPreset Current() => Of(PlayerSettings.GraphicsLevel(), PlayerSettings.GraphicsRow());

        void Msaa(string level, S.GDict row)
        {
            msaa = (int)Number(level, row, "msaa");
            if (msaa < 0 || msaa >= MSAA_SAMPLES.Length) throw new ArgumentException($"graphics {level}: msaa = {msaa} is not 0, 1 or 2");
            msaaSamples = MSAA_SAMPLES[msaa];
            smaaTier = screenAa == ScreenAa.Smaa ? TIER_HIGH : MSAA_SMAA[msaa];
            aa = smaaTier != OFF ? CameraAa.Smaa : screenAa == ScreenAa.Fxaa ? CameraAa.Fxaa : CameraAa.None;
        }

        void Shadows(string level, S.GDict row)
        {
            shadowSize = (int)Number(level, row, "shadow_size");
            shadowDistance = Number(level, row, "shadow_distance");
            sunAngular = Number(level, row, "sun_angular");
            filterName = Name(level, row, "shadow_filter");
            filterTier = Pick(SHADOW_FILTERS, level, "shadow_filter", filterName);
            splitsName = Name(level, row, "sun_splits");
            cascades = Pick(SUN_SPLITS, level, "sun_splits", splitsName);
            cascadeSize = shadowSize / ATLAS_TILES[splitsName];
        }

        // The row's look as one parseable line (SettingsApply logs it on every apply).
        public string Line()
        {
            string dof = farBlur == OFF ? "off" : farBlurName;
            return string.Format(CultureInfo.InvariantCulture,
                "scale {0:F2} upscaler {1} sharpness {2:F2} msaa {3} screen_aa {4} aa {5} smaa_tier {6} shadow {7} cascade_size {8} dist {9:F0} cascades {10} filter {11} sun {12:F1} ao {13} ssgi {14} dof {15}",
                scale, scalerName, fsrSharpness, msaaSamples, screenAaName, aa.ToString().ToLowerInvariant(), smaaTier, shadowSize,
                cascadeSize, shadowDistance, cascades, filterName, sunAngular, ssao ? "on" : "off", ssgi ? "on" : "off", dof);
        }

        // Freezes the counts for the rampage starting now (graphics_presets.gd start_run).
        public static void StartRun(GraphicsPreset preset)
        {
            runCaps = new Dictionary<string, double>(preset.counts);
        }

        // The rampage is over: Cap reads the row in use again.
        public static void EndRun()
        {
            runCaps = null;
        }

        public static bool InRun => runCaps != null;

        // A count of the rampage in play (StartRun); before any, the row in use.
        public static double Cap(string key)
        {
            if (runCaps != null) return runCaps[key];
            return Number(PlayerSettings.GraphicsLevel(), PlayerSettings.GraphicsRow(), key);
        }

        // The frozen counts as one parseable line, in CAPS order.
        public static string CapsLine()
        {
            var parts = new List<string>();
            foreach (string key in CAPS) parts.Add(string.Format(CultureInfo.InvariantCulture, "{0} {1}", key, Cap(key)));
            return string.Join(" ", parts);
        }

        static S.Variant Value(string level, S.GDict row, string key)
        {
            if (!row.Has(key)) throw new ArgumentException($"graphics {level}: missing {key}");
            return row[key];
        }

        static double Number(string level, S.GDict row, string key)
        {
            S.Variant v = Value(level, row, key);
            if (v.Type != S.Gd.TYPE_INT && v.Type != S.Gd.TYPE_FLOAT) throw new ArgumentException($"graphics {level}: {key} = {S.Gd.Str(v)} is not a number");
            return S.Num.F(v);
        }

        static bool Flag(string level, S.GDict row, string key)
        {
            S.Variant v = Value(level, row, key);
            if (v.Type != S.Gd.TYPE_BOOL) throw new ArgumentException($"graphics {level}: {key} = {S.Gd.Str(v)} is not a bool");
            return (bool)v;
        }

        static string Name(string level, S.GDict row, string key)
        {
            S.Variant v = Value(level, row, key);
            if (v.Type != S.Gd.TYPE_STRING) throw new ArgumentException($"graphics {level}: {key} = {S.Gd.Str(v)} is not a name");
            return (string)v;
        }

        static T Pick<T>(Dictionary<string, T> table, string level, string key, string name)
        {
            if (table.TryGetValue(name, out T v)) return v;
            throw new ArgumentException($"graphics {level}: {key} = {name} is not one of {string.Join(", ", table.Keys)}");
        }
    }
}
