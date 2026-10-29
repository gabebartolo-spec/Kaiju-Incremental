import sys, json
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix")
import numpy as np
from cascflip import cload, cskin
D = "C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts/"
A = json.load(open(D + "frames_adolescent_rise_bay_rise_r4.json"))["frames"]
sk = cload("ado_rise_r4"); n = sk["names"]; G = sk["G"]; W = sk["W"]; ground = cskin(sk, G[-1])[0][:, 1].min()
def rodr(k, a):
    K = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]]); return np.eye(3) + np.sin(a) * K + (1 - np.cos(a)) * K @ K
s = "r"; it = n.index("toe_" + s); wt = W[:, it]; idx = np.where(wt > 0.05)[0]
for f in (70, 72, 74):
    X = cskin(sk, G[f])[0]; j = G[f][it][:3, 3]
    v = np.subtract(A[f]["toe_DirectionPoint_" + s], A[f]["toe_MainPoint_" + s]); h = np.array([v[0], 0, v[2]]); h /= np.linalg.norm(h); k = np.cross(h, [0, 1, 0]); k /= np.linalg.norm(k)
    row = []
    for a in (0, 10, 20, 30, 45, 60):
        ys = [(j + rodr(k, np.radians(a * wt[i])) @ (X[i] - j))[1] - ground for i in idx]; b = int(np.argmin(ys)); i = idx[b]
        row.append("a%d %+.2f v%d w%.2f rel(%.1f,%.1f)" % (a, ys[b], i, wt[i], *(X[i] - j)[[0, 1]]))
    print("f%d" % f, " | ".join(row))
