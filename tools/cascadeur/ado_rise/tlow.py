"""tlow.py KEY: lowest leg point (foot/toe joints, both legs) over the ground (calibrated as u1p) per 3 frames 40-90."""
import sys, os, json
os.environ["DK_STAGE"] = "adolescent"
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts"); import dk
FR = json.load(open(dk.HERE + "frames_%s.json" % sys.argv[1]))["frames"]
G0 = json.load(open(dk.HERE + "frames_adolescent_rise_bay_rise_r2.json"))["frames"]
gnd = max(G0[116][k][1] for k in G0[116] if k.startswith(("pelvis", "lumbar"))) - 24.26
r = []
for f in range(0, 100, 3):
    lo = min((FR[f][k][1] - gnd, k) for k in FR[f] if k.startswith(("toe", "foot")))
    r.append("f%d %+.2f %s" % (f, lo[0], lo[1].replace("_MainPoint", "M").replace("_AdditionalPoint", "A").replace("_DirectionPoint", "D").replace("_Self0Point", "S")))
print(sys.argv[1], " ".join(r))
