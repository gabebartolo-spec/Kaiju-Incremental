using UnityEngine;

// The walk on the sim's step clock (scenes/clip_steps.gd, KaijuModel.follow_steps from rampage_ability.gd): the
// walk clip's frame is the clock's, its first footfall at step 0 and half a cycle a step, so its feet land where the
// sim steps. The keyed run blends in only from the sim's momentum (Momentum.Blend, clip_takes.gd walk_pose), on the
// same clock over its first RUN_LOOP frames. A body that does not step (clock INF) walks by distance, with no run.
// After the keyed rise he walks only once the clock has started (clip_choice.gd _sets_off: the rise's drift keeps
// it at 0).
public sealed partial class Croc
{
    const int RUN_LOOP = 95;  // clip_takes.gd: frame 95 of the run take matches frame 0; it runs on to 129
    const double HALF_CYCLE = 0.5;
    double stepPhase = double.PositiveInfinity;
    float runBlend;
    float walkLand = -1f, runLand = -1f;

    // Each frame, before Drive: the sim's step clock (BodyContact.StepClock) and momentum blend (0..1).
    public void FollowSteps(double phase, float blend)
    {
        stepPhase = phase;
        runBlend = blend;
    }

    bool OnSteps => !double.IsInfinity(stepPhase);

    // clip_choice.gd _sets_off: whether the step clock lets him walk.
    bool SetOff => !OnSteps || stepPhase > 0.0;

    float RunTake => hasRun && OnSteps ? Mathf.SmoothStep(0f, 1f, runBlend) : 0f;

    // The walk, run and idle clocks for this frame (dist: world units walked).
    void Clocks(float dist, float dt, Clip walk, Clip run)
    {
        idleFrame += dt * fps;
        if (!OnSteps)
        {
            walkFrame += dist / Stride * walk.frames / walk.cycles;
            runFrame += dist / Stride * run.frames / run.cycles;
            return;
        }
        walkFrame = StepFrame(walk, walk.frames, ref walkLand);
        runFrame = StepFrame(run, Mathf.Min(RUN_LOOP, run.frames), ref runLand);
    }

    // ClipSteps.frame_at: the frame `frames` of clip c loop over at the step clock.
    float StepFrame(Clip c, int frames, ref float land)
    {
        if (land < 0f) land = FirstLanding(c, frames);
        double at = (land + stepPhase * (frames / (double)c.cycles * HALF_CYCLE)) % frames;
        return (float)(at < 0.0 ? at + frames : at);
    }

    // ClipSteps._first_landing: the first frame a foot comes down, round the loop.
    float FirstLanding(Clip c, int frames)
    {
        for (int f = 0; f < frames; f++)
            if ((Planted(c, f) & ~Planted(c, (f + frames - 1) % frames)) != 0) return f;
        return 0f;
    }
}
