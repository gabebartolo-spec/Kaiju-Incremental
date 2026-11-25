using System;
using Kaiju.Game;
using UnityEngine;
using S = Kaiju.Sim;

// scenes/ability_fx.gd stomp_cracks on screen: heavy stomps crack the street and the cracks glow molten, brighter the
// heavier the stomp (GameLogic/StompCrack.cs decides when and how bright). A stomp cracks under the foot that delivers
// it (rampage_footfall.gd land_stomp); a leap's landing cracks as heavy as its blow is to a stomp (leap_view.gd). A
// DISC mark (ScorchMarks) that lands at once and cools over fx "crack_seconds"; Godot axes. Presentation only.
public sealed class StompCracks : IDisposable
{
    // scenes/ability_fx.gd: MOLTEN, and stomp_cracks' soot. Godot hands a Decal's modulate to the shader as it is,
    // not converted to linear, so the tint goes in unconverted too: the hot core reads peach-white, as in Godot.
    static readonly Color MOLTEN = new Color32(0xff, 0x7a, 0x2a, 0xff);
    const float SOOT = 0.5f;

    readonly S.RampageSim sim;
    readonly ScorchMarks marks;
    readonly double own;
    readonly float seconds;

    // own: the species' own stomp_damage (rampage.gd _power's base).
    public StompCracks(S.RampageSim sim, double own)
    {
        this.sim = sim;
        this.own = own;
        seconds = (float)S.Num.F(S.Content.Section("fx")["crack_seconds"]);
        marks = new ScorchMarks(Resources.Load<Shader>("Shaders/Scorch"));
    }

    // Cracks made so far this run, and how many still show (captures).
    public int Made { get; private set; }
    public int Live => marks.Live;

    // rampage_footfall.gd land_stomp: the waiting stomp lands under the foot at `at`, with the stomp's radius.
    public bool Stomp(Vector3 at, float radius) => Crack(at, radius, StompCrack.Power(sim.Stat("stomp_damage"), own));

    // leap_view.gd "leap_land": the landing's blow (the event's damage) as heavy as it is to a stomp.
    public bool Leap(Vector3 at, float radius, float damage) => Crack(at, radius, StompCrack.Power(damage, own));

    bool Crack(Vector3 at, float radius, double power)
    {
        if (!StompCrack.Cracks(power, out double glow)) return false;
        marks.Disc(at, radius * (float)StompCrack.SIZE, StompCrack.CRACKS, seconds, (float)glow, SOOT, MOLTEN);
        Made++;
        return true;
    }

    public void Step(float dt) => marks.Step(dt);

    public void Dispose() => marks.Dispose();
}
