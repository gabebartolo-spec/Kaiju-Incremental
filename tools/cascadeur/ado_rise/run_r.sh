# croc-claw rise/run_r.sh TAG: key drafts/cfg_adolescent_rise_bay_rise_<TAG>.json -> its .casc (cfg "out"), dump it
# (cdump ado_rise_<TAG>), measure rbars + ntable + rall + kcd. Behind the speed window; casc lock per job.
T=$1; D=C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts; G=C:/Users/DANTE/cascadeur_bridge/croc_new/claw/grown_fix1; R=C:/Users/DANTE/cascadeur_bridge/croc_new/claw/rise
KEY=adolescent_rise_bay_rise_$T
OUT=$(python -c "import json; print(json.load(open('$D/cfg_$KEY.json'))['out'])")
cd $G; bash grun.sh $KEY 2>&1 | grep -E "==|SAVED|rror|RAM|JAW"
sed "s/dump_cfg_p8.json/dump_cfg_r$T.json/" $D/job_casc_dump_p8.py > $D/job_casc_dump_r$T.py
echo "{\"out\": \"C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix/cd\", \"cascs\": [[\"ado_rise_$T\", \"$OUT.casc\"]]}" > $D/dump_cfg_r$T.json
for i in $(seq 16); do bash C:/kt/wait_window.sh >/dev/null && break; done
bash C:/kt/casc_lock.sh acquire keyer 5 || exit 1
timeout 300 C:/Python314/python.exe -I C:/Users/DANTE/cascadeur_bridge/cs.py $D/job_casc_dump_r$T.py 280 > $D/dump_r$T.log 2>&1; echo dump rc=$?
bash C:/kt/casc_lock.sh release keyer; grep -E "CDUMP|ERR|AFTER" $D/dump_r$T.log | cut -c1-200
cd $R; timeout 900 python rbars.py ado_rise_$T $KEY
cd $G; timeout 900 python ntable.py ado_rise_$T; timeout 600 python rall.py ado_rise_$T; timeout 300 python kcd.py ado_rise_$T
