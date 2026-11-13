// tools/kaiju_skin/dump_rest.gd without Godot: every rigged kaiju's rest pose as KaijuRig.load_from builds it (arms
// already lowered), for tools/kaiju_skin/bake.py. Per kaiju: the voxel size and, per bone in rig.json order, its rest
// transform relative to the rig (rig units, 12 numbers: basis columns x, y, z, then origin) and its head.
//   dotnet run --project tools/unity/slicebake -c Release -- --rest=<out.json>
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.Json;
using Kaiju.Sim;

static partial class CrocBake
{
    static readonly string[] REST_SPECIES = { "reptilian", "insectoid" };  // the croc and the far beast

    public static int DumpRest(string outPath, string repo)
    {
        var dump = new GDict();
        foreach (string species in REST_SPECIES)
        {
            foreach (string stage in STAGES)
            {
                string name = species + "_" + stage;
                string model = Path.Combine(repo, "assets", "kaiju", name);
                if (!File.Exists(model + ".rig.json")) continue;
                long height = KvoxHeight(model + ".kvox");
                if (height <= 0) continue;
                double voxel = BodyData.ModelHeight() / height;
                using JsonDocument spec = JsonDocument.Parse(File.ReadAllText(model + ".rig.json"));
                List<Bone> bones = Build(spec.RootElement, voxel);
                string plan = spec.RootElement.TryGetProperty("type", out JsonElement t) ? t.GetString() ?? "biped" : "biped";
                if (plan == "biped") RelaxArms(bones);
                else LowerArms(bones);
                var byName = new Dictionary<string, Bone>();
                foreach (Bone b in bones) byName[b.name] = b;
                var rows = new GArray<Variant>();
                foreach (Bone b in bones)
                {
                    Transform3D x = ToRig(b, byName);
                    var xform = Gd.Arr(x.basis.R0.x, x.basis.R1.x, x.basis.R2.x, x.basis.R0.y, x.basis.R1.y, x.basis.R2.y,
                        x.basis.R0.z, x.basis.R1.z, x.basis.R2.z, x.origin.x, x.origin.y, x.origin.z);
                    rows.Append(new GDict { { "name", b.name }, { "xform", xform }, { "head", Gd.Arr(b.head.x, b.head.y, b.head.z) } });
                }
                dump[name] = new GDict { { "voxel", voxel }, { "bones", rows } };
            }
        }
        File.WriteAllBytes(outPath, new UTF8Encoding(false).GetBytes(GodotJson.Stringify(dump)));
        System.Console.WriteLine($"dumped {dump.Size()} rigs");
        return 0;
    }
}
