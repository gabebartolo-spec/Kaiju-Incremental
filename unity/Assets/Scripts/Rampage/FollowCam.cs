using System.Collections.Generic;
using UnityEngine;
using S = Kaiju.Sim;

// The gameplay camera's follow, scenes/camera_follow.gd and scenes/damped.gd in Godot axes (the owner
// negates z when it places the camera): the aim keeps up with the body at once along the view and is
// critically damped across it; the offset sits behind the body's facing and eases as heavily as its
// turn; once the body has moved for lead_hold it slides toward where it is going. The player swings it up to
// swing_deg and it eases back behind him (D-259). Aim tilts the look up when the drawn body would ride into the
// frame's top margin (scenes/head_frame.gd; the body is the croc's bone spheres, not its voxel boxes).
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
    public float Yaw => yaw + swing;
    public float Tilt => tilt;
    readonly Vector3 rest;
    readonly float zoomBase, zoomPer, leadBase, leadPer, leadHold, leadEase, leadToward, leadMoving, leadDepth, followS, followAccel, turnFollow, swingDeg, swingReturn, swingMouse, safeTop, headRise, headSettle;
    readonly Damped chase = new Damped(), leadChase = new Damped(), headChase = new Damped();
    Vector3 focus, offset, lead, last;
    float yaw, swing, tilt, movingFor, framedScale = 1f;
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
        swingDeg = F(c, "swing_deg");
        swingReturn = F(c, "swing_return");
        swingMouse = F(c, "swing_mouse_deg_per_px");
        safeTop = F(c, "safe_top");
        headRise = F(c, "head_rise_s");
        headSettle = F(c, "head_settle_s");
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

    public void Step(Vector3 target, Vector2 facing, Vector3 bodyAt, float scale, bool hold, float dip, float swingTurn, float dt)
    {
        float zoom = zoomBase + zoomPer * scale;
        Vector3 wanted = rest * zoom - new Vector3(0, dip * zoom, 0);
        Vector3 turned = Rotated(offset, yaw + swing);
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
        float limit = swingDeg * Mathf.Deg2Rad;
        if (swingTurn != 0f) swing = Mathf.Clamp(swing + swingTurn, -limit, limit);
        else swing -= swing * Mathf.Min(1f, dt * swingReturn);

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
                Vector3 dir = Rotated(v.normalized, -yaw - swing);
                float toward = 1f + (leadToward - 1f) * Mathf.Max(0f, dir.z);
                aim = dir * (leadBase + leadPer * scale) * toward;
                aim.z *= leadDepth;
                aim = Rotated(aim, yaw + swing);
            }
        }
        last = bodyAt;
        hasLast = true;
        leadChase.value = lead;
        lead = leadChase.Step(aim, 1f / leadEase, 0f, dt);
    }

    public Vector3 Eye() => focus + Rotated(offset, yaw + swing) + lead;
    public Vector3 LookAt(float scale) => focus + lead + new Vector3(0, LOOK_UP * scale, 0);

    // The player's swing this frame (radians): a mouse drag with any button held. The stick joins with the gamepad.
    public float PlayerTurn()
    {
        if (!Input.GetMouseButton(0) && !Input.GetMouseButton(1) && !Input.GetMouseButton(2)) return 0f;
        return -Input.mousePositionDelta.x * swingMouse * Mathf.Deg2Rad;
    }

    // scenes/head_frame.gd aim: where to look so the highest drawn point sits safe_top below the frame's top.
    // `body` holds xyz centre, w radius; `nod` is the shake's pitch this frame.
    public Vector3 Aim(Vector3 eye, Vector3 look, float fovDeg, float nod, List<Vector4> body, float dt)
    {
        Vector3 forward = (look - eye).normalized;
        Vector3 right = Vector3.Cross(forward, Vector3.up).normalized;
        Vector3 up = Vector3.Cross(right, forward);
        float room = Mathf.Atan((1f - 2f * safeTop) * Mathf.Tan(fovDeg * Mathf.Deg2Rad * 0.5f));
        float need = 0f;
        foreach (Vector4 s in body)
        {
            Vector3 d = new Vector3(s.x, s.y, s.z) + up * s.w - eye;
            float ahead = Vector3.Dot(d, forward);
            if (ahead > 0f) need = Mathf.Max(need, Mathf.Atan2(Vector3.Dot(d, up), ahead) - room - nod);
        }
        tilt = headChase.Step(new Vector3(need, 0, 0), need > tilt ? headRise : headSettle, 0f, dt).x;
        return eye + (forward * Mathf.Cos(tilt) + up * Mathf.Sin(tilt)) * Vector3.Distance(eye, look);
    }
}
