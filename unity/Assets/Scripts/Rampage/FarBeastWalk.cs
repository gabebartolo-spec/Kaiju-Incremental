using System;
using System.Collections.Generic;
using S = Kaiju.Sim;

// The far beast's body as FarBeast walks it (scenes/far_beast.gd walk, kaiju_model.gd animate): a KaijuModel in a
// little world of its own at 1/size scale, its path mirrored in, so its legs plant because it really walks. Its
// footfalls come out at the feet in the skyline. UnityEngine-free (SimTests drive it); FarBeast films it.
public sealed class FarBeastWalk
{
    public readonly FarBeastRig rig;
    public readonly FarBeastGait gait;
    // How tall it stands in the skyline (world units), and the model's own height (KaijuModel.MODEL_HEIGHT).
    public readonly double height, modelHeight;
    public int Footfalls { get; private set; }

    // A foot came down (FarBeast.foot_planted): which, how hard, where in the skyline (Godot axes).
    public event Action<string, double, BV> FootPlanted;

    // `rigJson` far_beast.rig.json (tools/unity/slicebake BeastBake), `height` tuning skyline_rampage height.
    public FarBeastWalk(string rigJson, double height)
    {
        this.height = height;
        S.GDict spec = S.JSON.ParseString(rigJson);
        modelHeight = S.Num.F(spec["model_height"]);
        rig = new FarBeastRig(Bones(spec["bones"]));
        gait = new FarBeastGait(rig);
        rig.FootPlanted += (id, strength, at) =>
        {
            Footfalls++;
            FootPlanted?.Invoke(id, strength, at * Size);
        };
    }

    // The little world's scale: one of its units is this many in the skyline.
    public double Size => height / modelHeight;

    static List<FarBeastRig.Bone> Bones(S.GArray<S.Variant> rows)
    {
        var bones = new List<FarBeastRig.Bone>();
        foreach (S.Variant row in rows)
        {
            S.GDict d = row;
            bones.Add(new FarBeastRig.Bone
            {
                name = S.Gd.Str(d["name"]),
                parent = S.Gd.Str(d["parent"]),
                physics = d["physics"],
                head = Numbers(d["head"]),
                dir = Numbers(d["dir"]),
                rest = Numbers(d["rest"]),
                bind = Numbers(d["bind"]),
            });
        }
        return bones;
    }

    static double[] Numbers(S.GArray<S.Variant> list)
    {
        var f = new double[list.Size()];
        for (int i = 0; i < f.Length; i++) f[i] = S.Num.F(list[i]);
        return f;
    }

    // One frame: `at` its feet in the skyline, `yaw` its facing (rotation.y). The model stands at 1/size of it.
    public void Walk(double delta, BV at, double yaw)
    {
        rig.Frame = new BT(BB.Axis(BV.UP, yaw), new BV(at.x, 0.0, at.z) / Size);
        gait.Update(delta);
    }

    // SkylineRampage._walk's facing: side-on while it walks the skyline, turning to face the bay as it slows.
    public static double Yaw(double velocity, double speed)
    {
        const double TURN_SHARE = 0.35;  // below this share of full speed the beast turns to face the bay
        return Math.PI + Math.PI * 0.5 * BMath.Clamp(velocity / (TURN_SHARE * speed), -1.0, 1.0);
    }

    // A heavy stomp, as a tower goes down.
    public void Stomp() => gait.Stomp();
}
