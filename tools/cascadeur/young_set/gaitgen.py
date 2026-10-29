"""gaitgen.py MOVE OUT.json [T LIFT DUTY]: baby fix1 keys (fix1/fixgen.py, FixRig, arms carried, every frame keyed) with the hind
gait cycle T (s) and swing lift (H) changed. Director 10-29: shorter, quicker steps at the same speed (the old 3 s cycle's
stance swept ~9 cm under a 9.38 cm leg: knee pinned straight, then folded to ~95 deg). Default T 1.5 (stride x0.5, two
cycles in the 3 s loop), LIFT 0.06 H (was 0.18). DUTY (walk pace, default 0.65) stretches the swing. MOVE: walk, walk_turn_left, walk_turn_right, turn_on_the_spot."""
import json, math, sys
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_new/claw/fix1")
import fixgen
kg = fixgen.kg
MOVE, OUT = sys.argv[1], sys.argv[2]
GT = float(sys.argv[3]) if len(sys.argv) > 3 else 1.5
GL = float(sys.argv[4]) if len(sys.argv) > 4 else 0.06
GD = float(sys.argv[5]) if len(sys.argv) > 5 else 0.65
_wq = kg.walk_q
def walk_q(rig, t, v, T=3.0, duty=0.65, lift=0.18, **k):
    if T == 3.0: T, lift, duty = GT, GL, GD         # the walk-pace gait (walk, walk turns); the turn on the spot passes its own T
    return _wq(rig, t, v, T=T, duty=duty, lift=lift, **k)
kg.walk_q = walk_q
_tq = kg.turn_q
kg.turn_q = lambda rig, t, total, secs, T=1.4, duty=0.6, lift=0.14: _tq(rig, t, total, secs, T=T, duty=duty, lift=GL)
@fixgen.move("walk", 3.0, "loop, 3 s, gait T %g s duty %g lift %g H, 0.40 H/s; arms carried" % (GT, GD, GL), "AnimalAnimator walk")
def m_walk(rig, t):
    fixgen._FROM_STAND[0] = False
    q = kg.walk_q(rig, t, 0.40)
    q["head"] = (0, -3 + 1.0 * math.cos(4 * math.pi * t / 3.0), 0)
    return q
K = fixgen.build(MOVE); K["meta"]["note"] += " | gaitgen T %g LIFT %g DUTY %g" % (GT, GL, GD)
json.dump(K, open(OUT, "w")); print("KEYS", MOVE, len(K["meta"]["keyframes"]), "frames")
