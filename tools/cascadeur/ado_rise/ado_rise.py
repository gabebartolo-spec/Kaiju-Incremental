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
rig = rk.rig; NF = int(os.environ.get("NFR", "120"))
tail = dk.Tail([rk.hermite(rk.TAILP, f) for f in range(NF)], [0.0] * NF)
FR = [dk.pose(rig, rk.frame(f), f, tail) for f in range(NF)]
key = dk.KEY("rise_bay") + "_rise_" + TAG
dk.save("rise_bay", FR, {"reach": rig.reach, "note": "Behemoth rise_bay %s from rise_p" % TAG, "FD1": rk.FD1, "SE": rk.SE,
                         "phases": {"U0": rk.U0, "HB": rk.HB, "SC": rk.SC, "LP": rk.LP, "SE": rk.SE}})
jaw = {f: rk.hermite(rk.JAW, f) for f in range(NF)}
jp = dk.HERE + "jaw_%s.json" % key
json.dump({"deg": {str(f): round(d, 3) for f, d in jaw.items()}, "stage": dk.STAGE}, open(jp, "w"))
cf = dk.HERE + "cfg_%s.json" % key; c = json.load(open(cf)); c["jaw"] = jp; json.dump(c, open(cf, "w"))
print("RISE", key, "NF", NF, "FD1", rk.FD1, "SE", rk.SE, "K %.3f" % K, "jaw peak %.1f" % max(jaw.values()))
