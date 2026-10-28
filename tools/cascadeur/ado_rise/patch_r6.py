"""patch_r6.py: adds NSPLIT (r6 neck) and TOEUP (r6 toes) to ado_rise.py. Run once."""
p = "C:/Users/DANTE/cascadeur_bridge/croc_new/claw/rise/ado_rise.py"
s = open(p, encoding="utf-8").read()
assert "NSPLIT" not in s
old = "FR = [dk.pose(rig, rk.frame(f), f, tail) for f in range(NF)]\n"
new = '''NSPLIT = float(os.environ.get("NSPLIT", "0"))   # r6: share of the NECK pitch moved to the chest point (neck0) and to the head (neck2>head) each
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
'''
assert s.count(old) == 1
s = s.replace(old, new)
old2 = "key = dk.KEY(\"rise_bay\") + \"_rise_\" + TAG\n"
new2 = '''if os.environ.get("TOEUP", "0") == "1":   # r6: the toe never pitches under its rest pitch (r4 f70-76: toe frame -27.6 deg, its skin
    TM = float(os.environ.get("TOEUPM", "1.0"))   # 5 cm ahead dips 2.3 cm under the seabed); toe Direction + Additional points
    for s in "lr":                                # turn up about toe_MainPoint; the need is max-filtered +-3 f, then eased (sigma 2 f)
        M, Dn, Ad = "toe_MainPoint_" + s, "toe_DirectionPoint_" + s, "toe_AdditionalPoint_" + s
        pit = lambda v: _np.degrees(_np.arctan2(v[1], _np.hypot(v[0], v[2])))
        v0 = _np.subtract(FR[-1][Dn], FR[-1][M]); need = []
        for f in range(NF):
            v = _np.subtract(FR[f][Dn], FR[f][M]); need.append(max(0.0, pit(v0) - pit(v) + TM) if pit(v) < pit(v0) else 0.0)
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
'''
assert s.count(old2) == 1
s = s.replace(old2, new2 + old2)
open(p, "w", encoding="utf-8", newline="").write(s)
print("patched")
