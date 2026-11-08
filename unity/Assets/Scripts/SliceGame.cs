using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.SceneManagement;

// The playable: loads the block and the croc, reads input, ticks the carve, follows with the game's camera.
public sealed class SliceGame : MonoBehaviour
{
    Tuning tuning;
    City city;
    Croc croc;
    Debris debris;
    Fires fires;
    float fireClock;
    Camera cam;
    Mesh groundMesh, instanceCubeGodot, instanceCubeUnity;
    Material groundMat;
    VolumeProfile profile;
    readonly List<City.Sphere> spheres = new List<City.Sphere>();
    float accumulator, camYaw, orbit, zoom, followS, turnFollow, lookUp;
    Vector3 camOffset, focus, focusVel;
    float smoothDt = 1f / 60f;
    readonly FrameTiming[] timing = new FrameTiming[1];
    double cpuMs, gpuMs;
    GUIStyle hud;
    Texture2D hudBack;
    string error;

    // Unattended test: -slice-auto walks forward, -slice-shot <png> saves one frame and quits.
    bool auto;
    string shotPath;
    float shotAt = 12f, age;

    static Color Lin(Color c) => c.linear;

    void Awake()
    {
        Application.targetFrameRate = -1;
        QualitySettings.vSyncCount = 0;
        string[] args = Environment.GetCommandLineArgs();
        auto = args.Contains("-slice-auto");
        int shot = Array.IndexOf(args, "-slice-shot");
        if (shot >= 0 && shot + 1 < args.Length) shotPath = args[shot + 1];
        int shotTime = Array.IndexOf(args, "-slice-shot-at");
        if (shotTime >= 0 && shotTime + 1 < args.Length) shotAt = float.Parse(args[shotTime + 1], System.Globalization.CultureInfo.InvariantCulture);
        try
        {
            Load();
        }
        catch (Exception e)
        {
            error = e.ToString();
            Debug.LogException(e);
        }
    }

    void Load()
    {
        tuning = SliceData.LoadTuning();
        Physics.gravity = new Vector3(0, -tuning.gravity, 0);
        var slice = SliceData.LoadJson("slice.json");
        var look = MiniJson.Obj(slice["look"]);
        ApplyLook(slice, look);

        instanceCubeGodot = CubeMesh(1f, true);
        Debug.Log($"slice: core version {Native.kc_version()}");
        List<BuildingBlob> buildings = SliceData.LoadBuildings();
        var centre = new Vector3(tuning.spawn_x, 0, -tuning.spawn_z);
        instanceCubeUnity = CubeMesh(tuning.debris_size, false);
        Shader lit = Resources.Load<Shader>("Shaders/SliceLit");
        debris = new Debris(tuning, Resources.Load<ComputeShader>("Shaders/Debris"), lit, instanceCubeUnity, centre);
        var root = new GameObject("city");
        city = new City(tuning, buildings, lit, debris, root.transform);

        float inset = SliceData.F(look, "voxel_inset", 0.99f);
        croc = new Croc(tuning, slice, lit, instanceCubeGodot, inset);
        croc.position = new Vector3(tuning.spawn_x, 0, tuning.spawn_z);
        croc.yaw = 0;
        croc.Step(Vector2.zero, false, 1f / 60f);

        BuildCamera(slice);
        BuildWorld(look);
        fires = new Fires(FireTuning.Load(), Resources.Load<Shader>("Shaders/Flame"), ExposureUnit());
        Debug.Log($"slice: loaded {buildings.Count} buildings, {croc.CubeCount} croc cubes, spawn {croc.position}");
    }

    void ApplyLook(Dictionary<string, object> slice, Dictionary<string, object> look)
    {
        Color ambient = Lin(SliceData.Hex(look["ambient_color"])) * SliceData.F(look, "ambient", 1);
        Shader.SetGlobalVector("_SliceAmbient", ambient);
        Shader.SetGlobalFloat("_VoxelAoStrength", SliceData.F(look, "voxel_ao_strength", 0.6f));
        Shader.SetGlobalFloat("_VoxelAoLightAffect", SliceData.F(look, "voxel_ao_light_affect", 0.25f));
        Shader.SetGlobalFloat("_WindowGlow", SliceData.F(look, "window_glow", 1));
        Shader.SetGlobalFloat("_ColorInside", SliceData.F(look, "voxel_inside", 0.12f));
        var fr = MiniJson.Obj(look["finish_roughness"]);
        var fs = MiniJson.Obj(look["finish_specular"]);
        Shader.SetGlobalVector("_FinishRoughness", new Vector4(MiniJson.F(fr["rough"]), MiniJson.F(fr["glass"]), MiniJson.F(fr["metal"]), 0));
        Shader.SetGlobalVector("_FinishSpecular", new Vector4(MiniJson.F(fs["rough"]), MiniJson.F(fs["glass"]), MiniJson.F(fs["metal"]), 0));

        List<object> palette = MiniJson.Arr(slice["window_palette"]);
        var colors = new Vector4[8];
        var ends = new float[8];
        for (int i = 0; i < 8; i++)
        {
            var e = MiniJson.Obj(palette[Mathf.Min(i, palette.Count - 1)]);
            List<object> c = MiniJson.Arr(e["color"]);
            colors[i] = new Vector4(MiniJson.F(c[0]), MiniJson.F(c[1]), MiniJson.F(c[2]), 1);
            ends[i] = MiniJson.F(e["end"]);
        }
        Shader.SetGlobalVectorArray("_WinColors", colors);
        Shader.SetGlobalFloatArray("_WinEnds", ends);
        Shader.SetGlobalFloat("_WinCount", palette.Count);
        List<object> gain = MiniJson.Arr(slice["window_gain"]);
        Shader.SetGlobalVector("_WinGain", new Vector4(MiniJson.F(gain[0]), MiniJson.F(gain[1]), 0, 0));
        Shader.SetGlobalFloat("_WinPaletteOn", slice["window_palette_on"] is bool on && on ? 1 : 0);

        // Godot: euler (pitch, -35, 0); the light shines along its -z. Negate z for Unity axes.
        float pitch = SliceData.F(look, "sun_pitch", -38) * Mathf.Deg2Rad, turn = -35f * Mathf.Deg2Rad;
        var dir = new Vector3(-Mathf.Sin(turn) * Mathf.Cos(pitch), Mathf.Sin(pitch), -Mathf.Cos(turn) * Mathf.Cos(pitch));
        var sunGo = new GameObject("sun");
        sunGo.transform.rotation = Quaternion.LookRotation(new Vector3(dir.x, dir.y, -dir.z));
        Light sun = sunGo.AddComponent<Light>();
        sun.type = LightType.Directional;
        sun.color = SliceData.Hex(look["sun_color"]);
        sun.lightUnit = LightUnit.Lux;
        sun.intensity = SliceData.F(look, "sun_energy", 1) * Mathf.PI * ExposureUnit();
        sun.shadows = LightShadows.Soft;
        sunGo.AddComponent<HDAdditionalLightData>();
        Shader.SetGlobalVector("_FireSunDir", -sunGo.transform.forward);
        Shader.SetGlobalVector("_FireSunColor", sun.color.linear * SliceData.F(look, "sun_energy", 1));

        profile = ScriptableObject.CreateInstance<VolumeProfile>();
        var environment = profile.Add<VisualEnvironment>(true);
        environment.skyType.Override((int)SkyType.Gradient);
        environment.skyAmbientMode.Override(SkyAmbientMode.Static);
        var sky = profile.Add<GradientSky>(true);
        // Godot's fog covers its sky whole (fog_sky_affect 1), so what shows is the fog's colour.
        Color skyColor = Lin(SliceData.Hex(look["fog_color"]));
        sky.top.Override(skyColor);
        sky.middle.Override(skyColor);
        sky.bottom.Override(skyColor);
        sky.gradientDiffusion.Override(tuning.sky_diffusion);
        sky.skyIntensityMode.Override(SkyIntensityMode.Multiplier);
        sky.multiplier.Override(ExposureUnit());
        var exposure = profile.Add<Exposure>(true);
        exposure.mode.Override(ExposureMode.Fixed);
        exposure.fixedExposure.Override(tuning.hdrp_ev);
        var tone = profile.Add<Tonemapping>(true);
        tone.mode.Override(TonemappingMode.None);
        var agx = profile.Add<AgxTonemap>(true);
        agx.exposure.Override(SliceData.F(look, "exposure", 1));
        agx.contrast.Override(SliceData.F(look, "agx_contrast", 1));
        agx.white.Override(tuning.agx_white);
        agx.saturation.Override(SliceData.F(look, "saturation", 1));
        agx.postContrast.Override(SliceData.F(look, "post_contrast", 1));
        Bloom bloom = profile.Add<Bloom>(true);
        bloom.threshold.Override(SliceData.F(look, "glow_threshold", 0.9f));
        bloom.intensity.Override(tuning.bloom_intensity * SliceData.F(look, "glow", 1));
        profile.Add<MotionBlur>(true).intensity.Override(0f);
        var ssao = profile.Add<ScreenSpaceAmbientOcclusion>(true);
        ssao.intensity.Override(tuning.ssao_intensity);
        var contact = profile.Add<ContactShadows>(true);
        contact.enable.Override(true);
        var shadows = profile.Add<HDShadowSettings>(true);
        shadows.maxShadowDistance.Override(tuning.shadow_distance);
        var fog = profile.Add<Fog>(true);
        fog.enabled.Override(true);
        fog.colorMode.Override(FogColorMode.ConstantColor);
        fog.color.Override(Lin(SliceData.Hex(look["fog_color"])) * ExposureUnit());
        fog.meanFreePath.Override(1f / Mathf.Max(SliceData.F(look, "fog_density", 0), 1e-5f));
        fog.baseHeight.Override(0f);
        fog.maximumHeight.Override(tuning.fog_height);
        fog.enableVolumetricFog.Override(true);
        var volumeGo = new GameObject("volume");
        Volume volume = volumeGo.AddComponent<Volume>();
        volume.isGlobal = true;
        volume.sharedProfile = profile;
    }

    // One unit of Godot radiance in HDRP's physical units: the fixed exposure divides everything by this.
    float ExposureUnit() => 1.2f * Mathf.Pow(2f, tuning.hdrp_ev);

    void BuildCamera(Dictionary<string, object> slice)
    {
        var c = MiniJson.Obj(slice["camera"]);
        List<object> off = MiniJson.Arr(c["offset"]);
        camOffset = new Vector3(MiniJson.F(off[0]), MiniJson.F(off[1]), MiniJson.F(off[2]));
        zoom = SliceData.F(c, "zoom_base", 0.75f) + SliceData.F(c, "zoom_per_scale", 0.4f) * croc.Scale;
        followS = SliceData.F(c, "follow_s", 0.3f);
        turnFollow = SliceData.F(c, "turn_follow", 1.2f);
        lookUp = 3.5f * croc.Scale;
        var go = new GameObject("camera");
        cam = go.AddComponent<Camera>();
        cam.fieldOfView = SliceData.F(c, "fov", 60);
        cam.nearClipPlane = 0.5f;
        cam.farClipPlane = 3000;
        HDAdditionalCameraData data = go.AddComponent<HDAdditionalCameraData>();
        data.antialiasing = HDAdditionalCameraData.AntialiasingMode.SubpixelMorphologicalAntiAliasing;
        focus = croc.position;
        camYaw = croc.yaw;
        PlaceCamera();
    }

    void BuildWorld(Dictionary<string, object> look)
    {
        groundMesh = new Mesh { name = "ground" };
        const float S = 6000;
        groundMesh.vertices = new[] { new Vector3(-S, 0, -S), new Vector3(-S, 0, S), new Vector3(S, 0, S), new Vector3(S, 0, -S) };
        groundMesh.normals = new[] { Vector3.up, Vector3.up, Vector3.up, Vector3.up };
        groundMesh.triangles = new[] { 0, 1, 2, 0, 2, 3 };
        groundMat = new Material(Resources.Load<Shader>("Shaders/SliceLit"));
        groundMat.EnableKeyword("SLICE_GROUND");
        groundMat.SetColor("_GroundColor", Lin(SliceData.Hex(look["asphalt"])));
        var ground = new GameObject("ground");
        ground.AddComponent<MeshFilter>().sharedMesh = groundMesh;
        var mr = ground.AddComponent<MeshRenderer>();
        mr.sharedMaterial = groundMat;
        mr.shadowCastingMode = ShadowCastingMode.Off;
        var box = ground.AddComponent<BoxCollider>();
        box.center = new Vector3(0, -10, 0);
        box.size = new Vector3(S * 2, 20, S * 2);
    }

    // Godot's BoxMesh turned so the mirror at the shader leaves it facing out (godot: formula cross
    // points inward; unity: outward).
    static Mesh CubeMesh(float size, bool godot)
    {
        var verts = new List<Vector3>();
        var normals = new List<Vector3>();
        var tris = new List<int>();
        Vector3[] dirs = { Vector3.right, Vector3.left, Vector3.up, Vector3.down, Vector3.forward, Vector3.back };
        foreach (Vector3 n in dirs)
        {
            Vector3 a = Mathf.Abs(n.y) > 0.5f ? Vector3.right : Vector3.up;
            Vector3 u = Vector3.Cross(a, n);
            Vector3 v = Vector3.Cross(n, u);
            int at = verts.Count;
            Vector3 c = n * 0.5f;
            verts.Add((c - u * 0.5f - v * 0.5f) * size);
            verts.Add((c + u * 0.5f - v * 0.5f) * size);
            verts.Add((c + u * 0.5f + v * 0.5f) * size);
            verts.Add((c - u * 0.5f + v * 0.5f) * size);
            for (int k = 0; k < 4; k++) normals.Add(n);
            Vector3 cross = Vector3.Cross(verts[at + 1] - verts[at], verts[at + 2] - verts[at]);
            bool outward = Vector3.Dot(cross, n) > 0;
            bool flip = godot ? outward : !outward;
            if (flip)
                tris.AddRange(new[] { at, at + 2, at + 1, at, at + 3, at + 2 });
            else
                tris.AddRange(new[] { at, at + 1, at + 2, at, at + 2, at + 3 });
        }
        var mesh = new Mesh { name = "cube" };
        mesh.SetVertices(verts);
        mesh.SetNormals(normals);
        mesh.SetTriangles(tris, 0);
        mesh.bounds = new Bounds(Vector3.zero, Vector3.one * 8000);
        return mesh;
    }

    void Update()
    {
        if (Input.GetKeyDown(KeyCode.Escape))
        {
            Application.Quit();
            return;
        }
        if (error != null) return;
        if (Input.GetKeyDown(KeyCode.R))
        {
            SceneManager.LoadScene(SceneManager.GetActiveScene().buildIndex);
            return;
        }
        float dt = Time.deltaTime;
        age += dt;
        smoothDt = Mathf.Lerp(smoothDt, Time.unscaledDeltaTime, 0.05f);

        float h = (Input.GetKey(KeyCode.D) ? 1 : 0) - (Input.GetKey(KeyCode.A) ? 1 : 0);
        float v = (Input.GetKey(KeyCode.W) ? 1 : 0) - (Input.GetKey(KeyCode.S) ? 1 : 0);
        if (auto) v = 1;
        orbit += ((Input.GetKey(KeyCode.E) ? 1 : 0) - (Input.GetKey(KeyCode.Q) ? 1 : 0)) * tuning.cam_orbit_rate * dt;
        float look = camYaw + orbit;
        var forward = new Vector2(-Mathf.Sin(look), -Mathf.Cos(look));
        var right = new Vector2(Mathf.Cos(look), -Mathf.Sin(look));
        Vector2 move = forward * v + right * h;
        if (move.sqrMagnitude > 1) move.Normalize();
        bool run = Input.GetKey(KeyCode.LeftShift);
        if (Input.GetKeyDown(KeyCode.F) || Input.GetMouseButtonDown(0) || (auto && Mathf.Repeat(age, 6f) < dt)) croc.StartSweep();
        croc.Step(move, run, dt);

        accumulator += dt;
        float step = 1f / tuning.tick_hz;
        if (accumulator >= step)
        {
            accumulator = Mathf.Min(accumulator - step, step);
            spheres.Clear();
            croc.CollectSpheres(spheres);
            city.Tick(spheres, debris);
        }
        debris.Step(dt);
        croc.Draw();
        debris.Draw();
        FollowCamera(dt);
        fireClock += dt;
        SetSmokeFocus();
        fires.Draw(fireClock);

        FrameTimingManager.CaptureFrameTimings();
        if (FrameTimingManager.GetLatestTimings(1, timing) > 0)
        {
            cpuMs = timing[0].cpuFrameTime;
            gpuMs = timing[0].gpuFrameTime;
        }

        if (shotPath != null && age >= shotAt)
        {
            ScreenCapture.CaptureScreenshot(shotPath);
            Debug.Log($"slice: shot at {age:F1}s {HudLine()} pieces {city.Pieces()} debris {debris.Spawned} croc {croc.position} stride {croc.Stride} scale {croc.Scale} bodies {city.bodies.Count}");
            shotPath = null;
            Invoke(nameof(QuitNow), 1f);
        }
    }

    void QuitNow() => Application.Quit();

    // For a clip of the empty block: Godot axes, like croc.position.
    public void MoveCroc(float x, float z) => croc.position = new Vector3(x, 0, z);

    // Smoke between the camera and the kaiju thins out (Godot: CityView, smoke_focus).
    public void SetSmokeFocus()
    {
        var feet = new Vector3(croc.position.x, 0, -croc.position.z);
        fires.SetFocus(Vector3.Dot(feet - cam.transform.position, cam.transform.forward));
    }

    void FollowCamera(float dt)
    {
        camYaw += Mathf.DeltaAngle(camYaw * Mathf.Rad2Deg, croc.yaw * Mathf.Rad2Deg) * Mathf.Deg2Rad * (1f - Mathf.Exp(-turnFollow * dt));
        focus = Vector3.SmoothDamp(focus, croc.position, ref focusVel, followS, Mathf.Infinity, dt);
        PlaceCamera();
    }

    void PlaceCamera()
    {
        float y = camYaw + orbit;
        float s = Mathf.Sin(y), c = Mathf.Cos(y);
        Vector3 o = camOffset * zoom;
        var eye = new Vector3(focus.x + o.x * c + o.z * s, focus.y + o.y, focus.z - o.x * s + o.z * c);
        var target = new Vector3(focus.x, focus.y + lookUp, focus.z);
        cam.transform.position = new Vector3(eye.x, eye.y, -eye.z);
        cam.transform.LookAt(new Vector3(target.x, target.y, -target.z));
    }

    string HudLine()
    {
        return $"{1f / smoothDt:F0} fps  {smoothDt * 1000f:F1} ms  cpu {cpuMs:F1}  gpu {gpuMs:F1}";
    }

    void OnGUI()
    {
        if (hud == null)
        {
            hud = new GUIStyle(GUI.skin.label) { fontSize = 16, normal = { textColor = Color.white }, padding = new RectOffset(10, 10, 8, 8) };
            hudBack = new Texture2D(1, 1);
            hudBack.SetPixel(0, 0, new Color(0, 0, 0, 0.55f));
            hudBack.Apply();
            hud.normal.background = hudBack;
        }
        if (error != null)
        {
            GUI.Label(new Rect(10, 10, Screen.width - 20, Screen.height - 20), error, hud);
            return;
        }
        string text = HudLine()
            + $"\ntick {city.lastTickMs:F1} ms  mesh {city.lastMeshMs:F1} ms ({city.lastRegions} regions)  settle {city.lastSettleMs:F1} ms"
            + $"\npieces {city.Pieces()}  debris {debris.Live:N0}"
            + "\nWASD walk  Shift run  F / click tail sweep  Q E orbit  R restart  Esc quit";
        GUI.Label(new Rect(10, 10, 620, 106), text, hud);
    }

    void OnDestroy()
    {
        city?.Dispose();
        croc?.Dispose();
        debris?.Dispose();
        fires?.Dispose();
        if (groundMesh != null) Destroy(groundMesh);
        if (instanceCubeGodot != null) Destroy(instanceCubeGodot);
        if (instanceCubeUnity != null) Destroy(instanceCubeUnity);
        if (groundMat != null) Destroy(groundMat);
        if (profile != null) Destroy(profile);
        if (hudBack != null) Destroy(hudBack);
    }
}
