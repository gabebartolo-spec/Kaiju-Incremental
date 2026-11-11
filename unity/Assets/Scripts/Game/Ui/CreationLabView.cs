// The lab set of Kaiju Creation in 3D (scenes/creation_lab.gd, creation_set.gd, creation_injector.gd): the bench,
// the cradle with its dish, the rack of vials, the monitors, the Special K canister and the injector (a post and
// a carriage that rises, turns and slides), under the key lamp and the rim, seen by the lab's own camera. It
// draws what CreationLab (the numbers) says each tick. First version (D-476): the models as they are on disk,
// with no liquids, genome, lightning, room walls or screen paint yet.
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

    static readonly HashSet<string> warned = new HashSet<string>();

    GameObject root;
    Camera cam;
    Transform carriage;
    Light screens, focus;
    float unit;
    Shader lit;
    readonly Dictionary<float, Material> materials = new Dictionary<float, Material>();
    readonly List<UnityEngine.Object> owned = new List<UnityEngine.Object>();

    // How many of the set's five models were found and built.
    public int Props { get; private set; }

    // Builds the set for `lab`; null (said once in the log) when it cannot be built, and the screen shows its flat backdrop.
    public static CreationLabView Build(CreationLab lab)
    {
        var view = new CreationLabView();
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

    void Make(CreationLab lab)
    {
        root = new GameObject("creation_lab");
        Tuning tuning = SliceData.LoadTuning();
        unit = SliceGame.ExposureUnit(tuning);
        lit = Resources.Load<Shader>("Shaders/SliceLit");
        if (lit == null) throw new InvalidOperationException("Shaders/SliceLit is missing");
        Environment(tuning);
        Lights();
        Bench();
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
        data.antialiasing = HDAdditionalCameraData.AntialiasingMode.SubpixelMorphologicalAntiAliasing;
        // creation_set.gd environment: the room is a flat near-black, the ambient its own colour.
        data.clearColorMode = HDAdditionalCameraData.ClearColorMode.Color;
        data.backgroundColorHDR = Hex("background").linear * unit;
        Draw(lab);
    }

    // creation_set.gd environment: ambient colour and energy, AgX with the look's contrast and saturation.
    void Environment(Tuning tuning)
    {
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
        agx.exposure.Override(SliceData.F(look, "exposure", 1));
        agx.contrast.Override(SliceData.F(look, "agx_contrast", 1));
        agx.white.Override(tuning.agx_white);
        agx.saturation.Override(SliceData.F(look, "saturation", 1));
        agx.postContrast.Override(SliceData.F(look, "post_contrast", 1));
        profile.Add<MotionBlur>(true).intensity.Override(0f);
        var go = new GameObject("volume");
        go.transform.SetParent(root.transform, false);
        Volume volume = go.AddComponent<Volume>();
        volume.isGlobal = true;
        volume.sharedProfile = profile;
    }

    // One unit of Godot light energy as HDRP candela (the rampage's lamps use the same).
    float Candela(double energy) => (float)energy * Mathf.PI * unit;

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
        light.intensity = Candela(energy);
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
        materials[voxel] = m;
        owned.Add(m);
        return m;
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
        if (model == null) Warn(path, "creation: " + path + " is missing, the lab is drawn without it");
        return model;
    }

    // creation_set.gd place: the prop at its `at` (or `where`), turned by its yaw.
    void Place(string prop, CreationVec? where)
    {
        ModelColors.Model model = Read(prop, out float voxel);
        if (model == null) return;
        CreationLab.Placed(prop, out CreationVec at, out double yaw);
        Transform t = Show(prop, ArmyView.Faces(model, voxel, Vector3.zero), voxel, root.transform, true);
        t.position = U(where ?? at);
        t.rotation = Turn(yaw);
        Props++;
    }

    // creation_injector.gd _ready: the model split into the static post (its column carried on up, its foot clear
    // of the cradle) and the carriage (the boom and the head, the needle lengthened in steel).
    void Injector(CreationLab lab)
    {
        ModelColors.Model model = Read("injector", out float voxel);
        if (model == null) return;
        S.GDict cfg = CreationLab.Cfg()["injector"];
        S.GArray<S.Variant> pv = cfg["pivot"];
        var pivot = new Vector3Int((int)S.Num.I(pv[0]), 0, (int)S.Num.I(pv[1]));
        int splitX = (int)S.Num.I(cfg["split_x"]), splitY = (int)S.Num.I(cfg["split_y"]);
        var post = new Dictionary<Vector3Int, int>();
        var head = new Dictionary<Vector3Int, int>();
        int[] raw = model.xyz.Raw;
        for (int i = 0; i < model.rgb.Length; i++)
        {
            var cell = new Vector3Int(raw[i * 3], raw[i * 3 + 1], raw[i * 3 + 2]);
            bool onCarriage = cell.x >= splitX || cell.y >= splitY;
            (onCarriage ? head : post)[cell - pivot] = model.rgb[i];
        }
        // _extend_post: the post's cross-section at profile_y repeated from split_y up, for the carriage to ride.
        int profile = (int)S.Num.I(cfg["profile_y"]), extend = (int)S.Num.I(cfg["post_extend"]);
        var ring = new List<KeyValuePair<Vector3Int, int>>();
        foreach (KeyValuePair<Vector3Int, int> cell in post)
            if (cell.Key.y == profile) ring.Add(cell);
        for (int y = splitY; y < splitY + extend; y++)
            foreach (KeyValuePair<Vector3Int, int> cell in ring)
                post[new Vector3Int(cell.Key.x, y, cell.Key.z)] = cell.Value;
        // _seat: the foot's blocks inside the cradle's rim go.
        double seat = S.Num.F(cfg["post_seat"]), turn = lab.PostYaw();
        foreach (Vector3Int cell in new List<Vector3Int>(post.Keys))
        {
            CreationVec w = new CreationVec(cell.x, 0.0, cell.z).Turned(turn) * voxel;
            if ((lab.Post + w).FlatLength() < seat) post.Remove(cell);
        }
        // _lengthen: a cross, then one block at the point.
        S.GArray<S.Variant> tc = cfg["tip"];
        var tip = new Vector3Int((int)S.Num.I(tc[0]), (int)S.Num.I(tc[1]), (int)S.Num.I(tc[2])) - pivot;
        int needle = (int)S.Num.I(cfg["needle"]);
        Color32 steel32 = Hex("needle");
        int steel = steel32.r << 16 | steel32.g << 8 | steel32.b;
        Vector3Int[] sides = { Vector3Int.left, Vector3Int.right, new Vector3Int(0, 0, -1), new Vector3Int(0, 0, 1) };
        for (int i = 1; i <= needle; i++)
        {
            Vector3Int at = tip - new Vector3Int(0, i, 0);
            head[at] = steel;
            if (i > needle - 3) continue;
            foreach (Vector3Int d in sides) head[at + d] = steel;
        }
        var holder = new GameObject("injector");
        holder.transform.SetParent(root.transform, false);
        holder.transform.position = U(lab.Post);
        // It casts no shadow: under the key lamp the head's shadow lay on the agar as a blot.
        Transform column = Show("post", ArmyView.Faces(Model(post), voxel, Vector3.zero), voxel, holder.transform, false);
        column.localRotation = Turn(lab.PostYaw());
        carriage = Show("carriage", ArmyView.Faces(Model(head), voxel, Vector3.zero), voxel, holder.transform, false);
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
        if (screens != null) screens.intensity = Candela(lab.ScreensEnergy);
        if (focus != null)
        {
            focus.intensity = Candela(lab.Focused >= 0 ? CreationLab.Energy("focus") : 0.0);
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

    // Takes the set, its camera and its lights away.
    public void Close()
    {
        if (root != null) UnityEngine.Object.Destroy(root);
        root = null;
        foreach (UnityEngine.Object o in owned)
            if (o != null) UnityEngine.Object.Destroy(o);
        owned.Clear();
        materials.Clear();
    }
}
