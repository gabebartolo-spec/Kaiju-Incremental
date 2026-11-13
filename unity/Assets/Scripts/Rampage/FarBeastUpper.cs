using System;
using S = Kaiju.Sim;

// The far beast's upper body: scenes/hexapod_upper.gd (HexapodUpper) line for line. The head, the raptorial
// scythes, the mandibles, the antennae and the twitches; every move is a snap to a new pose (a stiff, fast spring)
// that is then held. The roar rears the body and flares the scythes and mandibles wide.
public sealed class FarBeastUpper
{
    const double TWITCH_EVERY_MIN = 0.12, TWITCH_EVERY_MAX = 0.5, TAP_EVERY_MIN = 0.2, TAP_EVERY_MAX = 0.6;
    const int TWITCH_PARTS = 3;
    static readonly string[] SNAPS =
        { "head_yaw", "head_pitch", "head_cock", "jerk_yaw", "jerk_pitch", "jerk_roll", "abdomen", "flex_l", "flex_r", "mandibles" };
    const double SNAP_OMEGA = 46.0, SNAP_ZETA = 0.75, TWITCH_HOLD_MIN = 0.1, TWITCH_HOLD_MAX = 0.45;
    const double HEAD_HOLD_MIN = 0.15, HEAD_HOLD_MAX = 0.6, HEAD_YAW = 0.9, HEAD_PITCH = 0.3, HEAD_COCK = 0.5;
    static readonly BV BODY_JERK = new BV(0.3, 0.16, 0.22);
    const double ABDOMEN_JERK = 0.35;
    static readonly BV FOLD_FEMUR = new BV(0.18, 0.75, 0.65), FOLD_TIBIA = new BV(0.05, -0.8, -0.45), FOLD_CLAW = new BV(0.0, -0.55, 0.7);
    static readonly BV STRIKE_FEMUR = new BV(0.1, 0.25, 1.0), STRIKE_TIBIA = new BV(0.0, -0.15, 1.0);
    static readonly BV FLARE_FEMUR = new BV(0.9, 0.9, 0.3), FLARE_TIBIA = new BV(1.0, 0.6, 0.15), FLARE_CLAW = new BV(0.5, -0.9, 0.2);
    const double FLEX = 1.0, FLEX_OUT = 0.5, CHATTER = 0.5, MANDIBLE_FLARE = 0.7;
    const double ROAR_SECONDS = 1.3, TREMBLE = 0.05, TREMBLE_HZ = 23.0, STRIKE_DECAY = 3.2, FLICK = 16.0;
    public const double REAR = 0.45;
    // The literals of the GDScript bodies, named.
    const double HEAD_SNAP_HOLD = 9.0, LEAD_SHARE = 0.25, LEAD_MAX = 0.5, WALK_LOOK = 0.4, COCK_CHANCE = 0.45;
    const double FLEX_R_SPASM = 0.7, DISPLAY_UP = 6.0, DISPLAY_DOWN = 12.0, STRIKE_PITCH = 0.4, DISPLAY_PITCH = 0.35;
    const double PERCH_ARMS = 0.35, FLEX_MIN = 0.4, CHATTER_MIN = 0.5, TAP_FLEX_MIN = 0.3, TAP_FLEX_MAX = 0.7;
    const double KICK_CHANCE = 0.7, KICK_UP_MIN = -0.5, KICK_DT = 1.0 / 60.0, MANDIBLE_PITCH = 0.3;
    const int TWITCH_KINDS = 6, LEG_COUNT = 4;

    // Outputs read by the gait: body jerk (yaw, pitch, roll), abdomen jerk, how far the body rears (0..1), and a
    // leg to tap (-1: none; the gait clears it).
    public BV body_jerk;
    public double abdomen_jerk, rear, perch;
    public int tap_leg = -1;
    readonly FarBeastGait gait;
    readonly FarBeastRig rig;
    readonly float[] val = new float[SNAPS.Length], vel = new float[SNAPS.Length];
    readonly float[] target = new float[SNAPS.Length], hold = new float[SNAPS.Length];
    double twitchIn = FIRST_TWITCH, tapIn = FIRST_TAP, headHold = FIRST_HEAD_HOLD, strike, roar;
    const double FIRST_TWITCH = 0.3, FIRST_TAP = 0.4, FIRST_HEAD_HOLD = 0.3;  // gait_hexapod.gd's starting timers

    public FarBeastUpper(FarBeastGait gait)
    {
        this.gait = gait;
        rig = gait.rig;
    }

    public void Strike() => strike = 1.0;
    public void Roar() => roar = 1.0;

    // A twitch at rest, a hunting head and the scythes posed. calm: 0 walking, 1 standing.
    public void Update(double dt, double calm)
    {
        S.RandomNumberGenerator rng = gait.rng;
        Restless(dt, calm, rng);
        for (int i = 0; i < SNAPS.Length; i++) StepSnap(i, dt);
        strike = Math.Max(0.0, strike - dt * STRIKE_DECAY);
        bool wasRoaring = roar > 0.0;
        roar = Math.Max(0.0, roar - dt / ROAR_SECONDS);
        if (wasRoaring && roar == 0.0) Spasm(rng);
        // The display: up fast, held, dropped at the end.
        double display = roar > 0.0 ? BMath.Clamp(Math.Min(roar * DISPLAY_UP, (1.0 - roar) * DISPLAY_DOWN), 0.0, 1.0) : 0.0;
        rear = display;
        double tremble = Math.Sin(gait.time * Math.PI * 2 * TREMBLE_HZ) * TREMBLE * display;
        body_jerk = new BV(V("jerk_yaw"), V("jerk_pitch"), V("jerk_roll") + tremble);
        abdomen_jerk = V("abdomen");
        PoseHead(display);
        double lash = strike > 0.0 ? Math.Sin(Math.PI * Math.Pow(1.0 - strike, 0.5)) : 0.0;
        PoseArm("arm_l", Math.Max(lash, perch * PERCH_ARMS), V("flex_l"), display);
        PoseArm("arm_r", Math.Max(lash, perch * PERCH_ARMS), V("flex_r"), display);
        PoseMandibles(Math.Max(V("mandibles"), display * MANDIBLE_FLARE));
    }

    // The display ends in a spasm, never a dead hold: both scythes, the head and a leg.
    void Spasm(S.RandomNumberGenerator rng)
    {
        SnapTo("flex_l", FLEX);
        SnapTo("flex_r", FLEX * FLEX_R_SPASM);
        SnapTo("jerk_roll", BODY_JERK.z * (rng.Randf() < 0.5 ? 1.0 : -1.0));
        headHold = 0.0;
        tap_leg = (int)(rng.Randi() % LEG_COUNT);
    }

    // A twitch now and then, a tapped leg at rest and a hunting head: each on its own timer.
    void Restless(double dt, double calm, S.RandomNumberGenerator rng)
    {
        twitchIn -= dt;
        if (twitchIn <= 0.0)
        {
            twitchIn = rng.RandfRange(TWITCH_EVERY_MIN, TWITCH_EVERY_MAX);
            long parts = rng.RandiRange(1, TWITCH_PARTS);
            for (long i = 0; i < parts; i++) Twitch((int)(rng.Randi() % TWITCH_KINDS), calm);
        }
        tapIn -= dt;
        if (tapIn <= 0.0)
        {
            tapIn = rng.RandfRange(TAP_EVERY_MIN, TAP_EVERY_MAX);
            if (calm > 0.5) tap_leg = (int)(rng.Randi() % LEG_COUNT);
        }
        headHold -= dt;
        if (headHold <= 0.0)
        {
            headHold = rng.RandfRange(HEAD_HOLD_MIN, HEAD_HOLD_MAX);
            double lead = BMath.Clamp(gait.yaw_rate * LEAD_SHARE, -LEAD_MAX, LEAD_MAX);
            SnapTo("head_yaw", rng.RandfRange(-HEAD_YAW, HEAD_YAW) * (WALK_LOOK + (1.0 - WALK_LOOK) * calm) + lead, HEAD_SNAP_HOLD);
            SnapTo("head_pitch", rng.RandfRange(-HEAD_PITCH, HEAD_PITCH * 0.5), HEAD_SNAP_HOLD);
            double cock = rng.Randf() < COCK_CHANCE ? rng.RandfRange(-HEAD_COCK, HEAD_COCK) : 0.0;
            SnapTo("head_cock", cock, HEAD_SNAP_HOLD);
        }
    }

    // One random part twitches to a new pose and holds it; the feelers flick with every twitch.
    void Twitch(int part, double calm)
    {
        S.RandomNumberGenerator rng = gait.rng;
        switch (part)
        {
            case 0:
                SnapTo("jerk_yaw", rng.RandfRange(-1, 1) * BODY_JERK.x * calm);
                SnapTo("jerk_pitch", rng.RandfRange(-1, 1) * BODY_JERK.y * calm);
                SnapTo("jerk_roll", rng.RandfRange(-1, 1) * BODY_JERK.z * calm);
                break;
            case 1: SnapTo("abdomen", rng.RandfRange(-1, 1) * ABDOMEN_JERK); break;
            case 2: FlexOne(rng, FLEX_MIN, 1.0); break;
            case 3: SnapTo("mandibles", rng.RandfRange(CHATTER_MIN, 1.0) * CHATTER); break;
            case 4:
                if (calm > 0.5) tap_leg = (int)(rng.Randi() % LEG_COUNT);
                else FlexOne(rng, TAP_FLEX_MIN, TAP_FLEX_MAX);
                break;
            default: headHold = 0.0; break;  // snap the head now
        }
        foreach (FarBeastRig.SpringChain chain in rig.chains)
        {
            if (rng.Randf() >= KICK_CHANCE) continue;
            double kx = rng.RandfRange(-1, 1);
            double ky = rng.RandfRange(KICK_UP_MIN, 1);
            double kz = rng.RandfRange(-1, 1);
            chain.Kick(rig.RigGlobal.basis * new BV(kx, ky, kz) * FLICK, KICK_DT);
        }
    }

    void FlexOne(S.RandomNumberGenerator rng, double lo, double hi)
    {
        string key = rng.Randf() < 0.5 ? "flex_l" : "flex_r";
        SnapTo(key, rng.RandfRange(lo, hi) * FLEX);
    }

    // Snap a value to a target and hold it there for a while (hold <= 0: a random hold).
    void SnapTo(string key, double to, double seconds = 0.0)
    {
        int i = Array.IndexOf(SNAPS, key);
        target[i] = (float)to;
        hold[i] = (float)(seconds > 0.0 ? seconds : gait.rng.RandfRange(TWITCH_HOLD_MIN, TWITCH_HOLD_MAX));
    }

    void StepSnap(int i, double dt)
    {
        hold[i] -= (float)dt;
        if (hold[i] <= 0.0f) target[i] = 0.0f;  // the hold is over: snap back
        double v = val[i], w = vel[i];
        FarBeastGait.Spring(ref v, ref w, target[i], SNAP_OMEGA, SNAP_ZETA, dt);
        val[i] = (float)v;
        vel[i] = (float)w;
    }

    double V(string key) => val[Array.IndexOf(SNAPS, key)];

    void PoseHead(double display)
    {
        if (!rig.HasBone("head0")) return;
        double yaw = V("head_yaw") * (1.0 - display);
        double pitch = V("head_pitch") - STRIKE_PITCH * strike + DISPLAY_PITCH * display;
        BB world = BB.Axis(BV.UP, gait.body_yaw + yaw) * BB.Axis(BV.RIGHT, pitch) * BB.Axis(BV.BACK, V("head_cock"));
        rig.SetWorldBasis("head0", world);
    }

    // One scythe by aiming its three bones in the body's frame: folded, struck out (lash 0..1), flexed open
    // (flex 0..1) or flared in a display (0..1). Aimed from the thorax every frame, so it holds through any turn.
    void PoseArm(string arm, double lash, double flex, double display)
    {
        if (!rig.HasBone(arm + "2")) return;
        BB b = rig.RigGlobal.basis.Orthonormalized();
        double side = arm.EndsWith("_l") ? -1.0 : 1.0;
        BV femurV = FOLD_FEMUR.Lerp(STRIKE_FEMUR, Math.Max(lash, flex * 0.5)).Lerp(FLARE_FEMUR, display);
        femurV += new BV(FLEX_OUT, 0, 0) * flex;  // a twitch swings the scythe out: visible from above
        BV tibiaV = FOLD_TIBIA.Lerp(STRIKE_TIBIA, Math.Max(lash, flex)).Lerp(FLARE_TIBIA, display);
        BV clawV = FOLD_CLAW.Lerp(STRIKE_TIBIA, lash).Lerp(FLARE_CLAW, display);
        double s = gait.s;
        BV shoulder = rig.Global(arm + "0").origin;
        BV elbow = shoulder + Dir(b, side, femurV) * rig.DirOf(arm + "0").Length() * s;
        BV wrist = elbow + Dir(b, side, tibiaV) * rig.DirOf(arm + "1").Length() * s;
        BV tip = wrist + Dir(b, side, clawV) * rig.DirOf(arm + "2").Length() * s;
        rig.Aim(arm + "0", shoulder, elbow);
        rig.Aim(arm + "1", elbow, wrist);
        rig.Aim(arm + "2", wrist, tip);
    }

    // A body-frame direction (x out on this side, y up, z forward) in the world.
    static BV Dir(BB b, double side, BV v) => (b.X * side * v.x + b.Y * v.y - b.Z * v.z).Normalized();

    // Mandibles swing apart about the head's up axis; _l sits on the -x side, so +yaw is outward.
    void PoseMandibles(double spread)
    {
        foreach (string m in new[] { "mandible_l", "mandible_r" })
        {
            if (!rig.HasBone(m)) continue;
            double outward = m.EndsWith("_l") ? 1.0 : -1.0;
            rig.Pose(m, new BV(spread * MANDIBLE_PITCH, spread * outward, 0));
        }
    }
}
