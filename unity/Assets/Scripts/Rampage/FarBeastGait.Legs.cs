using System;

// The far beast's feet (gait_hexapod.gd: _step, _pair_step, _move_feet, _plant, _solve) and KaijuGait.solve_knee:
// diagonal pairs step when out of place, landing where the body is heading; a tap at rest moves one leg.
public sealed partial class FarBeastGait
{
    const double SWING_LIFT = 1.2, TAP_LIFT = 0.6, MIN_SWING = 0.05, STAGE_SCALE = 1.3, STAGE_MIN = 0.4;
    const double KNEE_OUT = 0.6, REACH_EPS = 0.0001, FIRST_SWING = 0.1;

    sealed class Leg
    {
        public readonly string[] names = new string[3];
        public int pair;
        public BV home, tarsus = BV.DOWN, foot, from, shift, plant_at;  // tarsus: rest ankle->foot, rig space
        public double l1, l2, t, swing_time = FIRST_SWING, side = 1.0, snap;
        public bool planted = true;
        public string id = "";  // footfall id: "fl", "fr", "bl", "br"
    }

    // The leg's bones, pair, side and home stance from its rest pose (HexapodGait._init).
    Leg NewLeg(string prefix)
    {
        var leg = new Leg();
        for (int i = 0; i < 3; i++) leg.names[i] = prefix + i;
        leg.pair = PAIR[prefix];
        leg.side = prefix.EndsWith("_l") ? -1.0 : 1.0;
        leg.id = (prefix.StartsWith("leg") ? "f" : "b") + (leg.side < 0.0 ? "l" : "r");
        leg.l1 = rig.DirOf(leg.names[0]).Length();
        leg.l2 = rig.DirOf(leg.names[1]).Length();
        leg.tarsus = rig.DirOf(leg.names[2]);
        BV foot = rig.HeadOf(leg.names[2]) + leg.tarsus;
        BV hip = rig.HeadOf(leg.names[0]);
        double outX = (foot.x - hip.x) * HOME_IN, outZ = (foot.z - hip.z) * HOME_IN;
        leg.home = new BV(hip.x + outX, 0.0, hip.z + outZ);
        return leg;
    }

    // Feet in diagonal pairs: a pair steps when it is out of place; a tap at rest moves one leg.
    void Step(double dt, BT root, bool moving)
    {
        BT frame = rig.Frame;
        if (!ready)
        {
            ready = true;
            foreach (Leg leg in legs) leg.plant_at = leg.foot = root * leg.home;
        }
        double hipW = hip_height * s;
        bool darting = lag.Length() > CALM_LAG * hipW;
        double swing = (darting ? SWING_DART : SWING_SETTLE) * Math.Sqrt(s);
        // Where each foot belongs: under the body where it will be (the model's place and heading).
        BV lead = velocity * swing;
        var swinging = new bool[2];
        var worst = new float[2];
        foreach (Leg leg in legs)
        {
            if (!leg.planted) swinging[leg.pair] = true;
            BV want = frame * leg.home + lead;
            double off = Flat(leg.foot - want).Length();
            worst[leg.pair] = (float)Math.Max(worst[leg.pair], off);
        }
        double limit = (moving || darting ? STEP_AT : SETTLE_AT) * hipW;
        if (!swinging[0] && !swinging[1]) PairStep(worst, limit, swing, hipW);
        upper.tap_leg = -1;
        MoveFeet(dt, root, swing, frame, lead);
    }

    // Every foot down: the pair furthest out of place (past limit) steps, or a tap at rest moves one leg.
    void PairStep(float[] worst, double limit, double swing, double hipW)
    {
        int pick = worst[0] >= worst[1] ? 0 : 1;
        if (worst[pick] > limit)
        {
            foreach (Leg leg in legs)
                if (leg.pair == pick) Lift(leg, swing, BV.ZERO);
        }
        else if (upper.tap_leg >= 0 && upper.tap_leg < legs.Count)
        {
            Leg tap = legs[upper.tap_leg];
            double sx = rng.RandfRange(-1, 1);
            double sz = rng.RandfRange(-1, 1);
            Lift(tap, TAP_SWING * Math.Sqrt(s), new BV(sx, 0, sz).Normalized() * TAP_SHIFT * hipW);
        }
    }

    // Each foot: a planted one stretched too far lifts; a lifted one snaps toward where it lands and plants there.
    void MoveFeet(double dt, BT root, double swing, BT frame, BV lead)
    {
        double ground = root.origin.y;
        double hipW = hip_height * s;
        foreach (Leg leg in legs)
        {
            if (leg.planted && Stretch(leg, root) > REACH_STEP) Lift(leg, swing, BV.ZERO);
            if (leg.planted)
            {
                leg.foot.y = ground;
                continue;
            }
            leg.t = Math.Min(1.0, leg.t + dt / leg.swing_time);
            BV land = frame * leg.home + lead + leg.shift;
            land.y = ground;
            land = WithinReach(leg, land, root);
            // Snap: most of the travel happens at once, then it settles (a fast ease-out).
            double e = 1.0 - Math.Pow(1.0 - leg.t, 3.0);
            leg.foot = leg.from.Lerp(land, e);
            double lift = LIFT * (leg.shift == BV.ZERO ? 1.0 : TAP_LIFT);
            leg.foot.y = ground + Math.Sin(Math.PI * Math.Min(1.0, leg.t * SWING_LIFT)) * lift * hipW;
            if (leg.t >= 1.0) Plant(leg, land);
        }
    }

    void Plant(Leg leg, BV land)
    {
        leg.planted = true;
        leg.foot = land;
        leg.plant_at = land;
        leg.snap = 1.0;
        double stage = BMath.Clamp(Math.Sqrt(s / STAGE_SCALE), STAGE_MIN, 1.0);
        double weight = STEP_WEIGHT + STEP_WEIGHT * BMath.Clamp(speed / (2.0 * hip_height * s), 0.0, 1.0);
        rig.Planted(leg.id, weight * stage, land);
    }

    // Pulls a landing spot in so the leg can still reach it from the hip.
    BV WithinReach(Leg leg, BV land, BT root)
    {
        BV hip = rig.Global(leg.names[0]).origin;
        BV ankle = land - root.basis * leg.tarsus;
        double reach = (leg.l1 + leg.l2) * s * LAND_REACH;
        double dy = hip.y - ankle.y;
        BV flat = Flat(ankle - hip);
        double most = Math.Sqrt(Math.Max(0.0, reach * reach - dy * dy));
        if (flat.Length() <= most) return land;
        return land + flat.Normalized() * most - flat;
    }

    void Lift(Leg leg, double seconds, BV shift)
    {
        leg.planted = false;
        leg.from = leg.foot;
        leg.shift = shift;
        leg.t = 0.0;
        leg.swing_time = Math.Max(MIN_SWING, seconds);
    }

    double Stretch(Leg leg, BT root) => (rig.Global(leg.names[0]).origin - Ankle(leg, root)).Length() / ((leg.l1 + leg.l2) * s);

    static BV Ankle(Leg leg, BT root) => leg.foot - root.basis * leg.tarsus;

    void Solve(BT root, double dt)
    {
        BV up = root.basis.Y.Normalized();
        BV right = root.basis.X.Normalized();
        foreach (Leg leg in legs)
        {
            BV hip = rig.Global(leg.names[0]).origin;
            BV ankle = Ankle(leg, root);
            // An insect's knee rides high and out: the leg arches over the foot, rising further in a swing and
            // flicking out on the plant.
            leg.snap = Math.Max(0.0, leg.snap - KNEE_SNAP * dt);
            double swingUp = !leg.planted ? Math.Sin(Math.PI * leg.t) : 0.0;
            BV pole = up * (1.0 + swingUp) + right * leg.side * (KNEE_OUT + KNEE_FLICK * leg.snap);
            BV knee = SolveKnee(hip, ankle, leg.l1 * s, leg.l2 * s, pole);
            rig.Aim(leg.names[0], hip, knee);
            rig.Aim(leg.names[1], knee, ankle);
            rig.Aim(leg.names[2], ankle, leg.foot);
        }
    }

    // Two-bone IK: where the middle joint goes so bones a (l1) and b (l2) reach from root to end, bending towards pole.
    public static BV SolveKnee(BV root, BV end, double l1, double l2, BV pole)
    {
        BV d = end - root;
        double dist = BMath.Clamp(d.Length(), Math.Abs(l1 - l2) + REACH_EPS, l1 + l2 - REACH_EPS);
        BV dir = d.Length() > REACH_EPS ? d.Normalized() : BV.DOWN;
        double cosA = BMath.Clamp((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0);
        BV p = pole - dir * pole.Dot(dir);
        p = p.Length() > REACH_EPS ? p.Normalized() : dir.Cross(BV.RIGHT).Normalized();
        return root + dir * (cosA * l1) + p * (Math.Sqrt(Math.Max(0.0, 1.0 - cosA * cosA)) * l1);
    }
}
