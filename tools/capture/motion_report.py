"""Numbers for a motion review from capture_motion.gd traces (--pose-trace and --trace).

    python tools/capture/motion_report.py <pose.csv> [<trace base: x.csv, for x_feet.csv>]

Reports, for the walking stretches: hard holds (runs where the body is in a hold: how long,
how far the body and the bones moved during them) and darts (runs between holds: how long,
top body speed); for the standing stretches: twitches (frames where the bones start moving
after a still moment) and the longest still gap; for the sharp turn: how long the body takes
to come round to the new heading and whether a foot lifts before the body turns.
"""
import csv
import math
import sys
from pathlib import Path

STILL = 0.002  # bone movement per frame (world units, summed) below which the body is still
SPIKE, SPIKE_MIN = 2.0, 0.3  # a twitch onset: bone movement this many times the frames before
WALKING = ("WALK", "CURVE", "SHARP TURN", "REVERSE + WALK")
RESTING = ("STAND (stomps)", "STOP (stomps)", "ROAR", "STAND")


def runs(rows, key):
    """(value, first row, last row) runs of consecutive equal key values."""
    out = []
    for i, r in enumerate(rows):
        if out and out[-1][0] == key(r) and out[-1][2] == i - 1:
            out[-1][2] = i
        else:
            out.append([key(r), i, i])
    return out


def stats(xs):
    if not xs:
        return "none"
    m = sum(xs) / len(xs)
    sd = math.sqrt(sum((x - m) ** 2 for x in xs) / len(xs))
    return f"n={len(xs)} min {min(xs):.3f} max {max(xs):.3f} mean {m:.3f} (cv {sd / m if m else 0:.2f})"


def main():
    rows = list(csv.DictReader(open(sys.argv[1], encoding="utf-8")))
    for r in rows:
        for k in ("t", "x", "z", "yaw", "bone_motion", "model_yaw"):
            r[k] = float(r[k])
        r["holding"] = int(r["holding"])
    dt = rows[1]["t"] - rows[0]["t"]
    walk = [r for r in rows if r["event"] in WALKING]
    holds, darts = [], []
    hold_body, hold_bones = 0.0, 0.0
    top_speed = []
    for val, a, b in runs(walk, lambda r: (r["holding"], r["event"])):
        seg = walk[a:b + 1]
        if b - a < 1 or seg[0]["t"] - walk[max(0, a - 1)]["t"] > 2 * dt:
            continue
        dur = (b - a + 1) * dt
        if val[0]:
            holds.append(dur)
            hold_body = max(hold_body, math.hypot(seg[-1]["x"] - seg[0]["x"], seg[-1]["z"] - seg[0]["z"]))
            hold_bones = max(hold_bones, max(r["bone_motion"] for r in seg[1:]) if len(seg) > 1 else 0.0)
        else:
            darts.append(dur)
            sp = [math.hypot(q["x"] - p["x"], q["z"] - p["z"]) / dt for p, q in zip(seg, seg[1:])]
            if sp:
                top_speed.append(max(sp))
    print(f"holds (s): {stats(holds)}")
    print(f"  worst body travel inside a hold: {hold_body:.4f} units; worst bone motion in a hold frame: {hold_bones:.5f}")
    print(f"darts (s): {stats(darts)}")
    print(f"  top body speed per dart (units/s): {stats(top_speed)}")
    for name in RESTING:
        seg = [r for r in rows if r["event"] == name]
        if not seg:
            continue
        # A twitch: the bones jump to well above how much they were moving just before.
        m = [r["bone_motion"] for r in seg]
        onsets = []
        for i in range(4, len(seg)):
            before = sorted(m[i - 4:i])[1]
            if m[i] > max(SPIKE_MIN, before * SPIKE) and m[i - 1] <= max(SPIKE_MIN, before * SPIKE):
                onsets.append(seg[i]["t"])
        gaps = [b - a for a, b in zip(onsets, onsets[1:])]
        still = max(((b - a + 1) * dt for v, a, b in runs(seg, lambda r: r["bone_motion"] < STILL) if v), default=0.0)
        print(f"{name} {seg[0]['t']:.1f}-{seg[-1]['t']:.1f}s: twitch onsets {len(onsets)}, gaps {stats(gaps)}, "
              f"longest still {still:.2f}s")
    turn = [r for r in rows if r["event"] == "SHARP TURN"]
    if turn:
        t0 = turn[0]["t"]
        after = [r for r in rows if r["t"] >= t0 and r["t"] < t0 + 2.0]
        target = after[-1]["model_yaw"]
        def err(r, k):
            return abs((r[k] - target + math.pi) % (2 * math.pi) - math.pi)
        model_in = next((r["t"] for r in after if err(r, "model_yaw") < math.radians(10)), None)
        body_start = next((r["t"] for r in after if abs(((r["yaw"] - after[0]["yaw"] + math.pi) % (2 * math.pi)) - math.pi) > math.radians(5)), None)
        body_in = next((r["t"] for r in after if err(r, "yaw") < math.radians(10)), None)
        print(f"sharp turn from {t0:.2f}s: sim heading in by {model_in}, body starts {body_start}, body in by {body_in}"
              + (f" (body turn {body_in - body_start:.2f}s)" if body_in and body_start else ""))
        if len(sys.argv) > 2:
            feet = Path(sys.argv[2]).with_name(Path(sys.argv[2]).stem + "_feet.csv")
            air_at_start, lifts, prev = False, [], {}
            for r in csv.DictReader(open(feet, encoding="utf-8")):
                t, f, p = float(r["t"]), r["foot"], int(r["planted"])
                if body_start is not None and abs(t - body_start) < 1e-3 and p == 0:
                    air_at_start = True
                if t >= t0 and prev.get(f) == 1 and p == 0:
                    lifts.append(t)
                prev[f] = p
            first = min(lifts) if lifts else None
            lead = air_at_start or (first is not None and body_start is not None and first <= body_start)
            print(f"  a foot in the air when the body starts turning: {air_at_start}; first fresh lift {first}; "
                  f"legs lead: {lead}")

if __name__ == "__main__":
    main()
