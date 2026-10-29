"""tailp.py KEY..: the tail's lowest joint point over the ground (u1p calibration) and its frame; skin ~ joint - 3.4 (r3 f54)."""
import sys, os, json
os.environ["DK_STAGE"] = "adolescent"
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts"); import dk
G0 = json.load(open(dk.HERE + "frames_adolescent_rise_bay_rise_r2.json"))["frames"]
gnd = max(G0[116][k][1] for k in G0[116] if k.startswith(("pelvis", "lumbar"))) - 24.26
for key in sys.argv[1:]:
    FR = json.load(open(dk.HERE + "frames_%s.json" % key))["frames"]
    lo = min((min(v[1] for k, v in FR[f].items() if k.startswith("tail")) - gnd, f) for f in range(30, len(FR)))
    print("TAILP %s joint low %+.2f f%d" % (key, *lo))
