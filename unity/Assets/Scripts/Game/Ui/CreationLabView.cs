// The lab set of Kaiju Creation in 3D (scenes/creation_lab.gd, creation_set.gd, creation_injector.gd): the bench,
// the cradle with its dish, the rack of vials, the monitors, the Special K canister and the injector (a post and
// a carriage that rises, turns and slides), under the key lamp and the rim, seen by the lab's own camera. It
// draws what CreationLab (the numbers) says each tick. The room round it (CreationRoom), the props despeckled and
// the monitors' readouts, the serums and the Special K painted (CreationPaint), the dish cleaned (CreationDish);
// the serums, the Special K and the barrel drain and fill (CreationLiquid). No genome or lightning yet.
using System;
using System.Collections.Generic;
using Kaiju.Game;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;
using S = Kaiju.Sim;

public sealed class CreationLabView
{
    // creation_set.gd lights: the key lamp's place, aim, range and cone (half angle, degrees); the rim's place and range.
    static readonly CreationVec KEY_AT = new CreationVec(0.1, 2.4, 0.4), KEY_LOOK = new CreationVec(0.0, 0.0, -0.2);
    static readonly CreationVec RIM_AT = new CreationVec(-0.2, 1.1, -1.25);
    const float KEY_RANGE = 6f, KEY_HALF_ANGLE = 58f, RIM_RANGE = 2f;
    // creation_lab.gd _add_glows: the focus glow over a vial, the screens' spill in front of the monitors.
    static readonly CreationVec FOCUS_OFF = new CreationVec(0.0, 0.3, 0.2), SCREENS_OFF = new CreationVec(-0.1, 0.4, 0.35);
    const float FOCUS_RANGE = 0.45f, SCREENS_RANGE = 1.2f;
    // Godot's Camera3D defaults for a set this small.
    const float NEAR = 0.05f, FAR = 100f;
    // Drawn over any camera left in the scene.
    const float CAMERA_DEPTH = 10f;
    // Over any other global volume left in the scene (the rampage's sky and fog read through as white).
    const float VOLUME_PRIORITY = 100f;
    // creation_set.gd leaves Godot's AgX exposure and contrast at the engine's defaults (the look gives the rest).
    const float GODOT_TONEMAP_EXPOSURE = 1f, GODOT_AGX_CONTRAST = 1.25f;

    static readonly int SLICE_AMBIENT = Shader.PropertyToID("_SliceAmbient");  // SliceLit's flat ambient, set per scene
    static readonly HashSet<string> warned = new HashSet<string>();

    IList<CreationTitan> titans;
    GameObject root;
    Camera cam;
    Transform carriage;
    // Each shown titan's serum, the Special K canister's and the injector's barrel.
    readonly Dictionary<int, CreationLiquid> vials = new Dictionary<int, CreationLiquid>();
    CreationLiquid specialK, barrel;
    // What Paint took out of the prop it is painting, to drain on its own.
    Dictionary<int, Dictionary<Vector3Int, int>> taken;
    Light screens, focus;
    float unit; Tuning tuning;
    Shader lit;
    readonly Dictionary<float, Material> materials = new Dictionary<float, Material>();
    readonly List<UnityEngine.Object> owned = new List<UnityEngine.Object>();

    // How many of the set's five models were found and built.
    public int Props { get; private set; }

    // Builds the set for `lab`; null (said once in the log) when it cannot be built, and the screen shows its flat backdrop.
    public static CreationLabView Build(CreationLab lab, IList<CreationTitan> titans)
    {
        var view = new CreationLabView { titans = titans };
        try
        {
            view.Make(lab);
            if (view.Props > 0) return view;
            Warn("set", "creation: no lab model under assets/lab, a flat backdrop instead");
        }
        catch (Exception e)
        {
            Warn("build", "creation: the lab set could not be built, a flat backdrop instead: " + e.Message);
        }
        view.Close();
        return null;
    }

    static void Warn(string key, string line)
    {
        if (warned.Add(key)) Debug.LogWarning(line);
    }

    // Godot's axes to Unity's: z is mirrored, so a turn about Y runs the other way.
    static Vector3 U(CreationVec v) => new Vector3((float)v.x, (float)v.y, -(float)v.z);

    static Quaternion Turn(double radians) => Quaternion.Euler(0f, -(float)(radians * 180.0 / Math.PI), 0f);

    static Color Hex(string key)
    {
        S.GDict colors = CreationLab.Cfg()["colors"];
        int v = Convert.ToInt32(S.Gd.Str(colors[key]).Substring(0, 6), 16);
        return new Color(((v >> 16) & 255) / 255f, ((v >> 8) & 255) / 255f, (v & 255) / 255f, 1f);
    }

    static int Rgb(Color32 c) => CreationPaint.Pack(c.r, c.g, c.b);

    void Make(CreationLab lab)
    {
        root = new GameObject("creation_lab");
        tuning = SliceData.LoadTuning();
        unit = SliceGame.ExposureUnit(tuning);
        lit = Resources.Load<Shader>("Shaders/SliceLit");
        if (lit == null) throw new InvalidOperationException("Shaders/SliceLit is missing");
        Environment(tuning);
        Lights();
        Bench();
        Room();
        foreach (string prop in new[] { "cradle", "monitors", "rack" }) Place(prop, null);
        Place("canister", lab.CanisterAt);
        Injector(lab);
        Glows();
        var go = new GameObject("camera");
        go.transform.SetParent(root.transform, false);
        cam = go.AddComponent<Camera>();
        cam.nearClipPlane = NEAR;
        cam.farClipPlane = FAR;
        cam.depth = CAMERA_DEPTH;
        HDAdditionalCameraData data = go.AddComponent<HDAdditionalCameraData>();
        GraphicsView.UseCamera(data);
        // creation_set.gd environment: the room is a flat near-black, the ambient its own colour.
        data.clearColorMode = HDAdditionalCameraData.ClearColorMode.Color;
        data.backgroundColorHDR = Hex("background").linear * unit;
        Draw(lab);
    }

    // creation_set.gd environment: ambient colour and energy, AgX with the look's contrast and saturation.
    void Environment(Tuning tuning)
    {
        Shader.SetGlobalVector(SLICE_AMBIENT, Hex("ambient").linear * (float)CreationLab.Energy("ambient"));
        VolumeProfile profile = ScriptableObject.CreateInstance<VolumeProfile>();
        owned.Add(profile);
        var environment = profile.Add<VisualEnvironment>(true);
        environment.skyType.Override((int)SkyType.Gradient);
        environment.skyAmbientMode.Override(SkyAmbientMode.Static);
        var sky = profile.Add<GradientSky>(true);
        Color ambient = Hex("ambient").linear * (float)CreationLab.Energy("ambient");
        sky.top.Override(ambient);
        sky.middle.Override(ambient);
        sky.bottom.Override(ambient);
        sky.skyIntensityMode.Override(SkyIntensityMode.Multiplier);
        sky.multiplier.Override(unit);
        var exposure = profile.Add<Exposure>(true);
        exposure.mode.Override(ExposureMode.Fixed);
        exposure.fixedExposure.Override(tuning.hdrp_ev);
        profile.Add<Tonemapping>(true).mode.Override(TonemappingMode.None);
        Dictionary<string, object> look = MiniJson.Obj(SliceData.LoadJson("slice.json")["look"]);
        var agx = profile.Add<AgxTonemap>(true);
        agx.exposure.Override(GODOT_TONEMAP_EXPOSURE);
        agx.contrast.Override(GODOT_AGX_CONTRAST);
        agx.white.Override(tuning.agx_white);
        agx.saturation.Override(SliceData.F(look, "saturation", 1));
        agx.postContrast.Override(SliceData.F(look, "contrast", 1));
        profile.Add<MotionBlur>(true).intensity.Override(0f);
        // creation_set.gd environment: a thin haze lit only by the lamps, over the near-black room.
        var fog = profile.Add<Fog>(true);
        fog.enabled.Override(true);
        fog.meanFreePath.Override(1f / (float)S.Num.F(CreationLab.Cfg()["fog"]));
        fog.colorMode.Override(FogColorMode.ConstantColor);
        fog.color.Override(Hex("background").linear * unit);
        fog.enableVolumetricFog.Override(true);
        var go = new GameObject("volume");
        go.transform.SetParent(root.transform, false);
        Volume volume = go.AddComponent<Volume>();
        volume.isGlobal = true;
        volume.priority = VOLUME_PRIORITY;
        volume.sharedProfile = profile;
    }

    // Godot energy as HDRP candela for lamp `name`, matched to Godot at its subject (tuning.json lab_*_match_m).
    float Candela(double energy, string name) => (float)energy * Mathf.PI * unit * tuning.LabMatch(name);

    Light Lamp(string name, LightType type, Color colour, double energy, float range, CreationVec at)
    {
        var go = new GameObject(name);
        go.transform.SetParent(root.transform, false);
        go.transform.position = U(at);
        Light light = go.AddComponent<Light>();
        light.type = type;
        light.shadows = LightShadows.None;
        light.lightUnit = LightUnit.Candela;
        go.AddComponent<HDAdditionalLightData>();
        light.color = colour;
        light.range = range;
        light.intensity = Candela(energy, name);
        return light;
    }

    // The cold key lamp over the dish (shadows on) and the warm rim behind the set.
    void Lights()
    {
        Light key = Lamp("key", LightType.Spot, Hex("key"), CreationLab.Energy("key"), KEY_RANGE, KEY_AT);
        key.spotAngle = KEY_HALF_ANGLE * 2f;  // Godot's cone is the half angle
        key.shadows = LightShadows.Soft;
        key.transform.LookAt(U(KEY_LOOK));
        Lamp("rim", LightType.Point, Hex("rim"), CreationLab.Energy("rim"), RIM_RANGE, RIM_AT);
    }

    void Glows()
    {
        focus = Lamp("focus", LightType.Point, Hex("screen"), 0.0, FOCUS_RANGE, CreationLab.VialPoint(0) + FOCUS_OFF);
        S.GDict props = CreationLab.Cfg()["props"];
        S.GDict monitors = props["monitors"];
        screens = Lamp("screens", LightType.Point, Hex("screen"), CreationLab.Energy("screens"), SCREENS_RANGE, CreationLab.Vec(monitors["at"]) + SCREENS_OFF);
    }

    Material Surface(float voxel)
    {
        if (materials.TryGetValue(voxel, out Material known)) return known;
        Material m = ArmyView.PlainMaterial(lit, voxel);
        m.SetFloat("_WindowGlow", (float)S.Num.F(CreationLab.Cfg()["glow"]));
        materials[voxel] = m;
        owned.Add(m);
        return m;
    }

    // creation_room.gd build: the walls, shelves, cables, screens and strip, and the strip's cold washes.
    void Room()
    {
        CreationRoom room = CreationRoom.Build();
        Show("room", ArmyView.Faces(room.Model(out bool[] glow), room.Voxel, Vector3.zero, glow), room.Voxel, root.transform, false);
        foreach (CreationVec at in room.Washes())
            Lamp("wash", LightType.Point, room.WashColour, room.WashEnergy, room.WashRange, at);
    }

    Transform Show(string name, Mesh mesh, float voxel, Transform parent, bool shadows)
    {
        owned.Add(mesh);
        var go = new GameObject(name);
        go.transform.SetParent(parent, false);
        go.AddComponent<MeshFilter>().sharedMesh = mesh;
        MeshRenderer r = go.AddComponent<MeshRenderer>();
        r.sharedMaterial = Surface(voxel);
        r.shadowCastingMode = shadows ? ShadowCastingMode.On : ShadowCastingMode.Off;
        return go.transform;
    }

    // creation_set.gd slab("bench"): the bench top at the bench's height (y 0), centred on its `at`. One flat face
    // here, not blocks.
    void Bench()
    {
        S.GDict row = CreationLab.Cfg()["bench"];
        S.GArray<S.Variant> size = row["size"];
        float hx = (float)S.Num.F(size[0]) * 0.5f, hz = (float)S.Num.F(size[1]) * 0.5f;
        Color32 colour = Hex("bench");
        var mesh = new Mesh { name = "bench" };
        mesh.vertices = new[] { new Vector3(-hx, 0, -hz), new Vector3(-hx, 0, hz), new Vector3(hx, 0, hz), new Vector3(hx, 0, -hz) };
        mesh.normals = new[] { Vector3.up, Vector3.up, Vector3.up, Vector3.up };
        mesh.colors32 = new[] { colour, colour, colour, colour };
        mesh.uv = new[] { new Vector2(1f, 0f), new Vector2(1f, 0f), new Vector2(1f, 0f), new Vector2(1f, 0f) };
        mesh.triangles = new[] { 0, 1, 2, 0, 2, 3 };
        Transform t = Show("bench", mesh, Voxel(), root.transform, true);
        t.position = U(CreationLab.Vec(row["at"]));
    }

    static float Voxel() => (float)S.Num.F(CreationLab.Cfg()["voxel"]);

    // creation_set.gd read: a prop's model off disk (null, said once, with no file).
    static ModelColors.Model Read(string prop, out float voxel)
    {
        S.GDict props = CreationLab.Cfg()["props"];
        S.GDict row = props[prop];
        voxel = row.Has("voxel") ? (float)S.Num.F(row["voxel"]) : Voxel();
        string path = row.Has("model") ? S.Gd.Str(row["model"]) : "res://assets/lab/" + prop + ".kvox";
        ModelColors.Model model = ModelColors.Read(path);
        if (model == null)
        {
            Warn(path, "creation: " + path + " is missing, the lab is drawn without it");
            return null;
        }
        model = CreationPaint.Copy(model);
        CreationPaint.Despeckle(model);
        return model;
    }

    // creation_set.gd place: the prop at its `at` (or `where`), turned by its yaw.
    // creation_lab.gd _add_props: the dish cleaned, the screens lit, the serums and the Special K in their glass.
    bool[] Paint(string prop, ref ModelColors.Model model)
    {
        if (prop == "monitors") return CreationPaint.Screens(model, Rgb(Hex("screen")), Rgb(Hex("screen_glass")));
        Dictionary<Vector3Int, int> cells = CreationPaint.Cells(model);
        if (prop == "cradle") CreationDish.Clean(cells);
        else if (prop == "rack") taken = CreationPaint.Rack(cells, titans);
        else if (prop == "canister") taken = new Dictionary<int, Dictionary<Vector3Int, int>> { [0] = CreationPaint.Canister(cells) };
        else return null;
        model = CreationPaint.Model(cells, null, out bool[] glow);
        return glow;
    }

    void Place(string prop, CreationVec? where)
    {
        ModelColors.Model model = Read(prop, out float voxel);
        if (model == null) return;
        CreationLab.Placed(prop, out CreationVec at, out double yaw);
        taken = null;
        bool[] glow = Paint(prop, ref model);
        Transform t = Show(prop, ArmyView.Faces(model, voxel, Vector3.zero, glow), voxel, root.transform, true);
        t.position = U(where ?? at);
        t.rotation = Turn(yaw);
        Props++;
        if (taken == null) return;
        foreach (KeyValuePair<int, Dictionary<Vector3Int, int>> liquid in taken)
        {
            CreationLiquid l = Liquid(prop, liquid.Value, voxel, t);
            if (prop == "canister") specialK = l;
            else vials[liquid.Key] = l;
        }
    }

    // A liquid drawn on its own under `parent` (creation_liquid.gd), shown full until Draw says otherwise.
    CreationLiquid Liquid(string name, Dictionary<Vector3Int, int> empties, float voxel, Transform parent)
    {
        var liquid = new CreationLiquid(empties, voxel);
        Show(name + "_liquid", liquid.Mesh, voxel, parent, false);
        return liquid;
    }

    // creation_injector.gd _ready: the static post, the carriage that rises, turns and slides, and its glass barrel.
    void Injector(CreationLab lab)
    {
        ModelColors.Model model = Read("injector", out float voxel);
        if (model == null) return;
        Color32 steel = Hex("needle");
        CreationInjector.Split(lab, model, voxel, CreationPaint.Pack(steel.r, steel.g, steel.b), out var post, out var head, out var glass);
        var holder = new GameObject("injector");
        holder.transform.SetParent(root.transform, false);
        holder.transform.position = U(lab.Post);
        // It casts no shadow: under the key lamp the head's shadow lay on the agar as a blot.
        Transform column = Show("post", ArmyView.Faces(Model(post), voxel, Vector3.zero), voxel, holder.transform, false);
        column.localRotation = Turn(lab.PostYaw());
        carriage = Show("carriage", ArmyView.Faces(Model(head), voxel, Vector3.zero), voxel, holder.transform, false);
        barrel = Liquid("barrel", glass, voxel, carriage);
        Props++;
    }

    static ModelColors.Model Model(Dictionary<Vector3Int, int> cells)
    {
        var xyz = new S.PackedInt32Array();
        xyz.Resize(cells.Count * 3);
        int[] raw = xyz.Raw;
        var rgb = new int[cells.Count];
        int i = 0;
        foreach (KeyValuePair<Vector3Int, int> cell in cells)
        {
            raw[i * 3] = cell.Key.x;
            raw[i * 3 + 1] = cell.Key.y;
            raw[i * 3 + 2] = cell.Key.z;
            rgb[i++] = cell.Value;
        }
        return new ModelColors.Model { xyz = xyz, rgb = rgb };
    }

    // Shows the lab as `lab` stands this tick: the injector's pose, the glows, the camera and its shake.
    public void Draw(CreationLab lab)
    {
        if (root == null) return;
        if (carriage != null)
        {
            carriage.localPosition = U(lab.CarriageAt());
            carriage.localRotation = Turn(lab.Yaw);
        }
        Liquids(lab);
        if (screens != null) screens.intensity = Candela(lab.ScreensEnergy, "screens");
        if (focus != null)
        {
            focus.intensity = Candela(lab.Focused >= 0 ? CreationLab.Energy("focus") : 0.0, "focus");
            focus.transform.position = U(CreationLab.VialPoint(Math.Max(lab.Focused, 0)) + FOCUS_OFF);
        }
        if (cam == null) return;
        Transform t = cam.transform;
        t.position = U(lab.CameraAt);
        t.LookAt(U(lab.CameraLook), Vector3.up);
        // Godot's h_offset / v_offset: the view slides along the camera's own right and up.
        t.position += t.right * (float)lab.ShakeX + t.up * (float)lab.ShakeY;
        cam.fieldOfView = (float)lab.CameraFov;
    }

    // creation_lab.gd place / inject / takeover: the serums drain, the Special K is drawn, the barrel fills and
    // empties, in the picked genome's colour or Special K's.
    void Liquids(CreationLab lab)
    {
        foreach (KeyValuePair<int, CreationLiquid> vial in vials)
            if (vial.Key < lab.Vials.Length) vial.Value.Show(lab.Vials[vial.Key], Genome(vial.Key));
        if (specialK != null) specialK.Show(lab.SpecialK, Hex("special_k"));
        if (barrel == null) return;
        bool genome = !lab.BarrelIsSpecialK && lab.Picked >= 0 && lab.Picked < titans.Count;
        barrel.Show(lab.Barrel, genome ? Genome(lab.Picked) : Hex("special_k"));
    }

    Color Genome(int titan) => CreationPaint.Rgb(CreationPaint.Hex(titans[titan].Genome));

    // Takes the set, its camera and its lights away.
    public void Close()
    {
        if (root != null) UnityEngine.Object.Destroy(root);
        root = null;
        foreach (UnityEngine.Object o in owned)
            if (o != null) UnityEngine.Object.Destroy(o);
        owned.Clear();
        materials.Clear();
        vials.Clear();
        specialK = barrel = null;
    }
}
