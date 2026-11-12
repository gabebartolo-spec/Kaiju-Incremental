using System;
using System.Collections.Generic;
using System.IO;
using S = Kaiju.Sim;

// What StadiumCrowd is made of (scenes/crowd_build.gd), read off the baked stadium once: where the seats are, what
// the fans wear, and where a fan stands on the stadium's chunks and cells. Pure functions of the model and
// data/tuning.json "crowd". No UnityEngine here: unity/SimTests compiles this file (StadiumCheck).
public static class CrowdBuild
{
    // A kit shirt this unsaturated (and bright) reads as an empty seat from above.
    const float PALE = 0.25f, BRIGHT = 0.7f;
    const float CHANNEL = 255f;
    const int RED = 16, GREEN = 8, BYTE = 255, HEX = 16;
    // The buildings' cube (BuildingVoxels.VOXEL).
    public const double VOXEL = 1.0 / PitchProps.RES;
    // A .kvox (LandmarkCells._Read's format): where the first pose's voxels begin, and each one's size.
    const int KVOX_DATA = 14, KVOX_VOXEL = 10, KVOX_RGB = 6;

    public sealed class Model
    {
        public S.Vector3i[] cells;
        public int[] rgb;  // 0xRRGGBB
    }

    public struct Outfit
    {
        public string shirt, pants, hair, skin;
    }

    // The first pose of a landmark's baked model, cells and colours in file order (scenes/landmark_voxels.gd).
    public static Model Voxels(string landmark)
    {
        S.GDict row = S.Content.Landmarks().Get(landmark, new S.GDict());
        string path = S.Gd.Str(row.Get("kvox", ""));
        var model = new Model { cells = new S.Vector3i[0], rgb = new int[0] };
        if (path == "" || !S.FileAccess.FileExists(path)) return model;
        byte[] b = File.ReadAllBytes(path.Replace("res://", S.FileAccess.Root + "/"));
        int at = KVOX_DATA, count = BitConverter.ToInt32(b, 8);
        if (BitConverter.ToInt32(b, 4) != 1)
        {
            count = BitConverter.ToInt32(b, at);
            at += 4;
        }
        model.cells = new S.Vector3i[count];
        model.rgb = new int[count];
        for (int v = 0; v < count; v++)
        {
            int o = at + v * KVOX_VOXEL;
            model.cells[v] = new S.Vector3i(BitConverter.ToInt16(b, o), BitConverter.ToInt16(b, o + 2), BitConverter.ToInt16(b, o + 4));
            model.rgb[v] = b[o + KVOX_RGB] << RED | b[o + KVOX_RGB + 1] << GREEN | b[o + KVOX_RGB + 2];
        }
        return model;
    }

    static int Hex(string color) => Convert.ToInt32(color, HEX);

    // How far two colours are apart, on their widest channel, as Godot's float colours.
    static double Apart(int a, int b)
    {
        double most = 0.0;
        for (int shift = 0; shift <= RED; shift += GREEN)
        {
            float x = ((a >> shift) & BYTE) / CHANNEL, y = ((b >> shift) & BYTE) / CHANNEL;
            most = Math.Max(most, Math.Abs((double)x - (double)y));
        }
        return most;
    }

    // Seats: the model's seat-coloured voxels open to the sky, one per `spacing` square of plan, shuffled and
    // capped at `max` (the graphics preset's crowd_max).
    public static List<S.Vector3i> Seats(Model vox, S.GDict cfg, S.RandomNumberGenerator rng, int max)
    {
        S.GArray<S.Variant> keys = cfg["seats"];
        double near = S.Num.F(cfg["seat_match"]) / CHANNEL;
        double spacing = S.Num.I(cfg["spacing"]);
        var filled = new HashSet<S.Vector3i>(vox.cells);
        var taken = new HashSet<S.Vector2i>();
        var found = new List<S.Vector3i>();
        for (int i = 0; i < vox.cells.Length; i++)
        {
            S.Vector3i cell = vox.cells[i];
            if (filled.Contains(cell + S.Vector3i.UP)) continue;
            bool seat = false;
            foreach (S.Variant key in keys) seat = seat || Apart(vox.rgb[i], Hex(S.Gd.Str(key))) <= near;
            var square = new S.Vector2i(S.Gd.Floori(cell.x / spacing), S.Gd.Floori(cell.z / spacing));
            if (seat && taken.Add(square)) found.Add(cell);
        }
        for (int i = found.Count - 1; i > 0; i--)
        {
            int j = (int)rng.RandiRange(0, i);
            S.Vector3i swap = found[i];
            found[i] = found[j];
            found[j] = swap;
        }
        return found.GetRange(0, Math.Min(found.Count, max));
    }

    // A pale shirt: unsaturated and bright, as Godot's Color.s and Color.v read it.
    static bool Pale(int rgb)
    {
        float r = ((rgb >> RED) & BYTE) / CHANNEL, g = ((rgb >> GREEN) & BYTE) / CHANNEL, b = (rgb & BYTE) / CHANNEL;
        float most = Math.Max(r, Math.Max(g, b)), least = Math.Min(r, Math.Min(g, b));
        float s = most == 0f ? 0f : (most - least) / most;
        return s < PALE && most > BRIGHT;
    }

    // Every (shirt, skin) outfit: the kits' colours then the neutral shirts, on street trousers and hair. A pale
    // kit shirt (cricket whites) reads as an empty grey seat from above, so its fans wear the kit's trim (its
    // "hair" colour: caps and helmets) instead.
    public static List<Outfit> Outfits(S.GArray<S.Variant> kits, S.GArray<S.Variant> neutral)
    {
        var shirts = new List<string>();
        foreach (S.Variant k in kits)
        {
            S.GDict kit = k;
            string shirt = S.Gd.Str(kit["shirt"]);
            shirts.Add(Pale(Hex(shirt)) ? S.Gd.Str(kit["hair"]) : shirt);
        }
        foreach (S.Variant n in neutral)
        {
            S.GDict row = n;
            shirts.Add(S.Gd.Str(row["shirt"]));
        }
        var all = new List<Outfit>();
        for (int i = 0; i < shirts.Count; i++)
        {
            S.GDict street = neutral[i % neutral.Size()];
            foreach (string skin in StadiumMatch.SKINS)
                all.Add(new Outfit { shirt = shirts[i], pants = S.Gd.Str(street["pants"]), hair = S.Gd.Str(street["hair"]), skin = skin });
        }
        return all;
    }

    // The fans of stadium `b`: one on each seat its model gives, in a kit's colours or a neutral shirt, with a skin
    // each. Draws the run's presentation stream (the seats' shuffle first).
    public static List<StadiumCrowd.Fan> Sit(S.RampageSim.Building b, long kits, S.GDict cfg, S.RandomNumberGenerator rng, int max)
    {
        S.Vector2 corner = new S.Vector2(b.x, b.z) - new S.Vector2(b.w, b.d) * 0.5;
        var origin = new S.Vector3(corner.x + VOXEL * 0.5, 0.0, corner.y + VOXEL * 0.5);
        S.GArray<S.Variant> neutral = cfg["neutral"];
        double share = S.Num.F(cfg["team_share"]);
        int skins = StadiumMatch.SKINS.Length;
        var fans = new List<StadiumCrowd.Fan>();
        foreach (S.Vector3i cell in Seats(Voxels(b.landmark), cfg, rng, max))
        {
            var fan = new StadiumCrowd.Fan { pos = origin + new S.Vector3(cell.x, cell.y + 1, cell.z) * VOXEL };
            long shirt = rng.Randf() < share ? rng.RandiRange(0, kits - 1) : rng.RandiRange(kits, kits + neutral.Size() - 1);
            fan.outfit = (int)(shirt * skins + rng.RandiRange(0, skins - 1));
            fans.Add(fan);
        }
        return fans;
    }

    // Stands every seated fan up, each with its own moment to start running (a share of flee_delay by its slot)
    // and the time it is through an exit; returns them.
    public static List<StadiumCrowd.Fan> Rise(List<StadiumCrowd.Fan> fans, S.GDict cfg, S.Vector2 centre, S.Vector2 half)
    {
        double speed = S.Num.F(cfg["flee_speed"]), delay = S.Num.F(cfg["flee_delay"]);
        double exitR = S.Num.F(cfg["exit_r"]), sink = S.Num.F(cfg["sink"]);
        var risen = new List<StadiumCrowd.Fan>();
        foreach (StadiumCrowd.Fan fan in fans)
        {
            if (fan.state != StadiumCrowd.State.SEATED) continue;
            fan.state = StadiumCrowd.State.UP;
            fan.leaves = fan.Beat() * delay;
            fan.run = RunOut(new S.Vector2(fan.pos.x, fan.pos.z) - centre, half, exitR);
            fan.outAt = fan.leaves + (fan.run + sink) / speed;
            risen.Add(fan);
        }
        return risen;
    }

    // How far a fan at `at` (from the stadium's middle) runs, straight out, to normalised radius exitR: the root of
    // |q + d m| = exitR, q its seat and d its direction over the half size `half`.
    public static double RunOut(S.Vector2 at, S.Vector2 half, double exitR)
    {
        S.Vector2 q = at / half;
        S.Vector2 d = at.Normalized() / half;
        double a = d.Dot(d);
        double b = q.Dot(d);
        double c = q.Dot(q) - exitR * exitR;
        return Math.Max(0.0, (-b + Math.Sqrt(Math.Max(0.0, b * b - a * c))) / a);
    }

    // The chunk of the stadium (corner `corner` in plan) that world point `at` lies in.
    public static S.Vector3i Chunk(S.Vector3 at, S.Vector2 corner) =>
        new S.Vector3i(S.Gd.Floori(at.x - corner.x), S.Gd.Floori(at.y - VOXEL * 0.5), S.Gd.Floori(at.z - corner.y));

    // The grid index of the fine cell (Carving's VoxelFrame `f` of the stadium, corner `corner`) that world point
    // `at` stands on: the highest solid cell from just under it down `reach` metres, or -1 when there is none
    // (nothing under the feet, or outside the grid).
    public static long Under(S.VoxelFrame f, S.Vector3 at, S.Vector2 corner, double reach)
    {
        var c = new S.Vector3i(S.Gd.Floori((at.x - corner.x) * f.res), S.Gd.Floori(at.y * f.res - 0.5), S.Gd.Floori((at.z - corner.y) * f.res));
        c -= f.offset;
        if (c.x < 0 || c.z < 0 || c.x >= f.w || c.z >= f.d) return -1;
        long plan = f.w * f.d;
        long col = c.x + c.z * f.w;
        long floor = Math.Max(-1, c.y - S.Gd.Ceili(reach * f.res) - 1);
        for (long y = Math.Min(c.y, f.h - 1); y > floor; y--)
            if (f.cells[col + y * plan] != S.VoxelFrame.EMPTY) return col + y * plan;
        return -1;
    }

    // The y of the highest standing chunk below chunk `c` (0: the ground) in `frame`, whose chunk health is `hp`:
    // where a fan whose stand has gone lands.
    public static long Land(S.Structure frame, S.PackedFloat32Array hp, S.Vector3i c)
    {
        if (!frame.Inside(c)) return 0;
        long plan = frame.w * frame.d;
        long col = c.x + c.z * frame.w;
        for (long y = Math.Min(c.y, frame.h) - 1; y >= 0; y--)
            if (hp[col + y * plan] > 0.0) return y + 1;
        return 0;
    }
}
