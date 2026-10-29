"""posechk.py TAG "v;v;..." : static start-pose batch for the Behemoth rise (rise_keys posechk method): frame 0 = rest,
then 2 frames per variant v = Y0,FL,KN,AN,ABD,N0,H0,P0 (Y0 in ADULT cm, scaled x K; FK legs by legs_fk; neck/head pitch).
Writes drafts frames/cfg (key adolescent_rise_pc_<TAG>) for rise/run_pc.sh; pcmeas.py reads the dump."""
import os, sys, json
os.environ["DK_STAGE"] = "adolescent"
TAG, VS = sys.argv[1], sys.argv[2]; os.environ["DK_SUFFIX"] = "_pc_" + TAG
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts")
import dk  # noqa: E402
cp = dk.cp; K = dk.K
cp.Rig.pose = dk._p0
sys.argv = [sys.argv[0], "pc"]
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_new/rig11/roar_intro")
import rise_keys as rk  # noqa: E402
from legs_fk import leg_fk  # noqa: E402
rig = rk.rig; tl = dk.Tail([0.0], [0.0])
FR = [dk.pose(rig, {"T": (0.0, dk.DROPX, 0.0), "Tb": True}, 0, tl)]; LAB = ["rest"]
for v in VS.split(";"):
    c_ = [float(c) for c in v.split(",")] + [rk.TP0]; Y, fl, kn, an, ab, n0, h0, p0, tp = c_[:9]
    sp = rk.frame(0); T = (0.0, Y * K + dk.DROPX, 0.0); Rp = rk.rd(rk.Z, p0); sp["T"] = T; sp["Rp"] = Rp
    sp["q"]["neck1"] = rk.rd(rk.Z, n0); sp["q"]["head"] = rk.rd(rk.Z, h0)
    sp["feet"] = {x: leg_fk(rig, T, Rp, x, fl, kn, an, ab if x == "l" else -ab) for x in "lr"}
    tlv = dk.Tail([tp], [0.0])
    p = dk.pose(rig, sp, 0, tlv); FR += [p, p]; LAB += [v, v]
dk.save("rise", FR, {"labels": LAB, "reach": rig.reach})
print("POSECHK", TAG, len(FR), "frames")
