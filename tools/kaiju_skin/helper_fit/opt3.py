"""D-374 helper fit, torch autograd. Per side, per helper (hip pelvis/thigh, knee thigh/shin, web pelvis/shin):
rotation = Ra expmap(frac r) (r = rotvec of Ra^T Rb, b's turn relative to a vs rest), pivot c to the pair's average,
push (helper frame) = D1 r + d (1 - cos|r|)/2. Weights share=1 (helper takes 2 min(wa, wb)). Loss over every tri with a
vert in the leg or helper zone: soft flips, soft collapse (CW, x10 outside the knee crease), stretch past
max(plain, CAP) (SW), mean move^2 (DW). All frames of TRAIN (STEP), no thigh-angle exclusion.
env: SIDE=l KINDS=hip,knee,web STEP=2 IT=600 LR=0.02 CAP=0.8 SW=5 CW=2 DW=0.02 OUT=name
writes opt3_<OUT>_<side>.json {kinds, side, helpers:[{a,b,frac,d,D1,c}]}"""
import os, json, time, numpy as np, torch
from cascflip import cload
from regions import polar, tri, REG
from helpers import rot_of
from scipy.spatial.transform import Rotation as Rot

torch.set_num_threads(4)
D = os.environ.get("KAIJU_FIT_DATA", "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix/").rstrip("/") + "/"; E_ = os.environ.get
S = E_("SIDE", "l"); KINDS = E_("KINDS", "hip,knee,web").split(","); STEP = int(E_("STEP", "2")); IT = int(E_("IT", "600"))
LR, CAP, SW, CW, DW, KC = (float(E_(k, v)) for k, v in (("LR", "0.02"), ("CAP", "0.8"), ("SW", "5"), ("CW", "2"), ("DW", "0.02"), ("KC", "0.05")))
TRAIN = E_("TRAIN", "ad_walk,ad_hlt,f1_charge,f2_charge,f1_emerge,f1_hlt,f1_run,f1_slam,f2_leap").split(",")
PAIR = {"hip": ("pelvis", "thigh_" + S), "knee": ("thigh_" + S, "shin_" + S), "web": ("pelvis", "shin_" + S), "ankle": ("shin_" + S, "foot_" + S), "belly": ("pelvis", "thigh_" + S)}
SINGLE = {"belly"}

base = cload("r12m"); GAME = E_("GAME", "0") == "1"
if GAME:  # fit what the game skins: merged chains (game_proxy)
    import game_proxy; base = game_proxy.gameify(base)
n = base["names"]; T = base["T"]; W0 = base["W"]; NJ = len(n)
Pb = (base["BS"] @ base["P"].T).T[:, :3]
CLEAN = float(E_("CLEAN", "0"))
if CLEAN:
    W0 = W0.copy()
    for sd in "lr":
        sh_ = n.index("shin_" + sd); m = W0[:, sh_] >= CLEAN
        for jn in ("pelvis", "lumbar0", "lumbar1"):
            j = n.index(jn); W0[m, sh_] += W0[m, j]; W0[m, j] = 0
    print("CLEAN", CLEAN, "verts", int((base["W"] != W0).any(1).sum()), flush=True)
pairs = [(n.index(PAIR[k][0]), n.index(PAIR[k][1])) for k in KINDS]
hipc = np.linalg.inv(base["IB"][n.index("thigh_" + S)])[:3, 3]; BR = float(E_("BR", "5"))
common = [np.minimum(W0[:, a], W0[:, b]) if k not in SINGLE else W0[:, a] * (np.linalg.norm(Pb - hipc, axis=1) < BR) for k, (a, b) in zip(KINDS, pairs)]; cs = [(Pb * c[:, None]).sum(0) / c.sum() for c in common]
if E_("JC", "1") == "1": cs = [np.linalg.inv(base["IB"][b])[:3, 3] for a, b in pairs]
cs = [hipc if k in SINGLE else c for k, c in zip(KINDS, cs)]   # pivot = child joint centre
legj = [n.index("thigh_" + S), n.index("shin_" + S)]
zone = np.isin(W0.argmax(1), legj) | (np.array(common).sum(0) > 1e-4)
tm = zone[T].any(1); vs = np.unique(T[tm]); rm = -np.ones(len(Pb), int); rm[vs] = np.arange(len(vs)); Tl = rm[T[tm]]
W = W0[vs].copy(); cols = []
for k, (a, b), c in zip(KINDS, pairs, common):
    g = c[vs]; W[:, a] -= g
    if k in SINGLE: cols.append(g)
    else: W[:, b] -= g; cols.append(2 * g)
W = np.c_[W, np.array(cols).T]; W /= W.sum(1, keepdims=True)
J = [j for j in range(NJ) if W0[vs][:, j].any()]; NH = len(KINDS)
dom = W[Tl].sum(1).argmax(1)
crease = (np.minimum(W0[:, legj[0]], W0[:, legj[1]]) >= KC)[T[tm]].any(1)
n0, a0 = tri(Pb[vs], Tl); ok = a0 > 1e-6 * a0.max()
El = np.unique(np.sort(np.r_[Tl[:, [0, 1]], Tl[:, [1, 2]], Tl[:, [2, 0]]], 1), axis=0); le0 = np.linalg.norm(Pb[vs][El[:, 0]] - Pb[vs][El[:, 1]], axis=1)
Ph = np.c_[Pb[vs], np.ones(len(vs))]
Ys, Xps, Rds, RA, RV, TG = [], [], [], [], [], []; CAPF = []; STRICT = E_("STRICT", "ad_walk,ad_hlt").split(",")
for t in TRAIN:
    G = game_proxy.gameify(dict(cload(t), W=W0))["G"] if GAME else cload(t)["G"]
    for f in range(0, len(G), STEP):
        Ms = np.array([G[f][j] @ base["IB"][j] for j in range(NJ)])
        Y = np.einsum("vk,jik->jvi", Ph, Ms[J])[:, :, :3]; Ys.append(Y); CAPF.append(float(E_("SCAP", "0.02")) if t in STRICT else CAP)
        Xps.append(np.einsum("vj,jvi->vi", W0[vs][:, J], Y))
        Rj = np.array([polar(M[:3, :3]) for M in Ms]); ra, rv, tg = [], [], []
        for (a, b), c in zip(pairs, cs):
            Ra, Rb = rot_of(Ms[a]), rot_of(Ms[b]); ra.append(Ra); rv.append(Rot.from_matrix(Ra.T @ Rb).as_rotvec())
            ch = np.r_[c, 1]; tg.append(0.5 * ((Ms[a] @ ch)[:3] + (Ms[b] @ ch)[:3]))
        Rds.append(Rj); RA.append(ra); RV.append(rv); TG.append(tg)
F = len(Ys); print("side", S, "frames", F, "zone tris", int(tm.sum()), "verts", len(vs), flush=True)
tt = lambda x: torch.tensor(np.asarray(x), dtype=torch.float64)
Ys, Xps, Rds, RA, RV, TG = tt(Ys), tt(Xps), tt(Rds), tt(RA), tt(RV), tt(TG)
Wbase = tt(W0[vs]); Ccom = tt(np.array([c[vs] for c in common]).T); PA = [a for a, b in pairs]; PB_ = [b for a, b in pairs]
SH = torch.full((len(vs), NH), 4.0, dtype=torch.float64, requires_grad=E_("PV", "1") == "1")
Ei = torch.tensor(El); FMASK = tt([0.0 if k in SINGLE else 1.0 for k in KINDS]); MULT = tt([1.0 if k in SINGLE else 2.0 for k in KINDS])
Tl_t = torch.tensor(Tl); El_t = torch.tensor(El); n0t, a0t, le0t = tt(n0), tt(a0), tt(le0); C = tt(np.array(cs)); P0 = tt(Pb[vs])
legm = torch.tensor(np.isin(W0[T[tm]].sum(1).argmax(1), legj)); emask = torch.tensor(le0 > 1e-4)
vd0 = W0[vs].argmax(1); legE = torch.tensor(np.isin(vd0[El], legj).all(1) & (le0 > 1e-4)); CAPF = torch.tensor(CAPF, dtype=torch.float64)
okt = torch.tensor(ok); cw = torch.where(torch.tensor(crease), 1.0, 10.0).double()
domt = torch.tensor(dom); Jt = torch.tensor(J)


def expmap(v):                                                 # (..., 3) -> (..., 3, 3)
    th = v.norm(dim=-1, keepdim=True).clamp_min(1e-9); k = v / th; th = th[..., None]
    K = torch.zeros(v.shape[:-1] + (3, 3), dtype=v.dtype)
    K[..., 0, 1], K[..., 0, 2], K[..., 1, 2] = -k[..., 2], k[..., 1], -k[..., 0]; K = K - K.transpose(-1, -2)
    return torch.eye(3, dtype=v.dtype) + torch.sin(th) * K + (1 - torch.cos(th)) * (K @ K)


frac = torch.full((NH,), 0.5, dtype=torch.float64, requires_grad=True)
dv = torch.zeros((NH, 3), dtype=torch.float64, requires_grad=True); D1 = torch.zeros((NH, 3, 3), dtype=torch.float64, requires_grad=True)
if E_("P0"):
    jj = json.load(open(E_("P0"))); j0 = jj["helpers"]; ov = {v: i for i, v in enumerate(jj.get("verts", []))}
    with torch.no_grad():
        for k, h in enumerate(j0):
            frac[k] = h["frac"]; dv[k] = tt(h["d"]); D1[k] = tt(h.get("D1", np.zeros((3, 3))))
            if "share" in h:
                sh0 = np.array([h["share"][ov[v]] if v in ov else 0.98 for v in vs]); SH[:, k] = torch.logit(tt(sh0).clamp(1e-4, 1 - 1e-4))


TOPK = int(E_("TOPK", "0")); TOPFIX = E_("TOPFIX", "1") == "1"; TMASK = None; PUSHQ = E_("PUSHQ", "0") == "1"; LCL = E_("LCL", "0") == "1"; SHIN = n.index("shin_" + S); PLJ = [n.index(x) for x in ("pelvis", "lumbar0", "lumbar1")]
if TOPK and E_("P0") and jj.get("top") and jj.get("verts") == vs.tolist():   # keep the P0 fit's own support mask
    TMASK = torch.zeros((len(vs), NJ + NH), dtype=torch.float64)
    for r_, cs_ in enumerate(jj["top"]): TMASK[r_, cs_] = 1.0
    print("P0 mask kept", flush=True)
CMASK = tt((W0[vs][:, SHIN] >= float(E_("CMIN", "0.3"))).astype(float)); BMASK = tt((np.linalg.norm(Pb[vs] - hipc, axis=1) < BR).astype(float))
CL = torch.full((len(vs),), -6.0, dtype=torch.float64, requires_grad=LCL)
if E_("P0") and jj.get("clean"):
    with torch.no_grad(): c0_ = np.array([jj["clean"][ov[v]] if v in ov else 0.0 for v in vs]); CL[:] = torch.logit(tt(c0_).clamp(2.5e-3, 1 - 1e-4))


EPL = torch.zeros(NJ, dtype=torch.float64); EPL[PLJ] = 1.0; ESH = torch.zeros(NJ, dtype=torch.float64); ESH[SHIN] = 1.0
EA = torch.zeros((NH, NJ), dtype=torch.float64); EB = torch.zeros((NH, NJ), dtype=torch.float64)
for k_, (a_, b_) in enumerate(pairs):
    EA[k_, a_] = 1.0
    if KINDS[k_] not in SINGLE: EB[k_, b_] = 1.0


def wmat():
    Wb = Wbase
    if LCL:
        m = (torch.sigmoid(CL) * CMASK)[:, None]
        Wb = Wb * (1 - m * EPL) + (Wb * EPL).sum(1, keepdim=True) * m * ESH
        Cc = torch.stack([torch.minimum(Wb[:, a], Wb[:, b]) if k not in SINGLE else Wb[:, a] * BMASK for k, (a, b) in zip(KINDS, pairs)], 1)
    else: Cc = Ccom
    sh = torch.sigmoid(SH) * Cc
    Wb = Wb - sh @ EA - sh @ EB
    Wb = torch.cat([Wb.clamp_min(0), sh * MULT], 1); Wb = Wb / Wb.sum(1, keepdim=True)
    if TOPK:  # the game keeps each voxel's 3 biggest bones (tools/kaiju_skin/bake.py top3): fit what it keeps
        global TMASK
        if TMASK is None or not TOPFIX:
            k = torch.topk(Wb.detach(), TOPK, dim=1).indices; TMASK = torch.zeros_like(Wb).scatter_(1, k, 1.0)
        Wb = Wb * TMASK; Wb = Wb / Wb.sum(1, keepdim=True).clamp_min(1e-12)
    return Wb


def pose(idx):
    Wt = wmat(); fr = frac.clamp(0.05, 0.95) * FMASK
    rv = RV[idx]; th = rv.norm(dim=-1, keepdim=True)                       # (B, H, 3)
    R = RA[idx] @ expmap(fr[None, :, None] * rv)                           # (B, H, 3, 3)
    push = torch.einsum("hij,bhj->bhi", D1, rv) + dv[None] * (1 - torch.cos(th)) / 2
    if PUSHQ: push = (torch.einsum("hij,bhj->bhi", D1, rv) + dv[None]) * (1 - torch.cos(th)) / 2
    Yh = torch.einsum("bhij,vj->bhvi", R, P0) + (TG[idx] - torch.einsum("bhij,hj->bhi", R, C) + torch.einsum("bhij,bhj->bhi", R, push))[:, :, None]
    X = torch.einsum("vj,bjvi->bvi", Wt[:, Jt], Ys[idx]) + torch.einsum("vh,bhvi->bvi", Wt[:, NJ:], Yh)
    Rall = torch.cat([Rds[idx], R], 1)                                     # joint index NJ+k = helper k
    return X, Rall


def tris(X):
    a, b, c = X[:, Tl_t[:, 0]], X[:, Tl_t[:, 1]], X[:, Tl_t[:, 2]]; cr = torch.cross(b - a, c - a, dim=-1)
    ar = cr.norm(dim=-1); return cr / ar.clamp_min(1e-12)[..., None], ar


def loss(idx, detail=False):
    X, Rall = pose(idx); n1, a1 = tris(X)
    with torch.no_grad(): Wd = wmat(); dmt = torch.cat([Wd[:, :NJ], Wd[:, NJ:]], 1)[Tl_t].sum(1).argmax(1)
    ref = torch.einsum("btij,tj->bti", Rall[:, dmt], n0t); dots = (ref * n1).sum(-1)
    dl = ((X[:, El_t[:, 0]] - X[:, El_t[:, 1]]).norm(dim=-1) / le0t.clamp_min(1e-4) - 1).abs() * emask
    Xp = Xps[idx]; dlp = ((Xp[:, El_t[:, 0]] - Xp[:, El_t[:, 1]]).norm(dim=-1) / le0t.clamp_min(1e-4) - 1).abs() * emask
    L = ((torch.relu(0.3 - dots) ** 2) * okt).sum() + CW * ((torch.relu(0.3 - a1 / a0t) ** 2) * cw * okt).sum()
    RG = float(E_("RG", "0"))
    if RG: L = L + RG * len(idx) / 64 * (torch.relu(dv.norm(dim=-1) - float(E_("DMAX", "6"))) ** 2 + torch.relu(D1.flatten(1).norm(dim=-1) - float(E_("DMAX", "6"))) ** 2).sum()
    BW = float(E_("BW", "0"))
    if BW: L = L + BW * ((torch.relu(0.05 - dots) * okt).sum() + (torch.relu(0.15 - a1 / a0t) * okt * ~torch.tensor(crease)).sum())
    if LCL: L = L + float(E_("SM", "50")) * ((torch.sigmoid(CL)[Ei[:, 0]] - torch.sigmoid(CL)[Ei[:, 1]]) ** 2).sum() * len(idx) / 64
    if SH.requires_grad: L = L + float(E_("SM", "50")) * ((torch.sigmoid(SH)[Ei[:, 0]] - torch.sigmoid(SH)[Ei[:, 1]]) ** 2).sum() * len(idx) / 64
    L = L + SW * (torch.relu(dl - torch.maximum(dlp, CAPF[idx][:, None])) ** 2).sum() + DW * ((X - Xp).norm(dim=-1) ** 2).mean(1).sum()
    if detail:
        print("  terms flip %.0f coll %.0f stretch %.0f move %.0f" % (((torch.relu(0.3 - dots) ** 2) * okt).sum(), CW * ((torch.relu(0.3 - a1 / a0t) ** 2) * cw * okt).sum(), SW * (torch.relu(dl - torch.maximum(dlp, CAPF[idx][:, None])) ** 2).sum(), DW * ((X - Xp).norm(dim=-1) ** 2).mean(1).sum()))
        fl = ((dots < 0) & okt & legm).sum(1); co = ((a1 < 0.1 * a0t) & okt & legm & ~torch.tensor(crease)).sum(1)
        fo = ((dots < 0) & okt & ~legm).sum(1); co = torch.stack([co, ((a1 < 0.1 * a0t) & okt & ~legm).sum(1), fo])
        sx = ((dl - dlp) * legE).max(1).values * (CAPF[idx] < CAP)
        co = torch.cat([co, sx[None] * 100])
        return L, fl, co, dl.max(1).values, (X - Xp).norm(dim=-1).max(1).values
    return L


with torch.no_grad():
    R0 = Rds[:, torch.tensor(W0[T[tm]].sum(1).argmax(1))]; n1p, a1p = tris(Xps); dp = (torch.einsum("btij,tj->bti", R0, n0t) * n1p).sum(-1)
    print("PLAIN leg flips max %d frames>6 %d coll-out %d | belly flips %d coll %d" % (((dp < 0) & okt & legm).sum(1).max(), (((dp < 0) & okt & legm).sum(1) > 6).sum(),
          ((a1p < 0.1 * a0t) & okt & legm & ~torch.tensor(crease)).sum(1).max(), ((dp < 0) & okt & ~legm).sum(1).max(), ((a1p < 0.1 * a0t) & okt & ~legm).sum(1).max()), flush=True)
opt = torch.optim.Adam([frac, dv, D1] + ([SH] if SH.requires_grad else []) + ([CL] if LCL else []), lr=LR); sch = torch.optim.lr_scheduler.CosineAnnealingLR(opt, max(IT, 1), eta_min=LR * 0.05); t0 = time.time(); B = int(E_("B", "64")); g = torch.Generator().manual_seed(7)
with torch.no_grad(): _, fl, co, st, mv = loss(torch.arange(F), True)
print("start max flips %d frames>6 %d coll-out %d | belly coll %d flips %d" % (fl.max(), (fl > 6).sum(), co[0].max(), co[1].max(), co[2].max()), flush=True)
pw = (fl.double() + 1) ** 2
import copy
PB_F, PB_C = int(((dp < 0) & okt & ~legm).sum(1).max()), int(((a1p < 0.1 * a0t) & okt & ~legm).sum(1).max())
def key(fl, co): return (int(co[0].max()) + int((fl > 6).sum()) + max(int(co[2].max()) - PB_F, 0) + max(int(co[1].max()) - PB_C, 0) + int(co[3].max() > 5), int(fl.max()), int(co[2].max()), int(co[1].max()))
best = (key(fl, co), [frac.detach().clone(), dv.detach().clone(), D1.detach().clone(), SH.detach().clone(), CL.detach().clone()], None if TMASK is None else TMASK.clone())
for it in range(IT):
    if TOPK and TOPFIX and int(E_("TOPEVERY", "0")) and it % int(E_("TOPEVERY", "0")) == 0: TMASK = None
    idx = torch.multinomial(pw, B, replacement=False, generator=g) if E_("HARD", "1") == "1" else torch.randperm(F, generator=g)[:B]; opt.zero_grad(); L = loss(idx); L.backward(); opt.step(); sch.step()
    if it % int(E_("EV", "100")) == int(E_("EV", "100")) - 1:
        with torch.no_grad(): Lf, fl, co, st, mv = loss(torch.arange(F), True)
        pw = (fl.double() + 1) ** 2
        if key(fl, co) < best[0]: best = (key(fl, co), [frac.detach().clone(), dv.detach().clone(), D1.detach().clone(), SH.detach().clone(), CL.detach().clone()], None if TMASK is None else TMASK.clone())
        print("walk stretch excess %.0f pts" % float(co[3].max()), end=" "); print("it %d loss %.1f max flips %d frames>6 %d coll-out %d | belly coll %d flips %d | stretch %.0f%% move %.2f %.0fs" % (it + 1, Lf, fl.max(), (fl > 6).sum(), co[0].max(), co[1].max(), co[2].max(), 100 * st.max(), mv.max(), time.time() - t0), flush=True)
print("best", best[0], flush=True)
with torch.no_grad():
    for v, b in zip([frac, dv, D1, SH, CL], best[1]): v.copy_(b)
out = {"top": None if best[2] is None else [torch.nonzero(r).flatten().tolist() for r in best[2]], "nj": NJ, "pushq": PUSHQ, "verts": vs.tolist(), "clean": (torch.sigmoid(CL) * CMASK).detach().tolist() if LCL else None, "kinds": KINDS, "side": S, "helpers": [dict(a=n[a], b=n[b], frac=float(frac[k].detach().clamp(0.05, 0.95)), d=dv[k].detach().tolist(), D1=D1[k].detach().tolist(), c=cs[k].tolist(), share=torch.sigmoid(SH[:, k]).detach().tolist()) for k, (a, b) in enumerate(pairs)]}
json.dump(out, open(D + "opt3_%s_%s.json" % (E_("OUT", "x"), S), "w"))
