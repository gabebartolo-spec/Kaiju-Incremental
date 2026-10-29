"""reachpeel.py KEYS_IN KEYS_OUT DROP K C0 CAP: hind leg reach without foot skate. 1. every point except foot_*/toe_* down by
DROP (body lower). 2. foot_*/toe_* swing lift y -> ground + (y - ground) * K. 3. per side and frame, hip(thigh_MainPoint)->foot
distance d > C0 maps to C0 + w tanh((d - C0) / w), w = CAP - C0, by RAISING the foot and its toe/Self0 points (y only): the foot
peels off earlier and sets down later instead of pinning the leg straight; x/z never change (no slide)."""
import json, sys
import numpy as np
def apply(K, drop, k, c0, cap):
    for nm in K["keys"]:
        A = np.array(K["keys"][nm], float)
        if nm.startswith(("foot_", "toe_")): g = A[:, 1].min(); A[:, 1] = g + (A[:, 1] - g) * k
        else: A[:, 1] -= drop
        K["keys"][nm] = A
    w = cap - c0
    for s in "lr":
        v = K["keys"]["foot_MainPoint_" + s] - K["keys"]["thigh_MainPoint_" + s]; d = np.linalg.norm(v, axis=1)
        dn = np.where(d > c0, c0 + w * np.tanh((d - c0) / w), d); hz2 = v[:, 0] ** 2 + v[:, 2] ** 2
        dy = -np.sqrt(np.maximum(dn ** 2 - hz2, 0)) - v[:, 1]
        for nm in K["keys"]:
            if nm.endswith("_" + s) and nm.startswith(("foot_", "toe_")): K["keys"][nm][:, 1] += dy
    for nm in K["keys"]: K["keys"][nm] = K["keys"][nm].round(5).tolist()
    return K
if __name__ == "__main__":
    a = sys.argv; K = apply(json.load(open(a[1])), *map(float, a[3:7]))
    K["meta"]["note"] = K["meta"].get("note", "") + " | reachpeel %s" % " ".join(a[3:7]); json.dump(K, open(a[2], "w"))
