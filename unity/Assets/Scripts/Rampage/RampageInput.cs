using System.Collections.Generic;
using UnityEngine;
using S = Kaiju.Sim;
using Kaiju.Game;

// RampageGame's input (scenes/run_input.gd) and the landmark slow motion (scenes/landmark_slowmo.gd, D-259): the
// presses read once a frame; the latches that keep a tap for a later step (while he rises, and on a frame no step
// runs on); and Time.timeScale, which a landmark's fall drops for a moment. Slowed, Unity's delta shrinks and the
// accumulator steps whole ticks on fewer frames, so the sim is the same run, only longer on the wall clock.
public sealed partial class RampageGame
{
    // scenes/run_input.gd: a tap made while he rises is kept for the first live tick; the held move as hold or toggle.
    HudLatch latch;
    readonly HudHeld heldButton = new HudHeld();
    readonly Dictionary<string, bool> taps = new Dictionary<string, bool>();
    // A tap on a frame the sim sat out, kept for its next step (landmark_slowmo.gd sit_out and merge).
    HudLatch waited;
    LandmarkSlowmo slowmo;
    // The speed this frame's delta was shrunk by: the one set last frame (landmark_slowmo.gd scale_then).
    double speedThen = 1.0;

    struct Presses
    {
        public Vector2 stick;
        public bool signature, held, ultimate, breath, dash, pause, restart, any;
    }

    Presses pressed;

    // INPUT SEAM: the only place the rampage reads its input. Hosted, the player's bindings and the pad (Inputs,
    // as scenes/run_input.gd reads its actions); alone, the fixed keys the captures and dry runs were made with.
    Presses ReadPresses()
    {
        var p = new Presses();
        if (Hosted)
        {
            Inputs.Poll();
            Vector2 m = Inputs.Move();
            p.stick = new Vector2(m.x, -m.y);
            p.signature = Inputs.Down("signature");
            // Not while paused: run_input.gd reads it in _physics_process, which a paused tree skips, and the
            // menu's confirm (Space / pad A) is the signature key, so a menu press must not flip the toggle latch.
            if (!Paused) p.held = heldButton.Read(Inputs.Held("signature"), p.signature, PlayerSettings.HoldToggle);
            p.breath = Inputs.Down("breath");
            p.ultimate = Inputs.Down("ultimate");
            p.dash = Inputs.Down("dash");
            p.pause = Inputs.Down("pause");
            p.any = Inputs.AnyDown();
            return p;
        }
        p.stick = new Vector2((Input.GetKey(KeyCode.D) ? 1 : 0) - (Input.GetKey(KeyCode.A) ? 1 : 0), (Input.GetKey(KeyCode.S) ? 1 : 0) - (Input.GetKey(KeyCode.W) ? 1 : 0));
        p.signature = Input.GetKeyDown(KeyCode.Space) || Input.GetMouseButtonDown(0);
        p.held = Input.GetKey(KeyCode.Space) || Input.GetMouseButton(0);
        p.breath = Input.GetKeyDown(KeyCode.Q);
        p.ultimate = Input.GetKeyDown(KeyCode.E);
        p.dash = Input.GetKeyDown(KeyCode.LeftShift);
        p.pause = Input.GetKeyDown(KeyCode.Escape);
        p.restart = Input.GetKeyDown(KeyCode.R);
        p.any = Input.anyKeyDown;
        return p;
    }

    void MakeLatches()
    {
        double window = S.Num.F(S.Content.Section("emerge")["input_latch_seconds"]);
        latch = new HudLatch(window);
        waited = new HudLatch(window);
        slowmo = new LandmarkSlowmo(S.Content.Section("slowmo"), SlowmoHeldOff);
    }

    // His death playing, the end beat up or the run over: time stays whole (landmark_slowmo.gd _suppressed).
    bool SlowmoHeldOff() => sim.over || sim.death.Active() || (hudView != null && hudView.BeatRunning);

    // A frame no sim step runs on keeps its taps for the next one that does, once (landmark_slowmo.gd sit_out and
    // merge): slowed, most frames step nothing, and a tap there must still reach the croc. Autoplay and the pause
    // menu press nothing.
    void WaitPresses(bool stopped, ref bool signature, ref bool ultimate, ref bool breathKey, ref bool dash, float dt)
    {
        if (auto || Paused) return;
        bool steps = !stopped && accumulator >= TICK;
        taps["signature"] = signature;
        taps["ultimate"] = ultimate;
        taps["breath"] = breathKey;
        taps["dash"] = dash;
        Dictionary<string, bool> now = waited.Through(!steps, taps, dt);
        if (!steps) return;
        signature = now["signature"];
        ultimate = now["ultimate"];
        breathKey = now["breath"];
        dash = now["dash"];
    }

    // After the frame's steps: the slowed clock moves on by the real time the frame stood for, and the next frame
    // runs at its speed. Behind the pause menu time is whole and the fall waits (landmark_slowmo.gd _physics_process).
    void StepSlowmo(float dt)
    {
        if (!Paused) slowmo.Advance(LandmarkSlowmo.Real(dt, speedThen));
        speedThen = Paused ? 1.0 : slowmo.Speed;
        Time.timeScale = (float)speedThen;
    }

    void StopSlowmo()
    {
        slowmo.Stop();
        speedThen = 1.0;
        Time.timeScale = 1f;
    }
}
