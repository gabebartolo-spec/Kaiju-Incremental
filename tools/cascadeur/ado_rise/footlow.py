"""footlow.py TAG F..: lowest shin/foot-dominated skin vertex per side at frames F (cdump), with position vs foot and toe joints."""
import sys
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix")
import numpy as np
from cascflip import cload, cskin
sk = cload(sys.argv[1]); n = sk["names"]; G = sk["G"]; dom = np.array(n)[sk["W"].argmax(1)]
ground = cskin(sk, G[-1])[0][:, 1].min()
for F in map(int, sys.argv[2:]):
    X = cskin(sk, G[F])[0]
    for s in "r":
        m = np.where([d.startswith(("shin", "foot")) and d.endswith("_" + s) for d in dom])[0]; i = m[X[m, 1].argmin()]
        w = sk["W"][i]; top = np.argsort(w)[::-1][:3]
        print("f%d %s v%d y %+.2f | weights %s | foot joint y %+.2f toe joint y %+.2f" % (F, s, i, X[i, 1] - ground,
              ", ".join("%s %.2f" % (n[t], w[t]) for t in top), G[F][n.index("foot_" + s)][1, 3] - ground, G[F][n.index("toe_" + s)][1, 3] - ground))
