"""refoot.py KEYS_IN KEYS_OUT [FRAC]: recentre the hind footprints under the hip. Per side, each stance (foot key on its ground,
<= 0.01) gets one constant horizontal offset = -FRAC * the forward part (body heading pelvis->chest at mid-stance) of the mean
hip(thigh_MainPoint)->foot vector over that stance; swings blend the two neighbouring offsets (smoothstep), so planted feet never
slide (a looping take's stance across the wrap, same foot at first and last frame, is one). Applied to every foot_*/toe_* point of the side; y untouched. Loops (first frame == last) wrap."""
import json, sys
import numpy as np
def apply(K, frac=1.0):
    P = {n: np.array(v, float) for n, v in K["keys"].items()}; n = len(P["pelvis_MainPoint"])
    for s in "lr":
        h, f = P["thigh_MainPoint_" + s], P["foot_MainPoint_" + s]; pl = f[:, 1] - f[:, 1].min() <= 0.01
        runs, i = [], 0
        while i < n:
            if pl[i]:
                j = i
                while j + 1 < n and pl[j + 1]: j += 1
                runs.append([i, j]); i = j + 1
            else: i += 1
        wrap = len(runs) > 1 and runs[0][0] == 0 and runs[-1][1] == n - 1 and np.allclose(f[0], f[-1], atol=1e-3)
        off = []
        for r, (a, b) in enumerate(runs):
            ix = list(range(a, b + 1))
            if wrap and r in (0, len(runs) - 1): ix = list(range(runs[-1][0], n)) + list(range(0, runs[0][1] + 1))
            m = ix[len(ix) // 2]; fw = P["chest_MainPoint"][m] - P["pelvis_MainPoint"][m]; fw[1] = 0; fw /= np.linalg.norm(fw)
            v = (f[ix] - h[ix]).mean(0); v[1] = 0; off.append(-frac * np.dot(v, fw) * fw)
        O = np.zeros((n, 3))
        for (a, b), o in zip(runs, off): O[a:b + 1] = o
        for k in range(len(runs) - 1):
            a, b = runs[k][1], runs[k + 1][0]; t = (np.arange(a, b + 1) - a) / (b - a); t = t * t * (3 - 2 * t)
            O[a:b + 1] = off[k] + (off[k + 1] - off[k])[None] * t[:, None]
        if runs and runs[0][0] > 0: O[:runs[0][0]] = off[0]
        if runs and runs[-1][1] < n - 1: O[runs[-1][1] + 1:] = off[-1]
        for nm in P:
            if nm.endswith("_" + s) and nm.startswith(("foot_", "toe_")): P[nm] += O
    K["keys"] = {k: v.round(5).tolist() for k, v in P.items()}; return K
if __name__ == "__main__":
    a = sys.argv; fr = float(a[3]) if len(a) > 3 else 1.0; K = apply(json.load(open(a[1])), fr)
    K["meta"]["note"] = K["meta"].get("note", "") + " | refoot %g" % fr; json.dump(K, open(a[2], "w"))
