# croc-claw rise/run_pc.sh TAG: key + dump + measure a posechk batch (rise/posechk.py TAG "...", already written)
T=$1; D=C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts; G=C:/Users/DANTE/cascadeur_bridge/croc_new/claw/grown_fix1
KEY=adolescent_rise_pc_$T
OUT=$(python -c "import json; print(json.load(open('$D/cfg_$KEY.json'))['out'])")
cd $G; bash grun.sh $KEY 2>&1 | grep -E "==|SAVED|rror|RAM"
sed "s/dump_cfg_p8.json/dump_cfg_pc$T.json/" $D/job_casc_dump_p8.py > $D/job_casc_dump_pc$T.py
echo "{\"out\": \"C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix/cd\", \"cascs\": [[\"ado_pc_$T\", \"$OUT.casc\"]]}" > $D/dump_cfg_pc$T.json
for i in $(seq 16); do bash C:/kt/wait_window.sh >/dev/null && break; done
bash C:/kt/casc_lock.sh acquire keyer 5 || exit 1
timeout 300 C:/Python314/python.exe -I C:/Users/DANTE/cascadeur_bridge/cs.py $D/job_casc_dump_pc$T.py 280 > $D/dump_pc$T.log 2>&1; echo dump rc=$?
bash C:/kt/casc_lock.sh release keyer; grep -E "CDUMP|ERR" $D/dump_pc$T.log | cut -c1-200
timeout 600 python C:/Users/DANTE/cascadeur_bridge/croc_new/claw/rise/pcmeas.py $T
