"""tpose.py TAG..: per cdump, frames where a limb sits within TOL deg of the BIND (T-) pose: every bone of that limb's
local rotation (vs its parent) within TOL of its bind local rotation. Also the standing-rest closeness (last frame) for
reference. Prints the frame list per limb."""
import sys
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix")
import numpy as np
from cascflip import cload
TOL = 5.0
LIMBS = {"arm_l": ["clavicle_l", "upperarm_l", "forearm_l", "hand_l"], "arm_r": ["clavicle_r", "upperarm_r", "forearm_r", "hand_r"],
         "leg_l": ["thigh_l", "shin_l", "foot_l", "toe_l"], "leg_r": ["thigh_r", "shin_r", "foot_r", "toe_r"]}
PAR = {"clavicle_l": "chest", "clavicle_r": "chest", "thigh_l": "pelvis", "thigh_r": "pelvis"}
def ang(R):
    return float(np.degrees(np.arccos(np.clip((np.trace(R) - 1) / 2, -1, 1))))
def rot(M):
    R = M[:3, :3]; return R / np.linalg.norm(R, axis=0)
for tag in sys.argv[1:]:
    sk = cload(tag); n = sk["names"]; G = sk["G"]; NF = len(G); B = [np.linalg.inv(I) for I in sk["IB"]]
    out = []
    for limb, bones in LIMBS.items():
        near_b, near_r, worst_min = [], [], 999.0
        for f in range(NF):
            db, dr_ = 0.0, 0.0
            for i, b in enumerate(bones):
                p = PAR.get(b, bones[i - 1] if i else None); j, q = n.index(b), n.index(p)
                L = rot(G[f][q]).T @ rot(G[f][j]); Lb = rot(B[q]).T @ rot(B[j]); Lr = rot(G[-1][q]).T @ rot(G[-1][j])
                db = max(db, ang(Lb.T @ L)); dr_ = max(dr_, ang(Lr.T @ L))
            worst_min = min(worst_min, db)
            if db < TOL: near_b.append(f)
            if dr_ < TOL: near_r.append(f)
        out.append("%s bind-near %d f %s (min %.1f) rest-near %d f" % (limb, len(near_b), (near_b[:3], near_b[-3:]) if near_b else "", worst_min, len(near_r)))
    print(tag, "NF", NF, "|", " | ".join(out))
