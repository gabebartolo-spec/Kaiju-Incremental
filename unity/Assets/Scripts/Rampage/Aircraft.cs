using System.Collections.Generic;
using UnityEngine;
using S = Kaiju.Sim;

// A few aircraft crossing the evening sky far off (scenes/aircraft.gd): blinking navigation lights, nothing
// more. Presentation only, part of the skyline; no sim input. Godot axes; z flips where the transform is written.
// The numbers are aircraft.gd's literals, held in StreamingAssets/tuning.json (aircraft_*).
public sealed class Aircraft : System.IDisposable
{
    sealed class Plane
    {
        public Transform body;
        public MeshRenderer light;
        public Vector3 at;
        public float way, speed, phase;
    }

    readonly Tuning tuning;
    readonly Material material;
    readonly Mesh red, white;
    readonly List<Plane> planes = new List<Plane>();
    float clock;

    public int Count => planes.Count;
    // Lights showing on this frame.
    public int Lit { get; private set; }

    static Color Hex(string hex)
    {
        ColorUtility.TryParseHtmlString("#" + hex, out Color c);
        return c;
    }

    public Aircraft(Tuning tuning, Shader lit, Transform parent, int seed)
    {
        this.tuning = tuning;
        Transform root = new GameObject("aircraft").transform;
        root.SetParent(parent, false);
        // Godot draws these from the skyline's stream after its last draw; here a stream of their own.
        S.RandomNumberGenerator rng = S.Seeds.Make("aircraft", seed);
        material = ArmyView.PlainMaterial(lit, 1f);
        red = Glow(Hex(tuning.aircraft_red));
        white = Glow(Hex(tuning.aircraft_white));
        var report = new System.Text.StringBuilder();
        for (int i = 0; i < tuning.aircraft_count; i++)
        {
            // aircraft.gd's order of draws: x, y, speed, phase.
            float x = (float)(double)rng.RandfRange(-tuning.aircraft_x_range, tuning.aircraft_x_range);
            float y = (float)(double)rng.RandfRange(tuning.aircraft_y_min, tuning.aircraft_y_max);
            var p = new Plane { at = new Vector3(x, y, tuning.aircraft_z_first + i * tuning.aircraft_z_step) };
            // rotation.y = PI/2 on the even ones and they move along -basis.z: even fly to -x, odd to +x.
            p.way = i % 2 == 0 ? -1f : 1f;
            p.speed = (float)(double)rng.RandfRange(tuning.aircraft_speed_min, tuning.aircraft_speed_max);
            p.phase = (float)(double)rng.Randf();
            var go = new GameObject("plane");
            go.transform.SetParent(root, false);
            go.transform.localScale = Vector3.one * tuning.aircraft_light_size;
            go.AddComponent<MeshFilter>().sharedMesh = i % 2 == 0 ? red : white;
            p.light = go.AddComponent<MeshRenderer>();
            p.light.sharedMaterial = material;
            p.light.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            p.body = go.transform;
            p.body.position = new Vector3(p.at.x, p.at.y, -p.at.z);
            planes.Add(p);
            report.Append($" {p.at.x:F1},{p.at.y:F1},{p.at.z:F1}");
        }
        Debug.Log($"aircraft: {planes.Count} lights at{report}");
    }

    // A unit cube that glows its own colour: vertex alpha 0 is the surface shader's lit window (ArmyView.Box).
    static Mesh Glow(Color color)
    {
        Color32 c = color;
        c.a = 0;
        var model = new ModelColors.Model { xyz = new S.PackedInt32Array(), rgb = new[] { c.r << 16 | c.g << 8 | c.b } };
        model.xyz.Resize(3);
        Mesh mesh = ArmyView.Faces(model, 1f, new Vector3(0f, 0.5f, 0f));
        var colors = new Color32[mesh.vertexCount];
        for (int i = 0; i < colors.Length; i++) colors[i] = c;
        mesh.SetColors(colors);
        return mesh;
    }

    public void Step(float dt)
    {
        clock += dt;
        Lit = 0;
        foreach (Plane p in planes)
        {
            p.at.x += p.way * p.speed * dt;
            if (Mathf.Abs(p.at.x) > tuning.aircraft_wrap_x) p.at.x = -Mathf.Sign(p.at.x) * tuning.aircraft_wrap_to;
            p.body.position = new Vector3(p.at.x, p.at.y, -p.at.z);
            bool on = Mathf.Repeat(clock + p.phase, tuning.aircraft_blink_period) < tuning.aircraft_blink_on;
            if (p.light.enabled != on) p.light.enabled = on;
            if (on) Lit++;
        }
    }

    public void Dispose()
    {
        Object.Destroy(red);
        Object.Destroy(white);
        Object.Destroy(material);
    }
}
