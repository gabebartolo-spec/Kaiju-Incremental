using System.Collections.Generic;
using UnityEngine;
using S = Kaiju.Sim;

// Time's up (scenes/airstrike_view.gd, D-263): the sim's airstrike event flies `jets` olive jets in a V from
// `from` to `to` in `seconds` at `altitude`. The bombs are EventFx's (airstrike_bomb). It reads the event and
// decides nothing. Positions are in Godot axes; z flips where the transform is written.
public sealed class AirstrikeView : System.IDisposable
{
    // scenes/airstrike_view.gd BASE.
    const string PARTS = "res://assets/vehicles/jet.parts.json", FOLDER = "res://assets/vehicles/", PART = "body";

    sealed class Jet
    {
        public Transform body;
        public S.Vector2 from, to, offset;
        public float altitude, seconds, gone;
        public bool lead, overhead;
    }

    readonly S.RampageSim sim;
    readonly Mesh mesh;
    readonly Material material;
    readonly Transform root;
    readonly float spacing;
    readonly List<Jet> jets = new List<Jet>();
    float clock;

    // Jets flown so far, and those in the air now.
    public int Flown { get; private set; }
    public int Live => jets.Count;

    static float F(S.GDict d, string key) => (float)(double)S.Num.F(d[key]);

    public AirstrikeView(S.RampageSim sim, Shader lit, Transform parent)
    {
        this.sim = sim;
        root = new GameObject("airstrike").transform;
        root.SetParent(parent, false);
        S.GDict vehicles = S.Content.Section("vehicles");
        S.GDict parts = S.Content.LoadJson(PARTS);
        spacing = F(vehicles, "jet_spacing");
        // scenes/vehicle_parts.gd: one voxel's size, and the part's hinge; the jet is centred on it, feet at y 0.
        float voxel = F(vehicles, "jet_height") / Mathf.Max(1f, F(parts, "height") - 1f);
        S.GDict all = parts["parts"];
        S.GDict entry = all[PART];
        S.GArray<S.Variant> p = entry["pivot"];
        var centre = new Vector3((float)(double)S.Num.F(p[0]), 0f, (float)(double)S.Num.F(p[2])) * voxel;
        mesh = ArmyView.Faces(ModelColors.Read(FOLDER + S.Gd.Str(entry["kvox"])), voxel, centre);
        material = ArmyView.PlainMaterial(lit, voxel);
    }

    public void OnEvent(S.GDict e)
    {
        if (S.Gd.Str(e["type"]) != "airstrike") return;
        S.Vector2 a = e["from"];
        S.Vector2 b = e["to"];
        float altitude = F(e, "altitude"), seconds = F(e, "seconds");
        long count = S.Num.I(e["jets"]);
        S.Vector2 along = (b - a).Normalized();
        // Godot's yaw atan2(-along.x, -along.y) turns the model's -Z along the run; mirrored, that is Unity's +Z.
        var ahead = new Vector3((float)along.x, 0f, -(float)along.y);
        Quaternion heading = ahead.sqrMagnitude > 0f ? Quaternion.LookRotation(ahead) : Quaternion.identity;
        for (long i = 0; i < count; i++)
        {
            var go = new GameObject("jet");
            go.transform.SetParent(root, false);
            go.AddComponent<MeshFilter>().sharedMesh = mesh;
            go.AddComponent<MeshRenderer>().sharedMaterial = material;
            var jet = new Jet { body = go.transform, from = a, to = b, offset = AirstrikePath.Offset(a, b, spacing, i), altitude = altitude, seconds = seconds, lead = i == 0 };
            go.transform.rotation = heading;
            Place(jet, 0.0);
            jets.Add(jet);
            Flown++;
            Debug.Log($"airstrike jet {i} starts {jet.offset.x:F2},{jet.offset.y:F2} from the lead");
        }
        Debug.Log($"airstrike: {count} jets from {a.x:F1},{a.y:F1} to {b.x:F1},{b.y:F1} in {seconds:F2}s at {altitude:F1}, kaiju {sim.kaijuPos.x:F1},{sim.kaijuPos.y:F1}, view clock {clock:F3}");
    }

    S.Vector2 Place(Jet jet, double share)
    {
        S.Vector2 at = AirstrikePath.At(jet.from, jet.to, jet.offset, share);
        jet.body.position = new Vector3((float)at.x, jet.altitude, -(float)at.y);
        return at;
    }

    public void Step(float dt)
    {
        clock += dt;
        for (int i = jets.Count - 1; i >= 0; i--)
        {
            Jet jet = jets[i];
            jet.gone += dt;
            double share = AirstrikePath.Share(jet.gone, jet.seconds);
            if (share >= 1.0)
            {
                Object.Destroy(jet.body.gameObject);
                jets.RemoveAt(i);
                if (jets.Count == 0) Debug.Log($"airstrike: last jet gone, view clock {clock:F3}");
                continue;
            }
            S.Vector2 at = Place(jet, share);
            if (!jet.lead || jet.overhead || share < 0.5) continue;
            // The lead passes over the kaiju: logged here; RampageAudio.Jets plays its sonic_boom.
            jet.overhead = true;
            double off = at.DistanceTo(sim.kaijuPos), frame = jet.from.DistanceTo(jet.to) / System.Math.Max(0.01, jet.seconds) * dt;
            Debug.Log($"airstrike lead overhead at {at.x:F1},{at.y:F1} y {jet.altitude:F1}: {off:F2} m from the kaiju, one frame is {frame:F2} m, view clock {clock:F3}");
        }
    }

    public void Dispose()
    {
        Object.Destroy(mesh);
        Object.Destroy(material);
    }
}
