# croc-claw: key+measure r4, then its neck1 roll fix (nroll2 on r4's dump) as r4n, key+measure it.
R=C:/Users/DANTE/cascadeur_bridge/croc_new/claw/rise; D=C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts; G=C:/Users/DANTE/cascadeur_bridge/croc_new/claw/grown_fix1
cd $R; bash run_r.sh r4 > r4.log 2>&1
cd $G; DK_STAGE=adolescent DK_SUFFIX=_rise_r4n timeout 600 python nroll2.py ado_rise_r4 adolescent_rise_bay_rise_r4 rise_bay 2>&1 | tail -3
python - <<'PY'
import json
D = "C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts/"
a = json.load(open(D + "cfg_adolescent_rise_bay_rise_r4.json")); b = json.load(open(D + "cfg_adolescent_rise_bay_rise_r4n.json"))
b["jaw"] = a["jaw"]; json.dump(b, open(D + "cfg_adolescent_rise_bay_rise_r4n.json", "w")); print("cfg r4n", b)
PY
cd $R; bash run_r.sh r4n > r4n.log 2>&1
grep -E "BAR|RBARS|FAIL|PASS|max" $R/r4.log $R/r4n.log | cut -c1-300
