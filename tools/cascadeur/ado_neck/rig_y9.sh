# build croc_adolescent_rig_y9.casc (ya9.fbx = y8 + nsmooth neck0/neck1 patch), then key/dump/measure slam_stop on it
cd C:/Users/DANTE/cascadeur_bridge/croc_young; bash casc_run.sh C:/Users/DANTE/cascadeur_bridge/croc_young job_rig_young.py 600 work/rig_ya9.log
grep -E "saved|ERR|rror|JOB_EXIT" work/rig_ya9.log | cut -c1-200; ls -la work/croc_adolescent_rig_y9.casc || exit 1
sleep 20; bash C:/Users/DANTE/cascadeur_bridge/croc_new/claw/drafts/run_y9.sh
