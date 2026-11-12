using System;
using S = Kaiju.Sim;

// Where one fan of the stadium's crowd is drawn this frame: scenes/crowd.gdshader's vertex maths, worked out per
// fan instead of per vertex (D-474). Seated fans bob on their own beat; once the match panics every fan is up and,
// after its own delay, runs straight out from the middle and up the stands, facing out, to the back, where it steps
// down out of sight; a fan that dies falls from where it is to its landing height, goes over, lies there a while
// and shrinks away under the dust. The beat and the delay are the ones StadiumCrowd places and counts them with.
// No UnityEngine here: unity/SimTests compiles this file (StadiumCheck). Presentation only.
public struct CrowdPose
{
    const double HOP = 0.06, HOP_HZ = 9.0, LIFT = 0.15;

    public bool hidden;
    public S.Vector3 off;  // from its seat, in the world's (Godot's) axes
    public bool turned;  // facing out, the way it runs
    public double tilt;  // radians it has gone over, about its own x (on its back or its face by the sign)
    public double lift;  // raised this much in its own frame as it goes over
    public double scale;

    // `time` is the bob's clock (any running clock).
    public static CrowdPose Of(StadiumCrowd crowd, StadiumCrowd.Fan fan, double time)
    {
        var pose = new CrowdPose { scale = 1.0, hidden = fan.state == StadiumCrowd.State.GONE };
        if (pose.hidden) return pose;
        bool dying = fan.state == StadiumCrowd.State.DYING;
        double h = fan.Beat();
        double ft = dying ? fan.frozen : (crowd.fleeing ? crowd.since : -1.0);
        if (ft >= 0.0) pose.Run(crowd, fan, ft, h);
        else if (!dying)
        {
            S.GArray<S.Variant> hz = crowd.cfg["bob_hz"];
            double beat = S.Num.F(hz[0]) + (S.Num.F(hz[1]) - S.Num.F(hz[0])) * h;
            pose.off = new S.Vector3(0, S.Num.F(crowd.cfg["bob"]) * Math.Max(0.0, Math.Sin((time * beat + h) * S.Gd.TAU)), 0);
        }
        if (dying && !pose.hidden) pose.Fall(crowd, fan, h);
        return pose;
    }

    void Run(StadiumCrowd crowd, StadiumCrowd.Fan fan, double ft, double h)
    {
        S.GDict cfg = crowd.cfg;
        double t = Math.Max(0.0, ft - h * S.Num.F(cfg["flee_delay"]));
        S.Vector2 dir = (new S.Vector2(fan.pos.x, fan.pos.z) - crowd.centre).Normalized();
        double moved = S.Num.F(cfg["flee_speed"]) * t;
        double along = Math.Min(moved, fan.run);
        double down = Math.Max(0.0, moved - fan.run);
        if (down > S.Num.F(cfg["sink"]))
        {
            hidden = true;
            return;
        }
        turned = t > 0.0;
        double hop = HOP * Math.Abs(Math.Sin((ft * HOP_HZ + h) * Math.PI));  // a panicked hop
        off = new S.Vector3(dir.x * along, hop + along * S.Num.F(cfg["flee_slope"]) - down, dir.y * along);
    }

    void Fall(StadiumCrowd crowd, StadiumCrowd.Fan fan, double h)
    {
        double dt = Math.Max(0.0, crowd.clock - fan.fellAt);
        double air = Math.Max(0.0, fan.pos.y + off.y - fan.land);
        double lie = Math.Sqrt(2.0 * air / crowd.gravity) + StadiumCrowd.TOPPLE;
        double a = S.Gd.Clampf(dt / lie, 0.0, 1.0) * Math.PI * 0.5;  // goes over as it falls, flat on landing
        tilt = h < 0.5 ? a : -a;  // on its back or on its face
        lift = LIFT * Math.Sin(a);
        scale = 1.0 - S.Gd.Clampf((dt - lie - fan.stay) / crowd.shrink, 0.0, 1.0);  // gone under the dust
        off = new S.Vector3(off.x, off.y - Math.Min(0.5 * crowd.gravity * dt * dt, air), off.z);
    }
}
