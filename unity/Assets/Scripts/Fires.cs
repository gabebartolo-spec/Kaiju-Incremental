using System;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;

[Serializable]
public sealed class FireSystem
{
    public float count, life, box, box_y, spread, rise, wind_share, y, queue;
    public float[] speed, scale, curve;
}

[Serializable]
public sealed class FireSpot
{
    public float x, y, z, size, seed;
}

// StreamingAssets/fire.json: the numbers of scenes/fire.gd and its shaders. Positions and the wind are Godot axes.
[Serializable]
public sealed class FireTuning
{
    public float[] wind, tongue, grow, half_w, light, flicker;
    public float tongue_lift, flame_height, flame_heat, alpha_in, alpha_out;
    public float ember_cube, ember_heat, smoke_quad_base, smoke_quad_per_size, smoke_quad_tall;
    public float near_clear, near_full, centre_keep, centre_radius, focus_clear, focus_full, soft_contact_m, softness;
    public float light_match_m, draw_bounds;
    public Color ember_start, ember_end, light_color;
    public Color[] smoke_ramp;
    public float[] smoke_ramp_at;
    public FireSystem flame, ember, smoke;
    public FireSpot[] spots;

    public static FireTuning Load()
    {
        return JsonUtility.FromJson<FireTuning>(File.ReadAllText(Path.Combine(Application.streamingAssetsPath, "fire.json")));
    }
}

// Burning fires, drawn by Shaders/Flame: each fire is one draw per system and one real point light.
// Presentation only: a fire's whole picture is a function of its place, its seed and the clock.
public sealed class Fires : IDisposable
{
    const int QUAD_VERTS = 6, CUBE_VERTS = 36;

    public sealed class Burning
    {
        public Vector3 at;
        public float seed, energy, fade = 1f, fadeRate, gone = float.PositiveInfinity;
        public bool isOut, showEmbers = true;
        public Light light;
        public Bounds bounds;
        public MaterialPropertyBlock flame, ember, smoke;
        public int flameCount, emberCount, smokeCount;
    }

    readonly FireTuning tuning;
    readonly float exposureUnit;
    readonly Material flameMat, emberMat, smokeMat;
    readonly List<Burning> fires = new List<Burning>();
    readonly Stack<Burning> free = new Stack<Burning>();
    float lastTime;
    // The share of each system's particles drawn (the graphics preset's particles, Godot's amount_ratio; 1 in the slice).
    public float particles = 1f;

    static readonly int TIME = Shader.PropertyToID("_FireTime");
    static readonly int FOCUS = Shader.PropertyToID("_SmokeFocus");
    static readonly int START = Shader.PropertyToID("_FireStart"), END = Shader.PropertyToID("_FireEnd");
    // Longer than any game: a fire that never starts or stops inside the clock.
    const float ALWAYS = 1e7f;

    public Fires(FireTuning tuning, Shader shader, float exposureUnit, bool spots = true)
    {
        this.tuning = tuning;
        this.exposureUnit = exposureUnit;
        flameMat = Make(shader, "FIRE_FLAME", tuning.flame);
        emberMat = Make(shader, "FIRE_EMBER", tuning.ember);
        smokeMat = Make(shader, "FIRE_SMOKE", tuning.smoke);
        var ramp = new Vector4[tuning.smoke_ramp.Length];
        for (int i = 0; i < ramp.Length; i++) ramp[i] = tuning.smoke_ramp[i];
        Shader.SetGlobalVectorArray("_SmokeRamp", ramp);
        float[] at = tuning.smoke_ramp_at;
        Shader.SetGlobalVector("_SmokeRampAt", new Vector4(at[0], at[1], at[2], at[3]));
        Shader.SetGlobalVector("_SmokeClear", new Vector4(tuning.near_clear, tuning.near_full, tuning.centre_keep, tuning.centre_radius));
        Shader.SetGlobalVector("_SmokeBody", new Vector4(tuning.softness, 0, 0, 0));
        Shader.SetGlobalVector("_EmberStart", tuning.ember_start);
        Shader.SetGlobalVector("_EmberEnd", tuning.ember_end);
        Shader.SetGlobalFloat("_FlameHeat", tuning.flame_heat);
        Shader.SetGlobalFloat("_EmberHeat", tuning.ember_heat);
        if (spots) foreach (FireSpot spot in tuning.spots) Add(spot, -ALWAYS);
    }

    // A system's particles for a fire of `size`, at the preset's share (never under one).
    float Amount(FireSystem s, float size) => Mathf.Max(1f, Mathf.Round(s.count * Mathf.Max(1f, size) * particles));

    static Material Make(Shader shader, string keyword, FireSystem system)
    {
        var mat = new Material(shader) { renderQueue = (int)system.queue };
        mat.EnableKeyword(keyword);
        return mat;
    }

    // Unity's world is Godot's with z negated.
    static Vector3 Flip(Vector3 v) => new Vector3(v.x, v.y, -v.z);

    // A fire starting now, Godot axes (scenes/city_view.gd fire).
    public Burning Light(Vector3 at, float size, float seed, float time)
    {
        return Add(new FireSpot { x = at.x, y = at.y, z = at.z, size = size, seed = seed }, time);
    }

    // scenes/fire.gd go_out: no new particles, those in the air finish; the light fades over `fade`.
    public void GoOut(Burning fire, float fade, float time)
    {
        if (fire.isOut) return;
        fire.isOut = true;
        Stop(fire.flame, time);
        Stop(fire.ember, time);
        Stop(fire.smoke, time);
        if (fade > 0f)
        {
            fire.showEmbers = false;
            fire.fadeRate = 1f / fade;
        }
        else
        {
            fire.fade = 0f;
        }
        fire.gone = time + Mathf.Max(tuning.smoke.life, fade);
    }

    static void Stop(MaterialPropertyBlock block, float time) => block.SetFloat(END, time);

    Burning Add(FireSpot spot, float start)
    {
        float size = spot.size;
        float[] g = tuning.grow;
        float grow = Mathf.Clamp(g[0] + g[1] * size, g[2], g[3]);
        Burning burning = free.Count > 0 ? free.Pop() : new Burning();
        burning.at = Flip(new Vector3(spot.x, spot.y, spot.z));
        burning.seed = spot.seed;
        burning.fade = 1f;
        burning.fadeRate = 0f;
        burning.gone = float.PositiveInfinity;
        burning.isOut = false;
        burning.showEmbers = true;
        burning.bounds = new Bounds(burning.at, Vector3.one * tuning.draw_bounds);

        burning.flame = Block(burning.flame, burning, tuning.flame, size, grow, start);
        burning.flame.SetVector("_FireQuad", new Vector4(tuning.tongue[0] * grow, tuning.tongue[1] * grow, tuning.tongue_lift, 0));
        burning.flame.SetVector("_FireFlame", new Vector4(burning.at.y + tuning.flame.y, tuning.flame_height * grow, size * tuning.half_w[0] + tuning.half_w[1] * grow, 0));
        burning.flame.SetVector("_FireXZ", new Vector4(burning.at.x, burning.at.z, 0, 0));
        burning.flame.SetFloat("_AlphaIn", tuning.alpha_in);
        burning.flame.SetFloat("_AlphaOut", tuning.alpha_out);
        burning.flameCount = (int)Amount(tuning.flame, size);

        burning.ember = Block(burning.ember, burning, tuning.ember, size, 1f, start);
        burning.ember.SetVector("_FireQuad", new Vector4(tuning.ember_cube, 0, 0, 0));
        burning.emberCount = (int)Amount(tuning.ember, size);

        burning.smoke = Block(burning.smoke, burning, tuning.smoke, size, 1f, start);
        float quad = tuning.smoke_quad_base + size * tuning.smoke_quad_per_size;
        burning.smoke.SetVector("_FireQuad", new Vector4(quad, quad * tuning.smoke_quad_tall, 0, 0));
        burning.smokeCount = (int)Amount(tuning.smoke, size);

        float[] l = tuning.light;  // energy base, energy per size, range base, range per size, y base, y per size
        burning.energy = l[0] + l[1] * size;
        if (burning.light == null)
        {
            var made = new GameObject("fire light");
            burning.light = made.AddComponent<Light>();
            burning.light.type = LightType.Point;
            burning.light.color = tuning.light_color;
            burning.light.shadows = LightShadows.None;
            burning.light.lightUnit = LightUnit.Candela;
            made.AddComponent<HDAdditionalLightData>();
        }
        GameObject go = burning.light.gameObject;
        go.SetActive(true);
        go.transform.position = burning.at + Vector3.up * (l[4] + l[5] * size);
        burning.light.range = l[2] + l[3] * size;
        Color lit = tuning.light_color.linear * burning.energy;
        Vector3 p = go.transform.position;
        burning.smoke.SetVector("_FireLightPos", new Vector4(p.x, p.y, p.z, burning.light.range));
        burning.smoke.SetVector("_FireLightColor", lit);
        fires.Add(burning);
        return burning;
    }

    MaterialPropertyBlock Block(MaterialPropertyBlock reuse, Burning burning, FireSystem s, float size, float scaleBy, float start)
    {
        MaterialPropertyBlock b = reuse ?? new MaterialPropertyBlock();
        b.SetFloat(START, start);
        b.SetFloat(END, ALWAYS);
        Vector3 wind = Flip(new Vector3(tuning.wind[0], tuning.wind[1], tuning.wind[2])) * s.wind_share;
        b.SetVector("_FireOrigin", burning.at + Vector3.up * s.y);
        b.SetVector("_EmitBox", new Vector4(size * s.box, s.box_y, size * s.box, 0));
        b.SetVector("_FireGravity", wind + Vector3.up * s.rise);
        b.SetVector("_FireCurve", new Vector4(s.curve[0], s.curve[1], s.curve[2], s.curve[3]));
        b.SetFloat("_FireSeed", burning.seed);
        b.SetFloat("_FireCount", Amount(s, size));
        b.SetFloat("_FireLife", s.life);
        b.SetFloat("_FireSpread", s.spread * Mathf.Deg2Rad);
        b.SetFloat("_SpeedMin", s.speed[0]);
        b.SetFloat("_SpeedMax", s.speed[1]);
        b.SetFloat("_ScaleMin", s.scale[0] * scaleBy);
        b.SetFloat("_ScaleMax", s.scale[1] * scaleBy);
        return b;
    }

    // focusDepth: the camera-to-kaiju depth, inside which smoke clears so the kaiju reads through it.
    public void SetFocus(float focusDepth)
    {
        Shader.SetGlobalVector(FOCUS, new Vector4(tuning.focus_clear, tuning.focus_full, focusDepth, tuning.soft_contact_m));
    }

    public void Draw(float time)
    {
        Shader.SetGlobalFloat(TIME, time);
        float[] f = tuning.flicker;
        float dt = Mathf.Max(0f, time - lastTime);
        lastTime = time;
        for (int i = fires.Count - 1; i >= 0; i--)
        {
            Burning fire = fires[i];
            if (time > fire.gone)
            {
                fire.light.gameObject.SetActive(false);
                fires[i] = fires[fires.Count - 1];
                fires.RemoveAt(fires.Count - 1);
                free.Push(fire);
                continue;
            }
            fire.fade = Mathf.Max(0f, fire.fade - fire.fadeRate * dt);
            Graphics.DrawProcedural(flameMat, fire.bounds, MeshTopology.Triangles, QUAD_VERTS, fire.flameCount, null, fire.flame, ShadowCastingMode.Off, false, 0);
            if (fire.showEmbers) Graphics.DrawProcedural(emberMat, fire.bounds, MeshTopology.Triangles, CUBE_VERTS, fire.emberCount, null, fire.ember, ShadowCastingMode.Off, false, 0);
            Graphics.DrawProcedural(smokeMat, fire.bounds, MeshTopology.Triangles, QUAD_VERTS, fire.smokeCount, null, fire.smoke, ShadowCastingMode.Off, false, 0);
            float flicker = f[0] + f[1] * Mathf.Sin(time * f[2] + fire.seed) + f[3] * Mathf.Sin(time * f[4] + fire.seed * 2f);
            // Godot's omni falls off as 1/d, HDRP's as 1/d^2: equal at light_match_m.
            fire.light.intensity = fire.energy * fire.fade * flicker * Mathf.PI * exposureUnit * tuning.light_match_m;
        }
    }

    public void Dispose()
    {
        foreach (Burning fire in fires)
            if (fire.light != null) UnityEngine.Object.Destroy(fire.light.gameObject);
        foreach (Burning fire in free)
            if (fire.light != null) UnityEngine.Object.Destroy(fire.light.gameObject);
        UnityEngine.Object.Destroy(flameMat);
        UnityEngine.Object.Destroy(emberMat);
        UnityEngine.Object.Destroy(smokeMat);
    }
}
