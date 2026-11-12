using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;
using N = System.Numerics;
using S = Kaiju.Sim;

// scenes/death_view.gd: his death as the player sees it (DeathOverload; D-323, D-484 copy Godot exactly). Through
// the stagger a violet crackle builds over his hide with a violet light on the street (Special K,
// creation.lab.colors.special_k) and the stone creeps up from his feet (CrocDeath.Overload); at the shatter he is
// gone into jagged stone chunks (assets/death/chunk_*.obj, drawn with his own stone, SliceSurface.hlsl
// SLICE_STONE): his cubes burst out as small chunks that tumble and lie as rubble, the sim's shards fly their arcs
// as the big ones, each trailing dust, to where they smash, and a flash; then, once the last shard is down, the
// dust ring of his blast. Looks: data/tuning.json death.look. Seeded as Godot's (0xDEAD, same draw order).
// Presentation only: the sim decides every hit. Godot axes throughout; the shader mirrors z.
public sealed class DeathView : IDisposable
{
    // kaiju_model.gd VOXEL: one cube of his hide at design size (DESIGN_UNIT / RES).
    const float DESIGN_UNIT = 0.6f;
    const int RES = 5;
    const ulong SEED = 0xDEAD;
    const float MIN_SPAN = 0.001f, AXIS_MIN = 0.01f;
    const float FLICKER_BASE = 0.6f, FLICKER_SPAN = 0.4f;
    const float SHOCK_SHARE = 0.5f, HALF = 0.5f, LAND_DUST = 4f, ARC_PEAK = 4f;
    // How often a flying shard's dust trail puffs (Godot emits continuously).
    const float TRAIL_PUFF_S = 0.1f, TRAIL_REACH = 0.4f;
    // fx_particles.gd dust_trail: every way out, damping, size spread, and the puff growing over its life.
    const float TRAIL_SPREAD = 180f, TRAIL_DAMP_MIN = 0.5f, TRAIL_DAMP_MAX = 1.5f, TRAIL_SIZE_MIN = 0.7f, TRAIL_SIZE_MAX = 1.3f;
    const float TRAIL_GROW_FROM = 0.5f, TRAIL_GROW_TO = 1.6f;
    const float BOUNDS = 8000f;
    const int PIECE_FLOATS = 4, PIECE_BYTES = 64;
    // Color.GRAY: a shard's colour when no cube was found near it.
    const float GODOT_GRAY = 0.745f;
    // surface_detail.gdshaderinc defaults, the stone's grain (death_stone.gdshader sets none).
    static readonly string[] GRAIN_KEYS = { "g_block", "g_block_noise", "g_patch_noise", "g_speck_chance", "g_speck_dark", "g_seam", "g_fade_near", "g_fade_far", "g_seed" };
    static readonly float[] GRAIN_VALUES = { 0.125f, 0.09f, 0.05f, 0.04f, 0.72f, 0.05f, 35f, 80f, 0f };

    // One set of chunks (his cubes, or the sim's shards), drawn one instanced draw per chunk kind.
    sealed class Group
    {
        public DeathPieces pieces;
        public Vector4[] tint;
        public List<int>[] byKind;
        public GraphicsBuffer[] buffer;
        public Vector4[][] data;
        public MaterialPropertyBlock[] block;
    }

    readonly S.RampageSim sim;
    readonly Croc croc;
    readonly CityFx fx;
    readonly StreetView street;
    readonly CityTrees trees;
    readonly Action<float, Vector3> kick;
    readonly Shader lit;
    readonly float exposureUnit, lightMatch;
    readonly S.GDict cfg, look;
    readonly Color violet;
    readonly S.RandomNumberGenerator rng = new S.RandomNumberGenerator { seed = unchecked((long)SEED) };
    readonly List<Vector3> points = new List<Vector3>();
    readonly List<Color> colours = new List<Color>();
    readonly List<N.Vector3> spin = new List<N.Vector3>();
    readonly List<BurstStyle> trails = new List<BurstStyle>();
    readonly List<Vector3> trailAt = new List<Vector3>();
    readonly List<bool> landed = new List<bool>();
    Light light;
    Mesh[] chunks;
    N.Vector3[][] corners;
    Material stoneMat;
    Group debris, shards;
    float flash, trailIn;
    bool blasted;

    public bool Burst { get; private set; }
    public int Debris => debris?.pieces.Count ?? 0;
    public int Shards => shards?.pieces.Count ?? 0;
    public int Landed { get; private set; }
    public bool Blasted => blasted;

    public DeathView(S.RampageSim sim, Croc croc, CityFx fx, StreetView street, CityTrees trees, Shader lit, float exposureUnit, float lightMatch, Action<float, Vector3> kick)
    {
        this.sim = sim;
        this.croc = croc;
        this.fx = fx;
        this.street = street;
        this.trees = trees;
        this.lit = lit;
        this.exposureUnit = exposureUnit;
        this.lightMatch = lightMatch;
        this.kick = kick;
        cfg = S.Content.Section("death");
        look = cfg["look"];
        S.GDict lab = S.Content.Section("creation")["lab"];
        S.GDict labColours = lab["colors"];
        ColorUtility.TryParseHtmlString("#" + S.Gd.Str(labColours["special_k"]), out violet);
    }

    static float F(S.GDict d, string key) => (float)S.Num.F(d[key]);

    float Range(S.GDict d, string key)
    {
        S.GArray<S.Variant> span = d[key];
        return (float)rng.RandfRange(S.Num.F(span[0]), S.Num.F(span[1]));
    }

    // death_view.gd _process, after the croc's pose for this frame.
    public void Step(float dt)
    {
        S.DeathOverload d = sim.death;
        if (!d.Active()) return;
        float stagger = F(cfg, "stagger_s");
        float charge = Mathf.SmoothStep(0f, 1f, (float)d.t / Mathf.Max(MIN_SPAN, stagger));
        float stone = Mathf.Clamp01(((float)d.t - stagger) / Mathf.Max(MIN_SPAN, F(cfg, "stone_s")));
        if (light == null) Begin();
        if (d.phase != S.DeathOverload.Phase.SHATTER)
        {
            croc.Overload(charge, stone, look, violet);
            float flicker = FLICKER_BASE + FLICKER_SPAN * (float)rng.Randf();
            Energy(F(look, "light_energy") * charge * flicker);
            Vector3 at = croc.HipFocus();
            light.transform.position = new Vector3(at.x, at.y, -at.z);
            return;
        }
        if (!Burst) Shatter(d);
        flash = Mathf.Max(0f, flash - dt / Mathf.Max(MIN_SPAN, F(look, "burst_s")));
        Energy(F(look, "burst_light") * flash * flash);
        debris.pieces.Fall(dt, F(look, "gravity"));
        FlyShards(d, dt);
        if (d.blastBegan && !blasted) Blast(d);
        Draw(debris);
        Draw(shards);
    }

    void Energy(float energy) => light.intensity = energy * Mathf.PI * exposureUnit * lightMatch;

    // He starts to die: the stagger take, the violet light, and the chunks loaded ready.
    void Begin()
    {
        croc.StartDeath(S.Gd.Str(cfg["stagger_clip"]));
        var go = new GameObject("death light");
        light = go.AddComponent<Light>();
        light.type = LightType.Point;
        light.shadows = LightShadows.None;
        light.lightUnit = LightUnit.Candela;
        light.color = violet;
        light.range = F(look, "light_range") * (float)sim.BodyScale();
        go.AddComponent<HDAdditionalLightData>();
        S.GArray<S.Variant> paths = look["chunks"];
        chunks = new Mesh[paths.Size()];
        corners = new N.Vector3[paths.Size()][];
        for (int i = 0; i < paths.Size(); i++)
        {
            var obj = new ObjChunk(S.FileAccess.GetFileAsString(S.Gd.Str(paths[i])));
            corners[i] = obj.corners;
            chunks[i] = ChunkMesh(obj);
        }
        stoneMat = new Material(lit) { enableInstancing = true };
        stoneMat.EnableKeyword("SLICE_STONE");
        for (int i = 0; i < GRAIN_KEYS.Length; i++) stoneMat.SetFloat(GRAIN_KEYS[i], GRAIN_VALUES[i]);
    }

    static Mesh ChunkMesh(ObjChunk obj)
    {
        var at = new Vector3[obj.points.Count];
        var n = new Vector3[obj.points.Count];
        for (int i = 0; i < at.Length; i++)
        {
            at[i] = new Vector3(obj.points[i].X, obj.points[i].Y, obj.points[i].Z);
            n[i] = new Vector3(obj.normals[i].X, obj.normals[i].Y, obj.normals[i].Z);
        }
        var mesh = new Mesh { vertices = at, normals = n, triangles = obj.triangles.ToArray() };
        mesh.bounds = new Bounds(Vector3.zero, Vector3.one * BOUNDS);
        return mesh;
    }

    // death_view.gd _burst: his cubes burst out as small chunks, the sim's shards take flight as the big ones with
    // their dust, the flash and ring.
    void Shatter(S.DeathOverload d)
    {
        Burst = true;
        croc.BodyPoints((int)S.Num.I(look["debris_max"]), points, colours);
        croc.Visible = false;
        var centre = new Vector3((float)d.centre.x, 0f, (float)d.centre.y);
        flash = 1f;
        float bs = (float)sim.BodyScale();
        float voxel = DESIGN_UNIT / RES * bs;
        CrocDeathLook(voxel);
        debris = Pieces(points.Count, voxel, "debris_size");
        for (int i = 0; i < points.Count; i++)
        {
            Vector3 p = points[i];
            Vector3 outward = new Vector3(p.x - centre.x, 0f, p.z - centre.z).normalized;
            Vector3 v = outward * Range(look, "debris_speed");
            v.y = Range(look, "debris_up");
            float turn = Range(look, "debris_spin");
            v *= Mathf.Sqrt(bs);
            debris.pieces.Launch(i, Num(p), Num(v), Axis() * turn);
            debris.tint[i] = Piece(colours[i]);
        }
        int count = (int)d.shards.Size();
        shards = Pieces(count, (float)d.CellSize(), "shard_size");
        S.GDict trail = look["trail"];
        for (int i = 0; i < count; i++)
        {
            S.DeathOverload.Shard s = d.shards[i];
            Vector3 from = new Vector3((float)s.from.x, (float)s.from.y, (float)s.from.z);
            shards.tint[(int)s.id] = Piece(OwnColour(from));
            spin.Add(Axis());
            trails.Add(TrailStyle(shards.pieces.size[(int)s.id], trail));
            trailAt.Add(from);
            landed.Add(false);
        }
        kick(F(look, "burst_trauma"), centre);
        fx.Shockwave(centre, (float)sim.body.Length() * SHOCK_SHARE);
    }

    void CrocDeathLook(float voxel)
    {
        var b = new MaterialPropertyBlock();
        Croc.StoneLook(b, look);
        stoneMat.SetColor("_StoneColor", b.GetColor("_StoneColor"));
        stoneMat.SetFloat("_StoneVary", b.GetFloat("_StoneVary"));
        stoneMat.SetFloat("_StoneKeep", b.GetFloat("_StoneKeep"));
        stoneMat.SetFloat("_StoneVoxel", voxel);
    }

    // death_view.gd _pieces: `count` chunks, each a seeded kind and a size (longest side) of `unit` x a pick in
    // look[`sizes`], most of them small (size_skew), lying at a seeded turn.
    Group Pieces(int count, float unit, string sizes)
    {
        var kinds = new int[count];
        var size = new float[count];
        var lie = new Turn[count];
        S.GArray<S.Variant> span = look[sizes];
        float lo = (float)S.Num.F(span[0]), hi = (float)S.Num.F(span[1]);
        float skew = F(look, "size_skew");
        for (int i = 0; i < count; i++)
        {
            kinds[i] = (int)rng.RandiRange(0, chunks.Length - 1);
            float pick = Mathf.Pow((float)rng.Randf(), skew);
            size[i] = unit * Mathf.Lerp(lo, hi, pick);
            N.Vector3 axis = Axis();
            lie[i] = Turn.About(axis, (float)rng.Randf() * Mathf.PI * 2f);
        }
        var g = new Group
        {
            pieces = new DeathPieces(corners, kinds, size, lie),
            tint = new Vector4[count],
            byKind = new List<int>[chunks.Length],
            buffer = new GraphicsBuffer[chunks.Length],
            data = new Vector4[chunks.Length][],
            block = new MaterialPropertyBlock[chunks.Length],
        };
        for (int k = 0; k < chunks.Length; k++) g.byKind[k] = new List<int>();
        for (int i = 0; i < count; i++) g.byKind[kinds[i]].Add(i);
        for (int k = 0; k < chunks.Length; k++)
        {
            int n = g.byKind[k].Count;
            if (n == 0) continue;
            g.buffer[k] = new GraphicsBuffer(GraphicsBuffer.Target.Structured, n, PIECE_BYTES);
            g.data[k] = new Vector4[n * PIECE_FLOATS];
            g.block[k] = new MaterialPropertyBlock();
            g.block[k].SetBuffer("_Pieces", g.buffer[k]);
        }
        return g;
    }

    // scenes/fx_particles.gd dust_trail: the street's dust rising off a shard `size` across, puffs grown by
    // trail.size, rising at trail.rise and lifted by it, alpha trail.alpha fading out; sprayed in short bursts.
    BurstStyle TrailStyle(float size, S.GDict trail)
    {
        float grow = size * F(trail, "size"), rise = F(trail, "rise");
        Color dust = fx.dustLight, start = new Color(dust.r, dust.g, dust.b, F(trail, "alpha")), end = new Color(dust.r, dust.g, dust.b, 0f);
        return new BurstStyle
        {
            spread = TRAIL_SPREAD, gravity = new Vector3(0f, rise, 0f), vmin = 0f, vmax = rise, dmin = TRAIL_DAMP_MIN, dmax = TRAIL_DAMP_MAX,
            smin = grow * TRAIL_SIZE_MIN, smax = grow * TRAIL_SIZE_MAX, clear = 0f,
        }.Size(0f, TRAIL_GROW_FROM, 1f, TRAIL_GROW_TO).Colors(new[] { 0f, 1f }, start, end);
    }

    // death_view.gd _axis: a seeded direction (a tumble's axis).
    N.Vector3 Axis()
    {
        float x = (float)rng.RandfRange(-1, 1), y = (float)rng.RandfRange(-1, 1), z = (float)rng.RandfRange(-1, 1);
        var v = new N.Vector3(x, y, z);
        return v.Length() > AXIS_MIN ? N.Vector3.Normalize(v) : N.Vector3.UnitY;
    }

    // A piece's colour: its own sRGB shade where it flew from, and in alpha its 0..1 hash.
    Vector4 Piece(Color own) => new Vector4(own.r, own.g, own.b, (float)rng.Randf());

    // His colour at `at`: the nearest burst point's.
    Color OwnColour(Vector3 at)
    {
        float best = float.PositiveInfinity;
        var output = new Color(GODOT_GRAY, GODOT_GRAY, GODOT_GRAY);
        for (int i = 0; i < points.Count; i++)
        {
            float dist = (at - points[i]).sqrMagnitude;
            if (dist < best)
            {
                best = dist;
                output = colours[i];
            }
        }
        return output;
    }

    static N.Vector3 Num(Vector3 v) => new N.Vector3(v.x, v.y, v.z);

    // death_view.gd _fly_shards: the sim's shards along their arcs, tumbling a turn and trailing dust; each lies on
    // its lowest corner where it lands, which crushes the street under it, puffs dust and kicks the camera.
    void FlyShards(S.DeathOverload d, float dt)
    {
        float half = (float)d.CellSize() * HALF;
        float bs = (float)sim.BodyScale();
        trailIn -= dt;
        bool puff = trailIn <= 0f;
        if (puff) trailIn += TRAIL_PUFF_S;
        S.GDict trail = look["trail"];
        float life = F(trail, "life");
        int perPuff = Mathf.Max(1, Mathf.RoundToInt(F(trail, "amount") * TRAIL_PUFF_S / Mathf.Max(MIN_SPAN, life)));
        for (int i = 0; i < d.shards.Size(); i++)
        {
            S.DeathOverload.Shard s = d.shards[i];
            int id = (int)s.id;
            Turn rest = shards.pieces.lie[id];
            var to = new N.Vector3((float)s.to.x, shards.pieces.Lift(id, rest), (float)s.to.y);
            float k = Mathf.Clamp01((float)d.sinceShatter / Mathf.Max(MIN_SPAN, (float)s.t));
            float arc = F(look, "shard_arc") * bs * ARC_PEAK * k * (1f - k);
            var from = new N.Vector3((float)s.from.x, (float)s.from.y, (float)s.from.z);
            N.Vector3 p = N.Vector3.Lerp(from, to, k) + new N.Vector3(0f, arc, 0f);
            Turn turn = k < 1f ? Turn.About(spin[id], k * Mathf.PI * 2f) * rest : rest;
            shards.pieces.Place(id, turn, p);
            if (!landed[id])
            {
                trailAt[id] = new Vector3(p.X, p.Y, p.Z);
                float size = shards.pieces.size[id];
                if (puff) fx.Spray(trails[id], trailAt[id], Vector3.one * size * TRAIL_REACH, perPuff, life, TRAIL_PUFF_S);
            }
            if (!s.landed || landed[id]) continue;
            landed[id] = true;
            Landed++;
            var at = new Vector3((float)s.to.x, half, (float)s.to.y);
            float r = F(look, "crush_radius") * bs;
            trees.Crush(at, r);
            street.Crush(at, r);
            fx.Dust(at, half * LAND_DUST);
            kick(F(look, "shard_trauma"), at);
        }
    }

    // death_view.gd _blast: the blast front starts (the last shard is down): its dust ring out to the blast.
    void Blast(S.DeathOverload d)
    {
        blasted = true;
        var centre = new Vector3((float)d.centre.x, 0f, (float)d.centre.y);
        kick(F(look, "burst_trauma"), centre);
        fx.Shockwave(centre, (float)d.blastRadius);
    }

    // Each kind's pieces as they lie now: the turn's columns scaled to the size, the middle in their w, the tint.
    void Draw(Group g)
    {
        for (int k = 0; k < chunks.Length; k++)
        {
            List<int> ids = g.byKind[k];
            if (ids.Count == 0) continue;
            Vector4[] data = g.data[k];
            for (int j = 0; j < ids.Count; j++)
            {
                int i = ids[j];
                Turn t = g.pieces.drawTurn[i];
                float s = g.pieces.size[i];
                N.Vector3 at = g.pieces.drawAt[i];
                int o = j * PIECE_FLOATS;
                data[o] = new Vector4(t.x.X * s, t.x.Y * s, t.x.Z * s, at.X);
                data[o + 1] = new Vector4(t.y.X * s, t.y.Y * s, t.y.Z * s, at.Y);
                data[o + 2] = new Vector4(t.z.X * s, t.z.Y * s, t.z.Z * s, at.Z);
                data[o + 3] = g.tint[i];
            }
            g.buffer[k].SetData(data);
            Graphics.DrawMeshInstancedProcedural(chunks[k], 0, stoneMat, new Bounds(Vector3.zero, Vector3.one * BOUNDS), ids.Count, g.block[k], ShadowCastingMode.On, true);
        }
    }

    public void Dispose()
    {
        foreach (Group g in new[] { debris, shards })
        {
            if (g == null) continue;
            foreach (GraphicsBuffer b in g.buffer) b?.Release();
        }
        if (light != null) UnityEngine.Object.Destroy(light.gameObject);
    }
}
