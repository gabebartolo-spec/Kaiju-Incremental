using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using S = Kaiju.Sim;

// The street's people, parked cars, lamps and the beach's props on screen (scenes/street_life.gd with street_lod.gd,
// city_decor.gd and beach_props.gd): StreetPeople walks them, this draws them, one instanced batch per outfit and
// pose, and passes on what the kaiju, the army and the falling buildings crush. Presentation only (hard rule 3).
public sealed class StreetView
{
    // scenes/voxel_person.gd OUTFITS (the six civilians): shirt, pants, hair, skin; and _bake's shoe.
    static readonly int[][] OUTFITS =
    {
        new[] { 0x8a3a32, 0x2f3440, 0x2a1f18, 0xe0b48e },
        new[] { 0xc9c2b0, 0x3b3a36, 0x1a1714, 0x8d5a3b },
        new[] { 0x3f5f7a, 0x57503f, 0x6a4a2a, 0xf0caa8 },
        new[] { 0xc08a2e, 0x2a2a2e, 0x3a2a20, 0xc58c5f },
        new[] { 0x4f6a46, 0x4a4a50, 0xb8a888, 0xe0b48e },
        new[] { 0x6a4a6e, 0x1f2630, 0x1a1714, 0xa06a46 },
    };
    const int SHOE = 0x1a1a1a;
    // scenes/voxel_person.gd _body: each pose's stride (WALK_A, WALK_B, RUN_A, RUN_B).
    static readonly int[] STRIDE = { 1, -1, 2, -2 };
    // Graphics.DrawMeshInstanced's most per call.
    const int BATCH = 1023;
    // scenes/tank_yard.gd: a tank on the street flattens what is within 1.4 of it, every tenth step.
    const float TANK_CRUSH = 1.4f;
    const int TANK_EVERY = 10;
    // scenes/powers_view.gd: the automatic tail sweep crushes a disc half its reach, half its reach behind.
    const float TAIL_AUTO_CRUSH = 0.5f;
    // scenes/street_life.gd crush_all: a crushed person's dust puff rises from this height.
    const float PUFF_Y = 0.15f;

    public readonly StreetPeople people;
    readonly S.RampageSim sim;
    readonly CityFx fx;
    readonly Material material;
    readonly Mesh[] meshes = new Mesh[StreetPeople.OUTFITS * StreetPeople.POSES];
    readonly List<Matrix4x4[]>[] batches = new List<Matrix4x4[]>[StreetPeople.OUTFITS * StreetPeople.POSES];
    readonly int[] counts = new int[StreetPeople.OUTFITS * StreetPeople.POSES];
    readonly Plane[] planes = new Plane[6];
    readonly float viewMargin;
    readonly StreetDecor decor;
    readonly PropTiles beach, courts;
    int tankStep;

    public int Drawn { get; private set; }
    public int Props => decor.Count + (beach != null ? beach.Count : 0);
    public int PropsCrushed => decor.Crushed + (beach != null ? beach.Crushed : 0);

    public StreetView(S.RampageSim sim, CityFx fx, Shader shader, Transform parent)
    {
        this.sim = sim;
        this.fx = fx;
        S.GDict cfg = S.Content.Section("street");
        float voxel = (float)S.Num.F(cfg["person_voxel"]);
        viewMargin = (float)S.Num.F(cfg["view_margin"]);
        people = new StreetPeople(sim, S.Seeds.Make("civilians", 0), StreetPeople.PerLot());
        people.Puffed = at => fx.Puff(new Vector3((float)at.x, PUFF_Y, (float)at.y));
        material = ArmyView.PlainMaterial(shader, voxel);
        material.enableInstancing = true;
        for (int outfit = 0; outfit < StreetPeople.OUTFITS; outfit++)
            for (int pose = 0; pose < StreetPeople.POSES; pose++)
            {
                int k = outfit * StreetPeople.POSES + pose;
                meshes[k] = ArmyView.Faces(PropTiles.Model(Body(outfit, pose)), voxel, new Vector3(-0.5f * voxel, 0f, -0.5f * voxel));
                batches[k] = new List<Matrix4x4[]>();
            }
        decor = new StreetDecor(sim, shader, parent);
        S.GDict plan = S.CityGen.Map(sim.city);
        if (plan.Has("harbour"))
        {
            S.GDict harbour = sim.city["harbour"];
            S.GDict props = harbour["props"];
            float cell = (float)S.Num.F(props["voxel"]);
            float y = (float)BeachLayout.FloorY(plan);
            beach = new PropTiles("beach props", shader, parent, cell, y);
            courts = new PropTiles("beach courts", shader, parent, cell, y);
            BeachProps.Plant(plan, props, sim.arenaHalf + S.Num.F(sim.city["view_beyond"]), beach, courts);
            beach.Tick();
            courts.Tick();
        }
    }

    // scenes/voxel_person.gd _body: one civilian's cells in a pose, feet on y = 0, facing Godot -z.
    static Dictionary<Vector3Int, int> Body(int outfit, int pose)
    {
        int[] o = OUTFITS[outfit];
        int shirt = o[0], pants = o[1], hair = o[2], skin = o[3];
        var cells = new Dictionary<Vector3Int, int>();
        int stride = STRIDE[pose];
        for (int leg = 0; leg < 2; leg++)
        {
            int x = leg == 0 ? -2 : 1, f = leg == 0 ? stride : -stride;
            cells[new Vector3Int(x, 0, f)] = SHOE;
            cells[new Vector3Int(x, 0, f - 1)] = SHOE;
            cells[new Vector3Int(x, 1, f)] = pants;
            cells[new Vector3Int(x, 2, Math.Abs(f) > 1 ? Math.Sign(f) : 0)] = pants;
            PropTiles.Box(cells, new Vector3Int(x, 3, 0), new Vector3Int(x, 4, 0), pants);
        }
        PropTiles.Box(cells, new Vector3Int(-2, 5, -1), new Vector3Int(1, 5, 0), pants);
        PropTiles.Box(cells, new Vector3Int(-2, 6, -1), new Vector3Int(1, 8, 0), shirt);
        PropTiles.Box(cells, new Vector3Int(-1, 9, -1), new Vector3Int(0, 9, -1), skin);
        PropTiles.Box(cells, new Vector3Int(-1, 9, 0), new Vector3Int(0, 9, 0), hair);
        PropTiles.Box(cells, new Vector3Int(-1, 10, -1), new Vector3Int(0, 10, 0), hair);
        if (pose >= StreetPeople.RUN_A)
        {
            for (int side = 0; side < 2; side++)
            {
                int x = side == 0 ? -3 : 2;
                PropTiles.Box(cells, new Vector3Int(x, 8, 0), new Vector3Int(x, 10, 0), shirt);
                cells[new Vector3Int(x, 11, 0)] = skin;
            }
            return cells;
        }
        for (int side = 0; side < 2; side++)
        {
            int ax = side == 0 ? -3 : 2, ay = side == 0 ? -Math.Sign(stride) : Math.Sign(stride);
            PropTiles.Box(cells, new Vector3Int(ax, 7, 0), new Vector3Int(ax, 8, 0), shirt);
            cells[new Vector3Int(ax, 6, ay)] = shirt;
            cells[new Vector3Int(ax, 5, ay)] = skin;
        }
        return cells;
    }

    // ---------- Crushing ----------

    // The props under a disc of the walking body (city_decor.gd trample): never the people.
    public void Trample(Vector3 at, float radius)
    {
        Flatten(decor.props, at, radius);
        if (beach != null) Flatten(beach, at, radius);
    }

    void Flatten(PropTiles field, Vector3 at, float radius)
    {
        if (field.Crush(at, radius, out Vector3 first) > 0) fx.Puff(first);
    }

    // People and props within `radius` of `at` (Godot axes) are crushed (city_view.gd crush).
    public void Crush(Vector3 at, float radius, bool byTank = false, bool byArmy = false)
    {
        Trample(at, radius);
        people.Crush(at.x, at.z, radius, byTank, byArmy);
    }

    readonly List<S.Vector3> spots = new List<S.Vector3>();

    void CrushSpots(List<S.Vector3> at)
    {
        foreach (S.Vector3 s in at) Trample(new Vector3((float)s.x, 0f, (float)s.y), (float)s.z);
        people.CrushAll(at);
    }

    public void OnEvent(S.GDict e)
    {
        var feet = new Vector3((float)sim.kaijuPos.x, 0f, (float)sim.kaijuPos.y);
        switch (S.Gd.Str(e["type"]))
        {
            case "stomp":  // scenes/rampage_footfall.gd
                Crush(feet, (float)(S.Num.F(e["radius"]) + people.StompCatch * sim.BodyScale()));
                break;
            case "tail_auto":
                float reach = (float)S.Num.F(e["reach"]) * TAIL_AUTO_CRUSH;
                Crush(feet - new Vector3((float)sim.facing.x, 0f, (float)sim.facing.y) * reach, reach);
                break;
            case "ability":
                bool cone = S.Gd.Str(e["kind"]) == "cone";
                Crush(feet, (float)S.Num.F(e["reach"]) * (cone ? 0.5f : 1f));
                if (cone)
                {
                    spots.Clear();
                    foreach (S.Vector3 s in S.BreathCone.Cover(S.BreathCone.Of(sim))) spots.Add(s);
                    CrushSpots(spots);
                }
                break;
            case "leap_land":
                S.Vector2 land = e["at"];
                Crush(new Vector3((float)land.x, 0f, (float)land.y), (float)S.Num.F(e["radius"]));
                break;
            case "stray_landed":
                S.Vector2 hit = e["at"];
                S.GDict miss = sim.army["miss"];
                Crush(new Vector3((float)hit.x, 0f, (float)hit.y), (float)S.Num.F(miss["radius"]), false, true);
                break;
            case "fall_start":
                people.FallStart(sim, e);
                break;
            case "fall_land":
                CrushSpots(people.FallLandSpots(sim, e));
                break;
        }
    }

    // ---------- Each frame ----------

    // steps: the physics frames run so far (the tanks flatten every tenth).
    public void Step(float dt, int steps)
    {
        if (steps / TANK_EVERY != tankStep / TANK_EVERY)
            foreach (S.RampageSim.Tank tank in sim.tanks)
                if (tank.height <= 0.0) Crush(new Vector3((float)tank.pos.x, 0f, (float)tank.pos.y), TANK_CRUSH, true);
        tankStep = steps;
        people.Step(dt, sim.kaijuPos, sim.BodyScale(), sim.emerge.surfaced || !sim.emerge.active);
        decor.props.Tick();
        if (beach != null) beach.Tick();
    }

    // Everyone the camera sees, one instanced draw per outfit and pose (scenes/street_lod.gd draw).
    public void Draw(Camera cam)
    {
        GeometryUtility.CalculateFrustumPlanes(cam, planes);
        Array.Clear(counts, 0, counts.Length);
        Drawn = 0;
        List<StreetPeople.Person> list = people.people;
        for (int i = 0; i < list.Count; i++)
        {
            StreetPeople.Person p = list[i];
            S.Vector2 look = p.heading;
            float lx = (float)look.x, lz = (float)look.y;
            var at = new Vector3((float)p.pos.x - lz * (float)p.side, 0f, -((float)p.pos.y + lx * (float)p.side));
            bool seen = true;
            for (int k = 0; k < 6 && seen; k++) seen = planes[k].GetDistanceToPoint(at) > -viewMargin;
            if (!seen) continue;
            int bucket = p.outfit * StreetPeople.POSES + people.Pose(i);
            int n = counts[bucket]++;
            if (n / BATCH >= batches[bucket].Count) batches[bucket].Add(new Matrix4x4[BATCH]);
            var forward = new Vector3(lx, 0f, -lz);
            Quaternion turn = forward.sqrMagnitude > 1e-6f ? Quaternion.LookRotation(forward) : Quaternion.identity;
            batches[bucket][n / BATCH][n % BATCH] = Matrix4x4.TRS(at, turn, Vector3.one);
            Drawn++;
        }
        for (int bucket = 0; bucket < counts.Length; bucket++)
            for (int from = 0; from < counts[bucket]; from += BATCH)
                Graphics.DrawMeshInstanced(meshes[bucket], 0, material, batches[bucket][from / BATCH], Mathf.Min(BATCH, counts[bucket] - from), null, ShadowCastingMode.On, true);
    }

    public void Dispose()
    {
        foreach (Mesh mesh in meshes)
            if (mesh != null) UnityEngine.Object.Destroy(mesh);
        UnityEngine.Object.Destroy(material);
        decor.props.Dispose();
        beach?.Dispose();
        courts?.Dispose();
    }
}
