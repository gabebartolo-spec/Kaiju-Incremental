using UnityEngine;
using S = Kaiju.Sim;

// The gameplay camera's follow, scenes/camera_follow.gd and scenes/damped.gd in Godot axes (the owner
// negates z when it places the camera): the aim keeps up with the body at once along the view and is
// critically damped across it; the offset sits behind the body's facing and eases as heavily as its
// turn; once the body has moved for lead_hold it slides toward where it is going.
public sealed class FollowCam
{
    const float OFFSET_FOLLOW = 5f;
    const float LOOK_UP = 3.5f;

    sealed class Damped
    {
        public Vector3 value, velocity;

        public Vector3 Step(Vector3 target, float smooth, float maxAccel, float dt)
        {
            if (dt <= 0f) return value;
            float omega = 2f / Mathf.Max(smooth, 0.0001f);
            float x = omega * dt;
            float decay = 1f / (1f + x + 0.48f * x * x + 0.235f * x * x * x);
            Vector3 change = value - target;
            Vector3 temp = (velocity + change * omega) * dt;
            Vector3 next = (velocity - temp * omega) * decay;
            Vector3 nextValue = target + (change + temp) * decay;
            if (maxAccel > 0f)
            {
                Vector3 capped = velocity + Vector3.ClampMagnitude(next - velocity, maxAccel * dt);
                if ((capped - next).sqrMagnitude > 1e-10f) nextValue = value + (velocity + capped) * 0.5f * dt;
                next = capped;
            }
            value = nextValue;
            velocity = next;
            return value;
        }
    }

    public readonly float fov;
    public float Yaw => yaw;
    readonly Vector3 rest;
    readonly float zoomBase, zoomPer, leadBase, leadPer, leadHold, leadEase, leadToward, leadMoving, leadDepth, followS, followAccel, turnFollow;
    readonly Damped chase = new Damped(), leadChase = new Damped();
    Vector3 focus, offset, lead, last;
    float yaw, movingFor, framedScale = 1f;
    bool yawSet, hasLast;

    static float F(S.GDict c, string key) => (float)S.Num.F(c[key]);

    public FollowCam(Vector3 start, float scale)
    {
        S.GDict c = S.Content.Section("camera");
        var off = (S.GArray<S.Variant>)c["offset"];
        rest = new Vector3((float)S.Num.F(off[0]), (float)S.Num.F(off[1]), (float)S.Num.F(off[2]));
        fov = F(c, "fov");
        zoomBase = F(c, "zoom_base");
        zoomPer = F(c, "zoom_per_scale");
        leadBase = F(c, "lead_base");
        leadPer = F(c, "lead_per_scale");
        leadHold = F(c, "lead_hold");
        leadEase = F(c, "lead_ease");
        leadToward = F(c, "lead_toward_camera");
        leadMoving = F(c, "lead_moving");
        leadDepth = F(c, "lead_depth_share");
        followS = F(c, "follow_s");
        followAccel = F(c, "follow_accel");
        turnFollow = F(c, "turn_follow");
        focus = start;
        chase.value = start;
        offset = rest * (zoomBase + zoomPer * scale);
        framedScale = scale;
    }

    static Vector3 Rotated(Vector3 v, float a)
    {
        float s = Mathf.Sin(a), c = Mathf.Cos(a);
        return new Vector3(v.x * c + v.z * s, v.y, -v.x * s + v.z * c);
    }

    public void Step(Vector3 target, Vector2 facing, Vector3 bodyAt, float scale, bool hold, float dt)
    {
        Vector3 wanted = rest * (zoomBase + zoomPer * scale);
        Vector3 turned = Rotated(offset, yaw);
        Vector3 view = new Vector3(turned.x, 0, turned.z).normalized;
        focus += view * Vector3.Dot(target - focus, view);
        chase.value = focus;
        chase.velocity -= view * Vector3.Dot(chase.velocity, view);
        focus = chase.Step(target, followS, followAccel * framedScale, dt);
        offset = Vector3.Lerp(offset, wanted, Mathf.Min(1f, dt * OFFSET_FOLLOW));

        if (facing.sqrMagnitude >= 1e-6f)
        {
            float want = Mathf.Atan2(-facing.x, -facing.y);
            float gap = Mathf.DeltaAngle(yaw * Mathf.Rad2Deg, want * Mathf.Rad2Deg) * Mathf.Deg2Rad;
            yaw = yawSet ? yaw + gap * Mathf.Min(1f, dt * turnFollow) : want;
            yawSet = true;
        }

        framedScale = scale;
        Vector3 aim = Vector3.zero;
        if (hasLast && dt > 0f)
        {
            Vector3 v = (bodyAt - last) / dt;
            v.y = 0;
            bool moving = v.magnitude > leadMoving * scale;
            movingFor = moving ? movingFor + dt : 0f;
            if (hold) aim = lead;
            else if (movingFor >= leadHold)
            {
                Vector3 dir = Rotated(v.normalized, -yaw);
                float toward = 1f + (leadToward - 1f) * Mathf.Max(0f, dir.z);
                aim = dir * (leadBase + leadPer * scale) * toward;
                aim.z *= leadDepth;
                aim = Rotated(aim, yaw);
            }
        }
        last = bodyAt;
        hasLast = true;
        leadChase.value = lead;
        lead = leadChase.Step(aim, 1f / leadEase, 0f, dt);
    }

    public Vector3 Eye() => focus + Rotated(offset, yaw) + lead;
    public Vector3 LookAt(float scale) => focus + lead + new Vector3(0, LOOK_UP * scale, 0);
}
