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
if os.environ.get("KFLOOR"): dk._rc.FLOOR_DEG = float(os.environ["KFLOOR"])   # r7: the knee reach clamp floor (lead: 45.2; bar stays >= 45)
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
if "TSC" in os.environ or "TLP" in os.environ:   # r4: the tail's pitch at SC / LP-4 (rise_p: TP0+4, -12)
    rk.TAILP = rk.flat([(0, rk.TP0), (rk.U0 + 2, rk.TP0), (rk.HB + 2, rk.TP0 + 6), (rk.SC, float(os.environ.get("TSC", rk.TP0 + 4))),
                        (rk.LP - 4, float(os.environ.get("TLP", "-12"))), (rk.LP + 8, 4.0), (rk.SE + 4, 0.0)])
if os.environ.get("TOEFLAT"):   # r6 toes: the toe turns to its standing (world) orientation from TU0 to TU1 as the foot comes down,
    _TU0, _TU1 = (int(v) for v in os.environ["TOEFLAT"].split(",")); _TUP = float(os.environ.get("TUP", "0"))   # so it lands level, not hanging (r4 f70: toe skin 5.5 cm straight
    _foot0 = rk.foot                                                    # under its joint, -1.25 / -2.32 cm under the seabed f70 / f72)
    def _foot_flat(f, x, Rp):
        r = list(_foot0(f, x, Rp)); th = _TUP * rk.ss(_TU0, _TU1, f) * (1.0 - rk.ss(rk.FD1 - 2, rk.FD1 + 6, f))
        if r[2] is None: r[2] = rk.rlerp(r[1], cp.I3, rk.ss(_TU0, _TU1, f))
        r[2] = cp.mm(cp.rd(cp.Z, th), r[2])   # + TUP deg tip-up through the touchdown (r4 f73: a toe/foot vertex 3.2 cm ahead,
        return tuple(r)                        # 3.2 under the toe joint, w toe 0.56, needs ~15 deg), eased out FD1-2..FD1+6
    rk.foot = _foot_flat
rig = rk.rig; NF = int(os.environ.get("NFR", "120"))
tail = dk.Tail([rk.hermite(rk.TAILP, f) for f in range(NF)], [0.0] * NF)
NSPLIT = float(os.environ.get("NSPLIT", "0"))   # r6: share of the NECK pitch moved to the chest point (neck0) and to the head (neck2>head) each
if NSPLIT:
    _frame0 = rk.frame
    def _frame_split(f):
        sp = _frame0(f); nk = rk.hermite(rk.NECK, f); q = dict(sp["q"])
        q["neck1"] = rk.rd(rk.Z, nk * (1.0 - 2.0 * NSPLIT)); q["head"] = rk.rd(rk.Z, rk.hermite(rk.HEAD, f) + nk * NSPLIT)
        sp = dict(sp); sp["q"] = q; return sp
    rk.frame = _frame_split
FR = [dk.pose(rig, rk.frame(f), f, tail) for f in range(NF)]
if NSPLIT:   # the neck0 share: neck1 + head points turn about chest_MainPoint (world Z: this rise is planar); chest, arms and the
    for f in range(NF):   # neck1 pole (rides the chest) stay. Head world rotation = the unsplit one.
        C = FR[f]["chest_MainPoint"]; R = cp.rd(cp.Z, rk.hermite(rk.NECK, f) * NSPLIT)
        for k in [k for k in FR[f] if cp.seg_of(k) in ("neck1", "head")]:
            FR[f][k] = tuple(round(c, 4) for c in cp.add(C, cp.mv(R, cp.sub(FR[f][k], C))))
import numpy as _np
def _knee(H, K, A, L1, L2):   # two-bone knee for hip H, ankle A (rest lengths), bent to the side the old knee K was on
    u = (A - H) / _np.linalg.norm(A - H); d = min(_np.linalg.norm(A - H), L1 + L2 - 1e-4); a = (L1 * L1 - L2 * L2 + d * d) / (2 * d)
    w = (K - H) - _np.dot(K - H, u) * u; w /= _np.linalg.norm(w); return H + u * a + w * (max(L1 * L1 - a * a, 0.0) ** 0.5)
_TS = json.load(open(os.environ["TOESKIN"])) if os.environ.get("TOESKIN") else None   # r5: {"l": [cm/f], "r": [..]}
if os.environ.get("TOEFLOOR", "0") == "1":   # r3: no toe/heel point under its standing height (the FK ride blend dips the
    for f in range(NF):                        # foot 0.3-1.7 cm under its plant before FD1): lift that leg's foot+toe points
        for s in "lr":                         # rigidly, re-solve the knee at the rest lengths, the shin's points ride it
            g = [k for k in FR[f] if k.startswith(("foot_", "toe_")) and k.endswith("_" + s)]
            d = min(FR[f][k][1] - FR[-1][k][1] for k in g if k.startswith(("toe_", "foot_Self")))
            d = min(d, 0.0) - (_TS[s][f] if _TS else 0.0)   # r5: + the skin dip measured on Cascadeur's solve (skindip.py)
            if d >= 0.0: continue
            V = lambda f_, k: _np.array(FR[f_][k], float)
            H, Kn, A = V(f, "thigh_MainPoint_" + s), V(f, "shin_MainPoint_" + s), V(f, "foot_MainPoint_" + s)
            L1 = _np.linalg.norm(V(-1, "shin_MainPoint_" + s) - V(-1, "thigh_MainPoint_" + s)); L2 = _np.linalg.norm(V(-1, "foot_MainPoint_" + s) - V(-1, "shin_MainPoint_" + s))
            for k in g: FR[f][k] = (FR[f][k][0], round(FR[f][k][1] - d, 4), FR[f][k][2])
            K2 = _knee(H, Kn, V(f, "foot_MainPoint_" + s), L1, L2); dK = K2 - Kn
            for k in [k for k in FR[f] if k.startswith("shin_") and k.endswith("_" + s)]:
                FR[f][k] = tuple(round(float(c), 4) for c in V(f, k) + dK)
if os.environ.get("TOEUP", "0") == "1":   # r6: the toe never pitches under its rest pitch (r4 f70-76: toe frame -27.6 deg, its skin
    TM = float(os.environ.get("TOEUPM", "1.0")); TF0 = int(os.environ.get("TOEUPF0", "56"))   # the plant only (the start toes stay as posed)   # 5 cm ahead dips 2.3 cm under the seabed); toe Direction + Additional points
    for s in "lr":                                # turn up about toe_MainPoint; the need is max-filtered +-3 f, then eased (sigma 2 f)
        M, Dn, Ad = "toe_MainPoint_" + s, "toe_DirectionPoint_" + s, "toe_AdditionalPoint_" + s
        pit = lambda v: _np.degrees(_np.arctan2(v[1], _np.hypot(v[0], v[2])))
        v0 = _np.subtract(FR[-1][Dn], FR[-1][M]); need = []
        for f in range(NF):
            v = _np.subtract(FR[f][Dn], FR[f][M]); need.append(max(0.0, pit(v0) - pit(v) + TM) if pit(v) < pit(v0) and f >= TF0 else 0.0)
        need = _np.array(need); mx = _np.array([need[max(0, f - 3):f + 4].max() for f in range(NF)])
        g = _np.exp(-0.5 * (_np.arange(-6, 7) / 2.0) ** 2); g /= g.sum()
        sm = _np.convolve(_np.pad(mx, 6, mode="edge"), g, mode="same")[6:-6]; phi = _np.maximum(sm, need)
        for f in range(NF):
            if phi[f] <= 1e-3: continue
            P0 = _np.array(FR[f][M], float); v = _np.subtract(FR[f][Dn], P0); h = _np.array([v[0], 0.0, v[2]]); h /= _np.linalg.norm(h)
            k = _np.cross(h, [0.0, 1.0, 0.0]); k /= _np.linalg.norm(k); a = _np.radians(phi[f])
            Kx = _np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]]); Rr = _np.eye(3) + _np.sin(a) * Kx + (1 - _np.cos(a)) * Kx @ Kx
            for kk in (Dn, Ad):
                FR[f][kk] = tuple(round(float(c), 4) for c in P0 + Rr @ (_np.array(FR[f][kk], float) - P0))
        print("TOEUP %s max %.1f deg, frames %d" % (s, phi.max(), int((phi > 1e-3).sum())))
if os.environ.get("PLIFT"):   # r8 (lead): the body, not the toe: plift.py's curves from the solved r6/r7 over the plant. Every point
    _PL = json.load(open(os.environ["PLIFT"]))   # up by body[f] except the hind shin/foot/toe; foot+toe up by foot_<s>[f]; knee re-solved
    for f in range(NF):                          # at the rest lengths from the lifted hip + ankle, the shin's points ride it
        dy = _PL["body"][f]
        if dy == 0 and _PL["foot_l"][f] == 0 and _PL["foot_r"][f] == 0: continue
        V = lambda f_, k: _np.array(FR[f_][k], float); old = {s_: V(f, "shin_MainPoint_" + s_) for s_ in "lr"}
        hind = lambda k: k.startswith(("shin_", "foot_", "toe_"))
        for k in FR[f]:
            if not hind(k): FR[f][k] = (FR[f][k][0], round(FR[f][k][1] + dy, 4), FR[f][k][2])
        for s_ in "lr":
            for k in [k for k in FR[f] if k.startswith(("foot_", "toe_")) and k.endswith("_" + s_)]:
                FR[f][k] = (FR[f][k][0], round(FR[f][k][1] + _PL["foot_" + s_][f], 4), FR[f][k][2])
            L1 = _np.linalg.norm(V(-1, "shin_MainPoint_" + s_) - V(-1, "thigh_MainPoint_" + s_)); L2 = _np.linalg.norm(V(-1, "foot_MainPoint_" + s_) - V(-1, "shin_MainPoint_" + s_))
            dK = _knee(V(f, "thigh_MainPoint_" + s_), old[s_], V(f, "foot_MainPoint_" + s_), L1, L2) - old[s_]
            for k in [k for k in FR[f] if k.startswith("shin_") and k.endswith("_" + s_)]:
                FR[f][k] = tuple(round(float(c), 4) for c in V(f, k) + dK)
    print("PLIFT body max %.2f foot max %.2f/%.2f" % (max(_PL["body"]), max(_PL["foot_l"]), max(_PL["foot_r"])))
if os.environ.get("TOEROLL"):   # r7: toe_AdditionalPoint at the standing roll (the rest offset turned by the minimal turn of the
    _R0, _R1 = (int(v) for v in os.environ["TOEROLL"].split(","))   # toe's Main->Direction from rest), full on R0..R1, eased in/out 4 f
    def _rmin(a, b):
        a = a / _np.linalg.norm(a); b = b / _np.linalg.norm(b); v = _np.cross(a, b); c = float(_np.dot(a, b))
        if _np.linalg.norm(v) < 1e-9: return _np.eye(3)
        Kx = _np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]]); return _np.eye(3) + Kx + Kx @ Kx / (1 + c)
    for s_ in "lr":
        M, Dn, Ad = "toe_MainPoint_" + s_, "toe_DirectionPoint_" + s_, "toe_AdditionalPoint_" + s_
        d0 = _np.subtract(FR[-1][Dn], FR[-1][M]); a0 = _np.subtract(FR[-1][Ad], FR[-1][M]); mx = 0.0
        for f in range(NF):
            w = rk.ss(_R0 - 4, _R0, f) * (1.0 - rk.ss(_R1, _R1 + 4, f))
            if w <= 0: continue
            P0 = _np.array(FR[f][M], float); tgt = P0 + _rmin(d0, _np.subtract(FR[f][Dn], P0)) @ a0; old = _np.array(FR[f][Ad], float)
            new = old + w * (tgt - old); r = _np.linalg.norm(old - P0); v = new - P0; new = P0 + v / _np.linalg.norm(v) * r
            mx = max(mx, float(_np.linalg.norm(new - old))); FR[f][Ad] = tuple(round(float(c), 4) for c in new)
        print("TOEROLL %s f%d-%d move max %.2f cm" % (s_, _R0, _R1, mx))
key = dk.KEY("rise_bay") + "_rise_" + TAG
dk.save("rise_bay", FR, {"reach": rig.reach, "note": "Behemoth rise_bay %s from rise_p" % TAG, "FD1": rk.FD1, "SE": rk.SE,
                         "phases": {"U0": rk.U0, "HB": rk.HB, "SC": rk.SC, "LP": rk.LP, "SE": rk.SE}})
jaw = {f: rk.hermite(rk.JAW, f) for f in range(NF)}
jp = dk.HERE + "jaw_%s.json" % key
json.dump({"deg": {str(f): round(d, 3) for f, d in jaw.items()}, "stage": dk.STAGE}, open(jp, "w"))
cf = dk.HERE + "cfg_%s.json" % key; c = json.load(open(cf)); c["jaw"] = jp; json.dump(c, open(cf, "w"))
print("RISE", key, "NF", NF, "FD1", rk.FD1, "SE", rk.SE, "K %.3f" % K, "jaw peak %.1f" % max(jaw.values()))
