"""slide.py TAG..: planted hind-foot slide on the solved dump: per stance run (foot y <= ground + 0.3), max horizontal drift."""
import sys
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix")
import numpy as np
from cascflip import cload
for tag in sys.argv[1:]:
    sk = cload(tag); n = sk["names"]; P = np.array(sk["G"])[:, :, :3, 3]; out = []
    for s in "lr":
        f = P[:, n.index("foot_" + s)]; g = f[:, 1].min(); st = f[:, 1] <= g + float(__import__("os").environ.get("EPS", "0.3")); worst = 0.0; i = 0
        while i < len(st):
            if st[i]:
                j = i
                while j + 1 < len(st) and st[j + 1]: j += 1
                h = f[i:j + 1][:, [0, 2]]; worst = max(worst, np.linalg.norm(h - h[0], axis=1).max()); i = j + 1
            else: i += 1
        out.append("%s slide %.2f" % (s, worst))
    print(tag, " | ".join(out))
