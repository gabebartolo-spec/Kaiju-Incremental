using System.Collections.Generic;
using Kaiju.Game;
using UnityEngine;
using S = Kaiju.Sim;

// scenes/debris_field.gd: physics debris, real rigid pieces thrown out that fall heavily, settle on the street, then
// shrink away. Queued, at most SPAWN_PER_FRAME made a frame; past the cap the oldest go first. Each piece's size,
// push, spin and life come from the field's own stream in Godot's order (GameLogic/TreeBurst.cs DebrisSpawn, checked
// against Godot by SimTests/PropCrushCheck.cs). Spawned in Godot axes. Presentation only.
public sealed class DebrisField
{
    const int SPAWN_PER_FRAME = 30;
    const float SHRINK_SECONDS = 0.8f, SHRINK_MIN = 0.01f;
    // _spawn_now: gravity_scale 2.2 on Godot's default gravity (project.godot sets none).
    const float GRAVITY_SCALE = 2.2f, GODOT_GRAVITY = 9.8f;
    // Godot's RigidBody3D defaults: linear and angular damp 0.1, friction 1, no bounce, no spin cap (Unity's 7 rad/s
    // would clip a 6-per-axis throw).
    const float DAMP = 0.1f, FRICTION = 1f, SPIN_CAP = 100f;
    // _view: sizes snap to this, and a piece's box is this share of its snapped size.
    const float SIZE_SNAP = 0.02f, BOX_SHARE = 0.95f;
    // city_view.gd _build_ground: the street's collider, a box this wide and deep, one metre thick, top at y 0.
    const float GROUND_SPAN = 800f;
    const int HEX = 16;

    struct Item
    {
        public Vector3 pos, away;
        public Color color;
    }

    sealed class Piece
    {
        public GameObject go;
        public float end;
    }

    readonly S.RandomNumberGenerator rng;
    readonly int cap;
    readonly float sizeScale;
    readonly bool shadows;
    readonly Material material;
    readonly Transform root;
    readonly PhysicsMaterial surface;
    readonly List<Item> queue = new List<Item>();
    readonly List<Piece> pieces = new List<Piece>();
    readonly Dictionary<(float, Color32), Mesh> meshes = new Dictionary<(float, Color32), Mesh>();
    float clock;

    public int Live => pieces.Count;
    // keep_out: pos (Godot axes) moved clear of a body pieces must never start inside (CityDraw: the kaiju's hide).
    public System.Func<Vector3, Vector3> keepOut;

    public DebrisField(S.RandomNumberGenerator rng, int cap, float sizeScale, bool shadows, Material material, Transform parent, string name)
    {
        this.rng = rng;
        this.cap = cap;
        this.sizeScale = sizeScale;
        this.shadows = shadows;
        this.material = material;
        root = new GameObject(name).transform;
        root.SetParent(parent, false);
        surface = new PhysicsMaterial(name) { dynamicFriction = FRICTION, staticFriction = FRICTION, bounciness = 0f };
    }

    // The street the pieces land on: Godot's ground box, under `parent`.
    public static void Ground(Transform parent)
    {
        var go = new GameObject("debris ground");
        go.transform.SetParent(parent, false);
        var box = go.AddComponent<BoxCollider>();
        box.size = new Vector3(GROUND_SPAN, 1f, GROUND_SPAN);
        box.center = new Vector3(0f, -0.5f, 0f);
    }

    // spawn: queue a piece at `pos` (Godot axes) thrown with `away`; past the cap and a frame's worth the oldest
    // queued piece is dropped.
    public void Spawn(Vector3 pos, Color color, Vector3 away)
    {
        queue.Add(new Item { pos = pos, color = color, away = away });
        if (queue.Count > cap + SPAWN_PER_FRAME) queue.RemoveAt(0);
    }

    // _process: throw what this frame may, drop the queue past the cap, forget pieces past the cap and the ones
    // fully shrunk, and shrink the rest whose time is up.
    public void Tick(float dt)
    {
        clock += dt;
        if (pieces.Count == 0 && queue.Count == 0) return;
        int now = Mathf.Min(SPAWN_PER_FRAME, queue.Count);
        for (int n = 0; n < now; n++) Make(queue[n]);
        queue.RemoveRange(0, now);
        if (queue.Count > cap) queue.RemoveRange(0, queue.Count - cap);
        while (pieces.Count > cap) Forget(0);
        for (int k = pieces.Count - 1; k >= 0; k--)
        {
            Piece p = pieces[k];
            if (clock >= p.end + SHRINK_SECONDS)
            {
                Forget(k);
                continue;
            }
            float t = Mathf.Clamp01((clock - p.end) / SHRINK_SECONDS);
            if (t > 0f) p.go.transform.localScale = Vector3.one * Mathf.Lerp(1f, SHRINK_MIN, t);
        }
    }

    // _spawn_now, in Unity axes (z mirrored, so a spin's x and y turn the other way).
    void Make(Item item)
    {
        DebrisPiece d = DebrisSpawn.Draw(rng, sizeScale, new System.Numerics.Vector3(item.away.x, item.away.y, item.away.z));
        var go = new GameObject("piece");
        go.transform.SetParent(root, false);
        Vector3 pos = keepOut != null ? keepOut(item.pos) : item.pos;
        go.transform.position = new Vector3(pos.x, pos.y, -pos.z);
        var box = go.AddComponent<BoxCollider>();
        box.size = Vector3.one * d.size;
        box.sharedMaterial = surface;
        go.AddComponent<MeshFilter>().sharedMesh = Cube(Mathf.Round(d.size / SIZE_SNAP) * SIZE_SNAP, item.color);
        var view = go.AddComponent<MeshRenderer>();
        view.sharedMaterial = material;
        if (!shadows) view.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
        var body = go.AddComponent<Rigidbody>();
        body.useGravity = false;
        body.linearDamping = DAMP;
        body.angularDamping = DAMP;
        body.maxAngularVelocity = SPIN_CAP;
        body.interpolation = RigidbodyInterpolation.Interpolate;
        go.AddComponent<ConstantForce>().force = Vector3.down * (GRAVITY_SCALE * GODOT_GRAVITY * body.mass);
        body.linearVelocity = new Vector3(d.velocity.X, d.velocity.Y, -d.velocity.Z);
        body.angularVelocity = new Vector3(-d.angular.X, -d.angular.Y, d.angular.Z);
        pieces.Add(new Piece { go = go, end = clock + d.life });
    }

    // _view: one box per snapped size and colour (Godot keeps the colour per instance; here it rides on the mesh).
    Mesh Cube(float key, Color color)
    {
        Color32 c = color;
        if (meshes.TryGetValue((key, c), out Mesh mesh)) return mesh;
        int rgb = System.Convert.ToInt32(ColorUtility.ToHtmlStringRGB(color), HEX);
        var model = new ModelColors.Model { xyz = new S.PackedInt32Array(), rgb = new[] { rgb } };
        model.xyz.Resize(3);
        float edge = key * BOX_SHARE;
        mesh = ArmyView.Faces(model, edge, new Vector3(0f, edge * 0.5f, 0f));
        meshes[(key, c)] = mesh;
        return mesh;
    }

    void Forget(int k)
    {
        Object.Destroy(pieces[k].go);
        pieces.RemoveAt(k);
    }
}
