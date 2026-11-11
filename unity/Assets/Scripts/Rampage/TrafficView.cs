using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using S = Kaiju.Sim;

// The moving cars on screen (scenes/traffic_meshes.gd, and traffic.gd's views): one mesh per paint and the police
// cruiser twice, its light bar lit red, then blue; one instanced draw per mesh. Traffic moves them; a flattened car
// is drawn squashed. Presentation only (hard rule 3).
public sealed class TrafficView
{
    // Graphics.DrawMeshInstanced's most per call.
    const int BATCH = 1023;
    // Hex colour strings in data/tuning.json.
    const int HEX = 16;
    const float PROP_VOXEL = StreetDecor.PROP_VOXEL;

    readonly Traffic traffic;
    readonly Material material;
    readonly Mesh[] meshes;
    readonly List<Matrix4x4[]>[] batches;
    readonly int[] counts;
    readonly Plane[] planes = new Plane[6];
    readonly float viewMargin;
    readonly Vector3 crushed;

    public int Drawn { get; private set; }

    public TrafficView(Traffic traffic, S.RampageSim sim, Shader shader)
    {
        this.traffic = traffic;
        S.GDict cfg = S.Content.Section("street");
        viewMargin = (float)S.Num.F(cfg["view_margin"]);
        S.GArray<S.Variant> squash = cfg["car_crushed"];
        crushed = new Vector3((float)S.Num.F(squash[0]), (float)S.Num.F(squash[1]), (float)S.Num.F(squash[2]));
        material = ArmyView.PlainMaterial(shader, PROP_VOXEL);
        material.enableInstancing = true;
        // The lit cells' glow (traffic_meshes.gd LIGHT_GLOW); only they have vertex alpha 0.
        material.SetFloat("_WindowGlow", (float)S.Num.F(cfg["police_glow"]));
        S.GArray<S.Variant> colors = sim.city["car_colors"];
        int paints = traffic.paints;
        meshes = new Mesh[paints + 2];
        // Car cells span z -3..2: Godot's bake shifts them half a cell to +z (its origin), Faces takes it as -pivot.
        var pivot = new Vector3(0f, 0f, -PROP_VOXEL * 0.5f);
        for (int i = 0; i < paints; i++)
            meshes[i] = ArmyView.Faces(PropTiles.Model(StreetDecor.Car(Rgb(colors[i]), false)), PROP_VOXEL, pivot);
        S.GDict paint = cfg["police_paint"];
        for (int lit = 0; lit < 2; lit++) meshes[paints + lit] = Police(paint, lit, pivot);
        batches = new List<Matrix4x4[]>[meshes.Length];
        for (int i = 0; i < meshes.Length; i++) batches[i] = new List<Matrix4x4[]>();
        counts = new int[meshes.Length];
    }

    static int Rgb(S.Variant hex) => Convert.ToInt32(S.Gd.Str(hex), HEX);

    // A lit colour given as [r, g, b] floats (Godot's Color(r, g, b, 0)).
    static int Rgb(S.GArray<S.Variant> rgb)
    {
        var c = new Color((float)S.Num.F(rgb[0]), (float)S.Num.F(rgb[1]), (float)S.Num.F(rgb[2]));
        return Convert.ToInt32(ColorUtility.ToHtmlStringRGB(c), HEX);
    }

    // traffic_meshes.gd police: the car in police white, its lowest body row dark, and the light bar on the roof,
    // red lit (lit 0) or blue lit (lit 1).
    static Mesh Police(S.GDict paint, int lit, Vector3 pivot)
    {
        int white = Rgb(paint["police"]), low = Rgb(paint["police_low"]);
        Dictionary<Vector3Int, int> car = StreetDecor.Car(white, false);
        var cells = new Dictionary<Vector3Int, int>();
        foreach (KeyValuePair<Vector3Int, int> cell in car)
            cells[cell.Key] = cell.Value == white && cell.Key.y == 0 ? low : cell.Value;
        var red = new Vector3Int(-1, 3, 0);
        var blue = new Vector3Int(1, 3, 0);
        S.GArray<S.Variant> redLit = paint["red_lit"], blueLit = paint["blue_lit"];
        cells[red] = lit == 0 ? Rgb(redLit) : Rgb(paint["red"]);
        cells[new Vector3Int(0, 3, 0)] = Rgb(paint["bar"]);
        cells[blue] = lit == 0 ? Rgb(paint["blue"]) : Rgb(blueLit);
        Vector3Int glowing = lit == 0 ? red : blue;
        // PropTiles.Model keeps the dictionary's order, so the glow flags follow it.
        var glow = new bool[cells.Count];
        int i = 0;
        foreach (Vector3Int at in cells.Keys) glow[i++] = at == glowing;
        return ArmyView.Faces(PropTiles.Model(cells), PROP_VOXEL, pivot, glow);
    }

    // Every car the camera sees, one instanced draw per mesh (traffic.gd's per-car views).
    public void Draw(Camera cam)
    {
        GeometryUtility.CalculateFrustumPlanes(cam, planes);
        Array.Clear(counts, 0, counts.Length);
        Drawn = 0;
        foreach (Traffic.Car car in traffic.cars)
        {
            var at = new Vector3((float)car.pos.x, 0f, -(float)car.pos.y);
            bool seen = true;
            for (int k = 0; k < 6 && seen; k++) seen = planes[k].GetDistanceToPoint(at) > -viewMargin;
            if (!seen) continue;
            int bucket = car.police ? traffic.paints + car.mesh : car.mesh;
            int n = counts[bucket]++;
            if (n / BATCH >= batches[bucket].Count) batches[bucket].Add(new Matrix4x4[BATCH]);
            // Godot's rotation.y turns -z toward (-sin, -cos); Unity's mirrored z turns the other way.
            Quaternion turn = Quaternion.Euler(0f, -car.yaw * Mathf.Rad2Deg, 0f);
            batches[bucket][n / BATCH][n % BATCH] = Matrix4x4.TRS(at, turn, car.crushed ? crushed : Vector3.one);
            Drawn++;
        }
        for (int bucket = 0; bucket < counts.Length; bucket++)
            for (int from = 0; from < counts[bucket]; from += BATCH)
                Graphics.DrawMeshInstanced(meshes[bucket], 0, material, batches[bucket][from / BATCH], Mathf.Min(BATCH, counts[bucket] - from), null, ShadowCastingMode.On, true);
    }

    public void Dispose()
    {
        foreach (Mesh mesh in meshes)
            if (mesh != null) UnityEngine.Object.Destroy(mesh);
        UnityEngine.Object.Destroy(material);
    }
}
