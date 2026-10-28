"""kcd.py TAG...: the rigger's knee bars on a cdump's own solved joints (Cascadeur's output, not the keys): thigh/shin length
vs bind 1.00 +- 0.01, knee interior >= 45 deg, knee ahead of the hip-ankle line (pelvis forward), thigh twist < 5 deg/f."""
import sys
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix")
import numpy as np
from cascflip import cload
from regions import polar
for tag in sys.argv[1:]:
    sk = cload(tag); n = sk["names"]; G = sk["G"]; B = [np.linalg.inv(I) for I in sk["IB"]]
    P = lambda f, j: G[f][n.index(j)][:3, 3]; P0 = lambda j: B[n.index(j)][:3, 3]
    res = []
    for s in "lr":
        th, sh, ft = "thigh_" + s, "shin_" + s, "foot_" + s
        L1, L2 = np.linalg.norm(P0(sh) - P0(th)), np.linalg.norm(P0(ft) - P0(sh))
        lr, kmin, ahead, tw = [], 999, 99, 0.0; prev = None
        for f in range(len(G)):
            H, K, A = P(f, th), P(f, sh), P(f, ft)
            lr += [np.linalg.norm(K - H) / L1, np.linalg.norm(A - K) / L2]
            a, b = H - K, A - K; kmin = min(kmin, np.degrees(np.arccos(np.dot(a, b) / np.linalg.norm(a) / np.linalg.norm(b))))
            fw = P(f, "chest") - P(f, "pelvis"); fw[1] = 0; fw /= np.linalg.norm(fw)
            u = (A - H) / np.linalg.norm(A - H); k = (K - H) - np.dot(K - H, u) * u; ahead = min(ahead, float(np.dot(k, fw)))
            R = polar(G[f][n.index(th)][:3, :3])
            if prev is not None:
                D = prev.T @ R; ax = (K - H) / np.linalg.norm(K - H); axl = R.T @ ax
                ang = np.degrees(np.arccos(np.clip((np.trace(D) - 1) / 2, -1, 1)))
                w = np.array([D[2, 1] - D[1, 2], D[0, 2] - D[2, 0], D[1, 0] - D[0, 1]]); nw = np.linalg.norm(w)
                tw = max(tw, abs(ang * np.dot(w / nw, axl)) if nw > 1e-9 else 0.0)
            prev = R
        lr = np.array(lr); ok = abs(lr - 1).max() <= 0.01 and kmin >= 45 and ahead > 0 and tw < 5
        res.append((ok, "%s len %.3f-%.3f knee min %.1f ahead min %+.2f twist max %.1f deg/f" % (s, lr.min(), lr.max(), kmin, ahead, tw)))
    print("KNEE %s %s | %s" % ("PASS" if all(r[0] for r in res) else "FAIL", tag, " | ".join(r[1] for r in res)), flush=True)
