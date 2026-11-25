using System;
using System.Collections.Generic;
using UnityEngine;
using S = Kaiju.Sim;

// Capture only (-rampage-heli-deaths): tools/capture/capture_heli_deaths.gd's clip, ported. Two helicopters are
// parked over the street; the first is blown apart, then the second spins down burning onto a low block, its crew
// bailing out, to its crash. Run it without -rampage-auto (Godot's scripted run presses nothing), at stage 2 with
// -rampage-own r_ablaze (Godot's LEVELS). Godot counts frames at --fixed-fps 60, one physics frame each: here one
// Step is one physics step (RampageGame.TICK), so every count below is Godot's unchanged.
public sealed class HeliDeathsCapture
{
    // capture_heli_deaths.gd SETTLE: frames after the emerge before anything is staged.
    const int SETTLE = 120;
    // capture_heli_deaths.gd SPOT: where each helicopter is put, from the kaiju's feet, in body-scale units.
    const double SPOT_X = 6.0, SPOT_Z = -9.0;
    // capture_heli_deaths.gd LOW_BLOCK: the tallest building (metres) a wreck is dropped beside.
    const long LOW_BLOCK = 9;
    // capture_heli_deaths.gd _block_beside: the narrowest building taken, and how far off its camera-side face.
    const long MIN_WIDTH = 5;
    const double FACE_OFF = 1.0;
    // capture_heli_deaths.gd CLIP_LEAD, CLIP_GAP, CLIP_FRAMES: before the burst, burst to spin, the whole shot.
    const int CLIP_LEAD = 20, CLIP_GAP = 100, CLIP_FRAMES = 360;
    // capture_heli_deaths.gd PARK: frames the helicopters are parked before the shot.
    const int PARK = 45;
    // capture_heli_deaths.gd _run: the clock, so the run never ends in the shot.
    const double TIME_LEFT = 600.0;
    // capture_heli_deaths.gd _run: every crew bails out; the helicopters never strafe the kaiju.
    const double BAILOUT = 1.0, FIRE_INTERVAL = 999.0;
    // capture_heli_deaths.gd _clip_run: the first is blown apart (a whole burst_blow), the second spun down.
    const double BURST_SHARE = 1.0, SPIN_SHARE = 0.2;
    // capture_heli_deaths.gd _blow: the blow reaches only what is within this of the helicopter.
    const double HIT_REACH = 1.0;

    readonly S.RampageSim sim;
    readonly Action<S.GDict> handOver;
    readonly IEnumerator<bool> run;
    public bool Done { get; private set; }

    public HeliDeathsCapture(S.RampageSim simulation, Action<S.GDict> view)
    {
        sim = simulation;
        handOver = view;
        run = Run();
    }

    // The capture when the player was started with -rampage-heli-deaths, else null.
    public static HeliDeathsCapture From(string[] args, S.RampageSim simulation, Action<S.GDict> view) =>
        Array.IndexOf(args, "-rampage-heli-deaths") >= 0 ? new HeliDeathsCapture(simulation, view) : null;

    // One physics step; false once the shot is over.
    public bool Step()
    {
        if (!Done && !run.MoveNext()) Done = true;
        return !Done;
    }

    IEnumerator<bool> Run()
    {
        while (sim.emerge.active) yield return true;
        for (int i = 0; i < SETTLE; i++) yield return true;
        sim.timeLeft = TIME_LEFT;
        sim.air.cfg["bailout_chance"] = BAILOUT;
        sim.air.cfg["fire_interval"] = FIRE_INTERVAL;
        double scale = sim.BodyScale();
        S.Vector2 spot = sim.kaijuPos + new S.Vector2(SPOT_X, SPOT_Z) * scale;
        Debug.Log($"heli_deaths: body scale {scale:F2}");
        // Unlike Godot (CLIP_SPREAD round the kaiju from the first), the spinning one is parked over the block it
        // lands on: Unity's croc ends its emerge on open shore, 40-47 m from any low block, and a wreck moved there
        // when hit would jump that far (director, 2026-11-25: "Park it over the block").
        S.Vector2 block = BlockBeside(spot);
        S.Vector2[] toward = { spot, block };
        var both = new S.AirWing.Heli[toward.Length];
        sim.events.Clear();
        for (int n = 0; n < toward.Length; n++) both[n] = sim.air.Spawn();
        HandOver();
        for (int i = 0; i < PARK; i++)
        {
            for (int n = 0; n < both.Length; n++)
            {
                both[n].pos = toward[n];
                both[n].heading = (toward[n] - sim.kaijuPos).Angle();
            }
            yield return true;
        }
        Debug.Log($"heli_deaths: clip starts at frame {Time.frameCount} burst {both[0].pos.x:F2},{both[0].pos.y:F2} spin {both[1].pos.x:F2},{both[1].pos.y:F2} land {block.x:F2},{block.y:F2} altitude {S.Num.F(sim.air.Altitude()):F2}");
        for (int i = 0; i < CLIP_LEAD; i++) yield return true;
        Blow(both[0], BURST_SHARE, block);
        Debug.Log($"heli_deaths: burst at frame {Time.frameCount}");
        for (int i = 0; i < CLIP_GAP; i++) yield return true;
        Blow(both[1], SPIN_SHARE, block);
        Debug.Log($"heli_deaths: spin at frame {Time.frameCount}");
        for (int i = 0; i < CLIP_FRAMES - CLIP_LEAD - CLIP_GAP; i++) yield return true;
        Debug.Log($"heli_deaths: clip ends at frame {Time.frameCount}");
    }

    // capture_heli_deaths.gd _blow: downs `heli` alone with one blow of `share` x burst_blow; a spin falls
    // straight onto `land` (the sim's crash point and the view's wreck both), wherever it was hit.
    void Blow(S.AirWing.Heli heli, double share, S.Vector2 land)
    {
        double hp = S.Num.F(sim.air.cfg["burst_blow"]);
        S.Vector2 at = heli.pos;
        sim.events.Clear();
        sim.air.Hit(new S.Callable(a_ => ((S.Vector2)a_[0]).DistanceTo(at) < HIT_REACH ? 1.0 : 0.0), hp * share, true);
        foreach (S.AirWing.Falling down in sim.air.falling)
        {
            if (down.id != heli.id) continue;
            down.drift = S.Vector2.ZERO;
            down.pos = land;
        }
        foreach (S.GDict e in sim.events)
        {
            if (!e.Has("dx")) continue;
            e["dx"] = 0.0;
            e["dz"] = 0.0;
            e["x"] = land.x;
            e["z"] = land.y;
        }
        HandOver();
    }

    // capture_heli_deaths.gd _hand_over: events made outside a step go to the view as a step's would.
    void HandOver()
    {
        foreach (S.GDict e in sim.events) handOver(e);
    }

    // capture_heli_deaths.gd _block_beside: the camera-side face of the nearest low building, so the wreck's
    // crash smashes its floors where the camera sees them.
    S.Vector2 BlockBeside(S.Vector2 from)
    {
        S.Vector2 best = from;
        double gap = double.PositiveInfinity;
        foreach (S.RampageSim.Building b in sim.buildings)
        {
            if (b.height > LOW_BLOCK || b.w < MIN_WIDTH || b.frame.aliveCount == 0) continue;
            double d = new S.Vector2(b.x, b.z).DistanceTo(from);
            if (d >= gap) continue;
            // The game camera looks down +z, so the camera-side face is -z (director, 2026-11-25: "flip the
            // 'camera-side face' selection").
            var land = new S.Vector2(b.x, b.z - b.d * 0.5 - FACE_OFF);
            // Unlike Godot, a block whose landing point is inside another standing building is passed over: in a
            // packed block the wreck would crash out of sight (director, 2026-11-25: "Skip buried, take b381").
            if (Buried(land)) continue;
            gap = d;
            best = land;
        }
        Debug.Log($"heli_deaths: spot {from.x:F2},{from.y:F2} -> {best.x:F2},{best.y:F2} ({gap:F1} off)");
        return best;
    }

    // Whether `at` is inside the footprint of a building still standing.
    bool Buried(S.Vector2 at)
    {
        foreach (S.RampageSim.Building b in sim.buildings)
        {
            if (b.frame.aliveCount == 0) continue;
            if (Math.Abs(at.x - b.x) <= b.w * 0.5 && Math.Abs(at.y - b.z) <= b.d * 0.5) return true;
        }
        return false;
    }
}
