using System.Collections.Generic;
using Kaiju.Game;
using UnityEngine;
using N = System.Numerics;
using S = Kaiju.Sim;

// scenes/heli_wreck.gd and heli_debris.gd on screen (D-140, D-141, D-145, D-458): a "burst" blows the helicopter apart
// in the air (flash, light, fireball, smoke, its own body, rotors and gun thrown on arcs, burning chunks); a "spin"
// sends it falling along the sim's drift, three flames on its body and a smoke trail behind it, crew bailing out under
// pale voxel canopies, until "heli_crashed" lands it (flash, light, fireball, smoke, fire, dust, ring, its parts
// dropped and chunks thrown). The numbers and their draws are HeliWreck's (GameLogic, checked against Godot); the
// recipes are CityFx.HeliFx's. Tuning "heli_wreck". Godot axes until Mirror().
public sealed partial class ArmyView
{
    // heli_wreck.gd BLAST, CRASH_BLAST, CANOPY, CREW_OUTFIT (VoxelPerson.ROOFTOP_OUTFITS: a soldier in drab).
    static readonly Color BLAST = Hex("ffb468"), CRASH_BLAST = Hex("ff8a3a"), CANOPY = Hex("e2dac4");
    const int CREW_OUTFIT = 2;
    // crashed: the flash and flare 2 m up, the fireball 1 m, the smoke 1.5 m, the dust 0.4 m; the flare lasts 0.3 s.
    const float CRASH_FLASH_UP = 2f, CRASH_BALL_UP = 1f, CRASH_SMOKE_UP = 1.5f, CRASH_DUST_UP = 0.4f, CRASH_FLARE_SECONDS = 0.3f;
    // _burst: the smoke 1 m above the blast. _spin: the hit's light lasts 0.3 s; three flames (nose, middle, tail).
    const float BURST_SMOKE_UP = 1f, HIT_LIGHT_SECONDS = 0.3f;
    const int FLAMES = 3;
    // _canopy: the dark panels are CANOPY.darkened(0.28); the shroud lines are 0.04 m thick.
    const float CANOPY_DARKEN = 0.28f, LINE_THICK = 0.04f;
    // An opaque vertex (no glow) and where red sits in a packed 0xRRGGBB.
    const byte SOLID = 255;
    const int RED_SHIFT = 16;

    // A wreck falling (heli_wreck.gd Fall): its model (or a stand-in), the path, its flames and trail, its chunks' paints.
    sealed class Falling
    {
        public Heli heli;
        public Transform node;
        public HeliFall fall;
        public readonly Fires.Burning[] flames = new Fires.Burning[FLAMES];
        public CityFx.HeliTrail trail;
        public Color a, b;
    }

    // A piece in the air or on the street (heli_debris.gd Piece) and the fire it carries.
    sealed class Thrown
    {
        public HeliPiece piece;
        public Transform node;
        public Fires.Burning fire;
    }

    // A crew member under a canopy (heli_wreck.gd Chute).
    sealed class Bailing
    {
        public HeliChute chute;
        public Transform node;
        public double t;
    }

    readonly Dictionary<long, Falling> falling = new Dictionary<long, Falling>();
    readonly List<Thrown> thrown = new List<Thrown>();
    readonly List<Bailing> crew = new List<Bailing>();
    readonly List<HeliPiece> drawn = new List<HeliPiece>();
    S.RandomNumberGenerator wreckRng;
    HeliTuning tuning;
    Material canopyMat;
    Mesh runner, canopy;

    // HeliWreck._init: the view's own draw stream, the tuning; the canopy's material glows canopy_glow of its colour
    // (SliceSurface lights a voxel albedo * _WindowGlow * (1 - vertex alpha)).
    void WreckSetup(Shader shader)
    {
        wreckRng = S.Seeds.Make("heli_wreck");
        tuning = HeliTuning.Of(wreck);
        canopyMat = PlainMaterial(shader, (float)tuning.canopyVoxel);
        canopyMat.SetFloat("_WindowGlow", 1f);
    }

    static N.Vector3 Num(Vector3 v) => new N.Vector3(v.x, v.y, v.z);

    static Vector3 Godot(N.Vector3 v) => new Vector3(v.X, v.Y, v.Z);

    // Godot's basis (its up and back columns) as a Unity rotation (-Z is Godot's forward, +Z Unity's after the mirror).
    static Quaternion Turned(N.Vector3 by, N.Vector3 bz) =>
        Quaternion.LookRotation(Mirror(Godot(-bz)), Mirror(Godot(by)));

    // A Unity rotation read back as Godot's rotation (get_euler_normalized, YXZ).
    static N.Vector3 Euler(Quaternion q) =>
        GodotEuler.Euler(Num(Mirror(q * Vector3.right)), Num(Mirror(q * Vector3.up)), Num(-Mirror(q * Vector3.forward)));

    // heli_destroyed / vip_down: the model `id` (if there is one) blown apart or sent falling.
    void HeliDown(S.GDict e)
    {
        long id = S.Num.I(e["heli"]);
        helis.TryGetValue(id, out Heli h);
        Vector3 at = EventAt(e, (float)sim.air.Altitude());
        Downed(id, h, h?.root, at, e, h != null ? h.chunkA : HELI_PAINT, h != null ? h.chunkB : HELI_PAINT);
    }

    // gunship_destroyed: a Taskforce gunship falls as a helicopter does (powers_view.gd, D-458); its stand-in is
    // taskforce_view.gd wreck_box(), a black box the ship's size with no parts.
    void GunshipDown(S.GDict e)
    {
        Vector3 at = EventAt(e, (float)sim.armyUnits.taskforce.gunships.Altitude());
        Transform box = MakeBox(OBSIDIAN, SOLID, null);
        box.localScale = SHIP;
        box.position = Mirror(at);
        Downed(S.Num.I(e["heli"]), null, box, at, e, OBSIDIAN, OBSIDIAN);
    }

    // HeliWreck.downed: event "fate" spin falls, anything else bursts.
    void Downed(long id, Heli h, Transform node, Vector3 at, S.GDict e, Color a, Color b)
    {
        if (e.Has("fate") && S.Gd.Str(e["fate"]) == "spin")
        {
            Spin(id, h, node, at, e, a, b);
            return;
        }
        if (h != null) helis.Remove(id);
        fx.HeliFlare(at, F(wreck, "flare_size"), F(wreck, "flare_seconds"));
        fx.FlashLight(at, BLAST, F(wreck, "burst_light"), F(wreck, "burst_light_seconds"));
        fx.HeliFireball(at);
        fx.HeliSmoke(at + Vector3.up * BURST_SMOKE_UP);
        fx.Fire(at, F(wreck, "burst_fire"), F(wreck, "burst_seconds"));
        BreakUp(h, node, 1.0, true);
        Shards(at, (int)S.Num.I(wreck["burst_shards"]), (int)S.Num.I(wreck["burst_burning"]), 1.0, a, b);
    }

    void Spin(long id, Heli h, Transform node, Vector3 at, S.GDict e, Color a, Color b)
    {
        if (node == null)
        {
            node = new GameObject("wreck").transform;  // a model the view never drew still carries the fire down
            node.SetParent(root, false);
        }
        var drift = new Vector3((float)(double)S.Num.F(e["dx"]), 0f, (float)(double)S.Num.F(e["dz"]));
        var f = new Falling
        {
            heli = h, node = node, a = a, b = b, trail = fx.StartTrail(),
            fall = new HeliFall(Num(at), Num(drift), S.Num.F(e["seconds"])),
        };
        for (int k = 0; k < FLAMES; k++) f.flames[k] = fx.Fire(at, F(wreck, "trail_fire"));
        falling[id] = f;
        fx.HeliFlare(at, F(wreck, "hit_flare"), F(wreck, "flare_seconds"));
        fx.FlashLight(at, CRASH_BLAST, F(wreck, "hit_light"), HIT_LIGHT_SECONDS);
        fx.HeliSmoke(at, F(wreck, "hit_smoke"));
        long count = e.Has("crew") ? S.Num.I(e["crew"]) : 0;
        for (int n = 0; n < count; n++) Jump(HeliWreck.Chute(n, Num(at), Num(drift), tuning));
    }

    // heli_crashed: a falling wreck lands at the sim's crash point.
    void HeliCrashed(S.GDict e)
    {
        long id = S.Num.I(e["heli"]);
        Vector3 ground = EventAt(e, 0f);
        Color a = HELI_PAINT, b = HELI_PAINT;
        if (falling.TryGetValue(id, out Falling f))
        {
            a = f.a;
            b = f.b;
            foreach (Fires.Burning flame in f.flames) fx.PutOut(flame);
            f.trail.End();
            if (f.heli != null) helis.Remove(id);
            BreakUp(f.heli, f.node, HeliWreck.CRASH_REACH, false);
            falling.Remove(id);
        }
        float scale = F(wreck, "crash_scale");
        fx.HeliFlare(ground + Vector3.up * CRASH_FLASH_UP, F(wreck, "crash_flare"), CRASH_FLARE_SECONDS);
        fx.FlashLight(ground + Vector3.up * CRASH_FLASH_UP, CRASH_BLAST, F(wreck, "crash_light"), F(wreck, "crash_light_seconds"));
        fx.HeliFireball(ground + Vector3.up * CRASH_BALL_UP, F(wreck, "crash_fireball"));
        fx.HeliSmoke(ground + Vector3.up * CRASH_SMOKE_UP, F(wreck, "crash_smoke"));
        fx.Fire(ground, F(wreck, "crash_fire"));
        fx.Dust(ground + Vector3.up * CRASH_DUST_UP, scale);
        fx.Shockwave(ground, scale * F(wreck, "crash_ring"));
        Shards(ground + Vector3.up * HeliWreck.CRASH_LIFT, (int)S.Num.I(wreck["crash_shards"]), HeliWreck.CRASH_BURNING,
            HeliWreck.CRASH_SHARD_REACH, a, b);
    }

    // _break_up: the model's body, rotors and gun thrown from where they are; a stand-in with no parts is just
    // removed (no draws). The leader's model has no gun: its draws are made, the piece is not drawn.
    void BreakUp(Heli h, Transform node, double reach, bool inAir)
    {
        if (h == null)
        {
            if (node != null) Object.Destroy(node.gameObject);
            return;
        }
        Transform[] parts = { h.root.GetChild(0), h.mainRotor, h.tailRotor, h.gun };
        drawn.Clear();
        HeliWreck.BreakUp(wreckRng, tuning, reach, inAir, drawn);
        for (int n = 0; n < HeliWreck.PARTS; n++)
        {
            Transform part = parts[n];
            if (part == null) continue;
            HeliPiece piece = drawn[n];
            // HelicopterModel.break_up keeps each part's world transform.
            piece.position = Num(Mirror(part.position));
            piece.rotation = Euler(part.rotation);
            if (n == HeliWreck.BODY) piece.rotation.Y = HeliWreck.BODY_TURN;
            part.SetParent(root, true);
            Throw(piece, part);
        }
        Object.Destroy(h.root.gameObject);
    }

    // HeliDebris.shards: chunks in the wreck's paints round a charred pair.
    void Shards(Vector3 at, int count, int burning, double reach, Color a, Color b)
    {
        drawn.Clear();
        HeliWreck.Shards(wreckRng, tuning, Num(at), count, burning, reach, drawn);
        foreach (HeliPiece piece in drawn)
        {
            Color colour = piece.colour switch
            {
                HeliWreck.PAINT_A => a,
                HeliWreck.CHARCOAL => Rgb(HeliWreck.CHARCOAL_RGB),
                HeliWreck.SCORCH => Rgb(HeliWreck.SCORCH_RGB),
                _ => b,
            };
            Throw(piece, MakeBox(colour, SOLID, null));
        }
    }

    static Color Rgb(int rgb) => new Color32((byte)(rgb >> RED_SHIFT), (byte)(rgb >> 8), (byte)rgb, SOLID);

    void Throw(HeliPiece piece, Transform node)
    {
        var t = new Thrown { piece = piece, node = node };
        if (piece.burning) t.fire = fx.Fire(Godot(piece.position), piece.fire);
        Place(t);
        thrown.Add(t);
    }

    static void Place(Thrown t)
    {
        HeliPiece p = t.piece;
        GodotEuler.Columns(p.rotation, N.Vector3.One, out _, out N.Vector3 by, out N.Vector3 bz);
        t.node.SetPositionAndRotation(Mirror(Godot(p.position)), Turned(by, bz));
        t.node.localScale = Godot(p.scale);
    }

    // _jump: a soldier (VoxelPerson RUN_A, arms up) hanging under a canopy, drifting down with the wind.
    void Jump(HeliChute chute)
    {
        if (runner == null)
        {
            runner = PersonMesh.Runner(CREW_OUTFIT, F(S.Content.Section("street"), "person_voxel"));
            canopy = CanopyMesh();
        }
        var person = new GameObject("crew");
        person.transform.SetParent(root, false);
        person.AddComponent<MeshFilter>().sharedMesh = runner;
        person.AddComponent<MeshRenderer>().sharedMaterial = material;
        var dome = new GameObject("canopy");
        dome.transform.SetParent(person.transform, false);
        dome.AddComponent<MeshFilter>().sharedMesh = canopy;
        dome.AddComponent<MeshRenderer>().sharedMaterial = canopyMat;
        Mesh line = Box(CANOPY, CanopyAlpha());
        for (int corner = 0; corner < 4; corner++)
        {
            HeliWreck.Line(corner, tuning, out N.Vector3 from, out N.Vector3 to);
            var go = new GameObject("line");
            go.transform.SetParent(person.transform, false);
            go.AddComponent<MeshFilter>().sharedMesh = line;
            go.AddComponent<MeshRenderer>().sharedMaterial = canopyMat;
            // Basis.looking_at(to - from): the box's length along the line, at its middle.
            go.transform.localPosition = Mirror(Godot((from + to) * 0.5f));
            go.transform.localRotation = Quaternion.LookRotation(Mirror(Godot(to - from)));
            go.transform.localScale = new Vector3(LINE_THICK, LINE_THICK, N.Vector3.Distance(from, to));
        }
        crew.Add(new Bailing { chute = chute, node = person.transform });
    }

    // round(255 * (1 - canopy_glow)): the vertex alpha that makes SliceSurface glow canopy_glow of the albedo.
    byte CanopyAlpha() => (byte)Mathf.RoundToInt(SOLID * (1f - F(wreck, "canopy_glow")));

    // _canopy's dome: HeliWreck.Canopy's cubes, canopy_voxel each, canopy_hang above the soldier's feet, in two shades.
    Mesh CanopyMesh()
    {
        var cells = new List<CanopyCell>();
        HeliWreck.Canopy(tuning, cells);
        Color dark = CANOPY * (1f - CANOPY_DARKEN);
        var model = new ModelColors.Model { xyz = new S.PackedInt32Array(), rgb = new int[cells.Count] };
        for (int i = 0; i < cells.Count; i++)
        {
            model.xyz.Append(cells[i].x);
            model.xyz.Append(cells[i].y);
            model.xyz.Append(cells[i].z);
            Color32 c = cells[i].dark ? dark : CANOPY;
            model.rgb[i] = c.r << RED_SHIFT | c.g << 8 | c.b;
        }
        float voxel = (float)tuning.canopyVoxel;
        // Faces puts a cell's middle at (y + 0.5) voxels: lift by the hang, less that half.
        Mesh mesh = Faces(model, voxel, new Vector3(0f, voxel * 0.5f - tuning.canopyHang, 0f));
        var colors = new List<Color32>();
        mesh.GetColors(colors);
        byte alpha = CanopyAlpha();
        for (int i = 0; i < colors.Count; i++) colors[i] = new Color32(colors[i].r, colors[i].g, colors[i].b, alpha);
        mesh.SetColors(colors);
        mesh.name = "heli canopy";
        return mesh;
    }

    // Each frame (heli_wreck.gd _process, heli_debris.gd _process): the falls, the pieces, the crew.
    void Wrecks(float dt)
    {
        foreach (Falling f in falling.Values)
        {
            f.fall.Step(dt, tuning);
            f.node.SetPositionAndRotation(Mirror(Godot(f.fall.position)), Turned(f.fall.basisY, f.fall.basisZ));
            for (int k = 0; k < FLAMES; k++) fx.MoveFire(f.flames[k], Godot(f.fall.Flame(k, tuning)));
            fx.StepTrail(f.trail, Godot(f.fall.position), dt);
        }
        for (int i = thrown.Count - 1; i >= 0; i--)
        {
            Thrown t = thrown[i];
            bool alive = HeliWreck.Step(t.piece, dt, tuning);
            if (t.fire != null && !t.piece.burning)
            {
                fx.PutOut(t.fire);
                t.fire = null;
            }
            if (!alive)
            {
                Object.Destroy(t.node.gameObject);
                thrown.RemoveAt(i);
                continue;
            }
            Place(t);
            if (t.fire != null) fx.MoveFire(t.fire, Godot(t.piece.position));
        }
        for (int i = crew.Count - 1; i >= 0; i--)
        {
            Bailing c = crew[i];
            c.t += dt;
            if (!c.chute.Pose(c.t, out N.Vector3 at, out float swing))
            {
                Object.Destroy(c.node.gameObject);
                crew.RemoveAt(i);
                continue;
            }
            c.node.SetPositionAndRotation(Mirror(Godot(at)), Quaternion.Euler(0f, 0f, -swing * Mathf.Rad2Deg));
        }
    }
}
