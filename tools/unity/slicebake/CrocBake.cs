// export_slice.gd _export_croc without Godot: the croc's rest pose and binds as KaijuRig.load_from
// builds them (scenes/kaiju_rig.gd, arms relaxed by BipedSwing.rest_arm_bases), the clips' fit
// (scenes/kaiju_clips.gd fit), the skin gunzipped and the clips copied. Godot's 32-bit maths:
// the sim runtime's Vector3, Quaternion and Basis, plus Basis.inverse and the Transform3D product
// and affine inverse, which the runtime does not carry (core/math/basis.cpp, transform_3d.cpp).
using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using Kaiju.Sim;

static partial class CrocBake
{
    sealed class Bone
    {
        public string name = "", parent = "";
        public Vector3 head, dir;
        public Transform3D rest;
    }

    static readonly string[] STAGES = { "baby", "adolescent", "adult" };

    // export_slice.gd _stages and _stage_base: every growth stage (D-014) beside an ..._adult croc that has its
    // files, else the one croc given as the adult; each written as croc_<stage>.*.
    public static string ExportStages(string croc, string outDir, string repo)
    {
        const string ADULT = "_adult";
        bool beside = croc.EndsWith(ADULT, StringComparison.Ordinal);
        foreach (string stage in STAGES)
        {
            string stageBase = beside ? croc.Substring(0, croc.Length - ADULT.Length) + "_" + stage : croc;
            if (!beside && stage != "adult") continue;
            if (beside && !(File.Exists(stageBase + ".rig.json") && File.Exists(stageBase + ".kclip"))) continue;
            string why = Export(stageBase, stage, outDir, repo);
            if (why != "") return why;
        }
        return "";
    }

    static string Export(string croc, string stage, string outDir, string repo)
    {
        foreach (string ext in new[] { ".rig.json", ".kvox", ".kclip", ".vskin" })
        {
            if (!File.Exists(croc + ext)) return "no " + croc + ext;
        }
        long height = KvoxHeight(croc + ".kvox");
        if (height <= 0) return croc + ".kvox has no height";
        double voxel = GdConst.ModelHeight() / height;
        using JsonDocument spec = JsonDocument.Parse(File.ReadAllText(croc + ".rig.json"));
        List<Bone> bones = Build(spec.RootElement, voxel);
        string plan = spec.RootElement.TryGetProperty("type", out JsonElement t) ? t.GetString() ?? "biped" : "biped";
        if (plan == "biped") RelaxArms(bones, repo);

        (double scale, Vector3 origin, string why) = Fit(croc + ".kclip", bones);
        if (why != "") return "clips do not fit the rig: " + why;

        var byName = new Dictionary<string, Bone>();
        foreach (Bone b in bones) byName[b.name] = b;
        var rows = new GArray<Variant>();
        foreach (Bone b in bones)
        {
            Transform3D bind = AffineInverse(ToRig(b, byName));
            rows.Append(new GDict { { "name", b.name }, { "parent", b.parent }, { "rest", Xf(b.rest) }, { "bind", Xf(bind) } });
        }
        var rig = new GDict { { "bones", rows }, { "rig_scale", scale }, { "rig_origin", Gd.Arr(origin.x, origin.y, origin.z) } };
        string name = "croc_" + stage;
        File.WriteAllBytes(Path.Combine(outDir, name + ".rig.json"), new UTF8Encoding(false).GetBytes(GodotJson.Stringify(rig)));
        using (var gz = new GZipStream(File.OpenRead(croc + ".vskin"), CompressionMode.Decompress))
        using (var plain = File.Create(Path.Combine(outDir, name + ".vskin")))
            gz.CopyTo(plain);
        File.Copy(croc + ".kclip", Path.Combine(outDir, name + ".kclip"), true);
        return "";
    }

    // scenes/kvox.gd read: the header up to the model's height.
    static long KvoxHeight(string path)
    {
        using var f = new BinaryReader(File.OpenRead(path));
        if (Encoding.ASCII.GetString(f.ReadBytes(4)) != "KVOX") return 0;
        uint version = f.ReadUInt32();
        if (version != 1) f.ReadUInt32();  // frame count
        if (version == 1) f.ReadUInt32();  // the one frame's voxel count
        return f.ReadUInt16();
    }

    static Vector3 Vec(JsonElement a) => new Vector3(a[0].GetDouble(), a[1].GetDouble(), a[2].GetDouble());

    // KaijuRig._build / _add_bone: heads scaled to rig units, each bone placed at its head less its
    // parent's, its rest that local transform.
    static List<Bone> Build(JsonElement spec, double voxel)
    {
        var heads = new Dictionary<string, Vector3>();
        foreach (JsonElement d in spec.GetProperty("bones").EnumerateArray())
            heads[d.GetProperty("name").GetString()!] = Vec(d.GetProperty("head")) * voxel;
        var o = new List<Bone>();
        foreach (JsonElement d in spec.GetProperty("bones").EnumerateArray())
        {
            var b = new Bone { name = d.GetProperty("name").GetString()! };
            JsonElement p = d.GetProperty("parent");
            b.parent = p.ValueKind == JsonValueKind.Null ? "" : p.GetString()!;
            b.head = heads[b.name];
            Vector3 parentHead = heads.TryGetValue(b.parent, out Vector3 ph) ? ph : Vector3.ZERO;
            b.rest = new Transform3D(Basis.IDENTITY, b.head - parentHead);
            b.dir = Vec(d.GetProperty("tail")) * voxel - b.head;
            o.Add(b);
        }
        return o;
    }

    // KaijuRig._relax_arms with BipedSwing.rest_arm_bases (scenes/biped_swing.gd ARM_* directions).
    static void RelaxArms(List<Bone> bones, string repo)
    {
        var byName = new Dictionary<string, Bone>();
        foreach (Bone b in bones) byName[b.name] = b;
        string swing = File.ReadAllText(Path.Combine(repo, "scenes", "biped_swing.gd"));
        Vector3[] dirs = { ArmConst(swing, "ARM_UPPER"), ArmConst(swing, "ARM_FORE"), ArmConst(swing, "ARM_HAND") };
        var bases = new List<(string, Basis)>();
        foreach (string side in new[] { "l", "r" })
        {
            if (!byName.TryGetValue("arm_" + side + "0", out Bone root)) continue;
            double outward = Math.Sign((float)root.dir.x);
            Basis above = Basis.IDENTITY;
            for (int i = 0; i < dirs.Length; i++)
            {
                if (!byName.TryGetValue("arm_" + side + i, out Bone n)) break;
                Vector3 want = (dirs[i] * new Vector3(outward, 1.0, 1.0)).Normalized();
                var world = new Basis(new Quaternion(n.dir.Normalized(), want));
                bases.Add((n.name, Inverse(above) * world));
                above = world;
            }
        }
        foreach ((string n, Basis b) in bases) byName[n].rest = new Transform3D(b, byName[n].rest.origin);
    }

    static Vector3 ArmConst(string script, string name)
    {
        Match m = Regex.Match(script, @"^const\s+" + name + @"\s*:?=\s*Vector3\(([^,]+),([^,]+),([^)]+)\)", RegexOptions.Multiline);
        if (!m.Success) throw new InvalidOperationException("slicebake: no const " + name + " in scenes/biped_swing.gd");
        return new Vector3(Strtod.Parse(m.Groups[1].Value.Trim()), Strtod.Parse(m.Groups[2].Value.Trim()), Strtod.Parse(m.Groups[3].Value.Trim()));
    }

    // export_slice.gd _to_rig: the bone's transform through its parents, up to the rig.
    static Transform3D ToRig(Bone b, Dictionary<string, Bone> byName)
    {
        Transform3D t = b.rest;
        string p = b.parent;
        while (p != "" && byName.TryGetValue(p, out Bone up))
        {
            t = Mul(up.rest, t);
            p = up.parent;
        }
        return t;
    }

    // KaijuClips.read's header and fit: a least-squares scale and origin from clip metres to rig units.
    static (double, Vector3, string) Fit(string path, List<Bone> bones)
    {
        byte[] raw = File.ReadAllBytes(path);
        if (raw.Length < 12 || Encoding.ASCII.GetString(raw, 0, 4) != "KCLP") return (0, Vector3.ZERO, "not a clip file");
        int length = (int)BitConverter.ToUInt32(raw, 8);
        using JsonDocument header = JsonDocument.Parse(Encoding.UTF8.GetString(raw, 12, length));
        var names = new List<string>();
        foreach (JsonElement b in header.RootElement.GetProperty("bones").EnumerateArray()) names.Add(b.GetString()!);
        if (names.Count != bones.Count) return (0, Vector3.ZERO, "bone lists differ");
        for (int i = 0; i < names.Count; i++)
        {
            if (names[i] != bones[i].name) return (0, Vector3.ZERO, "bone lists differ at " + names[i]);
        }
        JsonElement heads = header.RootElement.GetProperty("rest_heads_m");
        var rest = new Vector3[names.Count];
        for (int i = 0; i < names.Count; i++)
            rest[i] = heads.TryGetProperty(names[i], out JsonElement h) ? Vec(h) : Vector3.ZERO;
        Vector3 cm = Vector3.ZERO, cr = Vector3.ZERO;
        for (int i = 0; i < names.Count; i++)
        {
            cm += rest[i];
            cr += bones[i].head;
        }
        cm /= names.Count;
        cr /= names.Count;
        double num = 0.0, den = 0.0;
        for (int i = 0; i < names.Count; i++)
        {
            num += (bones[i].head - cr).Dot(rest[i] - cm);
            den += (rest[i] - cm).LengthSquared();
        }
        if (den <= 0.0 || num <= 0.0) return (0, Vector3.ZERO, "rest heads are degenerate");
        double scale = num / den;
        return (scale, cr - cm * scale, "");
    }

    static float Cofac(Basis m, int r1, int c1, int r2, int c2) =>
        (float)(Row(m, r1).At(c1) * Row(m, r2).At(c2)) - (float)(Row(m, r1).At(c2) * Row(m, r2).At(c1));

    static Vector3 Row(Basis m, int i) => i == 0 ? m.R0 : i == 1 ? m.R1 : m.R2;

    // Basis::invert.
    static Basis Inverse(Basis m)
    {
        float co0 = Cofac(m, 1, 1, 2, 2), co1 = Cofac(m, 1, 2, 2, 0), co2 = Cofac(m, 1, 0, 2, 1);
        float det = (float)((float)((float)(m.R0.X * co0) + (float)(m.R0.Y * co1)) + (float)(m.R0.Z * co2));
        float s = 1f / det;
        return new Basis(
            new Vector3(co0 * s, Cofac(m, 0, 2, 2, 1) * s, Cofac(m, 0, 1, 1, 2) * s),
            new Vector3(co1 * s, Cofac(m, 0, 0, 2, 2) * s, Cofac(m, 0, 2, 1, 0) * s),
            new Vector3(co2 * s, Cofac(m, 0, 1, 2, 0) * s, Cofac(m, 0, 0, 1, 1) * s));
    }

    // Transform3D * Transform3D.
    static Transform3D Mul(Transform3D a, Transform3D b) => new Transform3D(a.basis * b.basis, a * b.origin);

    // Transform3D::affine_inverse.
    static Transform3D AffineInverse(Transform3D t)
    {
        Basis inv = Inverse(t.basis);
        return new Transform3D(inv, inv * -t.origin);
    }

    // export_slice.gd _xf: the basis columns x, y, z, then the origin.
    static GArray<Variant> Xf(Transform3D t)
    {
        Basis b = t.basis;
        return Gd.Arr(b.R0.x, b.R1.x, b.R2.x, b.R0.y, b.R1.y, b.R2.y, b.R0.z, b.R1.z, b.R2.z, t.origin.x, t.origin.y, t.origin.z);
    }
}
