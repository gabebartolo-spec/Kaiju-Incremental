"""skindip.py TAG OUT.json: per frame and side, how far that leg's lowest skin (foot/toe/shin zone) is under the seabed
(last frame's lowest skin), cm, + 0.05 cm margin where it is under -0.04 cm; 0 elsewhere. ado_rise.py TOESKIN=OUT.json lifts that foot by it."""
import sys, json
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix")
import numpy as np
from cascflip import cload, cskin
tag, out = sys.argv[1], sys.argv[2]
sk = cload(tag); n = sk["names"]; G = sk["G"]; NF = len(G); dom = np.array(n)[sk["W"].argmax(1)]
ground = cskin(sk, G[-1])[0][:, 1].min(); res = {"l": [0.0] * NF, "r": [0.0] * NF}
for s in "lr":
    m = np.array([d.startswith(("shin", "foot", "toe")) and d.endswith("_" + s) for d in dom])
    for f in range(NF):
        y = cskin(sk, G[f])[0][m, 1].min() - ground
        res[s][f] = round(float(-y + 0.05), 3) if y < -0.04 else 0.0
json.dump(res, open(out, "w"))
for s in "lr":
    nz = [(f, v) for f, v in enumerate(res[s]) if v > 0]; print(s, "frames", len(nz), "max %.2f" % max([v for _, v in nz] or [0]), nz[:1], nz[-1:])
