"""ntri.py TAG: head vs neck flip+collapsed tris per frame where any > 0, and the neck pair angles (pitch/yaw/roll about the child's axes) there."""
import sys
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix")
import numpy as np
import regions
from cascflip import cload
from regions import polar
regions.REG = {"head": regions.REG["head"], "neck": ("neck0", "neck1")}
sk = cload(sys.argv[1]); n = sk["names"]; G = sk["G"]; bind = [np.linalg.inv(I) for I in sk["IB"]]
out = regions.measure(sk)
def eul(a, b, f):
    ia, ib = n.index(a), n.index(b); R0 = polar(bind[ia][:3, :3]).T @ polar(bind[ib][:3, :3])
    D = R0.T @ (polar(G[f][ia][:3, :3]).T @ polar(G[f][ib][:3, :3]))
    return np.degrees([np.arctan2(D[2, 1], D[2, 2]), np.arcsin(-np.clip(D[2, 0], -1, 1)), np.arctan2(D[1, 0], D[0, 0])])
for f in range(len(G)):
    h = out["head"][f][1] + out["head"][f][2]; k = out["neck"][f][1] + out["neck"][f][2]
    if h + k > 3 or f in (0, 179):
        print("f%d head %d neck %d | n0>n1 %s n1>n2 %s chest>n0 %s" % (f, h, k, *["%+.0f/%+.0f/%+.0f" % tuple(eul(a, b, f)) for a, b in (("neck0", "neck1"), ("neck1", "neck2"), ("chest", "neck0"))]))
