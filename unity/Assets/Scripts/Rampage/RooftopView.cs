using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using S = Kaiju.Sim;

// scenes/rooftop_view.gd + scenes/rooftop_impacts.gd: the Rooftop Taskforce. Riflemen on the roofs the sim
// placed squads on, a muzzle flash and a tracer for each rifle of a volley, and the round landing on the hide.
// Reads the sim's squads and its rooftop events; decides nothing. Godot axes inside, z negated at the draw.
public sealed class RooftopView : IDisposable
{
    // scenes/rooftop_view.gd
    const int MAX_FLASHES = 48, MAX_TRACERS = 48, FLASH_FRAMES = 3, POINT_BLANK_FRAMES = 3;
    const float FLASH_SIZE = 0.5f, SHORT_PIXELS = 60f, HOT = 4f, TRACER_LENGTH = 1.75f, TRACER_WIDTH = 0.05f, TRACER_HOT = 2f;
    const float MAX_SCREEN_SHARE = 0.04f, DESTROYED_DUST = 0.5f;
    static readonly Color GLOW = new Color(1f, 0.82f, 0.45f);
    static readonly Vector3 TRAIL = new Vector3(1f, 0.55f, 0.25f);
    // scenes/rooftop_impacts.gd MAX
    const int MAX_ROUNDS = 48;
    // scenes/fx.gd sparks: the life of a spark burst.
    const float SPARK_LIFE = 0.5f;

    struct Strike
    {
        public bool loose;   // a fixed point (no bone to ride)
        public Vector3 at;
        public int bone;
        public Vector3 rest;
    }

    struct Flash
    {
        public Vector3 at;
        public int wait, left;
    }

    struct Tracer
    {
        public Vector3 from;
        public Strike hit;
        public float t, flight;
        public int wait;
    }

    struct Round
    {
        public Strike hit;
        public Vector3 from;
        public int wait;
    }

    struct Figure
    {
        public int outfit;
        public Matrix4x4 matrix;
    }

    readonly S.RampageSim sim;
    readonly CityFx fx;
    readonly Croc croc;
    readonly S.RandomNumberGenerator rng;
    readonly float voxel;
    readonly int squadSize, maxDrawn, sparkCount;
    readonly Color sparkTint;
    readonly Mesh[] meshes;
    readonly Mesh quad;
    readonly Material figureMat, flareMat, tracerMat;
    readonly MaterialPropertyBlock block = new MaterialPropertyBlock();

    // The TARGETS bones this body has, with the rest cubes each carries and their middle.
    readonly List<int> bones = new List<int>();
    readonly List<Vector3[]> boneCubes = new List<Vector3[]>();
    readonly List<Vector3> boneMiddle = new List<Vector3>();
    readonly double[] nearSq = new double[RooftopAim.TARGETS.Length];

    readonly List<S.Army.Squad> order = new List<S.Army.Squad>();
    readonly Comparison<S.Army.Squad> nearestFirst;
    readonly HashSet<long> shown = new HashSet<long>();
    readonly List<Figure> figures = new List<Figure>();
    readonly List<Flash> flashes = new List<Flash>();
    readonly List<Tracer> tracers = new List<Tracer>();
    readonly List<Round> rounds = new List<Round>();
    readonly List<Vector4> flashDraw = new List<Vector4>();   // Godot xyz, fade w
    readonly List<Vector3> tracerDraw = new List<Vector3>();  // head, tail pairs
    Camera cam;

    // Volleys shown or counted, figures drawn on the last tick and at most, rounds landed on the hide.
    public int Shots { get; private set; }
    public int Drawn { get; private set; }
    public int MostDrawn { get; private set; }
    public int Landed { get; private set; }

    // lit: the city's surface shader. The view's own seeded stream is the run's (Godot seeds it "rooftop_fx", 0).
    public RooftopView(S.RampageSim sim, CityFx fx, Croc croc, Shader lit, int seed)
    {
        this.sim = sim;
        this.fx = fx;
        this.croc = croc;
        rng = S.Seeds.Make("rooftop_fx", seed);
        S.GDict cfg = sim.army["rooftop"];
        squadSize = (int)S.Num.I(cfg["squad_size"]);
        maxDrawn = (int)S.Num.I(cfg["max_drawn"]);
        voxel = (float)(double)S.Num.F(S.Content.Section("street")["person_voxel"]);
        S.GDict hide = S.Content.Section("fx")["hide_hit"];
        sparkCount = (int)S.Num.I(hide["spark_count"]);
        sparkTint = Hex(S.Gd.Str(hide["spark_tint"]));

        meshes = new Mesh[PersonMesh.RooftopOutfits];
        for (int i = 0; i < meshes.Length; i++) meshes[i] = PersonMesh.Rifleman(i, voxel);
        figureMat = ArmyView.PlainMaterial(lit, voxel);
        quad = new Mesh { name = "rooftop quad" };
        quad.SetVertices(new[] { new Vector3(-1, -1, 0), new Vector3(1, -1, 0), new Vector3(1, 1, 0), new Vector3(-1, 1, 0) });
        quad.SetTriangles(new[] { 0, 1, 2, 0, 2, 3 }, 0, false);
        quad.bounds = new Bounds(Vector3.zero, Vector3.one * 1e6f);
        flareMat = new Material(Resources.Load<Shader>("Shaders/Flare"));
        tracerMat = new Material(Resources.Load<Shader>("Shaders/Tracer"));

        var cubes = new List<Vector3>();
        foreach (string name in RooftopAim.TARGETS)
        {
            int bone = croc.StrikeBone(name);
            if (bone < 0) continue;
            cubes.Clear();
            croc.StrikeCubes(bone, cubes);
            if (cubes.Count == 0) continue;
            Vector3 sum = Vector3.zero;
            foreach (Vector3 c in cubes) sum += c;
            bones.Add(bone);
            boneCubes.Add(cubes.ToArray());
            boneMiddle.Add(sum / cubes.Count);
        }
        nearestFirst = (a, b) =>
        {
            int by = a.pos.DistanceSquaredTo(sim.kaijuPos).CompareTo(b.pos.DistanceSquaredTo(sim.kaijuPos));
            return by != 0 ? by : a.id.CompareTo(b.id);
        };
        Debug.Log($"rooftops: {sim.armyUnits.squads.Size()} squads of {squadSize}, {bones.Count} bones to strike");
    }

    // The sim's rooftop events (true when it was one); the drawn body stands with its feet at kaijuAt (Godot axes).
    public bool OnEvent(S.GDict e, Vector3 kaijuAt)
    {
        string type = S.Gd.Str(e["type"]);
        if (type == "rooftop_fired")
        {
            Fired(S.Num.I(e["squad"]), kaijuAt);
            return true;
        }
        if (type != "rooftop_destroyed") return false;
        // Gone with its roof or under a blow: a puff of dust there.
        fx.Dust(new Vector3((float)(double)S.Num.F(e["x"]), (float)(double)S.Num.F(e["y"]), (float)(double)S.Num.F(e["z"])), DESTROYED_DUST);
        return true;
    }

    // One Godot physics frame (rooftop_view.gd _physics_process): who is drawn, then the flashes, tracers and
    // rounds each a frame on. camera: the game's, for the looming cull and the short-tracer rule; null for none.
    public void Tick(float delta, Camera camera)
    {
        cam = camera;
        figures.Clear();
        shown.Clear();
        order.Clear();
        foreach (S.Army.Squad squad in sim.armyUnits.squads) order.Add(squad);
        order.Sort(nearestFirst);
        int drawn = 0;
        foreach (S.Army.Squad squad in order)
        {
            if (drawn >= maxDrawn) break;
            if (Looms(Stance(squad, 0))) continue;
            shown.Add(squad.id);
            int count = Mathf.Min(squadSize, maxDrawn - drawn);
            for (int k = 0; k < count; k++)
            {
                S.Transform3D t = Stance(squad, k);
                figures.Add(new Figure
                {
                    outfit = (int)((squad.id + k * 2) % meshes.Length),
                    matrix = Matrix4x4.TRS(Unity(t.origin), Mirrored(t.basis), Vector3.one * (float)RooftopAim.FIGURE_SCALE),
                });
                drawn++;
            }
        }
        Drawn = drawn;
        MostDrawn = Mathf.Max(MostDrawn, drawn);
        StepFlashes();
        StepTracers(delta);
        Land();
    }

    // Every rendered frame: what the last tick left to draw.
    public void Draw()
    {
        foreach (Figure f in figures)
            Graphics.DrawMesh(meshes[f.outfit], f.matrix, figureMat, 0, null, 0, null, ShadowCastingMode.On, true);
        Vector4 hot = GLOW.linear * HOT;
        foreach (Vector4 f in flashDraw)
        {
            block.Clear();
            block.SetVector("_FlarePos", new Vector4(f.x, f.y, -f.z, FLASH_SIZE));
            block.SetVector("_FlareTint", hot);
            block.SetFloat("_FlareFade", f.w);
            block.SetFloat("_FlareEdge", 0f);
            block.SetFloat("_FlareSoft", 0f);
            Graphics.DrawMesh(quad, Matrix4x4.identity, flareMat, 0, null, 0, block, ShadowCastingMode.Off, false);
        }
        Vector4 streak = GLOW.linear * TRACER_HOT;
        for (int i = 0; i + 1 < tracerDraw.Count; i += 2)
        {
            Vector3 head = tracerDraw[i], tail = tracerDraw[i + 1];
            block.Clear();
            block.SetVector("_TracerHead", new Vector4(head.x, head.y, -head.z, TRACER_WIDTH));
            block.SetVector("_TracerTail", new Vector4(tail.x, tail.y, -tail.z, 0f));
            block.SetVector("_TracerTint", streak);
            block.SetVector("_TracerTrail", TRAIL);
            Graphics.DrawMesh(quad, Matrix4x4.identity, tracerMat, 0, null, 0, block, ShadowCastingMode.Off, false);
        }
    }

    // Soldier k of a squad (rooftop_view.gd stance).
    S.Transform3D Stance(S.Army.Squad squad, int k)
    {
        S.RampageSim.Building b = sim.buildings[squad.building];
        return RooftopAim.Stance(squad.pos, sim.kaijuPos, RooftopAim.Roof(b, squad.cell), RooftopAim.Feet(b, squad.cell), k, squadSize);
    }

    // A figure on a roof so near the camera that it stands taller than MAX_SCREEN_SHARE of the screen is not
    // drawn; its volleys show only the hit (D-076).
    bool Looms(S.Transform3D t)
    {
        if (cam == null) return false;
        Vector3 feet = cam.WorldToScreenPoint(Unity(t.origin));
        if (feet.z <= 0f) return false;
        Vector3 top = cam.WorldToScreenPoint(Unity(RooftopAim.Top(t, voxel)));
        return Vector2.Distance(feet, top) > cam.pixelHeight * MAX_SCREEN_SHARE;
    }

    // How long the line a to b is on screen, in pixels (infinite without a camera or with an end behind it).
    float OnScreen(Vector3 a, Vector3 b)
    {
        if (cam == null) return float.PositiveInfinity;
        Vector3 pa = cam.WorldToScreenPoint(Mirror(a)), pb = cam.WorldToScreenPoint(Mirror(b));
        if (pa.z <= 0f || pb.z <= 0f) return float.PositiveInfinity;
        return Vector2.Distance(pa, pb);
    }

    // A squad's volley (sim rooftop_fired): a flash at each muzzle and a tracer from each at the kaiju. A squad
    // that is not drawn (looming, past max_drawn) shows only the hits.
    void Fired(long squadId, Vector3 kaijuAt)
    {
        foreach (S.Army.Squad squad in sim.armyUnits.squads)
        {
            if (squad.id != squadId) continue;
            bool seen = shown.Contains(squadId);
            Shots++;
            Vector3 middle = kaijuAt + Vector3.up * (float)(sim.BodyScale() * RooftopAim.BODY_MIDDLE);
            for (int k = 0; k < squadSize; k++)
            {
                S.Transform3D t = Stance(squad, k);
                Vector3 muzzle = Godot(RooftopAim.Muzzle(t, voxel));
                int wait = RooftopAim.Wait(k, rng);
                if (seen && flashes.Count < MAX_FLASHES)
                    flashes.Add(new Flash { at = Godot(RooftopAim.FlashAt(t, voxel)), wait = wait, left = FLASH_FRAMES });
                Strike hit = StrikeFor(middle, muzzle);
                Vector3 to = At(hit);
                float flight = (float)RooftopAim.Flight(Sim(muzzle), Sim(to));
                int frames = RooftopAim.Frames(flight);
                if (!seen || frames < POINT_BLANK_FRAMES || OnScreen(muzzle, to) < SHORT_PIXELS)
                    AddRound(hit, muzzle, wait + frames);  // no tracer: a stub of one reads as noise
                else if (tracers.Count < MAX_TRACERS)
                    tracers.Add(new Tracer { from = muzzle, hit = hit, t = 0f, flight = flight, wait = wait });
            }
            return;
        }
    }

    // rooftop_aim.gd strike: a cube of one of the bones nearest the muzzle, on its side facing the muzzle; the
    // body's middle when it has none of the bones.
    Strike StrikeFor(Vector3 middle, Vector3 muzzle)
    {
        if (bones.Count == 0) return new Strike { loose = true, at = middle };
        S.Vector3 from = Sim(muzzle);
        for (int i = 0; i < bones.Count; i++)
            nearSq[i] = Sim(croc.StrikePoint(bones[i], boneMiddle[i])).DistanceSquaredTo(from);
        int pick = RooftopAim.Pick(nearSq, bones.Count, rng);
        int bone = bones[pick];
        Vector3[] cubes = boneCubes[pick];
        S.Vector3 axis = Sim(croc.StrikePoint(bone, boneMiddle[pick]));
        int cell = RooftopAim.Facing(cubes.Length, c => Sim(croc.StrikePoint(bone, cubes[c])), axis, from, rng);
        return new Strike { bone = bone, rest = cell < 0 ? boneMiddle[pick] : cubes[cell] };
    }

    // Where a strike is now: on its bone as the body moves, or the fixed point it was given.
    Vector3 At(Strike hit) => hit.loose ? hit.at : croc.StrikePoint(hit.bone, hit.rest);

    void AddRound(Strike hit, Vector3 from, int wait)
    {
        if (rounds.Count < MAX_ROUNDS) rounds.Add(new Round { hit = hit, from = from, wait = wait });
    }

    // Each flash whose wait is over, for its frames left: full on the first, fading out.
    void StepFlashes()
    {
        flashDraw.Clear();
        for (int i = 0; i < flashes.Count;)
        {
            Flash f = flashes[i];
            if (f.wait > 0)  // this rifle has not fired yet
            {
                f.wait--;
                flashes[i++] = f;
                continue;
            }
            if (f.left <= 0)
            {
                flashes.RemoveAt(i);
                continue;
            }
            flashDraw.Add(new Vector4(f.at.x, f.at.y, f.at.z, (float)f.left / FLASH_FRAMES));
            f.left--;
            flashes[i++] = f;
        }
    }

    // Each tracer flies muzzle to hide; on arrival it is gone and the round lands where it was headed.
    void StepTracers(float delta)
    {
        tracerDraw.Clear();
        for (int i = 0; i < tracers.Count;)
        {
            Tracer tr = tracers[i];
            if (tr.wait > 0)  // fired with its rifle, a frame or two after the first
            {
                tr.wait--;
                tracers[i++] = tr;
                continue;
            }
            tr.t += delta / Mathf.Max(tr.flight, 0.001f);
            if (tr.t >= 1f)
            {
                AddRound(tr.hit, tr.from, 0);
                tracers.RemoveAt(i);
                continue;
            }
            Vector3 to = At(tr.hit);
            Vector3 head = Vector3.Lerp(tr.from, to, tr.t);
            Vector3 z = (to - tr.from).normalized;
            tracerDraw.Add(head);
            tracerDraw.Add(head - z * Mathf.Min(TRACER_LENGTH, Vector3.Distance(head, tr.from)));
            tracers[i++] = tr;
        }
    }

    // rooftop_impacts.gd land: each round whose wait is over lands on the hide.
    void Land()
    {
        for (int i = 0; i < rounds.Count;)
        {
            Round r = rounds[i];
            if (r.wait > 0)  // the round has not arrived yet
            {
                r.wait--;
                rounds[i++] = r;
                continue;
            }
            rounds.RemoveAt(i);
            Hit(r.from, At(r.hit));
            Landed++;
        }
    }

    // Stand-in for scenes/hide_hit.gd HideHit.land (not ported: no hide ray, mist or wound): sparks thrown back
    // off the point the round was aimed at.
    void Hit(Vector3 from, Vector3 aim)
    {
        fx.AimedSparks(sparkTint, (from - aim).normalized, aim, sparkCount, SPARK_LIFE);
    }

    public void Dispose()
    {
        foreach (Mesh m in meshes) UnityEngine.Object.Destroy(m);
        UnityEngine.Object.Destroy(quad);
        UnityEngine.Object.Destroy(figureMat);
        UnityEngine.Object.Destroy(flareMat);
        UnityEngine.Object.Destroy(tracerMat);
    }

    static Color Hex(string hex) => ColorUtility.TryParseHtmlString("#" + hex, out Color c) ? c : Color.white;

    static S.Vector3 Sim(Vector3 v) => new S.Vector3(v.x, v.y, v.z);

    static Vector3 Godot(S.Vector3 v) => new Vector3((float)v.x, (float)v.y, (float)v.z);

    // ArmyView's own (private there): Godot axes to Unity's.
    static Vector3 Mirror(Vector3 v) => new Vector3(v.x, v.y, -v.z);

    static Vector3 Unity(S.Vector3 v) => new Vector3((float)v.x, (float)v.y, -(float)v.z);

    static Quaternion Mirrored(S.Basis m)
    {
        Vector3 forward = Unity(m * new S.Vector3(0, 0, -1));
        Vector3 up = Unity(m * new S.Vector3(0, 1, 0));
        return Quaternion.LookRotation(forward, up);
    }
}
