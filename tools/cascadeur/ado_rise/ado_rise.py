"""ado_rise.py TAG [k=v ...]: the Behemoth's rise_bay (D-270, D-373) on the y7 adolescent rig: the adult's approved
rise_p (croc_new/rig11/roar_intro/rise_keys.py: under hold, head, shoulders, legs push last, settle to rest by ~f108,
rest hold) run on dk's adolescent croc_pose, lengths x dk.K, the adult's 30 fps timing (1.0x, as the adult's rise_bay).
dk.pose adds the tail points (rise_p's tail pitch curve), the knee reach clamp and limb planes; the jaw curve goes to
jaw_<key>.json. k=v overrides rise_keys' env knobs (lengths in ADULT cm, scaled here). Writes drafts/frames+cfg via dk.save.
python ado_rise.py r1   (no -I: dk needs numpy)"""
import os, sys, json
os.environ["DK_STAGE"] = "adolescent"
TAG = sys.argv[1]; os.environ["DK_SUFFIX"] = "_rise_" + TAG
for kv in sys.argv[2:]:
    k, v = kv.split("="); os.environ[k] = v
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts")
import dk  # noqa: E402
cp = dk.cp; K = dk.K
LEN = {"Y0": -18.2, "YP": -8.0, "YD": -13.0, "ILIFT": 3.0, "RLIFT": 0.6, "LIFT": 0.0}
for k, v in LEN.items():
    os.environ[k] = str(float(os.environ.get(k, v)) * K)
cp.Rig.pose = dk._p0 if dk.DROPX else cp.Rig.pose   # DROPX goes into the body instead, so the FK legs see the same hip
sys.argv = [sys.argv[0], TAG]
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_new/rig11/roar_intro")
import rise_keys as rk  # noqa: E402
_py = rk.py
def body(f):
    pt = rk.hermite(rk.PIT, f)
    return (0.0, _py(f) + dk.DROPX + rk.PCOMP * max(0.0, pt - rk.P0) * (1.0 - rk.ss(rk.PU0, rk.FD1, f)), 0.0), rk.rd(rk.Z, pt)
rk.body = body
if "TSC" in os.environ or "TLP" in os.environ:   # r4: the tail's pitch at SC / LP-4 (rise_p: TP0+4, -12)
    rk.TAILP = rk.flat([(0, rk.TP0), (rk.U0 + 2, rk.TP0), (rk.HB + 2, rk.TP0 + 6), (rk.SC, float(os.environ.get("TSC", rk.TP0 + 4))),
                        (rk.LP - 4, float(os.environ.get("TLP", "-12"))), (rk.LP + 8, 4.0), (rk.SE + 4, 0.0)])
rig = rk.rig; NF = int(os.environ.get("NFR", "120"))
tail = dk.Tail([rk.hermite(rk.TAILP, f) for f in range(NF)], [0.0] * NF)
FR = [dk.pose(rig, rk.frame(f), f, tail) for f in range(NF)]
import numpy as _np
def _knee(H, K, A, L1, L2):   # two-bone knee for hip H, ankle A (rest lengths), bent to the side the old knee K was on
    u = (A - H) / _np.linalg.norm(A - H); d = min(_np.linalg.norm(A - H), L1 + L2 - 1e-4); a = (L1 * L1 - L2 * L2 + d * d) / (2 * d)
    w = (K - H) - _np.dot(K - H, u) * u; w /= _np.linalg.norm(w); return H + u * a + w * (max(L1 * L1 - a * a, 0.0) ** 0.5)
_TS = json.load(open(os.environ["TOESKIN"])) if os.environ.get("TOESKIN") else None   # r5: {"l": [cm/f], "r": [..]}
if os.environ.get("TOEFLOOR", "0") == "1":   # r3: no toe/heel point under its standing height (the FK ride blend dips the
    for f in range(NF):                        # foot 0.3-1.7 cm under its plant before FD1): lift that leg's foot+toe points
        for s in "lr":                         # rigidly, re-solve the knee at the rest lengths, the shin's points ride it
            g = [k for k in FR[f] if k.startswith(("foot_", "toe_")) and k.endswith("_" + s)]
            d = min(FR[f][k][1] - FR[-1][k][1] for k in g if k.startswith(("toe_", "foot_Self")))
            d = min(d, 0.0) - (_TS[s][f] if _TS else 0.0)   # r5: + the skin dip measured on Cascadeur's solve (skindip.py)
            if d >= 0.0: continue
            V = lambda f_, k: _np.array(FR[f_][k], float)
            H, Kn, A = V(f, "thigh_MainPoint_" + s), V(f, "shin_MainPoint_" + s), V(f, "foot_MainPoint_" + s)
            L1 = _np.linalg.norm(V(-1, "shin_MainPoint_" + s) - V(-1, "thigh_MainPoint_" + s)); L2 = _np.linalg.norm(V(-1, "foot_MainPoint_" + s) - V(-1, "shin_MainPoint_" + s))
            for k in g: FR[f][k] = (FR[f][k][0], round(FR[f][k][1] - d, 4), FR[f][k][2])
            K2 = _knee(H, Kn, V(f, "foot_MainPoint_" + s), L1, L2); dK = K2 - Kn
            for k in [k for k in FR[f] if k.startswith("shin_") and k.endswith("_" + s)]:
                FR[f][k] = tuple(round(float(c), 4) for c in V(f, k) + dK)
key = dk.KEY("rise_bay") + "_rise_" + TAG
dk.save("rise_bay", FR, {"reach": rig.reach, "note": "Behemoth rise_bay %s from rise_p" % TAG, "FD1": rk.FD1, "SE": rk.SE,
                         "phases": {"U0": rk.U0, "HB": rk.HB, "SC": rk.SC, "LP": rk.LP, "SE": rk.SE}})
jaw = {f: rk.hermite(rk.JAW, f) for f in range(NF)}
jp = dk.HERE + "jaw_%s.json" % key
json.dump({"deg": {str(f): round(d, 3) for f, d in jaw.items()}, "stage": dk.STAGE}, open(jp, "w"))
cf = dk.HERE + "cfg_%s.json" % key; c = json.load(open(cf)); c["jaw"] = jp; json.dump(c, open(cf, "w"))
print("RISE", key, "NF", NF, "FD1", rk.FD1, "SE", rk.SE, "K %.3f" % K, "jaw peak %.1f" % max(jaw.values()))
