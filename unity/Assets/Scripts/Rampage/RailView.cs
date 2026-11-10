using System.Collections.Generic;
using UnityEngine;
using S = Kaiju.Sim;

// The railway's trains on screen: scenes/rail_view.gd (one model per car, posed from the sim each frame; the
// derailment's chunks, flash, fire and shake) and scenes/train_model.gd (the voxel car). The viaduct and the
// station are city buildings, drawn and broken by CityDraw. It reads the sim and its events and never decides
// an outcome. Positions arrive in Godot axes; z flips at the Unity boundary.
public sealed class RailView : System.IDisposable
{
    // scenes/rail_view.gd FLOOR: the car's floor over the sim's height (the rails and sleepers under it).
    const float FLOOR = 0.5f;
    // scenes/train_model.gd CAR_VOXEL.
    const float CAR_VOXEL = 0.125f;
    // scenes/rail_view.gd on_event and _derailed.
    const int DERAIL_CHUNKS = 10, STATION_CHUNKS = 10, TRACK_CHUNKS = 6;
    const float DERAIL_CHUNK_LIFT = 0.5f, DERAIL_LIGHT = 9f, DERAIL_LIGHT_S = 0.6f, DERAIL_FIRE = 0.7f;
    const float TRACK_LIGHT = 4f, TRACK_LIGHT_S = 0.25f;
    static readonly Color DERAIL_FLASH = Hex("ffb35a"), TRACK_FLASH = Hex("ffd27a");
    // scenes/train_model.gd _bogies: half a bogie's length in cells, and how far in from its ends the wheels sit.
    const int BOGIE_HALF = 4, WHEEL_AT = 3;

    readonly S.RampageSim sim;
    readonly CityFx fx;
    readonly ArmyView army;
    readonly Material material;
    readonly Transform root;
    readonly System.Action<Vector3> kick;
    readonly S.GDict colors;
    readonly Mesh locoMesh, carriageMesh;
    readonly Dictionary<long, Transform[]> cars = new Dictionary<long, Transform[]>();
    readonly HashSet<long> seen = new HashSet<long>();
    readonly List<long> gone = new List<long>();
    readonly int nl, nw, nh;

    // Trains and cars with a model now, and derailments drawn so far.
    public int Trains => cars.Count;
    public int Cars { get; private set; }
    public int Derails { get; private set; }

    static Color Hex(string hex)
    {
        ColorUtility.TryParseHtmlString("#" + hex, out Color c);
        return c;
    }

    // Godot basis M becomes S M S (S mirrors z), as ArmyView.Mirrored.
    static Quaternion Mirrored(S.Basis m)
    {
        S.Vector3 f = m * new S.Vector3(0, 0, -1);
        S.Vector3 u = m * new S.Vector3(0, 1, 0);
        return Quaternion.LookRotation(new Vector3((float)f.x, (float)f.y, -(float)f.z), new Vector3((float)u.x, (float)u.y, -(float)u.z));
    }

    public RailView(S.RampageSim sim, CityFx fx, ArmyView army, Shader shader, Transform parent, System.Action<Vector3> kick)
    {
        this.sim = sim;
        this.fx = fx;
        this.army = army;
        this.kick = kick;
        root = new GameObject("rail").transform;
        root.SetParent(parent, false);
        S.GDict look = S.Content.Section("rail_look");
        colors = look["colors"];
        S.GArray<S.Variant> size = look["car_size"];
        nl = Mathf.RoundToInt((float)(double)S.Num.F(sim.rail.cfg["car_length"]) / CAR_VOXEL);
        nw = Mathf.RoundToInt((float)(double)S.Num.F(size[0]) / CAR_VOXEL);
        nh = Mathf.RoundToInt((float)(double)S.Num.F(size[1]) / CAR_VOXEL);
        material = ArmyView.PlainMaterial(shader, CAR_VOXEL);
        locoMesh = Car(true);
        carriageMesh = Car(false);
    }

    // ---------- The car (scenes/train_model.gd) ----------

    int Rgb(string key) => System.Convert.ToInt32(S.Gd.Str(colors[key]), 16);

    Color Paint(string key) => Hex(S.Gd.Str(colors[key]));

    // One car, centred on its middle at its floor, facing Godot +z: a box body with detail. The inside is filled
    // too (Godot keeps the shell): ArmyView.Faces drops every face between two cells.
    Mesh Car(bool loco)
    {
        var xyz = new List<int>();
        var rgb = new List<int>();
        // The headlamps glow: vertex alpha 0, the city's convention (ArmyView.Faces' glow cells).
        var glow = new List<bool>();
        for (int z = 0; z < nl; z++)
            for (int y = 0; y < nh; y++)
                for (int x = 0; x < nw; x++)
                {
                    bool lamp = loco && z == nl - 1 && y != nh - 1 && Headlamp(x, y);
                    Put(xyz, rgb, x - nw / 2, y + 2, z - nl / 2, lamp ? Rgb("headlamp") : CarCell(x, y, z, loco));
                    glow.Add(lamp);
                }
        Bogies(xyz, rgb);
        // The bogies' cells come after the body's and never glow.
        while (glow.Count < rgb.Count) glow.Add(false);
        return ArmyView.Faces(Model(xyz, rgb), CAR_VOXEL, Vector3.zero, glow.ToArray());
    }

    static void Put(List<int> xyz, List<int> rgb, int x, int y, int z, int color)
    {
        xyz.Add(x);
        xyz.Add(y);
        xyz.Add(z);
        rgb.Add(color);
    }

    static ModelColors.Model Model(List<int> xyz, List<int> rgb)
    {
        var model = new ModelColors.Model { xyz = new S.PackedInt32Array(), rgb = rgb.ToArray() };
        model.xyz.Resize(xyz.Count);
        int[] raw = model.xyz.Raw;
        for (int i = 0; i < xyz.Count; i++) raw[i] = xyz[i];
        return model;
    }

    // _car_cell: the roof, the locomotive's cab at its front, else a side or end cell.
    int CarCell(int x, int y, int z, bool loco)
    {
        if (y == nh - 1) return Rgb((x + z) % 7 != 0 ? "roof" : "roof_gear");
        if (loco && z == nl - 1) return CabCell(x, y);
        return SideCell(y, z);
    }

    // _side_cell: doors, the window band, the livery stripe, the skirt, panel seams.
    int SideCell(int y, int z)
    {
        int door = z % 16;
        if (door >= 6 && door <= 9 && y >= 2 && y <= nh - 2) return Rgb(door == 7 || door == 8 ? "door" : "door_frame");
        if (y >= nh - 5 && y <= nh - 2) return Rgb(z % 6 != 0 ? "glass" : "body");
        if (y == nh - 6 || y == nh - 7) return Rgb("stripe");
        if (y <= 1) return Rgb("skirt");
        return Rgb(z % 10 != 0 ? "body" : "seam");
    }

    // _cab_cell: the windscreen, the stripe, the body (the headlamps are Headlamp's).
    int CabCell(int x, int y)
    {
        if (y >= nh - 5 && y <= nh - 2 && x > 0 && x < nw - 1) return Rgb("glass");
        return Rgb(y == nh - 6 || y == nh - 7 ? "stripe" : "body");
    }

    // _cab_cell's two glowing headlamps (the windscreen comes first there, so it wins where they meet).
    bool Headlamp(int x, int y)
    {
        if (y >= nh - 5 && y <= nh - 2 && x > 0 && x < nw - 1) return false;
        return y == 3 && (x == 1 || x == nw - 2);
    }

    // _bogies: two dark bogies under the car with wheels.
    void Bogies(List<int> xyz, List<int> rgb)
    {
        int bogie = Rgb("bogie"), wheelColor = Rgb("wheel");
        foreach (int centre in new[] { -nl / 3, nl / 3 })
            for (int z = centre - BOGIE_HALF; z <= centre + BOGIE_HALF; z++)
                for (int x = -nw / 2 + 1; x < nw / 2 - 1; x++)
                {
                    bool wheel = (z == centre - WHEEL_AT || z == centre + WHEEL_AT) && (x == -nw / 2 + 1 || x == nw / 2 - 2);
                    Put(xyz, rgb, x, 1, z, wheel ? wheelColor : bogie);
                    if (wheel) Put(xyz, rgb, x, 0, z, wheelColor);
                }
    }

    // ---------- Per frame (rail_view.gd _process) ----------

    public void Update()
    {
        seen.Clear();
        foreach (S.Rail.Train train in sim.rail.trains)
        {
            seen.Add(train.id);
            if (!cars.TryGetValue(train.id, out Transform[] nodes)) cars[train.id] = nodes = Build(train);
            for (int i = 0; i < nodes.Length; i++) Pose(nodes[i], train.cars[i]);
        }
        gone.Clear();
        foreach (long id in cars.Keys)
            if (!seen.Contains(id)) gone.Add(id);
        foreach (long id in gone)
        {
            foreach (Transform node in cars[id]) Object.Destroy(node.gameObject);
            Cars -= cars[id].Length;
            cars.Remove(id);
        }
    }

    Transform[] Build(S.Rail.Train train)
    {
        var nodes = new Transform[(int)train.cars.Size()];
        for (int i = 0; i < nodes.Length; i++)
        {
            var go = new GameObject(train.cars[i].loco ? "loco" : "carriage");
            go.transform.SetParent(root, false);
            go.AddComponent<MeshFilter>().sharedMesh = train.cars[i].loco ? locoMesh : carriageMesh;
            go.AddComponent<MeshRenderer>().sharedMaterial = material;
            nodes[i] = go.transform;
        }
        Cars += nodes.Length;
        S.Vector2 lead = train.cars[0].pos;
        Debug.Log($"rail: train {train.id} dir {train.dir}, {nodes.Length} cars at {lead.x:F1},{lead.y:F1}");
        return nodes;
    }

    // _pose: yaw, then roll about the car's length (Godot's Vector3.BACK).
    static void Pose(Transform node, S.Rail.Car car)
    {
        S.Basis basis = new S.Basis(S.Vector3.UP, car.yaw) * new S.Basis(new S.Vector3(0, 0, 1), car.roll);
        node.SetPositionAndRotation(new Vector3((float)car.pos.x, (float)car.y + FLOOR, -(float)car.pos.y), Mirrored(basis));
    }

    // ---------- Events (rail_view.gd on_event) ----------

    public void OnEvent(S.GDict e)
    {
        switch (S.Gd.Str(e["type"]))
        {
            case "train_derailed": Derailed(e); break;
            case "station_broken":
                army.Chunks(Deck(e["at"]), STATION_CHUNKS, Paint("canopy"), Paint("canopy"));
                break;
            case "track_broken":
                Vector3 at = Deck(e["at"]);
                army.Chunks(at, TRACK_CHUNKS, Paint("concrete"), Paint("concrete"));
                fx.FlashLight(at, TRACK_FLASH, TRACK_LIGHT, TRACK_LIGHT_S);
                break;
        }
    }

    Vector3 Deck(S.Vector2 at) => new Vector3((float)at.x, (float)sim.rail.deckY, (float)at.y);

    // _derailed: debris and a flash where the train left the rail, fire, and the shake of a topple.
    void Derailed(S.GDict e)
    {
        var pos = new Vector3((float)(double)S.Num.F(e["x"]), (float)sim.rail.deckY + FLOOR, (float)(double)S.Num.F(e["z"]));
        army.Chunks(pos + Vector3.up * DERAIL_CHUNK_LIFT, DERAIL_CHUNKS, Paint("stripe"), Paint("body"));
        fx.FlashLight(pos, DERAIL_FLASH, DERAIL_LIGHT, DERAIL_LIGHT_S);
        fx.Fire(pos, DERAIL_FIRE);
        kick?.Invoke(pos);
        Derails++;
        Debug.Log($"rail: derail {Derails} train {S.Num.I(e["train"])} at {pos.x:F1},{pos.z:F1} frame {Time.frameCount}, fires {fx.LiveFires}");
    }

    public void Dispose()
    {
        Object.Destroy(locoMesh);
        Object.Destroy(carriageMesh);
        Object.Destroy(material);
    }
}
