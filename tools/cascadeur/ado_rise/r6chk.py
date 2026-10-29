"""r6chk.py CAND_KEY: offline proxies for r6 on the r4 cdump (ado_rise_r4) + r4 frames.
toes: each foot/toe-dominated vertex turned with the toe (the rotation taking r4's toe Main->Direction to the candidate's,
about the cdump toe joint) -> lowest leg skin per frame. tail: r4's lowest tail skin + the candidate's tail09 tip point rise.
neck: head_Main/Direction moves vs r4 (head world pose), neck1 pitch share. U2 start lows: legs from the toe proxy."""
import sys, json
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix")
import numpy as np
from cascflip import cload, cskin
D = "C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts/"
A = json.load(open(D + "frames_adolescent_rise_bay_rise_r4.json"))["frames"]; B = json.load(open(D + "frames_%s.json" % sys.argv[1]))["frames"]
sk = cload("ado_rise_r4"); n = sk["names"]; G = sk["G"]; NF = len(G); dom = np.array(n)[sk["W"].argmax(1)]
X = [cskin(sk, G[f])[0] for f in range(NF)]; ground = X[-1][:, 1].min()


def rot_ab(a, b):
    a = a / np.linalg.norm(a); b = b / np.linalg.norm(b); v = np.cross(a, b); c = np.dot(a, b)
    if np.linalg.norm(v) < 1e-9: return np.eye(3)
    K = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]]); return np.eye(3) + K + K @ K / (1 + c)


def kab(P, Q):   # rotation taking the vectors P (rows) onto Q (rows), least squares
    U, _, Vt = np.linalg.svd(np.array(P).T @ np.array(Q)); d = np.sign(np.linalg.det(Vt.T @ U.T))
    return Vt.T @ np.diag([1, 1, d]) @ U.T


W = sk["W"]; legmin = (99, 0, ""); startleg = 99
for f in range(NF):
    for s in "lr":
        M, Dn, Ad = "toe_MainPoint_" + s, "toe_DirectionPoint_" + s, "toe_AdditionalPoint_" + s
        R = kab([np.subtract(A[f][Dn], A[f][M]), np.subtract(A[f][Ad], A[f][M])], [np.subtract(B[f][Dn], B[f][M]), np.subtract(B[f][Ad], B[f][M])])
        j = G[f][n.index("toe_" + s)][:3, 3]; it, i_f, i_s = n.index("toe_" + s), n.index("foot_" + s), n.index("shin_" + s)
        dt = np.subtract(B[f][M], A[f][M]); df = np.subtract(B[f]["foot_MainPoint_" + s], A[f]["foot_MainPoint_" + s])
        ds = np.subtract(B[f]["shin_MainPoint_" + s], A[f]["shin_MainPoint_" + s])
        m = (W[:, it] + W[:, i_f] + W[:, i_s]) > 0.3
        Xm = X[f][m]; y = Xm + W[m, it][:, None] * ((Xm - j) @ (R - np.eye(3)).T + dt) + W[m, i_f][:, None] * df + W[m, i_s][:, None] * ds
        lo = y[:, 1].min() - ground
        if lo < legmin[0]: legmin = (lo, f, s)
        if f < 12: startleg = min(startleg, lo)
mt = np.array([d.startswith("tail") for d in dom]); tl = (99, 0)
for f in range(NF):
    dy = B[f]["tail09_DirectionPoint"][1] - A[f]["tail09_DirectionPoint"][1]
    lo = X[f][mt][:, 1].min() - ground + dy; tl = min(tl, (lo, f))
hm = max(np.linalg.norm(np.subtract(B[f][k], A[f][k])) for f in range(NF) for k in ("head_MainPoint", "head_DirectionPoint"))
hd = max(abs(np.degrees(np.arctan2(*np.subtract(B[f]["head_DirectionPoint"], B[f]["head_MainPoint"])[[1, 0]]) -
                        np.arctan2(*np.subtract(A[f]["head_DirectionPoint"], A[f]["head_MainPoint"])[[1, 0]]))) for f in range(NF))
print("R6CHK %s | legs skin proxy min %+.2f f%d %s, start (f<12) %+.2f | tail skin proxy min %+.2f f%d | head point move max %.2f cm, "
      "head dir change max %.2f deg" % (sys.argv[1], *legmin, startleg, *tl, hm, hd))
