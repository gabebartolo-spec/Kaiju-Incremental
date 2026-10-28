"""rdiag.py TAG KEY: which frames put leg tris over 6 (regions.measure), and the tail's skin low vs its joint low per frame."""
import sys, os, json
os.environ["DK_STAGE"] = "adolescent"
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix"); sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts")
import numpy as np, regions
from cascflip import cload, cskin
import dk
tag, key = sys.argv[1:3]; sk = cload(tag); m = regions.measure(sk)
for k in ("leg_l", "leg_r"):
    print(k, "over6:", [(f, v[1] + v[2]) for f, v in enumerate(m[k]) if v[1] + v[2] > 4])
FR = json.load(open(dk.HERE + "frames_%s.json" % key))["frames"]; n = sk["names"]; G = sk["G"]
dom = np.array(n)[sk["W"].argmax(1)]; tz = np.array([j.startswith("tail") for j in dom]); gr = cskin(sk, G[-1])[0][:, 1].min()
for f in range(30, 90, 4):
    X = cskin(sk, G[f])[0]; jl = min(v[1] for kk, v in FR[f].items() if kk.startswith("tail"))
    print(f, "tail skin low %+.2f joint low %+.2f" % (X[tz][:, 1].min() - gr, jl - gr))
