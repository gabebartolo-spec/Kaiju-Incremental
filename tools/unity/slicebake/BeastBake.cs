// The far rampage's beast (scenes/far_beast.gd: KaijuModel.new(species, colors, "adult")) for the Unity port: its
// rig as KaijuRig.load_from builds it (heads in rig units, rest poses, a hexapod's arms lowered by _relax_arms'
// fallback) with each bone's head, rest head->tail and physics flag for the gait, its binds as VoxelSkin takes
// them, KaijuModel.MODEL_HEIGHT, and its skin gunzipped. Written as far_beast.rig.json and far_beast.vskin.
using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Text;
using System.Text.Json;
using Kaiju.Sim;

static partial class CrocBake
{
    const double RELAX_TURN = 0.35, RELAX_LOWER = 0.95;  // kaiju_rig.gd _relax_arms (not a biped)

    // tuning skyline_rampage "species": its adult model, or why not.
    public static string ExportBeast(string outDir, string repo)
    {
        string species = Gd.Str(Content.Section("skyline_rampage")["species"]);
        string model = Path.Combine(repo, "assets", "kaiju", species + "_adult");
        foreach (string ext in new[] { ".rig.json", ".kvox", ".vskin" })
            if (!File.Exists(model + ext)) return "no " + model + ext;
        long height = KvoxHeight(model + ".kvox");
        if (height <= 0) return model + ".kvox has no height";
        using JsonDocument spec = JsonDocument.Parse(File.ReadAllText(model + ".rig.json"));
        List<Bone> bones = Build(spec.RootElement, BodyData.ModelHeight() / height);
        string plan = spec.RootElement.TryGetProperty("type", out JsonElement t) ? t.GetString() ?? "biped" : "biped";
        if (plan != "biped") LowerArms(bones);
        var byName = new Dictionary<string, Bone>();
        foreach (Bone b in bones) byName[b.name] = b;
        var rows = new GArray<Variant>();
        int i = 0;
        foreach (JsonElement d in spec.RootElement.GetProperty("bones").EnumerateArray())
        {
            Bone b = bones[i++];
            bool physics = d.TryGetProperty("physics", out JsonElement p) && p.ValueKind == JsonValueKind.True;
            rows.Append(new GDict
            {
                { "name", b.name }, { "parent", b.parent }, { "physics", physics },
                { "head", Gd.Arr(b.head.x, b.head.y, b.head.z) }, { "dir", Gd.Arr(b.dir.x, b.dir.y, b.dir.z) },
                { "rest", Xf(b.rest) }, { "bind", Xf(AffineInverse(ToRig(b, byName))) },
            });
        }
        var rig = new GDict { { "bones", rows }, { "type", plan }, { "species", species }, { "model_height", BodyData.ModelHeight() } };
        File.WriteAllBytes(Path.Combine(outDir, "far_beast.rig.json"), new UTF8Encoding(false).GetBytes(GodotJson.Stringify(rig)));
        using (var gz = new GZipStream(File.OpenRead(model + ".vskin"), CompressionMode.Decompress))
        using (var plain = File.Create(Path.Combine(outDir, "far_beast.vskin")))
            gz.CopyTo(plain);
        return "";
    }

    // kaiju_rig.gd _relax_arms without BipedSwing: each arm root turned down and forward from its T-pose.
    static void LowerArms(List<Bone> bones)
    {
        foreach (Bone b in bones)
        {
            if (b.name != "arm_l0" && b.name != "arm_r0") continue;
            double outward = Math.Sign(b.dir.x);
            var lower = new Basis(new Vector3(0, 0, 1), -outward * RELAX_LOWER);
            b.rest = new Transform3D(new Basis(new Vector3(0, 1, 0), outward * RELAX_TURN) * lower * b.rest.basis, b.rest.origin);
        }
    }
}
