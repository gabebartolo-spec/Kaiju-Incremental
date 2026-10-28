"""tdip.py KEY..: the deepest foot/toe point below its own rest height (last frame), frames 40+ (the draw and plant)."""
import sys, os, json
os.environ["DK_STAGE"] = "adolescent"
sys.path.insert(0, "C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts"); import dk
for key in sys.argv[1:]:
    FR = json.load(open(dk.HERE + "frames_%s.json" % key))["frames"]
    d = min((FR[f][k][1] - FR[-1][k][1], f, k) for f in range(40, len(FR)) for k in FR[f] if k.startswith(("toe", "foot_Self")))
    print("TDIP %s %+.2f f%d %s" % (key, *d))
