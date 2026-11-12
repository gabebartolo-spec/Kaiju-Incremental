using System;
using System.Collections.Generic;

// The croc's growth-stage bodies, plain C# (unity/SimTests runs it). scenes/kaiju_model.gd: the stage of a size
// tier (stage_for, D-014) and the body drawn for it, the stage's own or else the first one up that has a rig.
// scenes/clip_lash.gd: a stage's keyed lash plays only when both sides are layer clips, its sweep only with both
// sweep sides as well; scenes/clip_takes.gd and rampage_rise.gd: the run and the rise only where keyed.
public static class CrocStages
{
    public static readonly string[] STAGES = { "baby", "adolescent", "adult" };
    const long BABY_TIER = 1, ADOLESCENT_TIER = 2;

    public static string StageFor(long sizeTier) =>
        sizeTier <= BABY_TIER ? "baby" : sizeTier == ADOLESCENT_TIER ? "adolescent" : "adult";

    // carries(stage): whether that stage's body files are there.
    public static string BodyStage(long sizeTier, Func<string, bool> carries)
    {
        for (int i = Array.IndexOf(STAGES, StageFor(sizeTier)); i < STAGES.Length; i++)
        {
            if (carries(STAGES[i])) return STAGES[i];
        }
        return STAGES[STAGES.Length - 1];
    }

    public static bool Lashes(ICollection<string> layers) => layers.Contains("lash_r") && layers.Contains("lash_l");

    public static bool Sweeps(ICollection<string> layers) =>
        Lashes(layers) && layers.Contains("sweep_r") && layers.Contains("sweep_l");
}
