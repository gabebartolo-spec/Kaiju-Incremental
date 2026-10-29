# ado slam_stop on the y8 rig (neck2/head weight fix): key, dump, neck bar
D=C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts; G=C:/Users/DANTE/cascadeur_bridge/croc_new/claw/grown_fix1
cd $G; bash grun.sh adolescent_slam_stop_y9 2>&1 | grep -E "==|SAVED|rror|RAM"
F=$(ls -t C:/kt/casc_drafts_1028/adolescent/slam_stop_y9*.casc | head -1); echo "CASC $F"
printf '{"out": "C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix/cd", "cascs": [["ado_y9_slam", "%s"]]}' "$F" > $D/dump_cfg_y9.json
sleep 20; bash C:/kt/wait_window.sh; bash C:/kt/casc_lock.sh acquire keyer 5 || exit 1
timeout 300 C:/Python314/python.exe -I C:/Users/DANTE/cascadeur_bridge/cs.py $D/job_casc_dump_y9.py 280 > $D/dump_y9.log 2>&1; echo dump rc=$?
bash C:/kt/casc_lock.sh release keyer; grep -E "CDUMP|ERR|AFTER" $D/dump_y9.log | cut -c1-200
timeout 900 python ntable.py ado_y9_slam
