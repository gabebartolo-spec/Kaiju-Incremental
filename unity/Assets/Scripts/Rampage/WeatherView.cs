using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;
using Kaiju.Game;
using S = Kaiju.Sim;

// The look of the run's weather (scenes/weather_view.gd, D-155), built once when the city loads: the weather's
// layer in data/looks.json "weather" "layers" says what it lays over the look; clear has no layer and builds
// nothing. Rain (and the thunderstorm, which is rain) gives a duller sky and heavier veil (the sun, the ambient and
// the fog multiplied down, the sky and fog colours pulled toward their own grey) and the rain itself: three depth
// layers of falling streaks and the ground splashes in volumes that follow the camera, leaning with the run's wind,
// counts x the graphics preset's particles ratio, thinned round the camera, the screen centre and in front of the
// kaiju (Rain.shader). WeatherLook holds the numbers. Presentation only: it reads Content.WeatherId(), never the
// sim's state, and its clock is the frames' own delta, so it stops when the run is paused.
// Wet streets (D-484): the ground's `wet` and the sky it mirrors (CityGround.hlsl, ground_slab.gdshader), and with
// the rain the glowing smears of the streetlights and lit buildings on the wet road (RainSmear.shader,
// rain_smear.gdshader), re-placed on a timer round the camera (WetStreets).
public sealed class WeatherView : IDisposable
{
    public readonly string id;
    public int Drops { get; private set; }
    public int SplashCount { get; private set; }

    readonly S.GDict layer;
    readonly List<RainLayer> layers = new List<RainLayer>();
    readonly List<MaterialPropertyBlock> blocks = new List<MaterialPropertyBlock>();
    readonly RainSplashes splashes;
    readonly MaterialPropertyBlock splashBlock;
    readonly Material streakMat, splashMat;
    float time;
    readonly WetStreets wet;
    readonly Material smearMat;
    readonly GraphicsBuffer smearBuffer;
    readonly Vector4[] smearData;
    readonly List<WetStreets.Smear> placed = new List<WetStreets.Smear>();
    readonly StreetView street;
    readonly S.RampageSim sim;
    readonly float smearEvery, smearAlpha, exposure;
    float smearWait;
    bool smearLogged;
    public int Smears => placed.Count;
    public Color Sheen { get; private set; } = Color.black;

    const int QUAD_VERTS = 6;
    // weather_view.gd custom_aabb: the streak volume's bounds reach this far past it on each side.
    const float BOUNDS_PAD = 30f;

    static readonly int TIME = Shader.PropertyToID("_RainTime"), SEED = Shader.PropertyToID("_RainSeed");
    static readonly int VOL = Shader.PropertyToID("_RainVol"), CENTRE = Shader.PropertyToID("_RainCentre");
    static readonly int VEL = Shader.PropertyToID("_RainVel"), LOOK = Shader.PropertyToID("_RainLook");
    static readonly int SPLASH = Shader.PropertyToID("_RainSplash"), FADE = Shader.PropertyToID("_RainFade");
    static readonly int CLEAR = Shader.PropertyToID("_RainClear"), TINT = Shader.PropertyToID("_RainTint");
    static readonly int AMBIENT = Shader.PropertyToID("_SliceAmbient");
    static readonly int SMEARS = Shader.PropertyToID("_Smears"), TOWARD = Shader.PropertyToID("_SmearToward");
    // RainSmear.shader: three float4 a smear.
    const int SMEAR_ROWS = 3;
    // weather_view.gd custom_aabb: the smears' bounds, round the city.
    static readonly Bounds SMEAR_BOUNDS = new Bounds(Vector3.zero, new Vector3(4000f, 10f, 4000f));

    // Builds the current weather's view (weather_view.gd attach) over `profile` (the look SliceGame.ApplyLook made,
    // after its sun exists). wind: Fire.WIND (fire.json "wind", Godot axes); exposureUnit: SliceGame.ExposureUnit;
    // ground: the city's ground (wetted); street: its streetlights; sim: its buildings (the lit windows' smears); smear: RainSmear.shader.
    // Returns null when the weather has no layer (clear): nothing is changed then. Logs one line either way.
    public static WeatherView Attach(VolumeProfile profile, Shader rain, float[] wind, float exposureUnit,
        CityGround ground, StreetView street, S.RampageSim sim, Shader smear)
    {
        string id = S.Content.WeatherId();
        S.GDict found = WeatherLook.LayerOf(id);
        if (found.IsEmpty())
        {
            Debug.Log($"rampage: weather {(id != "" ? id : "none")}, no layer, rain 0 drops");
            Debug.Log($"wet streets: dry (weather {(id != "" ? id : "none")}), 0 smears");
            return null;
        }
        var view = new WeatherView(id, found, profile, rain, wind, exposureUnit, ground, street, sim, smear);
        Debug.Log(FormattableString.Invariant($"rampage: weather {id}, rain {view.Drops} drops ({string.Join(", ", view.layers.ConvertAll(l => $"{l.name} {l.count}"))}), splashes {view.SplashCount}, particles x{WeatherLook.ParticlesRatio():F2}, sun x{WeatherLook.Value(found, "sun_mul", 1.0):F2}, fog x{WeatherLook.Value(found, "fog_mul", 1.0):F2}"));
        string smears = view.smearMat != null ? $"up to {view.wet.max}" : "none";
        int lamps = street != null ? street.LampLights.Count : 0;
        Debug.Log(FormattableString.Invariant($"wet streets: wet {view.wet.wet:F2} (ground {(ground != null ? ground.WetNow : 0f):F2}), sheen {view.Sheen.r:F3} {view.Sheen.g:F3} {view.Sheen.b:F3}, smears {smears}, {lamps} lamps"));
        return view;
    }

    WeatherView(string id, S.GDict found, VolumeProfile profile, Shader rain, float[] wind, float exposureUnit,
        CityGround ground, StreetView street, S.RampageSim sim, Shader smear)
    {
        this.id = id;
        layer = found;
        this.street = street;
        this.sim = sim;
        exposure = exposureUnit;
        DullTheSky(profile, exposureUnit);
        wet = new WetStreets(found);
        WetTheGround(profile, ground);
        if (!WeatherLook.Rains(found) || rain == null) return;
        S.GDict smearCfg = S.Content.Section("rain")["smear"];
        smearEvery = (float)S.Num.F(smearCfg["every_s"]);
        smearAlpha = (float)S.Num.F(smearCfg["alpha"]);
        if (wet.smears && smear != null)
        {
            smearMat = new Material(smear);
            smearBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, wet.max * SMEAR_ROWS, Marshal.SizeOf<Vector4>());
            smearData = new Vector4[wet.max * SMEAR_ROWS];
            smearMat.SetBuffer(SMEARS, smearBuffer);
        }
        S.GDict cfg = S.Content.Section("rain");
        double ratio = WeatherLook.ParticlesRatio();
        double[] tint = WeatherLook.StreakColor();
        Color lin = new Color(Mathf.GammaToLinearSpace((float)tint[0]), Mathf.GammaToLinearSpace((float)tint[1]), Mathf.GammaToLinearSpace((float)tint[2])) * exposureUnit;
        streakMat = new Material(rain);
        streakMat.EnableKeyword("RAIN_STREAK");
        splashMat = new Material(rain);
        splashMat.EnableKeyword("RAIN_SPLASH");
        double[] clear = WeatherLook.StreakClear(cfg);
        int seed = 0;
        foreach (RainLayer l in WeatherLook.Layers(cfg, ratio, wind[0], wind[2]))
        {
            var b = new MaterialPropertyBlock();
            b.SetFloat(SEED, seed++);
            b.SetVector(VOL, new Vector4((float)l.volX, (float)l.volY, (float)l.volZ, l.count));
            // Godot axes to Unity's: z negated.
            b.SetVector(VEL, new Vector4((float)l.velX, (float)l.velY, -(float)l.velZ, (float)l.jitter));
            b.SetVector(LOOK, new Vector4((float)l.len, (float)l.width, (float)l.fadeIn, (float)l.fadeOut));
            b.SetVector(FADE, new Vector4((float)l.nearClear, (float)l.nearFull, (float)l.farBegin, (float)l.farEnd));
            b.SetVector(CLEAR, new Vector4((float)clear[0], (float)clear[1], (float)clear[2], (float)clear[3]));
            b.SetVector(TINT, new Vector4(lin.r, lin.g, lin.b, (float)l.alpha));
            layers.Add(l);
            blocks.Add(b);
            Drops += l.count;
        }
        splashes = WeatherLook.Splashes(cfg, ratio);
        SplashCount = splashes.count;
        splashBlock = new MaterialPropertyBlock();
        splashBlock.SetFloat(SEED, seed);
        splashBlock.SetVector(VOL, new Vector4((float)splashes.areaX, 0f, (float)splashes.areaZ, splashes.count));
        splashBlock.SetVector(SPLASH, new Vector4((float)splashes.size, (float)splashes.scaleMin, (float)splashes.scaleMax, (float)splashes.lifetimeSpread));
        splashBlock.SetVector(FADE, new Vector4((float)splashes.nearClear, (float)splashes.nearFull, 0f, 0f));
        splashBlock.SetVector(CLEAR, new Vector4((float)splashes.centreKeep, (float)splashes.centreRadius, (float)splashes.focusClear, (float)splashes.focusFull));
        splashBlock.SetVector(TINT, new Vector4(lin.r, lin.g, lin.b, (float)splashes.alpha));
    }

    // weather_view.gd _dull_the_sky: the layer's multipliers and greying on the sun, the ambient, the fog and the sky.
    void DullTheSky(VolumeProfile profile, float exposureUnit)
    {
        S.GDict d = layer;
        double grey = WeatherLook.Value(d, "sky_grey", 0.0), dim = WeatherLook.Value(d, "sky_dim", 1.0);
        GameObject sunGo = GameObject.Find("sun");
        Light sun = sunGo != null ? sunGo.GetComponent<Light>() : null;
        if (sun != null && sun.type == LightType.Directional) sun.intensity *= (float)WeatherLook.Value(d, "sun_mul", 1.0);
        Shader.SetGlobalVector(AMBIENT, Shader.GetGlobalVector(AMBIENT) * (float)WeatherLook.Value(d, "ambient_mul", 1.0));
        if (profile == null) return;
        if (profile.TryGet(out Fog fog))
        {
            fog.meanFreePath.Override(fog.meanFreePath.value / Mathf.Max((float)WeatherLook.Value(d, "fog_mul", 1.0), 1e-5f));
            fog.color.Override(Dulled(fog.color.value, grey, dim, exposureUnit));
        }
        if (profile.TryGet(out GradientSky sky))
        {
            // The sky's colours are look colours (linear) under its own multiplier; Godot dulls them as stored (sRGB).
            sky.top.Override(Dulled(sky.top.value, grey, dim, 1f));
            sky.middle.Override(Dulled(sky.middle.value, grey, dim, 1f));
            sky.bottom.Override(Dulled(sky.bottom.value, grey, dim, 1f));
        }
    }

    // weather_view.gd _wet_the_ground and _sheen_colour: the ground's wet, and the sky colour the wet road gives
    // back (the horizon, after the dulling; black where there is no sky). Other weathers leave the ground dry.
    void WetTheGround(VolumeProfile profile, CityGround ground)
    {
        if (wet.wet <= 0.0 || ground == null) return;
        if (profile != null && profile.TryGet(out GradientSky sky)) Sheen = sky.middle.value;
        ground.Wet((float)wet.wet, Sheen);
    }

    // A linear colour scaled by `unit`, dulled as Godot dulls its sRGB value (WeatherLook.Dulled), back again.
    static Color Dulled(Color linearScaled, double grey, double dim, float unit)
    {
        Color g = (linearScaled / unit).gamma;
        double[] o = WeatherLook.Dulled(g.r, g.g, g.b, grey, dim);
        Color back = new Color((float)o[0], (float)o[1], (float)o[2]).linear * unit;
        back.a = linearScaled.a;
        return back;
    }

    // One frame (weather_view.gd _process): the volumes follow the camera, and the rain is drawn. dt is 0 while paused.
    public void Step(float dt, Camera cam)
    {
        if (streakMat == null || cam == null) return;
        time += dt;
        Vector3 forward = cam.transform.forward;
        var flat = new Vector3(forward.x, 0f, forward.z);
        // Godot's Vector3.FORWARD (0, 0, -1) is Unity's +z.
        flat = flat.magnitude > 0.01f ? flat.normalized : Vector3.forward;
        Vector3 eye = cam.transform.position;
        for (int i = 0; i < layers.Count; i++)
        {
            RainLayer l = layers[i];
            Vector3 c = eye + flat * (float)l.ahead;
            float top = (float)l.volY;
            MaterialPropertyBlock b = blocks[i];
            b.SetFloat(TIME, time);
            b.SetVector(CENTRE, new Vector4(c.x, top, c.z, (float)l.lifetime));
            float drift = (float)(Math.Sqrt(l.velX * l.velX + l.velZ * l.velZ) * (1.0 + l.jitter) * l.lifetime);
            var bounds = new Bounds(new Vector3(c.x, top * 0.5f, c.z),
                new Vector3((float)l.volX + 2f * (BOUNDS_PAD + drift), top * 1.4f + 2f, (float)l.volZ + 2f * (BOUNDS_PAD + drift)));
            Graphics.DrawProcedural(streakMat, bounds, MeshTopology.Triangles, QUAD_VERTS, l.count, null, b, ShadowCastingMode.Off, false, 0);
        }
        Vector3 s = eye + flat * (float)splashes.ahead;
        splashBlock.SetFloat(TIME, time);
        splashBlock.SetVector(CENTRE, new Vector4(s.x, (float)splashes.y, s.z, (float)splashes.seconds));
        float reach = (float)(splashes.size * splashes.scaleMax);
        var area = new Bounds(new Vector3(s.x, (float)splashes.y, s.z), new Vector3((float)splashes.areaX + 2f * reach, 2f, (float)splashes.areaZ + 2f * reach));
        Graphics.DrawProcedural(splashMat, area, MeshTopology.Triangles, QUAD_VERTS, splashes.count, null, splashBlock, ShadowCastingMode.Off, false, 0);
        if (smearMat == null) return;
        // Godot axes: toward the camera is -flat, z negated.
        smearMat.SetVector(TOWARD, new Vector4(-flat.x, flat.z, smearAlpha, exposure));
        smearWait -= dt;
        if (smearWait <= 0f)
        {
            smearWait = smearEvery;
            PlaceSmears(eye);
        }
        if (placed.Count > 0)
            Graphics.DrawProcedural(smearMat, SMEAR_BOUNDS, MeshTopology.Triangles, QUAD_VERTS, placed.Count, null, null, ShadowCastingMode.Off, false, 0);
    }

    // weather_view.gd _place_smears: the lamps and lit buildings round the camera (Godot axes), uploaded.
    void PlaceSmears(Vector3 eye)
    {
        double lit = S.Num.F(S.Content.Look().Get("window_lit", 0.0));
        wet.Place(eye.x, -eye.z, street != null ? street.LampLights : Array.Empty<WetStreets.Lamp>(), sim, lit, placed);
        for (int i = 0; i < placed.Count; i++)
        {
            WetStreets.Smear m = placed[i];
            smearData[i * SMEAR_ROWS] = new Vector4((float)m.x, (float)m.y, (float)m.z, (float)m.width);
            smearData[i * SMEAR_ROWS + 1] = new Vector4((float)m.r, (float)m.g, (float)m.b, (float)m.a);
            smearData[i * SMEAR_ROWS + 2] = new Vector4((float)m.length, 0f, 0f, 0f);
        }
        if (placed.Count > 0) smearBuffer.SetData(smearData, 0, 0, placed.Count * SMEAR_ROWS);
        if (smearLogged) return;
        smearLogged = true;
        Debug.Log(FormattableString.Invariant($"wet streets: first smears {placed.Count} round ({eye.x:F1}, {-eye.z:F1}), window_lit {lit:F2}"));
    }

    public void Dispose()
    {
        if (streakMat != null) UnityEngine.Object.Destroy(streakMat);
        if (splashMat != null) UnityEngine.Object.Destroy(splashMat);
        if (smearMat != null) UnityEngine.Object.Destroy(smearMat);
        smearBuffer?.Dispose();
    }
}
