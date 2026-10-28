"""rbars.py CDUMP_TAG FRAMES_KEY: the adult rise_p's bars U1-U5 (rig11/roar_intro/bars_rise_p.txt) on the Behemoth's
Cascadeur skin (croc_young/skinfix/cd/cdump_<tag>.npz; zones by each vertex's heaviest joint), lengths x dk.K.
Seabed = the lowest skin of the last frame (standing at rest). W = the start's highest back skin + 1 game m
(Behemoth: 260/320 of the adult's 0.3462 m per rig cm). U6/U7 = the rigger's tables (ntable.py, rall.py, kcd.py)."""
import sys, os, json
os.environ["DK_STAGE"] = "adolescent"
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix"); sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts")
import numpy as np
from cascflip import cload, cskin
import dk
tag, key = sys.argv[1], sys.argv[2]; K = dk.K
FJ = json.load(open(dk.HERE + "frames_%s.json" % key)); meta = FJ["meta"]; FR = FJ["frames"]; FD1 = meta["FD1"]
sk = cload(tag); n = sk["names"]; G = sk["G"]; NF = len(G)
X = np.array([cskin(sk, G[f])[0] for f in range(NF)])   # NF x V x 3
dom = np.array(n)[sk["W"].argmax(1)]


def zone(j):
    if j.startswith(("neck2", "head", "jaw", "lid_")): return "head"
    if j.startswith(("chest", "clavicle", "upperarm", "forearm", "hand", "neck0", "neck1")): return "shoulders"
    if j.startswith(("pelvis", "lumbar")): return "belly"
    if j.startswith(("thigh", "shin", "foot", "toe")): return "legs"
    return "tail"


Z = np.array([zone(j) for j in dom]); zs = ["head", "shoulders", "belly", "legs", "tail"]
ground = X[-1][:, 1].min(); M_CM = 0.3462 * 260.0 / 320.0
top = lambda f, z: X[f][Z == z][:, 1].max() - ground
low = lambda f, z: X[f][Z == z][:, 1].min() - ground
U0 = meta["phases"]["U0"]
back = max(top(f, z) for f in range(U0) for z in ("head", "shoulders", "belly", "legs")); W = back + 1.0 / M_CM
res = []; cross = {}
for f in range(NF):
    for z in ("head", "shoulders", "belly"):
        if z not in cross and top(f, z) > W: cross[z] = f
g1 = cross.get("shoulders", 999) - cross.get("head", 0); g2 = cross.get("belly", 999) - cross.get("shoulders", 0)
res.append(("U1 order", g1 >= 12 and g2 >= 12 and len(cross) == 3, "head %s shoulders %s belly %s -> gaps %d / %d f (bar >= 12 each)"
            % (cross.get("head"), cross.get("shoulders"), cross.get("belly"), g1, g2)))
lows0 = {z: min(low(f, z) for f in range(U0)) for z in ("belly", "shoulders", "legs")}
allmin = min((low(f, z), f, z) for f in range(NF) for z in zs)
res.append(("U2 start", back < W and allmin[0] >= -0.05 and min(lows0.values()) < 1.0 * K,
            "start back top %.2f cm vs W %.2f (seabed depth %.2f game m); start lows %s (touching: min < %.2f); lowest skin %+.2f f%d %s (bar >= 0)"
            % (back, W, back * M_CM + 1.0, " ".join("%s %+.2f" % kv for kv in lows0.items()), 1.0 * K, *allmin)))
pel = np.array([FR[f]["pelvis_MainPoint"][1] for f in range(NF)])
sh = cross.get("shoulders", 0); rise = pel.max() - pel[0]; after = pel[sh:].max() - pel[sh] if rise > 0 else 0
foot = {s: np.array([FR[f]["foot_MainPoint_" + s] for f in range(FD1, NF)]) for s in "lr"}
slide = max(np.linalg.norm(foot[s] - foot[s][0], axis=1).max() for s in "lr")
res.append(("U3 legs last", after / rise >= 0.6 and slide <= 1.0 * K, "%.0f %% of the pelvis rise after the shoulders clear (bar >= 60); feet slide from the plant f%d %.2f cm (bar <= %.2f)"
            % (100 * after / rise, FD1, slide, 1.0 * K)))
vp = np.abs(np.diff(pel)).max() / dk.HIP
pts = [p for p in FR[0] if not p.startswith("tail")]
P = np.array([[FR[f][p] for p in pts] for f in range(NF)]); A = np.linalg.norm(P[2:] - 2 * P[1:-1] + P[:-2], axis=2)
spk = 0.0; wh = None
for f in range(2, len(A) - 2):
    for j in range(len(pts)):
        if A[f, j] < 0.3 * K: continue
        nb = max(A[f - 2, j], A[f - 1, j], A[f + 1, j], A[f + 2, j], 1e-6); r = A[f, j] / nb
        if r > spk: spk, wh = r, (pts[j], f + 1)
res.append(("U4 mass", vp <= 0.08 and spk <= 3, "pelvis vertical speed peak %.3f hip/f (bar <= 0.08); worst accel spike x%.2f %s (bar <= 3; under %.2f cm/f2 ignored)"
            % (vp, spk, wh, 0.3 * K)))
rest = dk.pose(dk.cp.Rig(), {}, 0, dk.Tail([0.0], [0.0]))
off = max(np.linalg.norm(np.array(FR[f][p]) - np.array(rest[p])) for f in range(NF - 12, NF) for p in rest)
still = max(np.abs(X[f] - X[NF - 12]).max() for f in range(NF - 12, NF))
res.append(("U5 end", off <= 0.5 and still <= 0.5, "last 12 f max key offset from the rest pose %.3f cm (bar <= 0.5); skin motion within them %.3f cm (bar <= 0.5)" % (off, still)))
for name, ok, txt in res: print("BAR %s %s: %s" % (name, "PASS" if ok else "FAIL", txt))
print("RBARS %s %d/%d" % (tag, sum(r[1] for r in res), len(res)))
