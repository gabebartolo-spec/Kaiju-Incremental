using System;
using System.Collections.Generic;
using S = Kaiju.Sim;

// The far beast's walk: scenes/gait_hexapod.gd (HexapodGait) on top of what it uses of kaiju_gait.gd (KaijuGait),
// line for line. The insectoid never walks, it skitters: hard holds while the model moves on, then darts that snap
// the body to where it is, the legs scrambling in diagonal pairs; a turn is led by the legs. The legs and the body
// are here; the feet in FarBeastGait.Legs.cs; the upper body (head, scythes, twitches) in FarBeastUpper. Godot axes,
// little-world units. Presentation only.
public sealed partial class FarBeastGait
{
    // kaiju_gait.gd
    const double BODY_TURN_MAX = 7.0, VELOCITY_SMOOTHING = 8.0, TURN_SMOOTHING = 10.0, SPRING_MARGIN = 0.9;
    const double MIN_DT = 0.0001, MIN_SCALE = 0.01;
    // gait_hexapod.gd
    static readonly string[] LEGS = { "leg_l", "leg_r", "hind_l", "hind_r" };
    static readonly Dictionary<string, int> PAIR = new Dictionary<string, int> { { "leg_l", 0 }, { "hind_r", 0 }, { "leg_r", 1 }, { "hind_l", 1 } };
    const double HOLD_MIN = 0.15, HOLD_MAX = 0.3, LONG_HOLD_MIN = 0.3, LONG_HOLD_MAX = 0.5, LONG_HOLD_CHANCE = 0.3;
    const double DART_RATE = 2.4, DART_MIN = 0.06, MAX_LAG = 2.2, FACING = 0.1, LEG_LEAD = 0.05, BIG_TURN = 0.06;
    const double TURN_RATE = 9.5, STAND_SPEED = 0.1, STEP_AT = 0.2, SETTLE_AT = 0.1, SWING_DART = 0.075;
    const double SWING_SETTLE = 0.11, LIFT = 0.5, REACH_STEP = 0.97, TAP_SWING = 0.09, TAP_SHIFT = 0.12;
    const double KNEE_SNAP = 9.0, KNEE_FLICK = 1.6, STEP_WEIGHT = 0.18, HOME_IN = 0.85, LAND_REACH = 0.9;
    const double PULSE_HZ = 2.2, PULSE = 0.05, DART_PITCH = 0.12, PERCH_CROUCH = 0.25, PERCH_PITCH = 0.25;
    const int STRIKE_EVERY = 3;
    // The literals of the GDScript bodies, named.
    const double MAX_DT = 1.0 / 20.0, CALM_LAG = 0.05, CAUGHT_UP = 0.01, DART_FLOOR = 4.0, JOLT_DECAY = 8.0;
    const double PERCH_RATE = 6.0, JOLT_DROP = 0.06, DART_SPAN = 0.3, THORAX_REAR = 0.6, THORAX_JOLT = 0.05;
    const double ABDOMEN_REAR = 0.3, ABDOMEN_JERK_FIRST = 0.6, ABDOMEN_JERK_REST = 0.3, MIN_SPAN = 0.001;
    const double FEELER_STIFFNESS = 60.0, FEELER_GRAVITY = 0.3;

    public readonly FarBeastRig rig;
    public readonly S.RandomNumberGenerator rng;
    public readonly FarBeastUpper upper;
    readonly List<Leg> legs = new List<Leg>();

    // KaijuGait's state.
    public double s = 1.0, speed, model_yaw, yaw_rate, body_yaw, time, hip_height = 1.0, max_drift;
    public BV velocity, accel;
    double turn_max = BODY_TURN_MAX, body_yaw_v, last_yaw;
    BV last_pos;
    bool started;

    // HexapodGait's state.
    public bool climbing, holding;
    double hold_left, dart_time, held_yaw, jolt, perch;
    BV anchor, lag;
    int stomps;
    bool ready;

    public FarBeastGait(FarBeastRig rig)
    {
        this.rig = rig;
        rng = new S.RandomNumberGenerator();
        rng.seed = 7;
        double hips = 0.0;
        foreach (string prefix in LEGS)
        {
            if (!rig.HasBone(prefix + "2")) continue;
            Leg leg = NewLeg(prefix);
            hips += rig.HeadOf(leg.names[0]).y;
            legs.Add(leg);
        }
        hip_height = hips / Math.Max(1.0, legs.Count);
        foreach (FarBeastRig.SpringChain chain in rig.chains)
        {
            chain.stiffness = FEELER_STIFFNESS;  // stiff, springy feelers
            chain.gravityScale = FEELER_GRAVITY;
        }
        upper = new FarBeastUpper(this);
    }

    public void Update(double delta)
    {
        Track(delta);
        double dt = Math.Min(delta, MAX_DT);
        double hipW = hip_height * s;
        bool moving = speed > STAND_SPEED * hipW;
        Skitter(dt, hipW, moving);
        if (holding)
        {
            // A hard hold: the body keeps its place and heading; nothing moves at all.
            rig.RigYaw = BMath.Wrap(held_yaw - model_yaw, -Math.PI, Math.PI);
            body_yaw = held_yaw;
            return;
        }
        BT root = rig.RigGlobal;
        Step(dt, root, moving);
        PoseBody(dt);
        Solve(root, dt);
        upper.perch = perch;
        upper.Update(dt, moving || lag.Length() > CALM_LAG * hipW ? 0.0 : 1.0);
        rig.SimulateChains(delta);
        foreach (Leg leg in legs)
        {
            if (!leg.planted) continue;
            BV at = rig.TailWorld(leg.names[2]);
            max_drift = Math.Max(max_drift, Flat(at - leg.plant_at).Length());
        }
    }

    public void Stomp()
    {
        stomps += 1;
        jolt = 1.0;
        if (stomps % STRIKE_EVERY == 0) upper.Strike();
    }

    public void Roar() => upper.Roar();

    // KaijuGait.track: reads the model's motion and turns the rig towards the body yaw.
    void Track(double delta)
    {
        double dt = Math.Max(delta, MIN_DT);
        time += delta;
        BT frame = rig.Frame;
        s = frame.basis.X.Length();
        BV fwd = -frame.basis.Z;
        model_yaw = Math.Atan2(-fwd.x, -fwd.z);
        BV pos = frame.origin;
        if (!started)
        {
            started = true;
            last_pos = pos;
            last_yaw = model_yaw;
            body_yaw = model_yaw;
        }
        BV raw = Flat((pos - last_pos) / dt);
        BV before = velocity;
        velocity = velocity.Lerp(raw, Math.Min(1.0, dt * VELOCITY_SMOOTHING));
        accel = accel.Lerp((velocity - before) / dt, Math.Min(1.0, dt * VELOCITY_SMOOTHING));
        speed = velocity.Length();
        double turn = BMath.Wrap(model_yaw - last_yaw, -Math.PI, Math.PI) / dt;
        yaw_rate += (turn - yaw_rate) * Math.Min(1.0, dt * TURN_SMOOTHING);
        last_pos = pos;
        last_yaw = model_yaw;
        double err = BMath.Wrap(model_yaw - body_yaw, -Math.PI, Math.PI);
        double top = turn_max / Math.Sqrt(Math.Max(s, MIN_SCALE));
        body_yaw_v = BMath.Clamp(err / dt, -top, top);
        body_yaw = BMath.Wrap(body_yaw + body_yaw_v * dt, -Math.PI, Math.PI);
        rig.RigYaw = BMath.Wrap(body_yaw - model_yaw, -Math.PI, Math.PI);
    }

    // Holds and darts: holding, the body stays put in the world (and keeps its heading) while the model moves on;
    // darting, it snaps to catch up, then holds again.
    void Skitter(double dt, double hipW, bool moving)
    {
        BT frame = rig.Frame;
        if (holding)
        {
            lag = Flat(frame.origin - anchor);
            hold_left -= dt;
            if (hold_left <= 0.0 || lag.Length() > MAX_LAG * hipW || !moving)
            {
                holding = false;
                dart_time = 0.0;
            }
        }
        else Dart(dt, hipW, moving, frame);
        rig.RigAt = frame.basis.Inverse() * -lag;
        if (!holding) SwingRound(dt);
    }

    // Darting: the body catches up; a hold starts once every foot is down and it faces the model's heading.
    void Dart(double dt, double hipW, bool moving, BT frame)
    {
        dart_time += dt;
        double rate = DART_RATE * Math.Max(speed, STAND_SPEED * hipW * DART_FLOOR);
        lag = lag.MoveToward(BV.ZERO, rate * dt);
        bool facing = Math.Abs(BMath.Wrap(model_yaw - body_yaw, -Math.PI, Math.PI)) < FACING;
        bool down = true;
        foreach (Leg leg in legs) down = down && leg.planted;
        if (moving && down && facing && lag.Length() < CAUGHT_UP * hipW && dart_time >= DART_MIN)
        {
            holding = true;
            held_yaw = body_yaw;
            anchor = frame.origin - lag;  // where the body is drawn now, not the model
            bool longHold = rng.Randf() < LONG_HOLD_CHANCE;
            hold_left = longHold ? rng.RandfRange(LONG_HOLD_MIN, LONG_HOLD_MAX) : rng.RandfRange(HOLD_MIN, HOLD_MAX);
        }
    }

    // The legs move first; then the body swings round after them at a constant, snappy rate.
    void SwingRound(double dt)
    {
        bool airborne = false;
        foreach (Leg leg in legs) airborne = airborne || !leg.planted;
        bool big = Math.Abs(BMath.Wrap(model_yaw - held_yaw, -Math.PI, Math.PI)) > BIG_TURN;
        if (dart_time >= LEG_LEAD && (airborne || !big))
            held_yaw = BMath.RotateToward(held_yaw, model_yaw, TURN_RATE / Math.Sqrt(Math.Max(s, MIN_SCALE)) * dt);
        body_yaw = held_yaw;
        rig.RigYaw = BMath.Wrap(body_yaw - model_yaw, -Math.PI, Math.PI);
    }

    void PoseBody(double dt)
    {
        jolt = Math.Max(0.0, jolt - dt * JOLT_DECAY);
        perch += ((climbing ? 1.0 : 0.0) - perch) * Math.Min(1.0, dt * PERCH_RATE);
        double hipW = hip_height;
        double dart = BMath.Clamp(lag.Length() / Math.Max(MIN_SPAN, DART_SPAN * hipW * s), 0.0, 1.0);
        BV jerk = upper.body_jerk;
        double rear = upper.rear * FarBeastUpper.REAR;
        double drop = -jolt * JOLT_DROP * hipW - PERCH_CROUCH * hipW * perch;
        double pitch = rear - PERCH_PITCH * perch - DART_PITCH * dart + jerk.y;
        rig.Pose("thorax0", new BV(pitch, jerk.x, jerk.z), new BV(0, drop, 0));
        rig.Pose("thorax1", new BV(rear * THORAX_REAR - THORAX_JOLT * jolt, 0, 0));
        double pulse = Math.Sin(time * Math.PI * 2 * PULSE_HZ) * PULSE;
        for (int i = 0; i < 3; i++)
        {
            double curl = pulse * (i + 1) * 0.5 - rear * ABDOMEN_REAR + upper.abdomen_jerk * (i == 0 ? ABDOMEN_JERK_FIRST : ABDOMEN_JERK_REST);
            rig.Pose("abdomen" + i, new BV(curl, 0, 0));
        }
    }

    // KaijuGait.spring: a damped spring step in sub-steps, so a slow frame never blows it up.
    public static void Spring(ref double value, ref double vel, double target, double omega, double zeta, double dt)
    {
        int steps = SpringSteps(omega, zeta, dt);
        double h = dt / steps;
        for (int i = 0; i < steps; i++)
        {
            double a = (target - value) * omega * omega - 2.0 * zeta * omega * vel;
            vel += a * h;
            value += vel * h;
        }
    }

    static int SpringSteps(double omega, double zeta, double dt)
    {
        double stable = 2.0 * (Math.Sqrt(zeta * zeta + 1.0) - zeta);
        return Math.Max(1, (int)Math.Ceiling(omega * dt / (stable * SPRING_MARGIN)));
    }

    static BV Flat(BV v) => new BV(v.x, 0.0, v.z);
}
