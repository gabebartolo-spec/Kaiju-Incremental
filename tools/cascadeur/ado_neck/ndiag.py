"""ndiag.py TAG: per-frame head/neck flips+collapsed (ntable regions) for frames with any bad tris."""
import sys
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix")
import numpy as np, regions
from cascflip import cload
regions.REG = {"head": regions.REG["head"], "neck": ("neck0", "neck1")}
sk = cload(sys.argv[1]); out = regions.measure(sk)
print("keys per row:", len(out["head"][0]), out["head"][0][:3])
for f in range(len(out["head"])):
    h, k = out["head"][f], out["neck"][f]
    if h[1] + h[2] + k[1] + k[2]: print("f%3d head flip %d coll %d | neck flip %d coll %d" % (f, h[1], h[2], k[1], k[2]))
