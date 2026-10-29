"""plift.py OUT.json: r8 body lift over the plant (lead r8). From Cascadeur's SOLVED r6 and r7 dumps (both legs), per frame
f56-76: toe lift dt_s = what keeps that leg's lowest skin >= TOE_MIN (worst of r6/r7), then the pelvis lift dy = what opens
the keyed knee by the solved deficit to KNEE_T (worst of r6/r7), with the ankle raised dt. Each curve: running max +-3 f,
then a 7-tap mean (stays >= the need), eased to 0 at f52 / f80. The legs stay on r7's keyed hip-ankle geometry."""
import sys, json
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix")
import numpy as np
from cascflip import cload, cskin
W0, W1, E0, E1 = 56, 76, 52, 80
KNEE_T, TOE_MIN = 45.45, 0.15
FR = json.load(open("C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts/frames_adolescent_rise_bay_rise_r7.json"))
FR = FR["frames"] if isinstance(FR, dict) else FR; NF = len(FR)
def ang(H, K, A):
    a, b = H - K, A - K; return float(np.degrees(np.arccos(np.dot(a, b) / np.linalg.norm(a) / np.linalg.norm(b))))
need_t = {s: np.zeros(NF) for s in "lr"}; sol_k = {s: np.full(NF, 999.0) for s in "lr"}
for tag in ("ado_rise_r6", "ado_rise_r7"):
    sk = cload(tag); n = sk["names"]; G = sk["G"]; dom = np.array(n)[sk["W"].argmax(1)]
    ground = cskin(sk, G[-1])[0][:, 1].min(); P = lambda f, j: G[f][n.index(j)][:3, 3]
    for f in range(W0, W1 + 1):
        y = cskin(sk, G[f])[0][:, 1] - ground
        for s in "lr":
            m = np.array([d.startswith(("thigh", "shin", "foot", "toe")) and d.endswith("_" + s) for d in dom])
            need_t[s][f] = max(need_t[s][f], TOE_MIN - float(y[m].min()))
            sol_k[s][f] = min(sol_k[s][f], ang(P(f, "thigh_" + s), P(f, "shin_" + s), P(f, "foot_" + s)))
def ss(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0); return t * t * (3 - 2 * t)
def shape(v):
    v = np.maximum(v, 0.0); r = np.array([v[max(0, f - 3):f + 4].max() for f in range(NF)])
    m = np.array([r[max(0, f - 3):f + 4].mean() for f in range(NF)])
    env = np.array([ss(E0, W0, f) * (1.0 - ss(W1, E1, f)) for f in range(NF)])
    m[W0:W1 + 1] = np.maximum(m[W0:W1 + 1], v[W0:W1 + 1]); return m * env
dt = {s: shape(need_t[s]) for s in "lr"}
V = lambda f, k: np.array(FR[f][k], float); need_y = np.zeros(NF); rows = []
for f in range(W0, W1 + 1):
    for s in "lr":
        H, K, A = V(f, "thigh_MainPoint_" + s), V(f, "shin_MainPoint_" + s), V(f, "foot_MainPoint_" + s)
        L1, L2 = np.linalg.norm(K - H), np.linalg.norm(A - K); k0 = ang(H, K, A)
        tgt = k0 + max(0.0, KNEE_T - sol_k[s][f]); d_req = np.sqrt(L1 * L1 + L2 * L2 - 2 * L1 * L2 * np.cos(np.radians(tgt)))
        A2 = A + np.array([0.0, dt[s][f], 0.0]); lo, hi = -5.0, 20.0   # vertical hip shift giving |H+dy - A2| = d_req (H above A)
        if np.linalg.norm(H + [0, lo, 0] - A2) >= d_req: dy = lo
        else:
            for _ in range(60):
                mid = (lo + hi) / 2; lo, hi = (mid, hi) if np.linalg.norm(H + [0, mid, 0] - A2) < d_req else (lo, mid)
            dy = hi
        need_y[f] = max(need_y[f], dy); rows.append((f, s, round(sol_k[s][f], 2), round(need_t[s][f], 2), round(dy, 2)))
body = shape(need_y)
json.dump({"body": body.tolist(), "foot_l": dt["l"].tolist(), "foot_r": dt["r"].tolist()}, open(sys.argv[1], "w"))
print("PLIFT body max %.2f @f%d | foot_l max %.2f @f%d | foot_r max %.2f @f%d" % (body.max(), body.argmax(), dt["l"].max(), dt["l"].argmax(), dt["r"].max(), dt["r"].argmax()))
for r in rows:
    if r[3] > 0 or r[4] > 0: print("  f%d %s solved knee %.2f toe need %.2f hip need %.2f" % r)
