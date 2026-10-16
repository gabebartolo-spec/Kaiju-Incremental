"""Motion as it renders: how much the picture changes, frame to frame, around the kaiju.

    python tools/capture/screen_motion.py <clip.mp4> <pose.csv> [--box=WxH] [--small=80x150]

The clip and pose trace come from one capture_motion.gd run (--pose-trace). Each frame is cut to a
box at the screen centre (the cameras keep the kaiju there), shrunk to the game size (--small,
default 80x150 px) and greyed; its "energy" is the mean absolute change from the frame before (0-1).
Reports energy in hard holds (frames past the first 3 of each hold), in darts, and at rest, the
share of hold frames under STILL, and how often a rest frame jumps above TWITCH (a twitch that
reads at game size).
"""
import csv
import sys

import cv2
import numpy as np

STILL = 0.01
TWITCH = 0.01


def main():
    clip, pose = sys.argv[1], sys.argv[2]
    opts = dict(a[2:].split("=") for a in sys.argv[3:])
    small = tuple(int(v) for v in opts.get("small", "80x150").split("x"))
    rows = list(csv.DictReader(open(pose, encoding="utf-8")))
    cap = cv2.VideoCapture(clip)
    w, h = int(cap.get(3)), int(cap.get(4))
    bw, bh = (int(v) for v in opts.get("box", f"{h * 26 // 100}x{h * 50 // 100}").split("x"))
    x0, y0 = (w - bw) // 2, (h - bh) // 2
    energy, last = [], None
    while True:
        ok, f = cap.read()
        if not ok:
            break
        g = cv2.cvtColor(f[y0:y0 + bh, x0:x0 + bw], cv2.COLOR_BGR2GRAY)
        g = cv2.resize(g, small, interpolation=cv2.INTER_AREA).astype(np.float32) / 255.0
        energy.append(0.0 if last is None else float(np.abs(g - last).mean()))
        last = g
    n = min(len(energy), len(rows))
    hold_e, dart_e, rest_e, rest_t = [], [], [], []
    run = 0
    for i in range(1, n):
        r = rows[i]
        walking = r["event"] in ("WALK", "CURVE", "SHARP TURN", "REVERSE + WALK")
        if walking and r.get("holding") == "1":
            run += 1
            if run > 3:
                hold_e.append(energy[i])
        else:
            run = 0
            if walking:
                dart_e.append(energy[i])
            elif r["event"] in ("STAND (stomps)", "STOP (stomps)", "ROAR", "STAND"):
                rest_e.append(energy[i])
                rest_t.append(float(r["t"]))

    def stat(xs):
        return f"n={len(xs)} median {np.median(xs):.4f} p90 {np.percentile(xs, 90):.4f} max {max(xs):.4f}" if xs else "none"

    print(f"box {bw}x{bh} at the centre, shrunk to {small[0]}x{small[1]}")
    print(f"hold frames (after 3): {stat(hold_e)}; under {STILL}: {np.mean(np.array(hold_e) < STILL) * 100 if hold_e else 0:.0f}%")
    print(f"dart frames: {stat(dart_e)}")
    print(f"rest frames: {stat(rest_e)}")
    jumps = [t for t, e, p in zip(rest_t[1:], rest_e[1:], rest_e) if e > TWITCH and p <= TWITCH]
    gaps = np.diff(jumps) if len(jumps) > 1 else []
    print(f"rest twitches over {TWITCH} at game size: {len(jumps)}; gaps " +
          (f"min {min(gaps):.2f} max {max(gaps):.2f} s" if len(gaps) else "none"))
    still_runs, cur = [], 0
    for e in rest_e:
        cur = cur + 1 if e <= TWITCH else 0
        still_runs.append(cur)
    print(f"longest dead still at rest: {max(still_runs, default=0) / 60:.2f} s")


if __name__ == "__main__":
    main()
