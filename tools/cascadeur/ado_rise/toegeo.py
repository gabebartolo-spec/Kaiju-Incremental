"""toegeo.py TAG KEY F: the lowest toe-zone skin vertex at frame F vs its rest (last frame): position, and the toe points' heights."""
import sys, json
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix")
import numpy as np
from cascflip import cload, cskin
tag, key, F = sys.argv[1], sys.argv[2], int(sys.argv[3])
sk = cload(tag); n = sk["names"]; G = sk["G"]; dom = np.array(n)[sk["W"].argmax(1)]
X = cskin(sk, G[F])[0]; XR = cskin(sk, G[-1])[0]; ground = XR[:, 1].min()
for s in "lr":
    m = np.where([d.startswith(("foot", "toe")) and d.endswith("_" + s) for d in dom])[0]; i = m[X[m, 1].argmin()]
    j = n.index("toe_" + s); jf = n.index("foot_" + s)
    print(s, "v%d dom %s y %+.2f (rest %+.2f) | joint toe y %+.2f rest %+.2f | vert rel toe joint now %s rest %s" % (
        i, dom[i], X[i, 1] - ground, XR[i, 1] - ground, G[F][j][1, 3] - ground, G[-1][j][1, 3] - ground,
        np.round(X[i] - G[F][j][:3, 3], 2), np.round(XR[i] - G[-1][j][:3, 3], 2)))
    def ang(M): return np.degrees(np.arctan2(M[1, 0], M[0, 0])), np.degrees(np.arctan2(M[2, 1], M[2, 2]))
    print("   toe frame pitch/roll now %.1f/%.1f rest %.1f/%.1f; foot now %.1f/%.1f rest %.1f/%.1f" % (*ang(G[F][j]), *ang(G[-1][j]), *ang(G[F][jf]), *ang(G[-1][jf])))
FR = json.load(open("C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts/frames_%s.json" % key))["frames"]
for k in sorted(FR[F]):
    if k.startswith(("toe_", "foot_")) and k.endswith("_r"): print("  ", k, FR[F][k], "rest", FR[-1][k])
