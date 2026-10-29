"""twp.py KEY..: thigh twist proxy from the keys: frame (thigh->shin axis, leg-plane normal from hip/knee/ankle [P] or the
shin_LimbDir pole [L]); per-frame turn about the axis, max deg/f and frames over 3 (left leg)."""
import sys, os, json
import numpy as np
D = "C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts/"
def fr(F, f, s, mode):
    P = lambda k: np.array(F[f][k + "_" + s], float)
    H, K, A = P("thigh_MainPoint"), P("shin_MainPoint"), P("foot_MainPoint"); ax = (K - H) / np.linalg.norm(K - H)
    o = (A - H) if mode == "P" else (P("shin_LimbDir") - H)
    y = o - np.dot(o, ax) * ax; y /= np.linalg.norm(y); return np.stack([ax, y, np.cross(ax, y)], 1)
def rmin(a, b):
    v = np.cross(a, b); c = np.dot(a, b); Kx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]]); return np.eye(3) + Kx + Kx @ Kx / (1 + c)
for key in sys.argv[1:]:
    F = json.load(open(D + "frames_%s.json" % key))["frames"]
    for mode in "PL":
        tw = []
        for f in range(1, len(F)):
            R0, R1 = fr(F, f - 1, "l", mode), fr(F, f, "l", mode); Rm = rmin(R0[:, 0], R1[:, 0]) @ R0   # swing only
            c = np.dot(Rm[:, 1], R1[:, 1]); sN = np.dot(np.cross(Rm[:, 1], R1[:, 1]), R1[:, 0]); tw.append(abs(np.degrees(np.arctan2(sN, c))))
        tw = np.array(tw); print("TWP %s %s max %.1f f%d over3 %s" % (key, mode, tw.max(), tw.argmax() + 1, [int(i + 1) for i in np.where(tw > 3)[0]]))
