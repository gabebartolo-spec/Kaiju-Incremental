using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using S = Kaiju.Sim;

// The street's people, parked cars, lamps, moving traffic and the beach's props on screen (scenes/street_life.gd
// with street_lod.gd, city_decor.gd and beach_props.gd): StreetPeople walks them, this draws them, one instanced batch
// per outfit and pose, owns Traffic (drawn by TrafficView), and passes on what the kaiju, the army and the falling
// buildings crush. Presentation only (hard rule 3).
public sealed class StreetView
{
    // scenes/voxel_person.gd OUTFITS (the six civilians): shirt, pants, hair, skin (PersonCells builds them).
    static readonly int[][] OUTFITS =
    {
        new[] { 0x8a3a32, 0x2f3440, 0x2a1f18, 0xe0b48e },
        new[] { 0xc9c2b0, 0x3b3a36, 0x1a1714, 0x8d5a3b },
        new[] { 0x3f5f7a, 0x57503f, 0x6a4a2a, 0xf0caa8 },
        new[] { 0xc08a2e, 0x2a2a2e, 0x3a2a20, 0xc58c5f },
        new[] { 0x4f6a46, 0x4a4a50, 0xb8a888, 0xe0b48e },
        new[] { 0x6a4a6e, 0x1f2630, 0x1a1714, 0xa06a46 },
        new[] { 0x1f2a44, 0x18202f, 0x101418, 0xc58c5f },  // COP: uniform, trousers, cap, skin
    };
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
    public readonly Traffic traffic;
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
    readonly TrafficView trafficView;
    public readonly Police police;
    readonly PoliceView policeView;
    readonly List<StadiumView> stadiums = new List<StadiumView>();
    int tankStep;
    // Where the camera was at the last Draw: the light pool picks the lights nearest it.
    Vector3 eye;

    public int Drawn { get; private set; }
    public int Props => decor.Count + (beach != null ? beach.Count : 0);
    // The Tripo street props standing in this city (street_props.gd placed).
    public int StreetProps => decor.street.placed.Count;
    // scenes/city_view.gd: the salt of the sport's stream off the run's presentation stream.
    const long SPORT_SALT = 0x5907;

    // street_life.gd civilians_killed and panicking: the streets', the pitch's and the stands' (fans crushed or gone
    // with their stand).
    public int CiviliansKilled
    {
        get
        {
            int n = people.killed;
            foreach (StadiumView s in stadiums) n += s.match.killed + (s.match.crowd != null ? s.match.crowd.killed + s.match.crowd.fallen : 0);
            return n;
        }
    }

    public int Panicking
    {
        get
        {
            int n = people.Panicking();
            foreach (StadiumView s in stadiums) n += s.match.crowd != null ? s.match.crowd.Running() : 0;
            return n;
        }
    }

    // The first stadium's match for the stats line: players on the pitch and escaped, kicks, then the fans in view,
    // running, fallen, out and drawn.
    public string StadiumStats()
    {
        if (stadiums.Count == 0) return "none";
        StadiumMatch m = stadiums[0].match;
        StadiumCrowd c = m.crowd;
        string fans = c == null ? "no crowd" : $"fans {c.InStands()} fans_running {c.Running()} fans_fallen {c.fallen} fans_out {c.escaped} fans_killed {c.killed} fans_drawn {stadiums[0].FansDrawn}";
        return $"{S.Gd.Str(m.sport["id"])} pitch {m.OnPitch()} players_out {m.escaped} kicks {m.kicks} {fans}";
    }

    public int PropsCrushed => decor.Crushed + (beach != null ? beach.Crushed : 0);

    public StreetView(S.RampageSim sim, CityFx fx, Shader shader, Transform parent, float exposureUnit, float lightMatch, long seed)
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
        double noise = S.Num.F(S.Content.Look().Get("color_noise", 0.0));
        for (int outfit = 0; outfit < StreetPeople.OUTFITS; outfit++)
            for (int pose = 0; pose < StreetPeople.POSES; pose++)
            {
                int k = outfit * StreetPeople.POSES + pose;
                meshes[k] = PersonCells.Mesh(PersonCells.Body(OUTFITS[outfit], pose, outfit == StreetPeople.COP), k, voxel, noise);
                batches[k] = new List<Matrix4x4[]>();
            }
        decor = new StreetDecor(sim, shader, parent);
        // After the decor, as street_life.gd: the diagonal's parked row keeps clear of its props.
        traffic = new Traffic(sim, S.Seeds.Make("traffic", 0));
        traffic.Populate(decor.props.Bases());
        trafficView = new TrafficView(traffic, sim, shader);
        // After the traffic and the people, as street_life.gd builds police.gd.
        police = new Police(people, traffic, S.Seeds.Make("police", 0));
        people.police = police;
        policeView = new PoliceView(police, shader, parent, fx.Lights, exposureUnit, lightMatch);
        Stadiums(shader, seed);
        S.GDict plan = S.CityGen.Map(sim.city);
        if (plan.Has("harbour"))
        {
            S.GDict props = ((S.GDict)sim.city["harbour"])["props"];
            float cell = (float)S.Num.F(props["voxel"]);
            float y = (float)BeachLayout.FloorY(plan);
            beach = new PropTiles("beach props", shader, parent, cell, y);
            courts = new PropTiles("beach courts", shader, parent, cell, y);
            BeachProps.Plant(plan, props, sim.arenaHalf + S.Num.F(sim.city["view_beyond"]), beach, courts);
            beach.Tick();
            courts.Tick();
        }
    }

    // street_life.gd: a match on every stadium's pitch, its sport off the run's presentation stream (city_view.gd).
    void Stadiums(Shader shader, long seed)
    {
        string landmark = S.Gd.Str(((S.GDict)S.Content.Sports()["pitch"])["landmark"]);
        S.RandomNumberGenerator rng = S.Seeds.Derive(S.Seeds.Make("fx", seed), SPORT_SALT);
        int max = (int)Kaiju.Game.GraphicsPreset.Cap("crowd_max");
        for (int i = 0; i < sim.buildings.Size(); i++)
            if (sim.buildings[i].landmark == landmark) stadiums.Add(new StadiumView(sim, i, fx, shader, rng, max));
    }

    // ---------- Crushing ----------

    // The props under a disc of the walking body (city_decor.gd trample): never the people.
    public void Trample(Vector3 at, float radius)
    {
        Flatten(decor.props, at, radius);
        Flatten(decor.streetTiles, at, radius);
        if (beach != null) Flatten(beach, at, radius);
    }

    void Flatten(PropTiles field, Vector3 at, float radius)
    {
        if (field.Crush(at, radius, out Vector3 first) > 0) fx.Puff(first);
    }

    // People, cars and props within `radius` of `at` (Godot axes) are crushed (city_view.gd crush).
    public void Crush(Vector3 at, float radius, bool byTank = false, bool byArmy = false)
    {
        Trample(at, radius);
        traffic.Crush(new S.Vector2(at.x, at.z), radius);
        foreach (StadiumView stadium in stadiums) stadium.match.Crush(new S.Vector3(at.x, 0.0, at.z), radius);
        people.Crush(at.x, at.z, radius, byTank, byArmy);
    }

    readonly List<S.Vector3> spots = new List<S.Vector3>();

    void CrushSpots(List<S.Vector3> at)
    {
        foreach (S.Vector3 s in at)
        {
            Trample(new Vector3((float)s.x, 0f, (float)s.y), (float)s.z);
            traffic.Crush(new S.Vector2(s.x, s.y), s.z);  // street_life.gd crush_all, spot by spot
            foreach (StadiumView stadium in stadiums) stadium.match.Crush(new S.Vector3(s.x, 0.0, s.y), s.z);
        }
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
        traffic.Step(dt);  // before the police and the people, as street_life.gd
        police.Update(dt, sim.kaijuPos);
        people.Step(dt, sim.kaijuPos, sim.BodyScale(), sim.emerge.surfaced || !sim.emerge.active);
        fx.Lights.Step(dt, eye.x, eye.y, eye.z);  // the fires' lights and the beacons (scenes/light_pool.gd)
        policeView.Step();
        foreach (StadiumView stadium in stadiums) stadium.Step(dt);
        decor.Tick();
        if (beach != null) beach.Tick();
    }

    // Everyone the camera sees, one instanced draw per outfit and pose (scenes/street_lod.gd draw).
    public void Draw(Camera cam)
    {
        eye = cam.transform.position;
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
        trafficView.Draw(cam);
        policeView.Draw();
        foreach (StadiumView stadium in stadiums) stadium.Draw();
    }

    public void Dispose()
    {
        foreach (Mesh mesh in meshes)
            if (mesh != null) UnityEngine.Object.Destroy(mesh);
        UnityEngine.Object.Destroy(material);
        trafficView.Dispose();
        policeView.Dispose();
        foreach (StadiumView stadium in stadiums) stadium.Dispose();
        decor.Dispose();
        beach?.Dispose();
        courts?.Dispose();
    }
}
