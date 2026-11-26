using UnityEngine;

// The clip the legs play (scenes/clip_choice.gd pick, scenes/gait_clip.gd _choose and _go): idle while he stands;
// once he moves, from standing the keyed walk start (clip_takes.gd: from its first lift, WALK_START_FROM, for
// WALK_START_SECONDS, back to the idle if he stops), then the walk; stopping, the idle again. Each change
// cross-fades over BLEND_SECONDS from the old clip's pose where it was. He moves once his smoothed speed
// (kaiju_gait.gd track) reaches STAND_SPEED hip heights a second (and, after the rise, once the sim's step clock
// has started: CrocSteps SetOff). Held takes (stomps, slam stop), the roar and the lash lay on over this pose.
public sealed partial class Croc
{
    const float STAND_SPEED = 0.12f;  // gait_biped.gd: hip heights a second
    const float VELOCITY_SMOOTHING = 8f;  // kaiju_gait.gd: 1/s
    const float BLEND_SECONDS = 0.25f;  // gait_clip.gd
    const float WALK_START_SECONDS = 1.3f, WALK_START_FROM = 14f;  // clip_takes.gd
    const string WALK_START_CLIP = "walk_start";
    static readonly string[] HIP_BONES = { "leg_l0", "leg_r0" };

    enum Gait { Idle, WalkStart, Walk }

    Gait gait = Gait.Idle, gaitFrom = Gait.Idle;
    float walkStartFrame, gaitFromTime, gaitBlend = 1f;
    Vector3 smoothVelocity;
    float hipHeight = -1f;

    // The walk's share of the base pose: 0 standing, 1 walking, between in a cross-fade.
    float WalkShare => Mathf.Lerp(gaitFrom == Gait.Idle ? 0f : 1f, gait == Gait.Idle ? 0f : 1f, Mathf.SmoothStep(0f, 1f, gaitBlend));

    // gait_biped.gd hip_height: the legs' mean hip height in the rest pose (each leg's first bone's head), rig units.
    float HipHeight()
    {
        float hips = 0f;
        int legs = 0;
        foreach (string leg in HIP_BONES)
        {
            int b = System.Array.IndexOf(names, leg);
            if (b < 0) continue;
            hips += bind[b].inverse.GetColumn(3).y;
            legs++;
        }
        return hips / Mathf.Max(1, legs);
    }

    // kaiju_gait.gd track and clip_choice.gd pick: whether he moves (Velocity: this frame's, world units a second).
    bool Moving(float dt)
    {
        smoothVelocity = Vector3.Lerp(smoothVelocity, Velocity, Mathf.Min(1f, dt * VELOCITY_SMOOTHING));
        if (hipHeight < 0f) hipHeight = HipHeight();
        return SetOff && smoothVelocity.magnitude >= STAND_SPEED * hipHeight * Scale;
    }

    // clip_choice.gd pick for the idle, the walk start and the walk, then gait_clip.gd _choose's clocks.
    void Choose(float dt)
    {
        bool moving = Moving(dt);
        clips.TryGetValue(WALK_START_CLIP, out Clip start);
        if (gait == Gait.WalkStart && !moving) Go(Gait.Idle);
        else if (gait == Gait.WalkStart && walkStartFrame >= Mathf.Min(WALK_START_SECONDS * fps, start.frames - 1f)) Go(Gait.Walk);
        else if (gait == Gait.Idle && moving) Go(start != null ? Gait.WalkStart : Gait.Walk);
        else if (gait == Gait.Walk && !moving) Go(Gait.Idle);
        if (gait == Gait.WalkStart) walkStartFrame += dt * fps;
        gaitBlend = Mathf.Min(1f, gaitBlend + dt / BLEND_SECONDS);
    }

    // gait_clip.gd _go: the old clip's pose where it was fades out under the new one, which starts at its own frame
    // (the idle at 0, the walk start at its first lift, the walk at the step clock's frame).
    void Go(Gait next)
    {
        gaitFromTime = GaitFrame(gait);
        gaitFrom = gait;
        gaitBlend = 0f;
        gait = next;
        if (next == Gait.Idle) idleFrame = 0f;
        if (next == Gait.WalkStart) walkStartFrame = WALK_START_FROM;
    }

    float GaitFrame(Gait g) => g == Gait.Idle ? idleFrame : g == Gait.WalkStart ? walkStartFrame : walkFrame;

    Clip GaitClip(Gait g) => clips[g == Gait.Idle ? "idle" : g == Gait.WalkStart ? WALK_START_CLIP : "walk"];

    // The base pose into turnsOut and its feet down (gait_clip.gd update: the state's pose, the walk blended
    // toward the run (clip_takes.gd walk_pose), mixed from the old state's in a cross-fade, where the new clip's
    // lifted foot lifts at once).
    int BasePose(Clip run, out Vector3 offset)
    {
        Clip clip = GaitClip(gait);
        float at = GaitFrame(gait);
        ClipPose(clip, at, turnsOut, out offset);
        int planted = Planted(clip, at);
        if (gait == Gait.Walk && runWeight > 0f)
        {
            ClipPose(run, runFrame, turnsC, out Vector3 runOffset);
            for (int i = 0; i < turnsOut.Length; i++) turnsOut[i] = Quaternion.Slerp(turnsOut[i], turnsC[i], runWeight);
            offset = Vector3.Lerp(offset, runOffset, runWeight);
            planted = Mix(planted, Planted(run, runFrame), runWeight);
        }
        return gaitBlend < 1f ? FadeFrom(offset, planted, out offset) : planted;
    }

    int FadeFrom(Vector3 to, int planted, out Vector3 offset)
    {
        Clip from = GaitClip(gaitFrom);
        ClipPose(from, gaitFromTime, turnsB, out Vector3 fromOffset);
        float w = Mathf.SmoothStep(0f, 1f, gaitBlend);
        for (int i = 0; i < turnsOut.Length; i++) turnsOut[i] = Quaternion.Slerp(turnsB[i], turnsOut[i], w);
        offset = Vector3.Lerp(fromOffset, to, w);
        return Mix(Planted(from, gaitFromTime), planted, w) & planted;
    }

    // Off the gait (the keyed rise, the leap): gait_clip.gd plays those as states of their own. Out of the rise he
    // stands (its roar, then the walk start once he sets off); out of the leap, clip_choice.gd _moving goes straight
    // to the walk.
    void LeaveGait(Gait after)
    {
        gait = gaitFrom = after;
        gaitBlend = 1f;
    }
}
