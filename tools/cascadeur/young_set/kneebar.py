"""kneebar.py TAG..: hind-leg fold bar (director 2026-10-29, the 90 deg knee in the swing). Per frame from the cdump joints:
knee = angle thigh->shin->foot (180 straight), pitch = thigh (hip->knee) angle from world down. Bar: knee min >= 125,
pitch max <= 35, knee rate <= 6 deg/frame."""
import sys
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix")
import numpy as np
from cascflip import cload
KMIN, PMAX, RATE = 125.0, 35.0, 6.0
ang = lambda a, b: np.degrees(np.arccos(np.clip(np.sum(a * b, -1) / np.linalg.norm(a, axis=-1) / np.linalg.norm(b, axis=-1), -1, 1)))
for tag in sys.argv[1:]:
    sk = cload(tag); n = sk["names"]; P = np.array(sk["G"])[:, :, :3, 3]; ok = True; line = []
    for s in "lr":
        t, k, f = (P[:, n.index(j + "_" + s)] for j in ("thigh", "shin", "foot"))
        kn = ang(t - k, f - k); pt = ang(k - t, np.array([0, -1.0, 0])); r = np.abs(np.diff(kn))
        p = kn.min() >= KMIN and pt.max() <= PMAX and r.max() <= RATE; ok &= p
        line.append("%s knee min %5.1f@f%-3d max %5.1f | pitch max %4.1f@f%-3d | rate %4.1f@f%-3d%s" % (
            s, kn.min(), kn.argmin(), kn.max(), pt.max(), pt.argmax(), r.max(), r.argmax(), "" if p else "  X"))
    print("%s %s\n  %s" % (tag, "PASS" if ok else "FAIL", "\n  ".join(line)))
