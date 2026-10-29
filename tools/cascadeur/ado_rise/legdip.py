"""legdip.py TAG..: per cdump, the lowest leg-zone skin vs seabed (last frame's lowest skin) per frame 60-84, by heaviest joint."""
import sys
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix")
import numpy as np
from cascflip import cload, cskin
for tag in sys.argv[1:]:
    sk = cload(tag); n = sk["names"]; G = sk["G"]; NF = len(G); dom = np.array(n)[sk["W"].argmax(1)]
    leg = np.array([d.startswith(("thigh", "shin", "foot", "toe")) for d in dom])
    ground = cskin(sk, G[-1])[0][:, 1].min(); out = []
    for f in range(56, 86, 2):
        y = cskin(sk, G[f])[0][:, 1] - ground; i = np.where(leg)[0][y[leg].argmin()]
        out.append("f%d %+.2f %s" % (f, y[i], dom[i]))
    print(tag, " | ".join(out))
