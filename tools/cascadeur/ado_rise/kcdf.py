"""kcdf.py TAG: kcd's thigh twist per frame (deg/f about the thigh axis, Cascadeur's solve), frames over 3 deg."""
import sys
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix")
import numpy as np
from cascflip import cload
from regions import polar
sk = cload(sys.argv[1]); n = sk["names"]; G = sk["G"]
for s in "lr":
    th, sh = "thigh_" + s, "shin_" + s; prev = None; out = []
    for f in range(len(G)):
        H, K = G[f][n.index(th)][:3, 3], G[f][n.index(sh)][:3, 3]; R = polar(G[f][n.index(th)][:3, :3])
        if prev is not None:
            D = prev.T @ R; axl = R.T @ ((K - H) / np.linalg.norm(K - H)); ang = np.degrees(np.arccos(np.clip((np.trace(D) - 1) / 2, -1, 1)))
            w = np.array([D[2, 1] - D[1, 2], D[0, 2] - D[2, 0], D[1, 0] - D[0, 1]]); nw = np.linalg.norm(w)
            tw = abs(ang * np.dot(w / nw, axl)) if nw > 1e-9 else 0.0
            if tw > 3: out.append("f%d %.1f" % (f, tw))
        prev = R
    print(s, " ".join(out))
