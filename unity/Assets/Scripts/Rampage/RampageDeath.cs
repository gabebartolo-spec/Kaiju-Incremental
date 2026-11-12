using UnityEngine;

// RampageGame's croc pose each frame, and his death (scenes/death_view.gd, DeathView): built the first frame he
// dies, it lights the overload, shatters him and kicks the camera with the death's own trauma amounts.
public sealed partial class RampageGame
{
    DeathView death;

    // The croc's pose this frame: his death (the stagger take holds the body), the keyed rise from the bay, a
    // leap, or the gait.
    void DriveCroc(Vector3 feet, float scale, float dt)
    {
        if (sim.death.Active())
        {
            death ??= new DeathView(sim, croc, fx, street, trees, Resources.Load<Shader>("Shaders/SliceLit"),
                SliceGame.ExposureUnit(tuning), FireTuning.Load().light_match_m, DeathKick);
            death.Step(dt);
            croc.DriveDeath(dt);
        }
        else if (KeyedRise())
            croc.DriveClip(feet, Facing(), scale, RISE_CLIP, (float)(sim.emerge.Progress() * sim.emerge.Total()) + accumulator);
        else if (sim.body.dash.On())
            leap.Pose(feet, Facing(), scale, dt);
        else
            croc.Drive(feet, Facing(), scale, dt);
    }

    // scenes/rampage.gd add_trauma: an amount at a place, faded by its distance from him.
    void DeathKick(float amount, Vector3 at) => shake.AddAmountAt(amount, at, Focus(Feet()), (float)sim.BodyScale());

    string DeathStats() => death == null ? "death_burst False" :
        $"death_burst {death.Burst} death_debris {death.Debris} death_shards {death.Shards} shards_landed {death.Landed} death_blast {death.Blasted}";
}
