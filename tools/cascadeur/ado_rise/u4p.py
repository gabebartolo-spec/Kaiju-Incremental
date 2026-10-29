"""u4p.py KEY: rbars' U3 slide + U4 (pelvis speed, accel spike) on the frames alone (no cdump)."""
import sys, os, json
os.environ["DK_STAGE"] = "adolescent"; sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts")
import numpy as np, dk
K = dk.K; FJ = json.load(open(dk.HERE + "frames_%s.json" % sys.argv[1])); FR = FJ["frames"]; NF = len(FR); FD1 = FJ["meta"]["FD1"]
foot = {s: np.array([FR[f]["foot_MainPoint_" + s] for f in range(FD1, NF)]) for s in "lr"}
slide = max(np.linalg.norm(foot[s] - foot[s][0], axis=1).max() for s in "lr")
pel = np.array([FR[f]["pelvis_MainPoint"][1] for f in range(NF)]); vp = np.abs(np.diff(pel)).max() / dk.HIP
pts = [p for p in FR[0] if not p.startswith("tail")]
P = np.array([[FR[f][p] for p in pts] for f in range(NF)]); A = np.linalg.norm(P[2:] - 2 * P[1:-1] + P[:-2], axis=2)
spk, wh = 0.0, None
for f in range(2, len(A) - 2):
    for j in range(len(pts)):
        if A[f, j] < 0.3 * K: continue
        r = A[f, j] / max(A[f - 2, j], A[f - 1, j], A[f + 1, j], A[f + 2, j], 1e-6)
        if r > spk: spk, wh = r, (pts[j], f + 1)
print("U4P %s slide %.2f | pelvis %.3f | spike x%.2f %s" % (sys.argv[1], slide, vp, spk, wh))
