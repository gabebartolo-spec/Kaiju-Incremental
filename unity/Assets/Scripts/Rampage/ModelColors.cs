using System.Collections.Generic;
using System.IO;
using Unity.Collections;
using UnityEngine;
using S = Kaiju.Sim;

// A landmark's or pool building's baked colours (scenes/landmark_voxels.gd), onto the same cells the
// sim's LandmarkCells reads from the same .kvox. The mesher takes one byte per cell, so each building
// has its own palette, its colours merged only as far as 253 slots need. Reads, decides nothing.
public static class ModelColors
{
    const int RES = 8;
    const int SLOTS = 253;
    static readonly int[] Masks = { 0xFFFFFF, 0xFCFCFC, 0xF8F8F8, 0xF0F0F0, 0xE0E0E0, 0xC0C0C0 };

    public sealed class Model
    {
        public S.PackedInt32Array xyz;
        public int[] rgb;
    }

    static readonly Dictionary<string, Model> cache = new Dictionary<string, Model>();

    // Fills this site's palette, and gives every model cell's grid index with its palette id.
    public static void Paint(S.RampageSim.Building b, Vector3Int size, Vector3Int offset, NativeArray<byte> palette, NativeArray<byte> finish, out int[] index, out byte[] ids)
    {
        index = new int[0];
        ids = new byte[0];
        S.GDict row = b.model != "" ? S.ModelVariant.RowOf(b.model) : S.Content.Landmarks().Get(b.landmark, new S.GDict());
        Model model = Read(S.Gd.Str(row.Get("kvox", "")));
        if (model == null) return;
        S.PackedInt32Array xyz = model.xyz;
        int[] src = null;
        Vector3 shift = new Vector3(0f, 1f, 1f);
        if (b.model != "")
        {
            S.GDict v = !b.variant.IsEmpty() ? b.variant : S.ModelVariant.Of(new S.GDict());
            S.GDict turned = S.ModelVariant.Cells(model.xyz, row, v, RES);
            xyz = turned["xyz"];
            S.PackedInt32Array from = turned["src"];
            src = from.Raw;
            shift = Shift(row, b.palette);
        }
        int count = (int)(xyz.Size() / 3);
        int[] raw = xyz.Raw;
        var shaded = new Dictionary<int, int>();
        var colors = new int[count];
        for (int i = 0; i < count; i++)
        {
            int c = model.rgb[src != null ? src[i] : i];
            if (!shaded.TryGetValue(c, out int s)) shaded[c] = s = Shaded(c, shift);
            colors[i] = s;
        }

        int mask = Masks[Masks.Length - 1];
        foreach (int m in Masks)
        {
            var seen = new HashSet<int>();
            foreach (int c in colors) seen.Add(c & m);
            if (seen.Count > SLOTS) continue;
            mask = m;
            break;
        }
        var slots = new Dictionary<int, int>();
        var sums = new List<Vector4>();
        index = new int[count];
        ids = new byte[count];
        for (int i = 0; i < count; i++)
        {
            int key = colors[i] & mask;
            if (!slots.TryGetValue(key, out int slot))
            {
                slot = sums.Count;
                slots[key] = slot;
                sums.Add(Vector4.zero);
            }
            int c = colors[i];
            sums[slot] += new Vector4((c >> 16) & 255, (c >> 8) & 255, c & 255, 1);
            ids[i] = (byte)(slot + 1);
            int x = raw[i * 3] - offset.x, y = raw[i * 3 + 1] - offset.y, z = raw[i * 3 + 2] - offset.z;
            index[i] = x + z * size.x + y * size.x * size.z;
        }
        for (int s = 0; s < sums.Count; s++)
        {
            Vector4 t = sums[s];
            int id = (s + 1) * 4;
            palette[id] = (byte)Mathf.RoundToInt(t.x / t.w);
            palette[id + 1] = (byte)Mathf.RoundToInt(t.y / t.w);
            palette[id + 2] = (byte)Mathf.RoundToInt(t.z / t.w);
            palette[id + 3] = 255;
            finish[s + 1] = 0;
        }
    }

    // The district's palette shift: hue degrees, saturation, value.
    static Vector3 Shift(S.GDict row, long n)
    {
        S.GDict districts = S.Content.CityBuildings().Get("districts", new S.GDict());
        S.GDict district = districts.Get(S.Gd.Str(row.Get("district", "")), new S.GDict());
        S.GArray<S.Variant> shifts = district.Get("shifts", S.Gd.Arr());
        if (shifts.IsEmpty()) return new Vector3(0f, 1f, 1f);
        long at = ((n % shifts.Size()) + shifts.Size()) % shifts.Size();
        S.GArray<S.Variant> s = shifts[at];
        return new Vector3((float)(double)S.Num.F(s[0]), (float)(double)S.Num.F(s[1]), (float)(double)S.Num.F(s[2]));
    }

    static int Shaded(int rgb, Vector3 shift)
    {
        var c = new Color(((rgb >> 16) & 255) / 255f, ((rgb >> 8) & 255) / 255f, (rgb & 255) / 255f);
        Color.RGBToHSV(c, out float h, out float s, out float v);
        h = Mathf.Repeat(h + shift.x / 360f, 1f);
        Color o = Color.HSVToRGB(h, Mathf.Clamp01(s * shift.y), Mathf.Clamp01(v * shift.z));
        return Mathf.RoundToInt(o.r * 255f) << 16 | Mathf.RoundToInt(o.g * 255f) << 8 | Mathf.RoundToInt(o.b * 255f);
    }

    // The first pose of a .kvox (LandmarkCells._Read's format). Workers bake in parallel.
    public static Model Read(string path)
    {
        if (path == "" || !S.FileAccess.FileExists(path)) return null;
        lock (cache)
        {
            if (cache.TryGetValue(path, out Model known)) return known;
        }
        byte[] b = File.ReadAllBytes(path.Replace("res://", S.FileAccess.Root + "/"));
        int version = System.BitConverter.ToInt32(b, 4);
        int first = System.BitConverter.ToInt32(b, 8);
        int at = 14;
        int voxels = first;
        if (version != 1)
        {
            voxels = System.BitConverter.ToInt32(b, at);
            at += 4;
        }
        var xyz = new S.PackedInt32Array();
        xyz.Resize(voxels * 3);
        int[] raw = xyz.Raw;
        var rgb = new int[voxels];
        for (int v = 0; v < voxels; v++)
        {
            int o = at + v * 10;
            raw[v * 3] = System.BitConverter.ToInt16(b, o);
            raw[v * 3 + 1] = System.BitConverter.ToInt16(b, o + 2);
            raw[v * 3 + 2] = System.BitConverter.ToInt16(b, o + 4);
            rgb[v] = b[o + 6] << 16 | b[o + 7] << 8 | b[o + 8];
        }
        var model = new Model { xyz = xyz, rgb = rgb };
        lock (cache) cache[path] = model;
        return model;
    }
}
