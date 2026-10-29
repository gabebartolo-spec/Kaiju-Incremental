"""lscan.py KEY: joint-level leg screen of a rise draft (no Cascadeur): per leg, frames where the knee reach clamp sits on
its 45 deg floor (hip-ankle = floor distance), the foot slide after the plant FD1 (rbars U3), the lowest foot joint vs
the rest frame's, and the biggest one-frame foot jump."""
import sys, os, json
os.environ["DK_STAGE"] = "adolescent"
import numpy as np, math
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts"); import dk
FJ = json.load(open(dk.HERE + "frames_%s.json" % sys.argv[1])); FR = FJ["frames"]; FD1 = FJ["meta"]["FD1"]; NF = len(FR)
P = lambda f, k: np.array(FR[f][k])
out = []
for s in "lr":
    H = lambda f: P(f, "thigh_MainPoint_" + s); Kn = lambda f: P(f, "shin_MainPoint_" + s); A = lambda f: P(f, "foot_MainPoint_" + s)
    L1 = np.linalg.norm(Kn(NF - 1) - H(NF - 1)); L2 = np.linalg.norm(A(NF - 1) - Kn(NF - 1))
    dfl = math.sqrt(L1 * L1 + L2 * L2 - 2 * L1 * L2 * math.cos(math.radians(45.05)))
    cl = [f for f in range(NF) if np.linalg.norm(A(f) - H(f)) < dfl + 0.02]
    sl = max(np.linalg.norm(A(f) - A(FD1)) for f in range(FD1, NF))
    low = min((A(f)[1] - A(NF - 1)[1], f) for f in range(NF))
    jump = max((np.linalg.norm(A(f + 1) - A(f)), f + 1) for f in range(NF - 1))
    out.append("%s clamp %d f (%s) slide %.2f low %+.2f f%d jump %.2f f%d" % (s, len(cl), "%d-%d" % (cl[0], cl[-1]) if cl else "-", sl, *low, *jump))
print("LSCAN %s FD1 %d | %s" % (sys.argv[1], FD1, " | ".join(out)))
