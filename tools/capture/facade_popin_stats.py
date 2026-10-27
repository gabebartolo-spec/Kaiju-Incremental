#!/usr/bin/env python3
"""facade_popin_stats.py: the numbers behind "pop-in on the facades" from capture_facade_popin.gd.
Run: py -3 -I tools/capture/facade_popin_stats.py <on_dir> <off_dir>
 on_dir / off_dir = the probe's output folders for the same walk with the far blur on / off.
Prints: stand-in <-> building swaps in view (count, per 10 s, depth, where they sit against the blur's
start), then the blur-driven sharpening of facades: frames a facade takes to go from blurry (sharpness
under BLURRY of its blur-off value) to sharp (over SHARP), per 10 s, and abrupt sharpness jumps in
each arm with whether a mesh swap happened in the same +-2 frames."""
import csv
import os
import statistics as st
import sys

FPS = 60.0
BLURRY, SHARP = 0.6, 0.9
JUMP = 1.35


def rows(path):
    with open(path, newline="") as f:
        return list(csv.DictReader(f))


def pct(vals, p):
    vals = sorted(vals)
    return vals[min(len(vals) - 1, int(len(vals) * p))] if vals else float("nan")


def swaps(d, label):
    s = rows(os.path.join(d, "swaps.csv"))
    fr = rows(os.path.join(d, "frames.csv"))
    secs = len(fr) / FPS
    print("== swaps in view, %s (%.0f s)" % (label, secs))
    for up, name in ((1, "box -> building"), (0, "building -> box")):
        sub = [r for r in s if int(r["up"]) == up]
        if not sub:
            print("  %s: none" % name)
            continue
        depth = [float(r["depth"]) for r in sub]
        ratio = [float(r["ratio"]) for r in sub]
        blur = [float(r["blur"]) for r in sub]
        pxh = [float(r["px_h"]) for r in sub]
        print("  %s: %d (%.1f per 10 s); depth m min %.0f med %.0f max %.0f; depth/blur-start med %.2f; "
              "blur share med %.2f, %.0f%% in the blur; on-screen height px med %.0f max %.0f; landmarks %d"
              % (name, len(sub), len(sub) * 10.0 / secs, min(depth), st.median(depth), max(depth),
                 st.median(ratio), st.median(blur), 100.0 * sum(b > 0.05 for b in blur) / len(blur),
                 st.median(pxh), max(pxh), sum(int(r["landmark"]) for r in sub)))


def series(d):
    out = {}
    for r in rows(os.path.join(d, "sharp.csv")):
        out.setdefault(int(r["n"]), {})[int(r["frame"])] = (float(r["sharp"]), float(r["depth"]),
                                                              float(r["blur"]), int(r["meshed"]))
    return out


def blur_to_sharp(on, off, secs):
    print("== blurry -> sharp, far blur ON vs the same frames OFF (ratio = sharpness_on / sharpness_off)")
    events = []
    for n, a in on.items():
        b = off.get(n, {})
        frames = sorted(f for f in a if f in b and b[f][0] > 1e-4)
        ratio = {f: a[f][0] / b[f][0] for f in frames}
        low = None
        for f in frames:
            r = ratio[f]
            if r < BLURRY:
                low = f
            elif r > SHARP and low is not None and f - low <= 90 and a[f][3] == a[low][3]:
                events.append((n, low, f, a[low][1], a[f][1], a[f][2]))
                low = None
    if not events:
        print("  none found (tracked facades: %d)" % len(on))
        return
    took = [e[2] - e[1] for e in events]
    print("  %d facades went blurry -> sharp (%.1f per 10 s); frames taken med %d max %d; at depth %.0f..%.0f m"
          % (len(events), len(events) * 10.0 / secs, st.median(took), max(took),
             min(e[4] for e in events), max(e[4] for e in events)))
    for e in events[:8]:
        print("    building %d: frames %d -> %d (%d), depth %.0f -> %.0f m" % (e[0], e[1], e[2], e[2] - e[1], e[3], e[4]))


def jumps(ser, label, secs):
    n_jump = n_swap = 0
    for n, a in ser.items():
        fs = sorted(a)
        for f0, f1 in zip(fs, fs[1:]):
            if f1 - f0 != 1:
                continue
            s0, s1 = a[f0][0], a[f1][0]
            if s0 < 1e-4 or s1 < 1e-4:
                continue
            if max(s1 / s0, s0 / s1) > JUMP:
                n_jump += 1
                if a[f0][3] != a[f1][3]:
                    n_swap += 1
    print("== sharpness jumps (>x%.2f in one frame), %s: %d (%.1f per 10 s), %d on a mesh swap" % (JUMP, label, n_jump,
          n_jump * 10.0 / secs, n_swap))


def main():
    on_d, off_d = sys.argv[1], sys.argv[2]
    secs = len(rows(os.path.join(on_d, "frames.csv"))) / FPS
    swaps(on_d, "blur on")
    swaps(off_d, "blur off")
    on, off = series(on_d), series(off_d)
    blur_to_sharp(on, off, secs)
    jumps(on, "blur on", secs)
    jumps(off, "blur off", secs)


main()
