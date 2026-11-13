// The title's burning city without the engine (scenes/title_fires.gd, title_burning_windows.gd, title_shore.gd's
// lamps and sand, title_sky_smoke.gd's banks): where each fire, burning pane, lamp and smoke puff goes, drawn from
// Godot's seeded streams in Godot's order, in Godot's axes. Game/Title/TitleCityView.cs draws them; SimTests
// TitleCheck holds them to a headless Godot run (golden/title_city.txt).
using System;
using System.Collections.Generic;
using S = Kaiju.Sim;

namespace Kaiju.Game
{
    public static class TitleCity
    {
        // CitySkyline.FAR_GRAIN: the far facades' window grid (cells per metre).
        public const double FAR_GRAIN = 1.2;
        // title_fires.gd WINDOW_OUT: window flames stand this far out from the wall (m).
        public const double WINDOW_OUT = 0.6;
        // title_burning_windows.gd OUT and ROWS: panes stand this far out from the wall, two rows tall.
        public const double PANE_OUT = 0.04;
        public const double PANE_ROWS = 2.0;
        // A window's lower row is on a multiple of this many rows (+1).
        const double FLOOR_ROWS = 4.0;
        // How far across the face and up the tower a window fire, a side fire and a hero blaze may stand.
        const double WALL_SPREAD = 0.4, WINDOW_LOW = -0.25, WINDOW_HIGH = 0.4, HERO_LOW = -0.1, SIDE = 0.25;
        const double SEED_SPAN = 10.0;
        // title_shore.gd: a lamp head's glow scale range.
        const double LAMP_LOW = 0.75, LAMP_HIGH = 1.15;
        const double TAU = Math.PI * 2.0;

        // A far-shore tower the fires choose from (CitySkyline.stand_ins): its middle and size.
        public struct Stand { public S.Vector3 at, size; }

        // One FarFire: where it stands, its seed and its spec (tuning "far", merged with "window" or "hero").
        public sealed class Fire
        {
            public S.Vector3 at;
            public double seed;
            public S.GDict spec;
        }

        // One fire-orange pane: its middle, width (its height is PANE_ROWS of it) and shade.
        public struct Pane { public S.Vector3 at; public double width, shade; }

        // A sky-smoke puff: its layer, size and middle.
        public struct Puff { public int layer; public double size; public S.Vector3 at; }

        public sealed class District
        {
            public readonly List<Fire> fires = new List<Fire>();
            // The x of each burning tower (the bay's fire reflections).
            public readonly List<double> lit = new List<double>();
            public readonly List<S.Vector3> burning = new List<S.Vector3>(), hero = new List<S.Vector3>();
            public List<Pane> windowPanes, heroPanes;
        }

        // TitleFires.light: the tallest front-row towers around each focus burn (roof, street face, windows, hero).
        public static District Light(S.GDict cfg, double farZ, IList<Stand> stands)
        {
            District made = new District();
            S.RandomNumberGenerator rng = S.Seeds.Make("title_fire", 0);
            S.GDict far = cfg["far"];
            S.GDict noSmoke = far.Duplicate();
            noSmoke["smoke_density"] = 0.0;
            S.GArray<S.Variant> foci = cfg["foci"];
            for (int f = 0; f < foci.Size(); f++)
            {
                S.GArray<S.Variant> focus = foci[f];
                List<Stand> towers = Tallest(cfg, farZ, S.Num.F(focus[0]), S.Num.F(focus[1]), stands);
                int count = Math.Min((int)S.Num.I(cfg["count"]), towers.Count);
                for (int n = 0; n < count; n++) Tower(made, cfg, towers[n], n, rng, far, noSmoke);
            }
            S.GDict windows = cfg["windows"];
            S.GDict heroWindows = windows.Duplicate();
            S.GDict hero = cfg["hero"];
            heroWindows["cells"] = hero["cells"];
            made.windowPanes = Panes(made.burning, windows);
            made.heroPanes = Panes(made.hero, heroWindows);
            return made;
        }

        static void Tower(District made, S.GDict cfg, Stand tower, int n, S.RandomNumberGenerator rng, S.GDict far, S.GDict noSmoke)
        {
            // The tallest burn at the roof (with the smoke columns); the others part way up their street face.
            double up = n < S.Num.I(cfg["roof_fires"]) ? 0.5 : rng.RandfRange(-SIDE, SIDE);
            Fire fire = new Fire { spec = up >= 0.5 ? far : noSmoke, seed = rng.Randf() * SEED_SPAN };
            fire.at = new S.Vector3(tower.at.x, tower.at.y + tower.size.y * up, tower.at.z + (up < 0.5 ? tower.size.z * 0.5 : 0.0));
            made.fires.Add(fire);
            made.lit.Add(fire.at.x);
            WindowFires(made, cfg, tower, rng);
            if (n < S.Num.I(cfg["hero_per_focus"])) made.lit.Add(HeroBlaze(made, cfg, tower, rng));
        }

        // title_fires.gd _tallest: the front-row towers within the radius of the focus, tallest first.
        static List<Stand> Tallest(S.GDict cfg, double farZ, double fx, double fz, IList<Stand> stands)
        {
            List<Stand> towers = new List<Stand>();
            double depth = S.Num.F(cfg["depth"]), radius = S.Num.F(cfg["radius"]);
            foreach (Stand box in stands)
            {
                bool front = box.at.z < farZ && box.at.z > farZ - depth;
                double dx = box.at.x - fx, dz = box.at.z - fz;
                if (front && Math.Sqrt(dx * dx + dz * dz) <= radius) towers.Add(box);
            }
            towers.Sort((a, b) => b.size.y.CompareTo(a.size.y));
            return towers;
        }

        // title_fires.gd _window_fires: flames out of window holes on the street face, each snapped to the middle
        // of its window (one cell wide, two rows tall, its lower row on a multiple of four rows, +1).
        static void WindowFires(District made, S.GDict cfg, Stand t, S.RandomNumberGenerator rng)
        {
            S.GDict spec = Merged(cfg["far"], cfg["window"]);
            long count = S.Num.I(cfg["window_fires"]);
            for (long i = 0; i < count; i++)
            {
                double seed = rng.Randf() * SEED_SPAN;
                double wall = t.at.z + t.size.z * 0.5;
                double x = t.at.x + rng.RandfRange(-WALL_SPREAD, WALL_SPREAD) * t.size.x;
                S.Vector3 raw = new S.Vector3(x, t.at.y + t.size.y * rng.RandfRange(WINDOW_LOW, WINDOW_HIGH), wall);
                double column = Math.Floor(raw.x * FAR_GRAIN);
                double floorRow = Math.Floor(raw.y * FAR_GRAIN / FLOOR_ROWS) * FLOOR_ROWS + 1.0;
                S.Vector3 at = new S.Vector3((column + 0.5) / FAR_GRAIN, (floorRow + 1.0) / FAR_GRAIN, wall);
                made.burning.Add(at);
                made.fires.Add(new Fire { spec = spec, seed = seed, at = new S.Vector3(at.x, at.y, at.z + WINDOW_OUT) });
            }
        }

        // title_fires.gd _hero_blaze: big window fires up several floors of one face; only the top keeps smoke.
        // Returns its x.
        static double HeroBlaze(District made, S.GDict cfg, Stand t, S.RandomNumberGenerator rng)
        {
            S.GDict hero = cfg["hero"];
            S.GDict spec = Merged(cfg["far"], hero);
            double column = Math.Floor((t.at.x + rng.RandfRange(-SIDE, SIDE) * t.size.x) * FAR_GRAIN);
            double rise = t.at.y + t.size.y * rng.RandfRange(HERO_LOW, SIDE);
            double baseRow = Math.Floor(rise * FAR_GRAIN / FLOOR_ROWS) * FLOOR_ROWS + 1.0;
            int floors = (int)S.Num.I(hero["floors"]);
            for (int level = 0; level < floors; level++)
            {
                S.GDict floorSpec = spec.Duplicate();
                if (level < floors - 1) floorSpec["smoke_density"] = 0.0;
                double seed = rng.Randf() * SEED_SPAN;
                double sway = rng.RandfRange(-1.0, 1.0) * S.Num.F(hero["spread"]);
                S.Vector3 at = new S.Vector3((column + 0.5 + sway) / FAR_GRAIN, (baseRow + FLOOR_ROWS * level + 1.0) / FAR_GRAIN, t.at.z + t.size.z * 0.5);
                made.hero.Add(at);
                made.fires.Add(new Fire { spec = floorSpec, seed = seed, at = new S.Vector3(at.x, at.y, at.z + WINDOW_OUT) });
            }
            return (column + 0.5) / FAR_GRAIN;
        }

        static S.GDict Merged(S.GDict under, S.GDict over)
        {
            S.GDict spec = under.Duplicate();
            spec.Merge(over, true);
            return spec;
        }

        // title_burning_windows.gd _ready: a row of panes either side of each spot, some missing, dimmer outward.
        public static List<Pane> Panes(IList<S.Vector3> spots, S.GDict cfg)
        {
            S.RandomNumberGenerator rng = S.Seeds.Make("title_windows", 0);
            double cell = 1.0 / FAR_GRAIN, gap = S.Num.F(cfg["gap"]);
            int reach = (int)S.Num.I(cfg["cells"]);
            List<Pane> panes = new List<Pane>();
            foreach (S.Vector3 spot in spots)
            {
                for (int k = -reach; k <= reach; k++)
                {
                    if (k != 0 && rng.Randf() < gap) continue;
                    double shade = 1.0 - Math.Abs(k) / (double)(reach + 1);
                    panes.Add(new Pane { at = new S.Vector3(spot.x + k * cell, spot.y, spot.z + PANE_OUT), width = cell, shade = shade });
                }
            }
            return panes;
        }

        // title_shore.gd _lamp_spots: each lamp's x and glow scale along the promenade, a few out.
        public static List<S.Vector2> Lamps(S.GDict shore, double span)
        {
            double gap = S.Num.F(shore["lamp_gap"]), off = S.Num.F(shore["lamp_out"]), jitter = S.Num.F(shore["lamp_jitter"]);
            S.RandomNumberGenerator rng = S.Seeds.Make("title_lamps", 0);
            List<S.Vector2> spots = new List<S.Vector2>();
            int count = (int)(span * 2.0 / gap);
            for (int i = 0; i < count; i++)
            {
                if (rng.Randf() < off) continue;
                double wander = rng.RandfRange(-1.0, 1.0) * jitter;
                spots.Add(new S.Vector2(-span + (i + 0.5 + wander) * gap, rng.RandfRange(LAMP_LOW, LAMP_HIGH)));
            }
            return spots;
        }

        // title_shore.gd _beach: the sand's two wave phases.
        public static double[] BeachPhases()
        {
            S.RandomNumberGenerator rng = S.Seeds.Make("title_beach", 0);
            double a = rng.Randf() * TAU;
            return new[] { a, rng.Randf() * TAU };
        }

        // title_sky_smoke.gd _bank, every layer on one stream: each puff's size and middle.
        public static List<Puff> Smoke(S.GArray<S.Variant> layers)
        {
            S.RandomNumberGenerator rng = S.Seeds.Make("title_sky_smoke", 0);
            List<Puff> puffs = new List<Puff>();
            for (int n = 0; n < layers.Size(); n++)
            {
                S.GDict layer = layers[n];
                S.GArray<S.Variant> x = layer["x"], y = layer["y"], size = layer["size"];
                long amount = S.Num.I(layer["amount"]);
                for (long i = 0; i < amount; i++)
                {
                    double puff = rng.RandfRange(S.Num.F(size[0]), S.Num.F(size[1]));
                    double px = rng.RandfRange(S.Num.F(x[0]), S.Num.F(x[1]));
                    double py = rng.RandfRange(S.Num.F(y[0]), S.Num.F(y[1]));
                    double pz = S.Num.F(layer["z"]) + rng.RandfRange(-1.0, 1.0) * S.Num.F(layer["depth"]);
                    puffs.Add(new Puff { layer = n, size = puff, at = new S.Vector3(px, py, pz) });
                }
            }
            return puffs;
        }

        // title_colossus.gd _place: the feet after `steps` footfalls (out along "step" for "steps_out", then back).
        public static S.Vector3 ColossusFeet(S.GDict cfg, long steps)
        {
            S.GArray<S.Variant> start = cfg["start"], stride = cfg["step"];
            long count = S.Num.I(cfg["steps_out"]);
            long along = ((steps % (count * 2)) + count * 2) % (count * 2);
            if (along > count) along = count * 2 - along;
            return new S.Vector3(S.Num.F(start[0]) + S.Num.F(stride[0]) * along, S.Num.F(cfg["ground_y"]), S.Num.F(start[1]) + S.Num.F(stride[1]) * along);
        }

        // title_colossus.gd burst_point: behind the colossus and high, where a revealing explosion goes off.
        public static S.Vector3 BurstPoint(S.GDict cfg, long steps)
        {
            S.Vector3 feet = ColossusFeet(cfg, steps);
            return new S.Vector3(feet.x, feet.y + S.Num.F(cfg["burst_height"]), feet.z - S.Num.F(cfg["burst_back"]));
        }

        // How far (screen shares, u and v) the card and its eye move once the feet have taken `steps`.
        public static float[] ColossusShift(S.GDict title, long steps, double aspect)
        {
            S.GDict cfg = title["colossus"], cam = title["camera"];
            S.GArray<S.Variant> position = cam["position"], target = cam["look"];
            double[] eye = { S.Num.F(position[0]), S.Num.F(position[1]), S.Num.F(position[2]) };
            double[] look = { S.Num.F(target[0]), S.Num.F(target[1]), S.Num.F(target[2]) };
            S.Vector3 rest = ColossusFeet(cfg, 0), now = ColossusFeet(cfg, steps);
            TitleMenu.Project(eye, look, S.Num.F(cam["fov"]), aspect, new[] { rest.x, rest.y, rest.z }, out double u0, out double v0, out _);
            TitleMenu.Project(eye, look, S.Num.F(cam["fov"]), aspect, new[] { now.x, now.y, now.z }, out double u1, out double v1, out _);
            return new[] { (float)(u1 - u0), (float)(v1 - v0) };
        }

        // title_colossus.gd _process: how lit the colossus is (0 hidden .. 1 clear) with `left` of `reveal_s` to go.
        public static double RevealAmount(S.GDict cfg, double left)
        {
            if (left <= 0.0) return 0.0;
            double age = S.Num.F(cfg["reveal_s"]) - left;
            return Math.Min(1.0, age / S.Num.F(cfg["rise_s"])) * Math.Min(1.0, left / S.Num.F(cfg["fall_s"]));
        }
    }
}
