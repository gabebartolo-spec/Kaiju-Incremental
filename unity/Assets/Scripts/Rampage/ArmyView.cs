using System.Collections.Generic;
using UnityEngine;
using S = Kaiju.Sim;

// The sim's army on screen: tank_model.gd, tank_yard.gd, tank_fx.gd, helicopter_model.gd, powers_view.gd's
// helicopters, heli_wreck.gd's fall and crash, and taskforce_view.gd's placeholder boxes (D-143). It reads the
// sim and its events and never decides an outcome. Positions arrive in Godot axes; z flips at Mirror().
public sealed class ArmyView
{
    // scenes/tank_model.gd, tank_fx.gd, helicopter_model.gd, taskforce_view.gd and ui_kit.gd.
    static readonly Color TANK_PAINT = Hex("6d7854"), HELI_PAINT = Hex("748059"), ACCENT = Hex("ffcc00"), WARN = Hex("ffd84a");
    static readonly Color OBSIDIAN = new Color(0.04f, 0.04f, 0.06f), GAS_SUIT = new Color(0.08f, 0.12f, 0.22f), BLUE = new Color(0.1f, 0.5f, 1f);
    static readonly Color WRECK_FLASH = Hex("ff8a3a"), MUZZLE_FLASH = Hex("ffc070"), CRASH_BLAST = Hex("ff8a3a");
    static readonly Vector3 AGENT = new Vector3(0.5f, 1f, 0.5f), MECH = new Vector3(0.12f, 0.25f, 0.12f), SHIP = new Vector3(3f, 1.2f, 1.2f);
    const float SHELL_SIZE = 0.35f, BARREL_DROP = -0.1f, WRECK_LIFT = 0.5f, AIM_HEIGHT = 2f, HIT_HEIGHT = 4f, HELI_AIM_HEIGHT = 3f;
    const float WRECK_LIGHT = 7f, WRECK_LIGHT_S = 0.5f, WRECK_FIRE = 0.6f, MUZZLE_LIGHT = 4f, MUZZLE_LIGHT_S = 0.12f;
    const float STRAY_LIGHT = 9f, STRAY_LIGHT_S = 0.45f, STRAY_DUST = 1.2f, STRAY_FIRE = 0.35f;
    const float LASER_WIDTH = 0.12f, LASER_SECONDS = 0.2f, AIM_LINE_WIDTH = 0.06f, CHEST = 2f, BOMB_RING_BOXES = 32f, BOMB_BOX = 0.3f;
    const int WRECK_CHUNKS = 8, CRASH_CHUNKS = 14;
    const float CHUNK_SIZE = 0.3f, GAS_PUFF_EVERY = 0.5f, FALL_SPIN = 3f, FALL_PITCH = 0.9f, FALL_ROLL = 0.7f;

    sealed class Tank
    {
        public Transform root, turret, barrel;
        public Vector3 barrelRest, turretAt;
        public float yaw, turretYaw, pitch, kick, muzzleZ, beaconClock;
        public GameObject beacon;
    }

    sealed class Heli
    {
        public Transform root, mainRotor, tailRotor, gun;
        public GameObject strobe;
        public float yaw, spin, clock, muzzleZ;
        public bool falling;
        public Vector3 fallFrom, fallDrift;
        public float fallT, fallSeconds;
    }

    sealed class Shell
    {
        public Transform box;
        public Vector3 from, to;
        public float t;
        public bool miss;
    }

    sealed class Chunk
    {
        public Transform box;
        public Vector3 velocity;
        public float left;
    }

    readonly S.RampageSim sim;
    readonly CityFx fx;
    readonly Material material;
    readonly Transform root;
    readonly System.Random rng;
    readonly Dictionary<long, Tank> tanks = new Dictionary<long, Tank>();
    readonly Dictionary<long, Heli> helis = new Dictionary<long, Heli>();
    readonly List<Shell> shells = new List<Shell>();
    readonly List<Chunk> chunks = new List<Chunk>();
    readonly Dictionary<Color32, Mesh> boxes = new Dictionary<Color32, Mesh>();
    readonly List<Transform> taskforceBoxes = new List<Transform>();
    readonly Dictionary<string, Mesh> partMeshes = new Dictionary<string, Mesh>();
    readonly S.GDict vehicles, wreck;
    readonly float tankVoxel, heliVoxel, shellFlight, chunkGravity, throwMin, throwMax, upMin, upMax, chunkRest;
    readonly S.GDict tankParts, heliParts;
    readonly bool beaconsOn;
    float gasWait;
    int boxesUsed;

    static float F(S.GDict d, string key) => (float)(double)S.Num.F(d[key]);

    static Color Hex(string hex)
    {
        ColorUtility.TryParseHtmlString("#" + hex, out Color c);
        return c;
    }

    static Vector3 Mirror(Vector3 v) => new Vector3(v.x, v.y, -v.z);

    static Vector3 Unity(S.Vector3 v) => new Vector3((float)v.x, (float)v.y, -(float)v.z);

    // Godot basis M becomes S M S (S mirrors z): -Z is its forward, as Unity's +Z after the mirror.
    static Quaternion Mirrored(S.Basis m)
    {
        Vector3 forward = Unity(m * new S.Vector3(0, 0, -1));
        Vector3 up = Unity(m * new S.Vector3(0, 1, 0));
        return Quaternion.LookRotation(forward, up);
    }

    public ArmyView(S.RampageSim sim, CityFx fx, Shader shader, Transform parent, int seed)
    {
        this.sim = sim;
        this.fx = fx;
        rng = new System.Random(seed);
        root = new GameObject("army").transform;
        root.SetParent(parent, false);
        vehicles = S.Content.Section("vehicles");
        wreck = S.Content.Section("heli_wreck");
        tankParts = S.Content.LoadJson("res://assets/vehicles/tank.parts.json");
        heliParts = S.Content.LoadJson("res://assets/vehicles/heli.parts.json");
        tankVoxel = F(vehicles, "tank_height") / Mathf.Max(1f, F(tankParts, "height") - 1f);
        heliVoxel = F(vehicles, "heli_height") / Mathf.Max(1f, F(heliParts, "height") - 1f);
        material = PlainMaterial(shader, tankVoxel);
        shellFlight = F(sim.army, "shell_flight");
        chunkGravity = F(wreck, "gravity");
        throwMin = F(wreck, "throw_min");
        throwMax = F(wreck, "throw_max");
        upMin = F(wreck, "up_min");
        upMax = F(wreck, "up_max");
        chunkRest = F(wreck, "rest_seconds");
        beaconsOn = F(S.Content.Look(), "lamp_energy") > 0f;
    }

    // The city's voxel surface with no windows or jitter, for models that bring their own colours.
    public static Material PlainMaterial(Shader shader, float voxel)
    {
        var m = new Material(shader);
        m.EnableKeyword("SLICE_BUILDING");
        m.SetFloat("_CullMode", 0);
        m.SetFloat("_CullModeForward", 0);
        m.SetVector("_VoxelOrigin", Vector3.zero);
        m.SetFloat("_VoxelSize", voxel);
        m.SetFloat("_Salt", 0f);
        m.SetFloat("_Noise", 0f);
        m.SetVector("_WinUnit", Vector2.one);
        m.SetVector("_WinAlign", Vector2.zero);
        return m;
    }

    // ---------- Voxel parts ----------

    static Vector3 Pivot(S.GDict parts, string part, float voxel)
    {
        S.GDict all = parts["parts"];
        S.GDict entry = all[part];
        S.GArray<S.Variant> p = entry["pivot"];
        return new Vector3((float)(double)S.Num.F(p[0]), (float)(double)S.Num.F(p[1]), (float)(double)S.Num.F(p[2])) * voxel;
    }

    // A part's most forward (-Z) voxel, in the model's space (VehicleParts.front).
    static float Front(S.GDict parts, string part, float voxel)
    {
        ModelColors.Model m = Model(parts, part);
        int[] raw = m.xyz.Raw;
        int low = int.MaxValue;
        for (int i = 2; i < raw.Length; i += 3) low = Mathf.Min(low, raw[i]);
        return low * voxel;
    }

    static ModelColors.Model Model(S.GDict parts, string part)
    {
        S.GDict all = parts["parts"];
        S.GDict entry = all[part];
        return ModelColors.Read("res://assets/vehicles/" + S.Gd.Str(entry["kvox"]));
    }

    public static Mesh Faces(ModelColors.Model model, float voxel, Vector3 pivot)
    {
        int[] raw = model.xyz.Raw;
        int count = raw.Length / 3;
        var solid = new HashSet<Vector3Int>();
        for (int i = 0; i < count; i++) solid.Add(new Vector3Int(raw[i * 3], raw[i * 3 + 1], raw[i * 3 + 2]));
        var verts = new List<Vector3>();
        var normals = new List<Vector3>();
        var colors = new List<Color32>();
        var uvs = new List<Vector2>();
        var tris = new List<int>();
        Vector3Int[] ways = { Vector3Int.right, Vector3Int.left, Vector3Int.up, Vector3Int.down, new Vector3Int(0, 0, 1), new Vector3Int(0, 0, -1) };
        float half = voxel * 0.5f;
        for (int i = 0; i < count; i++)
        {
            var cell = new Vector3Int(raw[i * 3], raw[i * 3 + 1], raw[i * 3 + 2]);
            Vector3 centre = Mirror(new Vector3(cell.x * voxel, (cell.y + 0.5f) * voxel, cell.z * voxel) - pivot);
            int c = model.rgb[i];
            var color = new Color32((byte)(c >> 16), (byte)(c >> 8), (byte)c, 255);
            foreach (Vector3Int way in ways)
            {
                if (solid.Contains(cell + way)) continue;
                Vector3 n = Mirror(way);
                Vector3 u = Mathf.Abs(n.y) > 0.5f ? Vector3.right : Vector3.up;
                Vector3 v = Vector3.Cross(u, n);
                int at = verts.Count;
                verts.Add(centre + (n - u - v) * half);
                verts.Add(centre + (n - u + v) * half);
                verts.Add(centre + (n + u + v) * half);
                verts.Add(centre + (n + u - v) * half);
                for (int k = 0; k < 4; k++)
                {
                    normals.Add(n);
                    colors.Add(color);
                    uvs.Add(new Vector2(1f, 0f));
                }
                tris.Add(at);
                tris.Add(at + 1);
                tris.Add(at + 2);
                tris.Add(at);
                tris.Add(at + 2);
                tris.Add(at + 3);
            }
        }
        var mesh = new Mesh { indexFormat = UnityEngine.Rendering.IndexFormat.UInt32 };
        mesh.SetVertices(verts);
        mesh.SetNormals(normals);
        mesh.SetColors(colors);
        mesh.SetUVs(0, uvs);
        mesh.SetTriangles(tris, 0);
        return mesh;
    }

    Transform Part(S.GDict parts, string kind, string part, float voxel, Transform parent, Vector3 at)
    {
        string key = kind + part;
        if (!partMeshes.TryGetValue(key, out Mesh mesh))
            partMeshes[key] = mesh = Faces(Model(parts, part), voxel, Pivot(parts, part, voxel));
        var go = new GameObject(part);
        go.transform.SetParent(parent, false);
        go.transform.localPosition = Mirror(at);
        go.AddComponent<MeshFilter>().sharedMesh = mesh;
        go.AddComponent<MeshRenderer>().sharedMaterial = material;
        return go.transform;
    }

    Mesh Box(Color color, byte alpha)
    {
        Color32 c = color;
        c.a = alpha;
        if (boxes.TryGetValue(c, out Mesh known)) return known;
        var model = new ModelColors.Model { xyz = new S.PackedInt32Array(), rgb = new[] { c.r << 16 | c.g << 8 | c.b } };
        model.xyz.Resize(3);
        Mesh mesh = Faces(model, 1f, new Vector3(0f, 0.5f, 0f));
        if (alpha != 255)
        {
            var colors = new Color32[mesh.vertexCount];
            for (int i = 0; i < colors.Length; i++) colors[i] = c;
            mesh.SetColors(colors);
        }
        boxes[c] = mesh;
        return mesh;
    }

    Transform MakeBox(Color color, byte alpha, Transform parent)
    {
        var go = new GameObject("box");
        go.transform.SetParent(parent != null ? parent : root, false);
        go.AddComponent<MeshFilter>().sharedMesh = Box(color, alpha);
        go.AddComponent<MeshRenderer>().sharedMaterial = material;
        return go.transform;
    }

    // ---------- Events ----------

    public void OnEvent(S.GDict e, Vector3 kaiju)
    {
        switch (S.Gd.Str(e["type"]))
        {
            case "tank_spawned": SpawnTank(S.Num.I(e["tank"])); break;
            case "tank_destroyed":
            case "tank_husk_down": TankDown(e); break;
            case "tank_fired": TankFired(e, kaiju); break;
            case "stray_landed": Stray(e); break;
            case "heli_spawned": SpawnHeli(S.Num.I(e["heli"])); break;
            case "heli_fired": HeliFired(S.Num.I(e["heli"])); break;
            case "heli_destroyed": HeliDown(e); break;
            case "heli_crashed": HeliCrashed(e); break;
            case "gunship_destroyed": Burst(EventAt(e, (float)sim.armyUnits.taskforce.gunships.Altitude()), OBSIDIAN); break;
        }
    }

    static Vector3 EventAt(S.GDict e, float height) => new Vector3(
        (float)(double)S.Num.F(e["x"]), e.Has("y") ? (float)(double)S.Num.F(e["y"]) : height, (float)(double)S.Num.F(e["z"]));

    void SpawnTank(long id)
    {
        var body = new GameObject("tank").transform;
        body.SetParent(root, false);
        float v = tankVoxel;
        Vector3 hull = Pivot(tankParts, "hull", v), turret = Pivot(tankParts, "turret", v), barrel = Pivot(tankParts, "barrel", v);
        var centre = new Vector3(hull.x, 0f, hull.z);
        Part(tankParts, "tank", "hull", v, body, hull - centre);
        var t = new Tank { root = body, turretAt = turret - centre, barrelRest = barrel - turret };
        t.turret = Part(tankParts, "tank", "turret", v, body, t.turretAt);
        t.barrel = Part(tankParts, "tank", "barrel", v, t.turret, t.barrelRest);
        t.muzzleZ = Front(tankParts, "barrel", v) - barrel.z;
        if (beaconsOn)
        {
            S.GDict lamp = vehicles["tank_beacon"];
            Transform box = MakeBox(Hex(S.Gd.Str(lamp["color"])), 0, body);
            float size = F(lamp, "size");
            box.localScale = Vector3.one * size;
            box.localPosition = new Vector3(0f, F(vehicles, "tank_height"), 0f);
            t.beacon = box.gameObject;
        }
        tanks[id] = t;
    }

    void TankDown(S.GDict e)
    {
        Vector3 at = EventAt(e, 0f) + Vector3.up * WRECK_LIFT;
        long id = S.Num.I(e["tank"]);
        bool husk = e.Has("husk") && (bool)e["husk"];
        if (!husk && tanks.TryGetValue(id, out Tank t))
        {
            Object.Destroy(t.root.gameObject);
            tanks.Remove(id);
        }
        Chunks(at, WRECK_CHUNKS, TANK_PAINT, ACCENT);
        fx.FlashLight(at + Vector3.up, WRECK_FLASH, WRECK_LIGHT, WRECK_LIGHT_S);
        fx.Fire(at, WRECK_FIRE);
    }

    void TankFired(S.GDict e, Vector3 kaiju)
    {
        if (!tanks.TryGetValue(S.Num.I(e["tank"]), out Tank t)) return;
        S.Vector2 kaijuPos = sim.kaijuPos;
        S.Vector2 aim = e.Has("at") ? (S.Vector2)e["at"] : kaijuPos;
        var world = new Vector3((float)aim.x, 0f, (float)aim.y);
        Vector3 target = world + Vector3.up;
        if ((world - new Vector3((float)kaijuPos.x, 0f, (float)kaijuPos.y)).magnitude < 0.01f)
            target = kaiju + Vector3.up * (HIT_HEIGHT * (float)sim.BodyScale());
        t.kick = 1f;
        Vector3 muzzle = Mirror(t.barrel.TransformPoint(Mirror(new Vector3(0f, 0f, t.muzzleZ))));
        Transform shell = MakeBox(WARN, 0, null);
        shell.localScale = Vector3.one * SHELL_SIZE;
        shells.Add(new Shell { box = shell, from = muzzle, to = target, miss = e.Has("miss") && (bool)e["miss"] });
        fx.FlashLight(muzzle, MUZZLE_FLASH, MUZZLE_LIGHT, MUZZLE_LIGHT_S);
    }

    void Stray(S.GDict e)
    {
        S.Vector2 at = e["at"];
        var world = new Vector3((float)at.x, 0f, (float)at.y);
        Chunks(world + Vector3.up * WRECK_LIFT, WRECK_CHUNKS, TANK_PAINT, WARN);
        fx.FlashLight(world + Vector3.up, WRECK_FLASH, STRAY_LIGHT, STRAY_LIGHT_S);
        fx.Dust(world + Vector3.up, STRAY_DUST);
        fx.Fire(world, STRAY_FIRE);
    }

    void SpawnHeli(long id)
    {
        var body = new GameObject("heli").transform;
        body.SetParent(root, false);
        float v = heliVoxel;
        Vector3 hull = Pivot(heliParts, "body", v);
        var centre = new Vector3(hull.x, 0f, hull.z);
        Part(heliParts, "heli", "body", v, body, hull - centre);
        var h = new Heli { root = body };
        h.mainRotor = Part(heliParts, "heli", "main_rotor", v, body, Pivot(heliParts, "main_rotor", v) - centre);
        h.tailRotor = Part(heliParts, "heli", "tail_rotor", v, body, Pivot(heliParts, "tail_rotor", v) - centre);
        h.gun = Part(heliParts, "heli", "gun", v, body, Pivot(heliParts, "gun", v) - centre);
        h.muzzleZ = Front(heliParts, "gun", v) - Pivot(heliParts, "gun", v).z;
        HeliLights(h, body);
        helis[id] = h;
    }

    // helicopter_model.gd _add_lights: red left, green right, a white strobe on the tail, a pale belly lamp.
    void HeliLights(Heli h, Transform body)
    {
        S.GDict lights = vehicles["heli_lights"];
        Bounds b = body.GetChild(0).GetComponent<MeshFilter>().sharedMesh.bounds;
        Vector3 offset = body.GetChild(0).localPosition;
        Vector3 min = b.min + offset, size = b.size;
        float top = min.y + size.y * F(lights, "mast");
        float side = size.x * 0.5f * F(lights, "wing");
        float mid = min.x + size.x * 0.5f, midZ = min.z + size.z * 0.5f;
        float lamp = F(lights, "size");
        // Godot's -x left is Unity's -x: the mirror is on z alone.
        Lamp(Hex(S.Gd.Str(lights["red"])), new Vector3(mid - side, top, midZ), lamp, body);
        Lamp(Hex(S.Gd.Str(lights["green"])), new Vector3(mid + side, top, midZ), lamp, body);
        h.strobe = Lamp(Hex(S.Gd.Str(lights["white"])), new Vector3(mid, top, min.z), lamp, body).gameObject;
        Lamp(Hex(S.Gd.Str(lights["belly"])), new Vector3(mid, min.y, midZ), F(lights, "belly_size"), body);
    }

    Transform Lamp(Color color, Vector3 at, float size, Transform parent)
    {
        Transform box = MakeBox(color, 0, parent);
        box.localScale = Vector3.one * size;
        box.localPosition = at;
        return box;
    }

    void HeliFired(long id)
    {
        if (!helis.TryGetValue(id, out Heli h)) return;
        Vector3 muzzle = Mirror(h.gun.TransformPoint(Mirror(new Vector3(0f, 0f, h.muzzleZ))));
        fx.FlashLight(muzzle, MUZZLE_FLASH, MUZZLE_LIGHT, MUZZLE_LIGHT_S);
    }

    void HeliDown(S.GDict e)
    {
        long id = S.Num.I(e["heli"]);
        Vector3 at = EventAt(e, (float)sim.air.Altitude());
        if (!helis.TryGetValue(id, out Heli h) || !e.Has("fate") || S.Gd.Str(e["fate"]) != "spin")
        {
            if (h != null)
            {
                Object.Destroy(h.root.gameObject);
                helis.Remove(id);
            }
            Burst(at, HELI_PAINT);
            return;
        }
        h.falling = true;
        h.fallFrom = at;
        h.fallDrift = new Vector3((float)(double)S.Num.F(e["dx"]), 0f, (float)(double)S.Num.F(e["dz"]));
        h.fallSeconds = (float)(double)S.Num.F(e["seconds"]);
        h.fallT = 0f;
        fx.FlashLight(at, CRASH_BLAST, F(wreck, "hit_light"), 0.3f);
        fx.Dust(at, F(wreck, "hit_smoke") * 0.1f);
        fx.Fire(at, F(wreck, "trail_fire"), h.fallSeconds);
    }

    void HeliCrashed(S.GDict e)
    {
        long id = S.Num.I(e["heli"]);
        Vector3 ground = EventAt(e, 0f);
        if (helis.TryGetValue(id, out Heli h))
        {
            Object.Destroy(h.root.gameObject);
            helis.Remove(id);
        }
        float scale = F(wreck, "crash_scale");
        fx.FlashLight(ground + Vector3.up * 2f, CRASH_BLAST, F(wreck, "crash_light"), F(wreck, "crash_light_seconds"));
        fx.Fireball(ground + Vector3.up, Vector3.one, F(wreck, "crash_fireball") * F(wreck, "fireball_radius"));
        fx.Fire(ground, F(wreck, "crash_fire"));
        fx.Dust(ground + Vector3.up * 0.4f, scale);
        fx.Shockwave(ground, scale * F(wreck, "crash_ring"));
        Chunks(ground + Vector3.up * 0.8f, CRASH_CHUNKS, HELI_PAINT, HELI_PAINT);
    }

    void Burst(Vector3 at, Color paint)
    {
        fx.FlashLight(at, CRASH_BLAST, F(wreck, "burst_light"), F(wreck, "burst_light_seconds"));
        fx.Fireball(at, Vector3.one, F(wreck, "fireball_radius"));
        Chunks(at, CRASH_CHUNKS, paint, paint);
    }

    public void Chunks(Vector3 at, int count, Color a, Color b)
    {
        for (int n = 0; n < count; n++)
        {
            Transform box = MakeBox(n % 2 == 0 ? a : b, 255, null);
            box.localScale = Vector3.one * CHUNK_SIZE;
            box.position = Mirror(at);
            double angle = rng.NextDouble() * System.Math.PI * 2.0;
            float speed = Mathf.Lerp(throwMin, throwMax, (float)rng.NextDouble());
            var velocity = new Vector3((float)System.Math.Cos(angle) * speed, Mathf.Lerp(upMin, upMax, (float)rng.NextDouble()), (float)System.Math.Sin(angle) * speed);
            chunks.Add(new Chunk { box = box, velocity = Mirror(velocity), left = chunkRest });
        }
    }

    // ---------- Per frame ----------

    public void Update(float dt, Vector3 kaiju)
    {
        Tanks(dt, kaiju);
        Helis(dt, kaiju);
        Shells(dt);
        Debris(dt);
        Taskforce(dt, kaiju);
    }

    void Tanks(float dt, Vector3 kaiju)
    {
        var aim = kaiju + Vector3.up * (AIM_HEIGHT * (float)sim.BodyScale());
        S.Convoy convoy = sim.armyUnits.convoy;
        foreach (S.RampageSim.Tank tank in sim.tanks)
        {
            if (!tanks.TryGetValue(tank.id, out Tank t)) continue;
            S.Vector2 front = convoy.Front(tank.id);
            if (front.x != 0.0 || front.y != 0.0) t.yaw = Mathf.Atan2(-(float)front.x, -(float)front.y);
            Place(t, tank);
            if (!tank.flying && !tank.toppled) Aim(t, aim, dt);
            Recoil(t, dt);
        }
        foreach (S.RampageSim.Tank husk in sim.flight.hold.husks)
            if (tanks.TryGetValue(husk.id, out Tank t)) Place(t, husk);
    }

    static void Place(Tank t, S.RampageSim.Tank tank)
    {
        t.root.position = new Vector3((float)tank.pos.x, (float)tank.height, -(float)tank.pos.y);
        t.root.rotation = Mirrored(tank.tilt) * Quaternion.Euler(0f, -t.yaw * Mathf.Rad2Deg, 0f);
    }

    void Aim(Tank t, Vector3 target, float dt)
    {
        Vector3 local = Mirror(t.root.InverseTransformPoint(Mirror(target))) - t.turretAt;
        float step = F(vehicles, "turret_turn") * dt;
        float yaw = Mathf.Atan2(-local.x, -local.z);
        float diff = Mathf.Repeat(yaw - t.turretYaw + Mathf.PI, Mathf.PI * 2f) - Mathf.PI;
        t.turretYaw += Mathf.Clamp(diff, -step, step);
        t.turret.localRotation = Quaternion.Euler(0f, -t.turretYaw * Mathf.Rad2Deg, 0f);
        float reach = new Vector2(local.x, local.z).magnitude;
        float pitch = Mathf.Atan2(local.y - t.barrelRest.y, Mathf.Max(reach, 0.01f));
        t.pitch = Mathf.MoveTowards(t.pitch, Mathf.Clamp(pitch, BARREL_DROP, F(vehicles, "gun_elevation")), step);
        t.barrel.localRotation = Quaternion.Euler(-t.pitch * Mathf.Rad2Deg, 0f, 0f);
    }

    void Recoil(Tank t, float dt)
    {
        t.kick = Mathf.Max(0f, t.kick - dt / F(vehicles, "recoil_seconds"));
        t.barrel.localPosition = Mirror(t.barrelRest + new Vector3(0f, 0f, F(vehicles, "recoil") * t.kick * t.kick));
        if (t.beacon == null) return;
        S.GDict lamp = vehicles["tank_beacon"];
        t.beaconClock += dt;
        t.beacon.SetActive(Mathf.Repeat(t.beaconClock, F(lamp, "period")) < F(lamp, "on"));
    }

    void Helis(float dt, Vector3 kaiju)
    {
        float turn = Mathf.Min(1f, dt * F(vehicles, "heli_turn"));
        float altitude = (float)sim.air.Altitude();
        Vector3 target = kaiju + Vector3.up * (HELI_AIM_HEIGHT * (float)sim.BodyScale());
        foreach (S.AirWing.Heli heli in sim.air.helis)
        {
            if (!helis.TryGetValue(heli.id, out Heli h)) continue;
            var at = new Vector3((float)heli.pos.x, altitude, -(float)heli.pos.y);
            Vector3 to = Mirror(at - h.root.position);
            h.root.position = at;
            if (to.magnitude > 0.001f)
                h.yaw = Mathf.LerpAngle(h.yaw * Mathf.Rad2Deg, Mathf.Atan2(-to.x, -to.z) * Mathf.Rad2Deg, turn) * Mathf.Deg2Rad;
            h.root.rotation = Quaternion.Euler(0f, -h.yaw * Mathf.Rad2Deg, 0f);
            h.gun.LookAt(Mirror(target));
        }
        foreach (Heli h in helis.Values)
        {
            h.spin += dt;
            h.clock += dt;
            h.mainRotor.localRotation = Quaternion.Euler(0f, -h.spin * F(vehicles, "main_rotor_spin") * Mathf.Rad2Deg, 0f);
            h.tailRotor.localRotation = Quaternion.Euler(-h.spin * F(vehicles, "tail_rotor_spin") * Mathf.Rad2Deg, 0f, 0f);
            S.GDict lights = vehicles["heli_lights"];
            h.strobe.SetActive(Mathf.Repeat(h.clock, F(lights, "strobe_period")) < F(lights, "strobe_on"));
            if (h.falling) Fall(h, dt);
        }
    }

    // heli_wreck.gd _fall: its height drops slowly then fast, it pitches nose down, rolls and spins up.
    static void Fall(Heli h, float dt)
    {
        h.fallT += dt;
        float u = Mathf.Clamp01(h.fallT / Mathf.Max(h.fallSeconds, 0.01f));
        Vector3 at = h.fallFrom + h.fallDrift * h.fallT - new Vector3(0f, h.fallFrom.y * u * u, 0f);
        h.root.position = Mirror(at);
        h.yaw += FALL_SPIN * (1f + u) * dt;
        h.root.rotation = Quaternion.Euler(-FALL_PITCH * u * Mathf.Rad2Deg, -h.yaw * Mathf.Rad2Deg, FALL_ROLL * u * Mathf.Rad2Deg);
    }

    void Shells(float dt)
    {
        for (int i = shells.Count - 1; i >= 0; i--)
        {
            Shell s = shells[i];
            s.t += dt / shellFlight;
            s.box.position = Mirror(Vector3.Lerp(s.from, s.to, Mathf.Min(s.t, 1f)));
            if (s.t < 1f) continue;
            if (!s.miss) fx.Sparks(s.to);
            Object.Destroy(s.box.gameObject);
            shells.RemoveAt(i);
        }
    }

    void Debris(float dt)
    {
        for (int i = chunks.Count - 1; i >= 0; i--)
        {
            Chunk c = chunks[i];
            c.left -= dt;
            if (c.left <= 0f)
            {
                Object.Destroy(c.box.gameObject);
                chunks.RemoveAt(i);
                continue;
            }
            Vector3 at = c.box.position;
            if (at.y <= CHUNK_SIZE * 0.5f && c.velocity.y <= 0f) continue;
            c.velocity.y -= chunkGravity * dt;
            at += c.velocity * dt;
            at.y = Mathf.Max(at.y, CHUNK_SIZE * 0.5f);
            c.box.position = at;
        }
    }

    // taskforce_view.gd: placeholder boxes (D-143), one per unit, redrawn from the sim each frame.
    void Taskforce(float dt, Vector3 kaiju)
    {
        S.Taskforce force = sim.armyUnits.taskforce;
        if (force == null) return;
        boxesUsed = 0;
        float reach = (float)sim.ReachHeight();
        foreach (S.Taskforce.Agent agent in force.agents)
        {
            var at = new Vector3((float)agent.pos.x, (float)agent.y, (float)agent.pos.y);
            Draw(agent.gas ? GAS_SUIT : OBSIDIAN, 255, at, AGENT, 0f);
            if (agent.state == S.Taskforce.AIM)
            {
                var from = at + Vector3.up;
                var to = new Vector3((float)agent.aimAt.x, (float)sim.standY + CHEST, (float)agent.aimAt.y);
                Line(from, to, AIM_LINE_WIDTH);
            }
        }
        foreach (S.TaskforceMechs.Mech mech in force.mechs.mechs)
        {
            var at = new Vector3((float)mech.pos.x, 0f, (float)mech.pos.y);
            Draw(OBSIDIAN, 255, at, MECH * reach, Mathf.Atan2(-(float)mech.facing.y, (float)mech.facing.x));
        }
        float altitude = (float)force.gunships.Altitude();
        double fireEvery = S.Num.F(sim.air.cfg["fire_interval"]);
        foreach (S.AirWing.Heli ship in force.gunships.ships)
        {
            var at = new Vector3((float)ship.pos.x, altitude, (float)ship.pos.y);
            Draw(OBSIDIAN, 255, at, SHIP, -(float)(double)ship.heading);
            if (ship.cooldown > fireEvery - LASER_SECONDS) Line(at, new Vector3((float)sim.kaijuPos.x, (float)sim.standY + CHEST, (float)sim.kaijuPos.y), LASER_WIDTH);
        }
        gasWait -= dt;
        bool puff = gasWait <= 0f;
        if (puff) gasWait = GAS_PUFF_EVERY;
        float gasRadius = (float)force.gas.Radius();
        foreach (S.GArray<S.Variant> cloud in force.gas.clouds)
        {
            if (!puff) continue;
            S.Vector2 at = cloud[1];
            fx.ToxicCloud(new Vector3((float)at.x, gasRadius * 0.5f, (float)at.y), Vector3.one * gasRadius, gasRadius, GAS_PUFF_EVERY * 4f);
        }
        float bombRadius = (float)(double)S.Num.F(force.mechs.cfg["bomb_radius"]);
        foreach (S.GArray<S.Variant> bomb in force.mechs.bombs)
        {
            S.Vector2 at = bomb[1];
            for (int k = 0; k < BOMB_RING_BOXES; k++)
            {
                float angle = k / BOMB_RING_BOXES * Mathf.PI * 2f;
                var ring = new Vector3((float)at.x + Mathf.Cos(angle) * bombRadius, 0.05f, (float)at.y + Mathf.Sin(angle) * bombRadius);
                Draw(BLUE, 0, ring, Vector3.one * BOMB_BOX, 0f);
            }
        }
        for (int i = boxesUsed; i < taskforceBoxes.Count; i++)
            if (taskforceBoxes[i].gameObject.activeSelf) taskforceBoxes[i].gameObject.SetActive(false);
    }

    void Draw(Color color, byte alpha, Vector3 at, Vector3 size, float yaw)
    {
        if (boxesUsed == taskforceBoxes.Count) taskforceBoxes.Add(MakeBox(color, alpha, null));
        Transform box = taskforceBoxes[boxesUsed++];
        if (!box.gameObject.activeSelf) box.gameObject.SetActive(true);
        box.GetComponent<MeshFilter>().sharedMesh = Box(color, alpha);
        box.position = Mirror(at);
        box.rotation = Quaternion.Euler(0f, -yaw * Mathf.Rad2Deg, 0f);
        box.localScale = size;
    }

    void Line(Vector3 from, Vector3 to, float width)
    {
        Vector3 a = Mirror(from), b = Mirror(to);
        if (boxesUsed == taskforceBoxes.Count) taskforceBoxes.Add(MakeBox(BLUE, 0, null));
        Transform box = taskforceBoxes[boxesUsed++];
        if (!box.gameObject.activeSelf) box.gameObject.SetActive(true);
        box.GetComponent<MeshFilter>().sharedMesh = Box(BLUE, 0);
        Vector3 along = b - a;
        box.position = a;
        box.rotation = Quaternion.FromToRotation(Vector3.up, along.normalized);
        box.localScale = new Vector3(width, along.magnitude, width);
    }
}
