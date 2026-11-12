using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;
using S = Kaiju.Sim;

// The police on screen that are not people or cars (scenes/police.gd _ready and _draw_flashes, pooled_light.gd): the
// muzzle flashes, one instanced draw of glowing cubes, and each blockade's beacon, a pooled point light (LightPool)
// that swaps red and blue. Police decides everything; this only draws it. Presentation only (hard rule 3).
public sealed class PoliceView
{
    sealed class Beacon
    {
        public GameObject go;
        public Light light;
        public LightPool.Slot slot;
    }

    // Hex colour strings.
    const int HEX = 16;

    readonly Police police;
    readonly Mesh flash;
    readonly Material material;
    readonly Matrix4x4[] spots;
    readonly Dictionary<Police.Blockade, Beacon> beacons = new Dictionary<Police.Blockade, Beacon>();
    readonly List<Police.Blockade> gone = new List<Police.Blockade>();
    readonly Transform parent;
    readonly LightPool pool;
    readonly float candela, sirenHeight, sirenRange, fadeDistance;
    readonly Color red, blue;

    public PoliceView(Police police, Shader shader, Transform parent, LightPool pool, float exposureUnit, float lightMatch)
    {
        this.pool = pool;
        this.police = police;
        this.parent = parent;
        S.GDict cfg = S.Content.Section("street");
        S.GDict lights = S.Content.Section("lights");
        S.GDict fade = lights["beacon"];
        float voxel = (float)S.Num.F(cfg["person_voxel"]);
        float side = voxel * (float)S.Num.F(cfg["muzzle_size"]);
        spots = new Matrix4x4[(int)S.Num.F(cfg["muzzle_max"])];
        Color glow = Rgb(cfg["muzzle_color"]);
        // One cell, all faces glowing (vertex alpha 0), centred on its origin as Godot's BoxMesh.
        var cell = new Dictionary<Vector3Int, int> { [Vector3Int.zero] = Hex(glow) };
        flash = ArmyView.Faces(PropTiles.Model(cell), side, new Vector3(0f, 0.5f * side, 0f), new[] { true });
        material = ArmyView.PlainMaterial(shader, side);
        material.enableInstancing = true;
        material.SetFloat("_WindowGlow", (float)S.Num.F(cfg["muzzle_glow"]));
        candela = (float)S.Num.F(cfg["siren_energy"]) * Mathf.PI * exposureUnit * lightMatch;
        sirenHeight = (float)S.Num.F(cfg["siren_height"]);
        sirenRange = (float)S.Num.F(cfg["siren_range"]);
        fadeDistance = (float)(S.Num.F(fade["fade_begin"]) + S.Num.F(fade["fade_length"]));
        red = Rgb(cfg["siren_red"]);
        blue = Rgb(cfg["siren_blue"]);
    }

    static Color Rgb(S.GArray<S.Variant> rgb) =>
        new Color((float)S.Num.F(rgb[0]), (float)S.Num.F(rgb[1]), (float)S.Num.F(rgb[2]));

    static int Hex(Color c) => System.Convert.ToInt32(ColorUtility.ToHtmlStringRGB(c), HEX);

    // Each blockade's beacon: made when it goes up, lit when the pool picks it, swaps colour with Police.Red,
    // gone when it ends.
    public void Step()
    {
        foreach (Police.Blockade b in police.blockades)
            if (!beacons.ContainsKey(b)) beacons[b] = Make(b);
        gone.Clear();
        foreach (KeyValuePair<Police.Blockade, Beacon> kv in beacons)
            if (!police.blockades.Contains(kv.Key)) gone.Add(kv.Key);
        foreach (Police.Blockade b in gone)
        {
            pool.Remove(beacons[b].slot);
            Object.Destroy(beacons[b].go);
            beacons.Remove(b);
        }
        Color now = police.Red ? red : blue;
        foreach (Beacon beacon in beacons.Values)
        {
            beacon.light.enabled = beacon.slot.weight > 0f;
            beacon.light.intensity = candela * beacon.slot.weight;
            beacon.light.color = now;
        }
    }

    Beacon Make(Police.Blockade b)
    {
        S.Vector2 line = police.Line(b);
        var go = new GameObject("police_beacon");
        go.transform.SetParent(parent, false);
        go.transform.localPosition = new Vector3((float)line.x, sirenHeight, -(float)line.y);
        Light light = go.AddComponent<Light>();
        light.type = LightType.Point;
        light.shadows = LightShadows.None;
        light.lightUnit = LightUnit.Candela;
        HDAdditionalLightData hd = go.AddComponent<HDAdditionalLightData>();
        hd.fadeDistance = fadeDistance;
        light.range = sirenRange;
        light.intensity = 0f;
        LightPool.Slot slot = pool.Add();
        Vector3 at = go.transform.position;
        slot.x = at.x;
        slot.y = at.y;
        slot.z = at.z;
        slot.energy = candela;
        return new Beacon { go = go, light = light, slot = slot };
    }

    // The lit flashes, one instanced draw (police.gd's MultiMesh).
    public void Draw()
    {
        int n = Mathf.Min(police.shown.Count, spots.Length);
        if (n == 0) return;
        for (int i = 0; i < n; i++)
        {
            S.Vector3 at = police.shown[i];
            spots[i] = Matrix4x4.Translate(new Vector3((float)at.x, (float)at.y, -(float)at.z));
        }
        Graphics.DrawMeshInstanced(flash, 0, material, spots, n, null, ShadowCastingMode.Off, false);
    }

    public void Dispose()
    {
        foreach (Beacon beacon in beacons.Values)
        {
            pool.Remove(beacon.slot);
            Object.Destroy(beacon.go);
        }
        beacons.Clear();
        Object.Destroy(flash);
        Object.Destroy(material);
    }
}
