"""zprox.py: calibrate joint proxies for rbars' zone tops on r2 (cdump ado_rise_r2 vs its frames): offset skin top - joint max."""
import sys, os, json
os.environ["DK_STAGE"] = "adolescent"
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix"); sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts")
import numpy as np
from cascflip import cload, cskin
import dk
FR = json.load(open(dk.HERE + "frames_adolescent_rise_bay_rise_r2.json"))["frames"]
print(sorted(k for k in FR[0] if not k.endswith(("_l", "_r")) and not k.startswith("tail")))
sk = cload("ado_rise_r2"); n = sk["names"]; G = sk["G"]; dom = np.array(n)[sk["W"].argmax(1)]
X = [cskin(sk, G[f])[0] for f in range(0, 120, 4)]
ground = cskin(sk, G[-1])[0][:, 1].min()
bz = np.array([j.startswith(("pelvis", "lumbar")) for j in dom]); sz = np.array([j.startswith(("chest", "clavicle", "upperarm", "forearm", "hand", "neck0", "neck1")) for j in dom])
for i, f in enumerate(range(0, 120, 4)):
    jb = max(FR[f][k][1] for k in FR[f] if k.startswith(("pelvis", "lumbar"))); js = max(FR[f][k][1] for k in FR[f] if k.startswith(("chest", "neck0", "neck1")))
    print(f, "belly skin %.2f joint %.2f d %.2f | sh skin %.2f joint %.2f d %.2f" % (X[i][bz][:, 1].max() - ground, jb - ground, X[i][bz][:, 1].max() - jb, X[i][sz][:, 1].max() - ground, js - ground, X[i][sz][:, 1].max() - js))
