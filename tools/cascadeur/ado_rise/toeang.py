"""toeang.py OUT.json [MARGIN_CM=0.05]: r6 toes. Per frame and side, the smallest up-turn of the toe (deg, about toe_MainPoint, axis
horizontal and square to the r4 frames' toe Main->Direction) that keeps every toe-weighted skin vertex of the r4 cdump
(ado_rise_r4) at or over the seabed + MARGIN (linear blend: x + w_toe (R - I)(x - j)). ado_rise.py TOEUP=1 TOEANG=OUT.json."""
import sys, json
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix")
import numpy as np
from cascflip import cload, cskin
D = "C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts/"
A = json.load(open(D + "frames_adolescent_rise_bay_rise_r4.json"))["frames"]
out, MG = sys.argv[1], float(sys.argv[2]) if len(sys.argv) > 2 else 0.05
sk = cload("ado_rise_r4"); n = sk["names"]; G = sk["G"]; NF = len(G); W = sk["W"]
ground = cskin(sk, G[-1])[0][:, 1].min(); res = {}


def rodr(k, a):
    K = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]]); return np.eye(3) + np.sin(a) * K + (1 - np.cos(a)) * K @ K


for s in "lr":
    it = n.index("toe_" + s); wt = W[:, it]; m = wt > 0.05; ang = []
    for f in range(NF):
        X = cskin(sk, G[f])[0][m]; w = wt[m]; j = G[f][it][:3, 3]
        v = np.subtract(A[f]["toe_DirectionPoint_" + s], A[f]["toe_MainPoint_" + s]); h = np.array([v[0], 0.0, v[2]]); h /= np.linalg.norm(h)
        k = np.cross(h, [0.0, 1.0, 0.0]); k /= np.linalg.norm(k)
        def low(a):
            R = rodr(k, np.radians(a)); return float((X[:, 1] + w * ((X - j) @ (R - np.eye(3)).T)[:, 1]).min()) - ground   # LBS: x + w (R - I)(x - j)
        if low(0.0) >= MG: ang.append(0.0); continue
        lo, hi = 0.0, 80.0
        if low(hi) < MG: ang.append(hi); continue
        for _ in range(18):
            mid = (lo + hi) / 2
            lo, hi = (mid, hi) if low(mid) < MG else (lo, mid)
        ang.append(round(hi, 2))
    res[s] = ang
    nz = [(f, a) for f, a in enumerate(ang) if a > 0]
    print("TOEANG", s, "frames", len(nz), "max %.1f" % max([a for _, a in nz] or [0]), nz)
json.dump(res, open(out, "w"))
