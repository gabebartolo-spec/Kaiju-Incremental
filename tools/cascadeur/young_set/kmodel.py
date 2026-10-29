"""kmodel.py KD [MOVES..]: key-model hind knee (from hip->foot distance) for fix1/keys/KD/<move>.json, as kn3sim prints it."""
import json, sys
import numpy as np
L = 4.69
for m in sys.argv[2:] or ["walk", "walk_turn_left", "walk_turn_right", "turn_on_the_spot"]:
    K = json.load(open("../fix1/keys/%s/%s.json" % (sys.argv[1], m))); fr = np.array(K["meta"]["keyframes"]); F = np.arange(fr[-1] + 1); air = None; row = []
    for s in "lr":
        h = np.array(K["keys"]["thigh_MainPoint_" + s]); f = np.array(K["keys"]["foot_MainPoint_" + s]); y = f[:, 1] - f[:, 1].min()
        d = np.interp(F, fr, np.linalg.norm(f - h, axis=1)); kn = np.degrees(2 * np.arcsin(np.clip(d / (2 * L), 0, 1)))
        up = np.interp(F, fr, y) > 0.02; air = up if air is None else air & up
        row.append("%s knee %3.0f..%3.0f rate %4.1f@f%d duty %.2f lift %.2f" % (s, kn.min(), kn.max(), np.abs(np.diff(kn)).max(), np.abs(np.diff(kn)).argmax(), 1 - up.mean(), y.max()))
    print("%-17s %s | both up %d f" % (m, " | ".join(row), air.sum()))
