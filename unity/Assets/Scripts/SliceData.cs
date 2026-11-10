using System;
using System.Collections.Generic;
using System.IO;
using Unity.Collections;
using UnityEngine;

// One building out of buildings.bin (tools/unity/export_slice.gd). Godot axes.
public sealed class BuildingBlob
{
    public int w, h, d, ox, oy, oz, hasFix, res;
    public Vector3 origin;
    public float voxel, noise;
    public uint salt;
    public Vector2 unit, align;
    public NativeArray<byte> cells, drawn, looks, palette, finish, fixtures;
}

[Serializable]
public sealed class SphereDef
{
    public string bone;
    public float r;
}

[Serializable]
public sealed class Tuning
{
    public float tick_hz = 30;
    public float turn_rate = 2.5f;
    public float clip_fade_s = 0.2f;
    public float sweep_fade_s = 0.15f;
    public float gravity = 20;
    public float cam_orbit_rate = 1.5f;
    public int settle_per_tick = 2;
    public float settle_cooldown_s = 0.1f;
    public int island_min_cells = 128;
    public float cell_mass = 0.02f;
    public float topple_turn = 0.25f;
    public float depenetration = 3;
    public float impact_speed = 7;
    public float impact_radius_per_speed = 0.1f;
    public float impact_radius_min = 0.5f;
    public float impact_radius_max = 2.5f;
    public float seam_dark = 0.22f;
    public int debris_pool = 2000000;
    public int debris_keep_every = 2;
    public float debris_burst = 7;
    public float debris_up = 5;
    public float debris_scatter = 4;
    public float debris_size = 0.11f;
    public bool debris_shadows = false;
    public float debris_grid_cell = 0.25f;
    public float debris_grid_span = 480;
    // How high a landed cube raises its column, as a share of its size (under 1: cubes overlap, no gaps).
    public float debris_pile = 0.6f;
    // Cubes of height difference a pile holds before one rolls to the lower neighbour.
    public int debris_slide = 3;
    public string debris_tint = "b8b0a0";
    public float debris_tint_mix = 0.55f;
    // The rubble a gone building and a toppled tower leave (RubbleView): the literals of scenes/ruin.gd heap
    // and strip_plan and scenes/landmark_rubble.gd, in sim units. ruin_share is Unity's own: the share of
    // Godot's height laid, since the carved cells' debris already lies on the lot.
    public float ruin_peak_base = 2.4f;
    public float ruin_peak_per_tier = 0.9f;
    public float ruin_spill_cells = 2f;
    public float ruin_wobble = 0.9f;
    public float ruin_wobble_swing = 0.1f;
    public float ruin_wobble_jitter = 0.04f;
    public float ruin_fall_power = 0.8f;
    public float ruin_height_jitter = 1.5f;
    public float ruin_strip_height = 1.6f;
    public string ruin_grey = "6e706e";
    public float ruin_grey_mix = 0.8f;
    public float ruin_share = 0.5f;
    public float landmark_rubble_back = 2f;
    public float landmark_rubble_reach = 0.6f;
    public float landmark_rubble_reach_max = 2f;
    public float landmark_rubble_peak = 1.4f;
    public int landmark_rubble_colors = 24;
    public float impact_burst = 3;
    public float pusher_scale = 0.8f;
    public float sweep_margin_frames = 4;
    public float spawn_x = -206;
    public float spawn_z = 248;
    public float bloom_intensity = 0.6f;
    public float agx_white = 16.29f;
    public float hdrp_ev = 9.5f;
    public float sky_diffusion = 1f;
    public float ssao_intensity = 1.2f;
    public float shadow_distance = 600f;
    public float fog_height = 70f;
    // The run's dust trail (SlamView.cs): scenes/powers_view.gd update's literals.
    public float momentum_dust_min = 0.5f;
    public float momentum_dust_every_s = 0.15f;
    public float momentum_dust_lift = 0.3f;
    // The far aircraft lights (Aircraft.cs): scenes/aircraft.gd's literals, Godot axes.
    public int aircraft_count = 3;
    public float aircraft_x_range = 600f;
    public float aircraft_y_min = 90f;
    public float aircraft_y_max = 150f;
    public float aircraft_z_first = -200f;
    public float aircraft_z_step = -160f;
    public float aircraft_speed_min = 18f;
    public float aircraft_speed_max = 30f;
    public float aircraft_wrap_x = 900f;
    public float aircraft_wrap_to = 880f;
    public float aircraft_blink_period = 1.4f;
    public float aircraft_blink_on = 0.18f;
    public float aircraft_light_size = 1.6f;
    public string aircraft_red = "ff3326";
    public string aircraft_white = "fff2d9";
    public SphereDef[] body = new SphereDef[0];
    public SphereDef[] tail = new SphereDef[0];
}

public static class SliceData
{
    public static string Dir => Path.Combine(Application.streamingAssetsPath, "slice");

    public static Tuning LoadTuning()
    {
        string path = Path.Combine(Application.streamingAssetsPath, "tuning.json");
        return JsonUtility.FromJson<Tuning>(File.ReadAllText(path));
    }

    public static Dictionary<string, object> LoadJson(string name)
    {
        return MiniJson.Obj(MiniJson.Parse(File.ReadAllText(Path.Combine(Dir, name))));
    }

    static NativeArray<byte> Take(byte[] raw, ref int at, int size)
    {
        var a = new NativeArray<byte>(size, Allocator.Persistent, NativeArrayOptions.UninitializedMemory);
        NativeArray<byte>.Copy(raw, at, a, 0, size);
        at += size;
        return a;
    }

    public static List<BuildingBlob> LoadBuildings()
    {
        byte[] raw = File.ReadAllBytes(Path.Combine(Dir, "buildings.bin"));
        if (raw[0] != 'K' || raw[1] != 'S' || raw[2] != 'B' || raw[3] != '1')
            throw new InvalidDataException("buildings.bin header");
        int count = BitConverter.ToInt32(raw, 4);
        int at = 8;
        var list = new List<BuildingBlob>(count);
        for (int k = 0; k < count; k++)
        {
            var b = new BuildingBlob();
            b.w = BitConverter.ToInt32(raw, at);
            b.h = BitConverter.ToInt32(raw, at + 4);
            b.d = BitConverter.ToInt32(raw, at + 8);
            b.ox = BitConverter.ToInt32(raw, at + 12);
            b.oy = BitConverter.ToInt32(raw, at + 16);
            b.oz = BitConverter.ToInt32(raw, at + 20);
            at += 24;
            b.origin = new Vector3(BitConverter.ToSingle(raw, at), BitConverter.ToSingle(raw, at + 4), BitConverter.ToSingle(raw, at + 8));
            b.voxel = BitConverter.ToSingle(raw, at + 12);
            at += 16;
            b.salt = BitConverter.ToUInt32(raw, at);
            at += 4;
            b.noise = BitConverter.ToSingle(raw, at);
            b.unit = new Vector2(BitConverter.ToSingle(raw, at + 4), BitConverter.ToSingle(raw, at + 8));
            b.align = new Vector2(BitConverter.ToSingle(raw, at + 12), BitConverter.ToSingle(raw, at + 16));
            at += 20;
            b.hasFix = BitConverter.ToInt32(raw, at);
            b.res = BitConverter.ToInt32(raw, at + 4);
            at += 8;
            int n = b.w * b.h * b.d;
            b.cells = Take(raw, ref at, n);
            b.drawn = Take(raw, ref at, n);
            b.looks = Take(raw, ref at, n);
            b.palette = Take(raw, ref at, 1024);
            b.finish = Take(raw, ref at, 256);
            b.fixtures = Take(raw, ref at, 256);
            list.Add(b);
        }
        return list;
    }

    public static void Dispose(BuildingBlob b)
    {
        b.palette.Dispose();
        b.finish.Dispose();
        b.fixtures.Dispose();
    }

    public static Color Hex(object value)
    {
        string s = (string)value;
        int v = Convert.ToInt32(s.Substring(0, 6), 16);
        return new Color(((v >> 16) & 255) / 255f, ((v >> 8) & 255) / 255f, (v & 255) / 255f, 1);
    }

    public static float F(Dictionary<string, object> d, string key, float fallback)
    {
        return d.TryGetValue(key, out object v) && v is double x ? (float)x : fallback;
    }
}
