// The kaiju body's fixed measures the bakes read, from data/tuning.json "kaiju_body" (hard rule 4; U6 moved them
// out of scenes/kaiju_model.gd and scenes/biped_swing.gd). Shared with unity/SimTests, which bakes the far
// beast's rig for its fixture.
using Kaiju.Sim;

static class BodyData
{
    // The model's height in floors at scale 1 (Godot's KaijuModel.MODEL_HEIGHT).
    public static double ModelHeight() => Num.F(Content.Section("kaiju_body")["model_height"]);

    // A relaxed arm bone's direction: "upper", "fore" or "hand" (Godot's BipedSwing.ARM_UPPER, ARM_FORE, ARM_HAND).
    public static Vector3 ArmRest(string part)
    {
        GDict arm = Content.Section("kaiju_body")["arm_rest"];
        GArray<Variant> v = arm[part];
        return new Vector3(Num.F(v[0]), Num.F(v[1]), Num.F(v[2]));
    }
}
