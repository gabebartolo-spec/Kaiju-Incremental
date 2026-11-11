using System;
using System.Collections.Generic;
using Kaiju.Game;
using UnityEngine;
using S = Kaiju.Sim;

// The rampage's sound (scenes/sfx.gd, sfx_beam.gd, sfx_crowd.gd, sfx_gate.gd, city_sound.gd, roar_cue.gd,
// power_cues.gd, and the play calls of rampage.gd, rampage_footfall.gd, rampage_ability.gd, army_view.gd,
// rooftop_view.gd, blast_fx.gd, rail_view.gd): the sim's events become sounds, and the beds and the music follow
// the city each frame. It decides nothing: it only reads the sim. Positions are in the sim's axes (x, height, y).
public sealed class RampageAudio : MonoBehaviour
{
    const float STOMP_WAIT = 0.6f;  // rampage.gd STOMP_WAIT: a stomp waits this long for its foot
    const float LEAP_SECONDS = 0.4f;  // rampage_ability.gd LEAP_SECONDS: the ability leap's take-off to landing
    const double BEAM_FADE_IN = 0.6, BEAM_FADE_OUT = 0.15;  // sfx_beam.gd
    const double REGEN_FADE_DB_PER_S = 40.0;  // sfx.gd
    const double COLLAPSE_PITCH = 0.85;  // sfx.gd collapse(): a topple lands lower than a dropped slab
    const double SLIDE_SPEED = 0.5;  // rail_view.gd: a car moving faster than this is sliding
    const string BEAM_LOOP = "thunder_beam_loop", REGEN = "regen_loop", ROTOR = "heli_rotor", CROWD = "crowd_panic";
    const string RUMBLE = "train_rumble", SLIDE = "train_slide";

    RampageGame game;
    S.RampageSim sim;
    AudioHost host;
    AudioTable table;
    S.GDict tune, crowdCfg, cityCfg, blast, gate, railLook, baseStats;
    Transform ears;
    Vector3 earsAt;
    // sfx_gate.gd
    int smooth;
    float waited;
    // sfx.gd
    readonly List<double> landings = new List<double>();
    string pending = "";
    bool pendingCrack;
    float pendingAge, stompWait, sinceStep, sinceCrack;
    int step;
    bool healing;
    double regenAge, regenDb;
    // sfx_crowd.gd
    double crowdDb = -80.0, crowdTrim, chunkRate;
    long chunksBefore;
    // city_sound.gd
    readonly Dictionary<string, double> beds = new Dictionary<string, double>();
    double population;
    // roar_cue.gd, power_cues.gd
    double roarAt = double.PositiveInfinity;
    bool wasReady = true;
    // rail_view.gd
    readonly Dictionary<long, float> horned = new Dictionary<long, float>();
    float clock;
    // Sounds that follow their cause after a wait (a shell's flight, a far blast's boom).
    readonly List<(float left, Action sound)> later = new List<(float, Action)>();

    // Called once by RampageGame when it starts. The integrator then forwards each sim event to OnEvent and
    // each footfall to Footfall; the rest runs itself each frame.
    public static RampageAudio Attach(RampageGame game)
    {
        var audio = game.gameObject.AddComponent<RampageAudio>();
        audio.game = game;
        audio.host = AudioHost.Ensure();
        Sfx.Live = false;  // closed until the first frames are smooth (sfx_gate.gd)
        return audio;
    }

    bool Ready()
    {
        if (sim != null) return true;
        if (game == null || game.Sim == null) return false;
        sim = game.Sim;
        table = host.Table;
        tune = table.sfx;
        crowdCfg = tune["crowd"];
        gate = tune["start_gate"];
        cityCfg = S.Content.Section("city_sound");
        blast = S.Content.Section("blast_fx")["sound"];
        railLook = S.Content.Section("rail_look");
        RunRequest request = game.Run;  // the host has let go of RampageGame.Request by now
        baseStats = S.Content.SpeciesDef(request != null ? request.species : "reptilian")["stats"];
        Sfx.Seed(request != null ? request.runIndex : 0, (int)sim.SizeTier());
        chunksBefore = sim.chunksDestroyed;
        S.GDict bedRows = cityCfg["beds"];
        foreach (S.Variant k in bedRows.Keys())
            beds[S.Gd.Str(k)] = S.Gd.Str(k) == "crowd" ? 0.0 : S.Num.F(cityCfg["silent_db"]);  // city_sound.gd _ready
        // The city's own track (city_sound.gd: tracks[size_tier - 1]), every stem silent until the city falls.
        List<string> tracks = table.Tracks();
        if (tracks.Count > 0) Music.Play(tracks[Mathf.Clamp((int)sim.SizeTier() - 1, 0, tracks.Count - 1)]);
        GameObject camera = GameObject.Find("camera");
        ears = camera != null ? camera.transform : Camera.main != null ? Camera.main.transform : null;
        return true;
    }

    void LateUpdate()
    {
        if (!Ready()) return;
        AudioHost.Paused = game.Paused;
        if (game.Paused) return;
        Tick(Time.deltaTime);
    }

    // One frame of the rampage's sound (sfx.gd _process and its neighbours').
    public void Tick(float dt)
    {
        if (ears != null)
        {
            // Unity's z runs the other way from the sim's y.
            earsAt = new Vector3(ears.position.x, ears.position.y, -ears.position.z);
            Sfx.Listener(earsAt);
        }
        if (!Sfx.Live && !Gate(dt)) return;
        SoundLandings();
        Rotors();
        sinceStep += dt;
        sinceCrack += dt;
        FadeRegen(dt);
        Crowd(dt);
        if (pending != "")
        {
            pendingAge += dt;
            if (pendingAge >= S.Num.F(tune["stomp_wait"])) ReleaseStomp();
        }
        if (stompWait > 0f)
        {
            stompWait -= dt;
            if (stompWait <= 0f) Stomp(Power("stomp_damage"), false);  // rampage.gd: no foot came down in time
        }
        PowerCues();
        City(dt);
        Rail(dt);
        for (int i = later.Count - 1; i >= 0; i--)
        {
            (float left, Action sound) = later[i];
            left -= dt;
            if (left > 0f)
            {
                later[i] = (left, sound);
                continue;
            }
            later.RemoveAt(i);
            sound();
        }
    }

    // sfx_gate.gd: the sound opens after "smooth_frames" quick frames in a row, or "max_wait_s" at the latest;
    // what queued up while loading is dropped, not played in a burst.
    bool Gate(float dt)
    {
        smooth = dt <= S.Num.F(gate["max_frame"]) ? smooth + 1 : 0;
        waited += dt;
        if (smooth < S.Num.I(gate["smooth_frames"]) && waited < S.Num.F(gate["max_wait_s"])) return false;
        landings.Clear();
        pending = "";
        Sfx.Live = true;
        return true;
    }

    // One sim event (RampageGame's drain loop forwards every one, in order).
    public void OnEvent(S.GDict e)
    {
        if (!Ready()) return;
        string type = S.Gd.Str(e["type"]);
        switch (type)
        {
            case "stomp":
                stompWait = STOMP_WAIT;
                break;
            case "fall_land":
                landings.Add(S.Gd.Str(e.Get("kind", "")) == "topple" ? 0.0 : S.Num.F(tune["drop_quiet_db"]));
                break;
            case "ability":
                Ability(S.Gd.Str(e["kind"]));
                break;
            case "leap_off":
                Sfx.Play("leap_whoosh");
                break;
            case "leap_land":
                Sfx.Play("leap_land");
                break;
            case "slam":
                Sfx.Play(S.Gd.Str(S.Content.Section("slam_fx")["sound"]));
                break;
            case "tail_auto":
                Sfx.Play("lash");
                break;
            case "leap":
            case "ultimate":
                RoarCue();
                break;
            case "surface_break":
                Sfx.Roar();
                break;
            case "strike_windup":
                string kind = S.Gd.Str(e.Get("kind", ""));
                if (kind == S.Strikes.BREATH || kind == S.Strikes.BEAM) BeamCharge(S.Num.F(e["strike_in"]));
                // thunder_beam.gd _charged: the breath's crackle goes out when its charge-up ends at the
                // strike (spine_charge.gd finished); the beam's carries on under it until beam_end.
                if (kind == S.Strikes.BREATH)
                    later.Add(((float)S.Num.F(e["strike_in"]), () => Sfx.LoopFade(BEAM_LOOP, Sfx.SILENT_DB, BEAM_FADE_OUT, true)));
                break;
            case "beam_start":
                Sfx.Play("thunder_beam");
                if (Sfx.Live) BeamFade(BEAM_FADE_IN);
                break;
            case "beam_end":
                Sfx.Play("thunder_beam_end");
                Sfx.LoopFade(BEAM_LOOP, Sfx.SILENT_DB, BEAM_FADE_OUT, true);
                break;
            case "rooftop_fired":
                Squad(S.Num.I(e["squad"]));
                break;
            case "tank_fired":
                Tank(e);
                break;
            case "stray_landed":
                S.Vector2 stray = e["at"];
                Sfx.PlayAt("shell_hit", Flat(stray.x, stray.y));
                break;
            case "heli_fired":
                if (Heli(S.Num.I(e["heli"]), out Vector3 muzzle)) Sfx.PlayAt("heli_gun", muzzle);
                break;
            case "heli_crashed":
                Sfx.PlayAt("heli_crash", Flat(S.Num.F(e["x"]), S.Num.F(e["z"])));
                break;
            case "heli_destroyed":
            case "vip_down":           // vip_view.gd _down -> HeliWreck.downed
            case "gunship_destroyed":  // powers_view.gd: a gunship falls as a helicopter does (D-458)
                // heli_wreck.gd downed(): a burst is heard where it blew (at the sim's "y", else the air's
                // altitude); one that spins down is heard when it hits the ground (heli_crashed).
                if (S.Gd.Str(e.Get("fate", "burst")) != "spin")
                {
                    double y = e.Has("y") ? S.Num.F(e["y"]) : sim.air.Altitude();
                    Sfx.PlayAt("heli_crash", new Vector3((float)S.Num.F(e["x"]), (float)y, (float)S.Num.F(e["z"])));
                }
                break;
            case "explosion":
                Blast(S.Gd.Str(e.Get("kind", "")), Flat(S.Num.F(e["x"]), S.Num.F(e["z"])));
                break;
            case "airstrike_bomb":
                Blast("fuel_silo", Flat(S.Num.F(e["x"]), S.Num.F(e["z"])));
                break;
            case "firework_burst":
                Sfx.PlayAt("fireworks_crackle", Flat(S.Num.F(e["x"]), S.Num.F(e["z"])));
                break;
            case "toxic_cloud":
                Sfx.PlayAt("chem_hiss", Flat(S.Num.F(e["x"]), S.Num.F(e["z"])));
                break;
            case "hazard_armed":
                S.RampageSim.Building b = sim.buildings[(int)S.Num.I(e["building"])];
                Sfx.PlayAt("chem_hiss", new Vector3((float)b.x, b.height + 0.8f, (float)b.z));
                break;
            case "airstrike":
                Jets(e);
                break;
            case "train_derailed":
                Vector3 wreck = new Vector3((float)S.Num.F(e["x"]), (float)sim.rail.deckY, (float)S.Num.F(e["z"]));
                RailSound("train_screech", wreck);
                RailSound("train_crash", wreck);
                break;
            case "train_station":
                RailSound("station_bell", new Vector3((float)sim.rail.TrackX(1), (float)sim.rail.deckY, 0f));
                break;
        }
    }

    // A foot came down (rampage_footfall.gd): `stomped` is whether it was the foot a sim stomp waited for
    // (EventFx.Footfall's answer), `strength` the step's 0..1.
    public void Footfall(float strength, bool stomped)
    {
        if (!Ready()) return;
        if (stomped)
        {
            stompWait = 0f;
            double power = Power("stomp_damage");
            Stomp(power, power >= S.Num.F(S.Content.Section("fx")["crack_stomp_power"]));
        }
        Footstep(strength);
    }

    // rampage.gd power(): an upgraded stat over the species' own, 1 up to "power_max".
    double Power(string stat)
    {
        double own = baseStats.Has(stat) ? S.Num.F(baseStats[stat]) : 0.0;
        double max = S.Num.F(S.Content.Section("fx")["power_max"]);
        return Math.Max(1.0, Math.Min(max, sim.Stat(stat) / Math.Max(own, 0.001)));
    }

    // sfx.gd stomp(): heavier the stronger it is; heard when the foot lands (footstep) or "stomp_wait" on.
    void Stomp(double power, bool crack)
    {
        int tier = 0;
        S.GArray<S.Variant> edges = tune["stomp_tiers"];
        foreach (S.Variant edge in edges)
            if (power >= S.Num.F(edge)) tier++;
        pending = "stomp_" + Math.Min(tier, AudioTable.STOMPS - 1);
        pendingCrack = crack;
        pendingAge = 0f;
    }

    void Footstep(float strength)
    {
        if (pending != "")
        {
            ReleaseStomp();
            return;
        }
        if (sinceStep < S.Num.F(tune["footstep_min_interval"])) return;
        sinceStep = 0f;
        Sfx.Play(AudioTable.STEPS[step % AudioTable.STEPS.Length], S.Num.F(tune["footstep_quiet_db"]) * (1.0 - Mathf.Clamp01(strength)));
        step++;
    }

    void ReleaseStomp()
    {
        Sfx.Play(pending);
        if (pendingCrack && sinceCrack >= S.Num.F(tune["crack_min_interval"]))
        {
            sinceCrack = 0f;
            Sfx.Play("stomp_crack");
        }
        pending = "";
    }

    // sfx.gd _sound_landings: of the parts that landed this frame, the loudest few are heard.
    void SoundLandings()
    {
        if (landings.Count == 0) return;
        landings.Sort((a, b) => b.CompareTo(a));
        int most = Math.Min(landings.Count, (int)S.Num.I(tune["collapse_per_frame"]));
        for (int i = 0; i < most; i++)
        {
            bool drop = landings[i] < 0.0;
            if (drop) Sfx.Play("collapse", landings[i], 1.0, table.BusOf("collapse_drop"), "debris");
            else Sfx.Play("collapse", landings[i], COLLAPSE_PITCH);
        }
        landings.Clear();
    }

    // rampage_ability.gd play(): the breath, the leap (its landing LEAP_SECONDS on) or the lash.
    void Ability(string kind)
    {
        if (kind == "cone") Sfx.Play("breath");
        else if (kind == "leap")
        {
            Sfx.Play("leap_whoosh");
            later.Add((LEAP_SECONDS, () => Sfx.Play("leap_land")));
        }
        else Sfx.Play("lash");
    }

    // roar_cue.gd: a leap or the ultimate roars, at most once each "roar_cooldown" of the run's clock.
    void RoarCue()
    {
        if (roarAt - sim.timeLeft < S.Num.F(tune["roar_cooldown"])) return;
        roarAt = sim.timeLeft;
        Sfx.Roar();
    }

    // sfx_beam.gd charge(): the crackle swells under the charge-up, over the time to the strike.
    void BeamCharge(double seconds)
    {
        if (Sfx.Live) BeamFade(Math.Max(seconds, BEAM_FADE_IN));
    }

    void BeamFade(double seconds)
    {
        double level = table.VolumeDb(BEAM_LOOP);
        if (Sfx.Looping(BEAM_LOOP)) Sfx.LoopFade(BEAM_LOOP, level, seconds);  // already crackling: carries on
        else Sfx.Loop(BEAM_LOOP, level, seconds, true);
    }

    // rooftop_view.gd: a squad's volley cracks near the kaiju and pops far from it.
    void Squad(long id)
    {
        foreach (S.Army.Squad squad in sim.armyUnits.squads)
        {
            if (squad.id != id) continue;
            float roof = squad.building >= 0 && squad.building < sim.buildings.Size() ? sim.buildings[(int)squad.building].height : 0f;
            Sfx.PlayNear("rifle", new Vector3((float)squad.pos.x, roof, (float)squad.pos.y), Feet());
            return;
        }
    }

    // army_view.gd: the shot at the tank, then the shell "shell_flight" on: armour rings, flesh thuds, a miss
    // lands as its own event (stray_landed).
    void Tank(S.GDict e)
    {
        long id = S.Num.I(e["tank"]);
        foreach (S.RampageSim.Tank tank in sim.tanks)
        {
            if (tank.id != id) continue;
            Sfx.PlayAt("tank_fire", Flat(tank.pos.x, tank.pos.y));
            break;
        }
        if (e.Has("miss") && (bool)e["miss"]) return;
        later.Add(((float)S.Num.F(sim.army["shell_flight"]), () =>
        {
            if (sim.Stat("armor") > 0.0) Sfx.Play("deflect");
            else Sfx.PlayAt("shell_hit", Feet());
        }));
    }

    bool Heli(long id, out Vector3 at)
    {
        foreach (S.AirWing.Heli heli in sim.air.helis)
        {
            if (heli.id != id) continue;
            at = new Vector3((float)heli.pos.x, (float)sim.air.Altitude(), (float)heli.pos.y);
            return true;
        }
        at = Vector3.zero;
        return false;
    }

    // blast_fx.gd _sound: the crack at once and full, the body and rumble by distance, and from "boom_from"
    // away the boom arriving at the speed of sound.
    void Blast(string kind, Vector3 at)
    {
        double small = kind == "fuel_silo" ? 0.0 : S.Num.F(blast["small_db"]);
        double tail = small + S.Num.F(blast["tail_db"]);
        Sfx.Play("blast_crack", S.Num.F(blast["crack_db"]));
        Sfx.PlayAt("blast_body", at, tail);
        Sfx.PlayAt("blast_rumble", at, tail);
        double far = Vector3.Distance(earsAt, at);
        if (ears == null || far < S.Num.F(blast["boom_from"])) return;
        float wait = (float)Math.Min(S.Num.F(blast["boom_max_delay"]), far / S.Num.F(blast["speed"]));
        later.Add((wait, () => Sfx.PlayAt("sonic_boom", at)));
    }

    // The test blast RampageGame fires itself (-rampage-blast) is an "explosion" event too: forward it here.
    // airstrike_view.gd: the lead jet booms as it passes half way.
    void Jets(S.GDict e)
    {
        S.Vector2 from = e["from"];
        S.Vector2 to = e["to"];
        float half = (float)S.Num.F(e["seconds"]) * 0.5f;
        var mid = new Vector3((float)(from.x + to.x) * 0.5f, (float)S.Num.F(e["altitude"]), (float)(from.y + to.y) * 0.5f);
        later.Add((half, () => Sfx.PlayAt("sonic_boom", mid)));
    }

    // sfx.gd rotors(): one rotor loop, as loud as the nearest helicopter.
    void Rotors()
    {
        if (sim.air.helis.Size() == 0)
        {
            if (Sfx.Looping(ROTOR)) Sfx.Stop(ROTOR);
            return;
        }
        double near = double.NegativeInfinity;
        foreach (S.AirWing.Heli heli in sim.air.helis)
            near = Math.Max(near, Sfx.DistanceDb(new Vector3((float)heli.pos.x, (float)sim.air.Altitude(), (float)heli.pos.y)));
        double level = table.VolumeDb(ROTOR) + near;
        if (!Sfx.Looping(ROTOR)) Sfx.Loop(ROTOR, level, 0.0, true);
        Sfx.LoopLevel(ROTOR, level);
    }

    // power_cues.gd: the ready chime when the signature comes back, the bubbling while the kaiju heals.
    void PowerCues()
    {
        bool charged = sim.abilityReadyIn <= 0.0;
        if (charged && !wasReady) Sfx.Play("ready");
        wasReady = charged;
        bool now = sim.Stat("regen") > 0.0 && sim.hp < sim.maxHp;
        if (now && !healing && Sfx.Live)
        {
            regenAge = 0.0;
            regenDb = table.VolumeDb(REGEN);
            Sfx.Stop(REGEN);
            Sfx.Loop(REGEN, regenDb, 0.0, true);
        }
        else if (!now && Sfx.Looping(REGEN)) Sfx.Stop(REGEN);
        healing = now;
    }

    // sfx.gd _fade_regen: a cue that healing began, not a bed: "regen_seconds" of it, then a fade.
    void FadeRegen(float dt)
    {
        if (!Sfx.Looping(REGEN)) return;
        regenAge += dt;
        if (regenAge < S.Num.F(tune["regen_seconds"])) return;
        regenDb -= REGEN_FADE_DB_PER_S * dt;
        if (regenDb <= Sfx.SILENT_DB) Sfx.Stop(REGEN);
        else Sfx.LoopLevel(REGEN, regenDb);
    }

    // sfx_crowd.gd update(): the panic follows the people running and the city breaking, ducks under the
    // breath, and takes the city's trim (the crowd thins as the city dies).
    void Crowd(float dt)
    {
        StreetPeople people = game.People;
        if (people == null) return;
        double rate = (sim.chunksDestroyed - chunksBefore) / Math.Max(dt, 0.001);
        chunksBefore = sim.chunksDestroyed;
        chunkRate += (rate - chunkRate) * Math.Min(1.0, dt * 2.0);
        double intensity = AudioMix.CrowdIntensity(crowdCfg, people.Panicking(), chunkRate);
        bool ducked = host.SinceBreath < S.Num.F(crowdCfg["duck_seconds"]);
        double silent = S.Num.F(crowdCfg["silent_db"]);
        double goal = AudioMix.CrowdTarget(crowdCfg, table.VolumeDb(CROWD), intensity, ducked);
        goal = Math.Max(silent, goal + Math.Min(crowdTrim, 0.0));
        crowdDb = AudioMix.MoveToward(crowdDb, goal, S.Num.F(crowdCfg["fade_db_per_s"]) * dt);
        Bed(CROWD, crowdDb, silent);
    }

    // A bed plays while it can be heard (city_sound.gd _apply, sfx_crowd.gd).
    void Bed(string id, double db, double silent)
    {
        bool audible = db > silent + 1.0;
        if (audible && !Sfx.Looping(id)) Sfx.Loop(id, db, 0.0, true);
        else if (!audible && Sfx.Looping(id)) Sfx.Stop(id);
        if (audible) Sfx.LoopLevel(id, db);
    }

    // city_sound.gd advance(): sirens, gunfire, fire and wind come and go with how far the city has fallen,
    // and the music's stems fade in on the same phase.
    void City(float dt)
    {
        StreetPeople people = game.People;
        if (population <= 0.0 && people != null) population = people.Civilians();
        double phase = AudioMix.Phase((S.GDict)cityCfg["phase"], sim.Destruction(), people != null ? people.fled : 0, population);
        double rate = S.Num.F(cityCfg["fade_db_per_s"]) * dt;
        double silent = S.Num.F(cityCfg["silent_db"]);
        S.GDict rows = cityCfg["beds"];
        foreach (S.Variant k in rows.Keys())
        {
            string bed = S.Gd.Str(k);
            S.GDict row = rows[k];
            S.GArray<S.Variant> curve = row["curve"];
            double level = AudioMix.MoveToward(beds[bed], AudioMix.Along(curve, phase), rate);
            beds[bed] = level;
            if (bed == "crowd") crowdTrim = level;
            else Bed(bed, level, silent);
        }
        Music.Follow(phase, dt);
    }

    // rail_view.gd: the rumble of the nearest train, the scrape of a sliding wreck, and a horn at a kaiju on
    // the line. Godot's one-shots here are 3D players ("unit_size"); they fall off by distance the same way.
    void Rail(float dt)
    {
        if (sim.rail == null) return;
        clock += dt;
        double loudest = 0.0;
        bool sliding = false;
        foreach (S.Rail.Train train in sim.rail.trains)
        {
            foreach (S.Rail.Car car in train.cars) sliding |= car.vel.Length() > SLIDE_SPEED;
            if (train.state == S.Rail.WRECK || train.cars.Size() == 0) continue;
            S.Vector2 head = train.cars[0].pos;
            double d = head.DistanceTo(sim.kaijuPos);
            double near = Math.Max(0.0, Math.Min(1.0, 1.0 - d / S.Num.F(railLook["hear_range"])));
            loudest = Math.Max(loudest, near * train.v / S.Num.F(sim.rail.cfg["cruise"]));
            if (clock < (horned.TryGetValue(train.id, out float next) ? next : 0f) || d >= S.Num.F(railLook["horn_range"])) continue;
            horned[train.id] = clock + (float)S.Num.F(railLook["horn_every"]);
            RailSound("train_horn", new Vector3((float)head.x, (float)sim.rail.deckY, (float)head.y));
        }
        Bed(RUMBLE, AudioMix.Db(Math.Max(loudest, 0.0001)) + S.Num.F(railLook["rumble_db"]), Sfx.SILENT_DB);
        Bed(SLIDE, sliding ? S.Num.F(railLook["slide_db"]) : -80.0, Sfx.SILENT_DB);
    }

    void RailSound(string id, Vector3 at)
    {
        if (!Sfx.Live) return;
        double db = ears != null ? AudioMix.UnitDb(Vector3.Distance(earsAt, at), S.Num.F(railLook["unit_size"])) : 0.0;
        Sfx.Direct(id, db);
    }

    Vector3 Flat(double x, double z) => new Vector3((float)x, 0f, (float)z);

    Vector3 Feet() => new Vector3((float)sim.kaijuPos.x, (float)sim.standY, (float)sim.kaijuPos.y);

    void OnDestroy()
    {
        // The rampage is gone: its voices, loops and music stop, and the menus' sounds are open again.
        if (AudioHost.I != null) AudioHost.I.StopWorld();
        Music.Stop();
        Sfx.Listener(null);
        Sfx.Live = true;
    }
}
