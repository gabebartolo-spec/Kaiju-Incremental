"""jstretch.py TAG..: per cdump, each joint's offset from its parent in the parent's frame vs the last (rest) frame: worst cm + frame."""
import sys
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix")
import numpy as np
from cascflip import cload
PAR = {"clavicle_r": "chest", "upperarm_r": "clavicle_r", "forearm_r": "upperarm_r", "hand_r": "forearm_r",
       "clavicle_l": "chest", "upperarm_l": "clavicle_l", "forearm_l": "upperarm_l", "hand_l": "forearm_l",
       "thigh_r": "pelvis", "shin_r": "thigh_r", "foot_r": "shin_r", "neck0": "chest", "neck1": "neck0", "neck2": "neck1", "head": "neck2"}
for tag in sys.argv[1:]:
    sk = cload(tag); n = sk["names"]; G = sk["G"]; NF = len(G); out = []
    for j, p in PAR.items():
        if j not in n or p not in n: continue
        loc = lambda f: np.linalg.inv(G[f][n.index(p)]) @ G[f][n.index(j)][:, 3]
        r = loc(NF - 1)[:3]; d = [np.linalg.norm(loc(f)[:3] - r) for f in range(NF)]
        out.append("%s %.2f@f%d" % (j, max(d), int(np.argmax(d))))
    print(tag, " | ".join(out))
