"""u1p.py KEY [W]: rbars U1 proxy from joints (calibrated on r2 by zprox.py: belly skin top = pelvis/lumbar joints + 6.0,
shoulders = chest/neck0/neck1 + 4.0, head = head points + 0 (crossing only checked vs the shoulders)); W default r2's 23.81."""
import sys, os, json
os.environ["DK_STAGE"] = "adolescent"
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts"); import dk
FR = json.load(open(dk.HERE + "frames_%s.json" % sys.argv[1]))["frames"]; W = float(sys.argv[2]) if len(sys.argv) > 2 else 23.81
g = min(v[1] for k, v in FR[-1].items()) - 0.0
ground = -10.52 - (-10.52 - g)  # rest lowest point
import numpy as np
gr = None
def top(f, pre, off): return max(FR[f][k][1] for k in FR[f] if k.startswith(pre)) + off
# ground: r2 cdump ground vs frame joints: calibrated via the belly offset measured relative to cdump ground
G0 = json.load(open(dk.HERE + "frames_adolescent_rise_bay_rise_r2.json"))["frames"]
# r2 belly joint over ground at f116 = 24.26 -> ground (frame axes) = joint - 24.26
gnd = max(G0[116][k][1] for k in G0[116] if k.startswith(("pelvis", "lumbar"))) - 24.26
cs = cb = None
for f in range(len(FR)):
    if cs is None and top(f, ("chest", "neck1"), 4.0) - gnd > W: cs = f
    if cb is None and top(f, ("pelvis", "lumbar"), 6.0) - gnd > W: cb = f
print("U1P %s shoulders f%s belly f%s gap %s" % (sys.argv[1], cs, cb, (cb - cs) if cs and cb else None))
