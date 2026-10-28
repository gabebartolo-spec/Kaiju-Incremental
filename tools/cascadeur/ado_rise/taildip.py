"""taildip.py TAG: per frame 0-40, the lowest tail-zone skin vs seabed and its heaviest joint (cdump)."""
import sys
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix")
import numpy as np
from cascflip import cload, cskin
sk = cload(sys.argv[1]); n = sk["names"]; G = sk["G"]; dom = np.array(n)[sk["W"].argmax(1)]
m = np.array([d.startswith("tail") for d in dom]); ground = cskin(sk, G[-1])[0][:, 1].min(); o = []
for f in range(0, 44, 2):
    y = cskin(sk, G[f])[0][:, 1] - ground; i = np.where(m)[0][y[m].argmin()]; o.append("f%d %+.2f %s" % (f, y[i], dom[i]))
print(" | ".join(o))
