"""heval3.py tag... : D-374 bar table, every frame, both legs + head + body, plain r12m skin vs r13 (CLEAN + helpers).
env SPECS=opt3_c1_l.json,opt3_c2_r.json CLEAN=0.7 KC=0.05. Uses the numpy reference model helpers2.py (not the torch fit).
Per clip: leg_X flips max@f, frames>6, collapsed out of the knee crease max, collapsed max, stretch max %;
head and body flips/collapsed max (body = every tri not in the head or legs)."""
import os, sys, json, numpy as np
import regions
from regions import measure, tri, COLLAPSE
from cascflip import cload, cskin
import helpers2, game_proxy
GAME = os.environ.get("GAME") == "1"   # skin as the game does: merged chains (game_proxy.gameify), TOP3 = bake.py top3

E_ = os.environ.get
base = cload("r12m"); n = base["names"]; T = base["T"]; W0 = base["W"]
regions.REG["body"] = tuple(x for x in n if not any(x in v for k, v in regions.REG.items() if k != "body"))
KC = float(E_("KC", "0.05"))
crease = {s: (np.minimum(W0[:, n.index("thigh_" + s)], W0[:, n.index("shin_" + s)]) >= KC)[T].any(1) for s in "lr"}
specs = helpers2.load_specs(E_("SPECS", "opt3_c1_l.json,opt3_c2_r.json").split(","))
W0c = helpers2.clean(W0, n, float(E_("CLEAN", "0.7")))


def top3(W):
    W = W.copy(); idx = np.argsort(-W, 1)[:, 3:]; np.put_along_axis(W, idx, 0, 1); W /= W.sum(1, keepdims=True)
    return np.round(W * 255) / np.maximum(np.round(W * 255).sum(1, keepdims=True), 1)


def table(sk):
    if E_("TOP3"): sk = dict(sk, W=(game_proxy.top3 if GAME else top3)(sk["W"]))
    o = measure(sk, Wreg=W0)
    bind = np.array([np.linalg.inv(I) for I in sk["IB"]]); _, Pb = cskin(sk, bind); _, a0 = tri(Pb, T)
    dom = W0[T].sum(1).argmax(1); oc = {s: [] for s in "lr"}
    for f in range(len(sk["G"])):
        X = cskin(sk, sk["G"][f])[0]; _, a1 = tri(X, T)
        for s in "lr":
            m = np.isin(dom, [n.index("thigh_" + s), n.index("shin_" + s)]) & (a0 > 1e-6 * a0.max())
            oc[s].append(int((m & ~crease[s] & (a1 < COLLAPSE * a0)).sum()))
    r = {}
    for s in "lr":
        rows = o["leg_" + s]; wf = max(rows, key=lambda x: x[1])
        r[s] = dict(fl=wf[1], f=wf[0], n6=sum(x[1] > 6 for x in rows), oc=max(oc[s]), co=max(x[2] for x in rows), st=max(x[3] for x in rows))
    for g in ("head", "body"): r[g] = dict(fl=max(x[1] for x in o[g]), co=max(x[2] for x in o[g]))
    return r, len(sk["G"])


print("| clip | frames | leg L flips max (plain) | L frames>6 | L coll out-crease (plain) | leg R flips max (plain) | R frames>6 | R coll out-crease (plain) | stretch max L/R % (plain) | body flips/coll (plain) | head flips/coll (plain) |")
print("|---|---|---|---|---|---|---|---|---|---|---|")
for t in sys.argv[1:]:
    sk = cload(t); sk = game_proxy.gameify(dict(sk, W=W0)) if GAME else sk
    p, nf = table(dict(sk, W=sk["W"] if GAME else W0)); h, _ = table(helpers2.add(sk, specs, game_proxy.gameify(dict(sk, W=W0c))["W"] if GAME else W0c))
    print("| %s | %d | %d@f%d (%d) | %d (%d) | %d (%d) | %d@f%d (%d) | %d (%d) | %d (%d) | %.0f/%.0f (%.0f/%.0f) | %d/%d (%d/%d) | %d/%d (%d/%d) |" % (
        t, nf, h["l"]["fl"], h["l"]["f"], p["l"]["fl"], h["l"]["n6"], p["l"]["n6"], h["l"]["oc"], p["l"]["oc"],
        h["r"]["fl"], h["r"]["f"], p["r"]["fl"], h["r"]["n6"], p["r"]["n6"], h["r"]["oc"], p["r"]["oc"],
        h["l"]["st"], h["r"]["st"], p["l"]["st"], p["r"]["st"], h["body"]["fl"], h["body"]["co"], p["body"]["fl"], p["body"]["co"],
        h["head"]["fl"], h["head"]["co"], p["head"]["fl"], p["head"]["co"]), flush=True)
