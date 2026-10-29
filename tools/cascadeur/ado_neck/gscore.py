"""gscore.py TAG...: head/body flips+collapsed on the cdump's own weights, Cascadeur full vs game proxy (gameify+top3),
all frames (ado_cap.py's row without the cap)."""
import sys
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix")
import numpy as np, regions, game_proxy
from cascflip import cload
from regions import measure
for t in sys.argv[1:]:
    sk = cload(t); n = sk["names"]
    regions.REG["body"] = tuple(x for x in n if not any(x in v for k, v in regions.REG.items() if k != "body"))
    g = game_proxy.gameify(sk); g = dict(g, W=game_proxy.top3(g["W"])); res = []
    for lab, x in (("casc", sk), ("game", g)):
        o = measure(x, Wreg=sk["W"]); hb = np.array([r[1] + r[2] for r in o["head"]]); bb = np.array([r[1] + r[2] for r in o["body"]])
        res.append("%s head %d@f%d (>6:%d) body %d@f%d (>6:%d)" % (lab, hb.max(), hb.argmax(), (hb > 6).sum(), bb.max(), bb.argmax(), (bb > 6).sum()))
    print(t, "|", " | ".join(res), flush=True)
