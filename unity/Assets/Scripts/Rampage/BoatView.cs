using System.Collections.Generic;
using UnityEngine;
using S = Kaiju.Sim;

// Draws the boats (scenes/boat_view.gd, D-404): one voxel mesh per model, shared by every boat of it (a boat only
// ever moves whole), posed each frame from Boats with the kaiju where the sim has him. Reads the sim, decides
// nothing. Positions and bases arrive in Godot axes; z flips here.
public sealed class BoatView
{
    public readonly Boats boats;
    readonly Material material;
    readonly Dictionary<string, Mesh> meshes = new Dictionary<string, Mesh>();
    readonly List<Transform> nodes = new List<Transform>();
    readonly List<S.Vector2> moored = new List<S.Vector2>();
    readonly S.RampageSim sim;
    double maxRoll;

    public BoatView(S.RampageSim sim, Shader lit, Transform parent)
    {
        this.sim = sim;
        boats = new Boats(sim.city);
        float voxel = (float)S.Num.F(S.Content.Section("boats")["voxel"]);
        material = ArmyView.PlainMaterial(lit, voxel);
        var root = new GameObject("Boats").transform;
        root.SetParent(parent, false);
        for (int i = 0; i < boats.boats.Count; i++)
        {
            Boats.Boat b = boats.boats[i];
            var go = new GameObject(b.id + "_" + i);
            go.transform.SetParent(root, false);
            Mesh mesh = Mesh(b.id, voxel);
            if (mesh != null)
            {
                go.AddComponent<MeshFilter>().sharedMesh = mesh;
                go.AddComponent<MeshRenderer>().sharedMaterial = material;
            }
            nodes.Add(go.transform);
            moored.Add(b.pos);
            Place(i);
        }
    }

    Mesh Mesh(string id, float voxel)
    {
        if (meshes.TryGetValue(id, out Mesh mesh)) return mesh;
        ModelColors.Model model = ModelColors.Read(Boats.File(id));
        meshes[id] = mesh = model == null ? null : ArmyView.Faces(model, voxel, Vector3.zero);
        return mesh;
    }

    public void Step(float dt)
    {
        boats.Step(dt, sim.kaijuPos);
        for (int i = 0; i < nodes.Count; i++) Place(i);
    }

    void Place(int i)
    {
        Boats.Boat b = boats.boats[i];
        Transform node = nodes[i];
        if (node.gameObject.activeSelf != b.visible) node.gameObject.SetActive(b.visible);
        if (!b.visible) return;
        node.localPosition = new Vector3((float)b.at.x, (float)b.at.y, -(float)b.at.z);
        node.localRotation = Mirrored(b.basis);
        maxRoll = System.Math.Max(maxRoll, System.Math.Abs((b.basis * new S.Vector3(1f, 0f, 0f)).y));
    }

    // Godot basis M becomes S M S (S mirrors z): its -Z forward and +Y up, mirrored (ArmyView.Mirrored).
    static Quaternion Mirrored(S.Basis m)
    {
        S.Vector3 f = m * new S.Vector3(0f, 0f, -1f), u = m * new S.Vector3(0f, 1f, 0f);
        return Quaternion.LookRotation(new Vector3((float)f.x, (float)f.y, -(float)f.z), new Vector3((float)u.x, (float)u.y, -(float)u.z));
    }

    // Counts by mooring place, for the load line.
    public string Moored()
    {
        int pier = 0, bay = 0, river = 0;
        foreach (Boats.Boat b in boats.boats)
        {
            if (b.where == "pier") pier++;
            else if (b.where == "bay") bay++;
            else river++;
        }
        return $"{boats.boats.Count} moored (pier {pier}, bay {bay}, river {river}), {meshes.Count} meshes";
    }

    // How far the boats have drifted from their moorings, and how many he rolled over and sank, for the end line.
    public string Moved()
    {
        int moved = 0, sunk = 0;
        double most = 0.0;
        for (int i = 0; i < moored.Count; i++)
        {
            double d = boats.boats[i].pos.DistanceTo(moored[i]);
            most = System.Math.Max(most, d);
            moved += d > 0.0 ? 1 : 0;
            sunk += boats.boats[i].sunk ? 1 : 0;
        }
        return $"{moved} of {moored.Count} drifted (most {most:F2} u), rocked up to {System.Math.Asin(maxRoll) * Mathf.Rad2Deg:F1} deg, capsized {boats.capsized}, sunk {sunk}";
    }

    public void Dispose()
    {
        foreach (Mesh mesh in meshes.Values)
            if (mesh != null) Object.Destroy(mesh);
        Object.Destroy(material);
    }
}
