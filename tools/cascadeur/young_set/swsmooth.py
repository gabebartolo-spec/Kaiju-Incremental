"""swsmooth.py IN OUT SIDE SIGMA: smooth one hind leg's swing in time (foot_/toe_ points of SIDE, frames off the ground, Gaussian
SIGMA frames, weight eased in/out at lift-off and touch-down so planted frames stay exact): evens out the knee fold rate."""
import json, sys
import numpy as np
IN, OUT, S, SG = sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4])
K = json.load(open(IN)); P = {n: np.array(v, float) for n, v in K["keys"].items()}; f = P["foot_MainPoint_" + S]; NF = len(f)
up = f[:, 1] > f[:, 1].min() + 0.01
d = np.full(NF, 99.0)   # distance in frames to the nearest planted frame
for i in range(NF):
    if up[i]: d[i] = min(abs(i - j) for j in np.where(~up)[0])
    else: d[i] = 0
w = np.clip(d / 3.0, 0, 1); w = w * w * (3 - 2 * w)
k = np.arange(-int(3 * SG), int(3 * SG) + 1); g = np.exp(-0.5 * (k / SG) ** 2); g /= g.sum()
for n in P:
    if n.startswith(("foot_", "toe_")) and n.endswith("_" + S):
        v = P[n]; pad = np.pad(v, ((len(k) // 2,) * 2, (0, 0)), mode="edge")
        sm = np.stack([np.convolve(pad[:, c], g, "valid") for c in range(3)], 1); sm[:, 1] = v[:, 1]   # keep height
        P[n] = v + w[:, None] * (sm - v)
K["keys"] = {n: v.tolist() for n, v in P.items()}; K["meta"]["note"] += " | swsmooth %s %g" % (S, SG); json.dump(K, open(OUT, "w"))
