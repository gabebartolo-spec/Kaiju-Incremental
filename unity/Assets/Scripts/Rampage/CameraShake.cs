using UnityEngine;
using Kaiju.Game;
using S = Kaiju.Sim;

// The gameplay camera's shake, scenes/camera_shake.gd: hits add trauma 0..1, the camera turns by trauma
// squared on smooth noise, rotation only, so the framing never drifts. Godot's simplex noise is Unity's
// Perlin here: the shape on screen is the same smooth wander, the exact values differ. The player's camera-motion
// setting (PlayerSettings.Motion(), read each frame as Godot does) scales the shake and the kick; the sizes are
// GameLogic/ShakeMotion.cs. Presentation only.
public sealed class CameraShake
{
    const float NOISE_ROW_A = 0.37f, NOISE_ROW_B = 100.37f, NOISE_SEED_SPAN = 1000f;

    readonly S.GDict cfg, sources;
    readonly float decay, kickS, rise, gain, hz, near, far, seedAt;
    float trauma, shown, time, kick, kickLeft;

    static float F(S.GDict c, string key) => (float)S.Num.F(c[key]);

    public CameraShake()
    {
        cfg = S.Content.Section("camera_shake");
        sources = (S.GDict)cfg["sources"];
        decay = F(cfg, "decay_per_s");
        kickS = F(cfg, "kick_s");
        rise = F(cfg, "rise_per_s");
        gain = F(cfg, "noise_gain");
        hz = F(cfg, "noise_hz");
        near = F(cfg, "near_per_scale");
        far = F(cfg, "far_per_scale");
        seedAt = Mathf.Repeat(F(cfg, "noise_seed"), NOISE_SEED_SPAN);
        Debug.Log($"camera shake: motion {motion:F2} (setting {PlayerSettings.CameraMotion:F2}, -1 = tuning default)");
    }

    // The player's camera-motion setting now (0..1): the post effects and the follow camera's dip read it here too.
    public float motion => (float)PlayerSettings.Motion();

    // A named source at the kaiju: full strength.
    public void Add(string source) => trauma = Mathf.Clamp01(trauma + F(sources, source));

    // A named source at `at`, faded by its distance from `focus` for a body of `scale`.
    public void AddAt(string source, Vector3 at, Vector3 focus, float scale)
    {
        float n = near * scale, f = Mathf.Max(far * scale, n + 0.001f);
        float fade = 1f - Mathf.Clamp01((Vector3.Distance(at, focus) - n) / (f - n));
        trauma = Mathf.Clamp01(trauma + F(sources, source) * fade);
    }

    // The same, the source's trauma times `mult` (scenes/slam_view.gd: source("slam") * strength).
    public void AddScaledAt(string source, float mult, Vector3 at, Vector3 focus, float scale)
    {
        float n = near * scale, f = Mathf.Max(far * scale, n + 0.001f);
        float fade = 1f - Mathf.Clamp01((Vector3.Distance(at, focus) - n) / (f - n));
        trauma = Mathf.Clamp01(trauma + F(sources, source) * mult * fade);
    }

    public void Kick(float rad)
    {
        kick = rad;
        kickLeft = kickS;
    }

    public void Update(float dt)
    {
        kickLeft = Mathf.Max(0f, kickLeft - dt);
        time += dt;
        trauma = Mathf.Max(0f, trauma - decay * dt);
        float goal = trauma * trauma;
        shown = goal < shown ? goal : Mathf.MoveTowards(shown, goal, rise * dt);
    }

    // This frame's turn in radians: x yaw, y pitch (up positive).
    public Vector2 Turn(float scale)
    {
        float m = motion;
        Vector2 nod = new Vector2(0f, -(float)ShakeMotion.Nod(kick, kickLeft / kickS, m));
        float amp = (float)ShakeMotion.Amplitude(cfg, scale, shown, m);
        if (amp <= 0f) return nod;
        float t = time * hz + seedAt;
        Vector2 wave = new Vector2(Mathf.PerlinNoise(t, NOISE_ROW_A) * 2f - 1f, Mathf.PerlinNoise(t, NOISE_ROW_B) * 2f - 1f);
        return Vector2.ClampMagnitude(wave * gain, 1f) * amp + nod;
    }

    // Turns `camera`, already aimed. Unity pitches down for a positive turn about its right.
    public void Apply(Transform camera, float scale)
    {
        Vector2 a = Turn(scale);
        if (a == Vector2.zero) return;
        camera.Rotate(Vector3.up, a.x * Mathf.Rad2Deg, Space.World);
        camera.Rotate(Vector3.right, -a.y * Mathf.Rad2Deg, Space.Self);
    }
}
