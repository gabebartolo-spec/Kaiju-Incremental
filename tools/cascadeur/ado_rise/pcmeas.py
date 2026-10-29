"""pcmeas.py TAG: per variant of a posechk dump (cdump ado_pc_<TAG>): zone tops/lows over the seabed (rest frame 0's lowest
skin), back top vs W, head+neck and leg flip+collapsed tris (regions.measure), knee interior."""
import sys, os, json
os.environ["DK_STAGE"] = "adolescent"
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix"); sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts")
import numpy as np
import regions
from cascflip import cload, cskin
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_new/claw/rise")
tag = sys.argv[1]
meta = json.load(open("C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts/frames_adolescent_rise_pc_%s.json" % tag))["meta"]
sk = cload("ado_pc_" + tag); n = sk["names"]; G = sk["G"]
dom = np.array(n)[sk["W"].argmax(1)]
zmap = lambda j: "head" if j.startswith(("neck2", "head", "jaw", "lid_")) else "sh" if j.startswith(("chest", "clav", "upper", "fore", "hand", "neck")) \
    else "belly" if j.startswith(("pelvis", "lumbar")) else "legs" if j.startswith(("thigh", "shin", "foot", "toe")) else "tail"
Z = np.array([zmap(j) for j in dom])
X0 = cskin(sk, G[0])[0]; ground = X0[:, 1].min()
regions.REG = {"head": regions.REG["head"] + ("neck0", "neck1"), "leg_l": regions.REG["leg_l"], "leg_r": regions.REG["leg_r"]}
m = regions.measure(sk)
for f in range(1, len(G), 2):
    X = cskin(sk, G[f])[0]; y = X[:, 1] - ground
    lo = {z: y[Z == z].min() for z in ("belly", "sh", "legs", "tail", "head")}; back = max(y[Z == z].max() for z in ("head", "sh", "belly", "legs"))
    P = lambda j: G[f][n.index(j)][:3, 3]
    kn = [np.degrees(np.arccos(np.dot(P("thigh_" + s) - P("shin_" + s), P("foot_" + s) - P("shin_" + s)) / np.linalg.norm(P("thigh_" + s) - P("shin_" + s)) / np.linalg.norm(P("foot_" + s) - P("shin_" + s)))) for s in "lr"]
    tri = {k: m[k][f][1] + m[k][f][2] for k in m}
    print("%-34s back %5.2f | low %s | tris %s | knee %.0f/%.0f" % (meta["labels"][f], back, " ".join("%s %+.2f" % kv for kv in lo.items()),
          " ".join("%s %d" % kv for kv in tri.items()), *kn))
