"""Cascadeur skin dumps (cdump_<tag>.npz under $KAIJU_FIT_DATA/cd, from the rigger's job_casc_dump.py): cload(tag) ->
mesh, weights, inverse binds, bindShape and per-frame joint matrices; cskin(sk, G) = sum_j w_j G_j IB_j BS p."""
import os, numpy as np
D = os.environ.get("KAIJU_FIT_DATA", "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix/").rstrip("/") + "/"
def cload(tag):
    z = np.load(D + "cd/cdump_%s.npz" % tag); n = [str(x) for x in z["names"]]
    W = np.zeros((len(z["P"]), len(n))); W[z["wi"], z["wj"]] = z["ww"]
    return dict(P=z["P"], T=z["C"].reshape(-1, 3), W=W, IB=z["IB"], BS=z["BS"], names=n, G=z["G"], POS=z["POS"], ROT=z["ROT"])
def cskin(sk, G):
    Pb = (sk["BS"] @ sk["P"].T).T[:, :3] if sk["P"].shape[1] == 4 else (sk["BS"][:3, :3] @ sk["P"].T).T + sk["BS"][:3, 3]
    Ph = np.c_[Pb, np.ones(len(Pb))]; X = np.zeros((len(Pb), 3))
    for j in range(len(sk["names"])):
        w = sk["W"][:, j]
        if w.any(): X += w[:, None] * (Ph @ (G[j] @ sk["IB"][j]).T)[:, :3]
    return X, Pb
