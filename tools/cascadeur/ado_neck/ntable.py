"""ntable.py TAG...: the rigger's head/neck table on a cdump (croc_young/skinfix/cd/cdump_<TAG>.npz).
twist: per joint pair, rotation vs bind (dbg_twist.py method), clip max, bar < 60 deg.
tris: regions.measure flips + collapsed per frame on head (neck2/head/jaw/lids) and neck (neck0/neck1), bar <= 6 every frame."""
import sys
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix")
import numpy as np
import regions
from cascflip import cload
from regions import polar
regions.REG = {"head": regions.REG["head"], "neck": ("neck0", "neck1")}
PAIRS = [("chest", "neck0"), ("neck0", "neck1"), ("neck1", "neck2"), ("neck2", "head")]
for tag in sys.argv[1:]:
    sk = cload(tag); n = sk["names"]; G = sk["G"]; bind = [np.linalg.inv(I) for I in sk["IB"]]
    tw = []
    for a, b in PAIRS:
        ia, ib = n.index(a), n.index(b); R0 = polar(bind[ia][:3, :3]).T @ polar(bind[ib][:3, :3])
        A = []
        for f in range(len(G)):
            D = (polar(G[f][ia][:3, :3]).T @ polar(G[f][ib][:3, :3])) @ R0.T
            A.append(np.degrees(np.arccos(np.clip((np.trace(D) - 1) / 2, -1, 1))))
        A = np.array(A); tw.append((a, b, A.max(), int(A.argmax())))
    out = regions.measure(sk)
    bad = np.array([[r[1] + r[2] for r in out[k]] for k in ("head", "neck")]).sum(0)
    tot = bad.max(); wf = int(bad.argmax()); over = int((bad > 6).sum())
    ok = all(t[2] < 60 for t in tw) and tot <= 6
    print("%s %s | twist max: %s | head+neck flip+collapsed tris max %d @f%d, frames over 6: %d/%d" % (
        "PASS" if ok else "FAIL", tag, ", ".join("%s>%s %.0f@f%d" % t for t in tw), tot, wf, over, len(bad)), flush=True)
