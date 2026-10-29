"""kmin.py TAG..: frames where the knee interior angle (kcd's measure, right leg) is under 45.5 deg."""
import sys
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix")
import numpy as np
from cascflip import cload
for tag in sys.argv[1:]:
    sk = cload(tag); n = sk["names"]; G = sk["G"]; P = lambda f, j: G[f][n.index(j)][:3, 3]; o = []
    for f in range(len(G)):
        a, b = P(f, "thigh_r") - P(f, "shin_r"), P(f, "foot_r") - P(f, "shin_r")
        k = np.degrees(np.arccos(np.dot(a, b) / np.linalg.norm(a) / np.linalg.norm(b)))
        if k < 45.5: o.append("f%d %.2f" % (f, k))
    print(tag, " ".join(o))
