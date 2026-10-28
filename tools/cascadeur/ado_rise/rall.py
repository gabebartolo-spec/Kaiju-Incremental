"""rall.py TAG...: regions.measure (rigger's default regions) flip+collapsed per region, max over frames, frames over 6."""
import sys
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix")
import numpy as np, regions
from cascflip import cload
for tag in sys.argv[1:]:
    out = regions.measure(cload(tag))
    print(tag, " | ".join("%s max %d over6 %d" % (k, max(r[1] + r[2] for r in v), sum(r[1] + r[2] > 6 for r in v)) for k, v in out.items()), flush=True)
