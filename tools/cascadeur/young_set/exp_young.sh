#!/usr/bin/env bash
# croc-claw exp_young.sh STAGE CASC CLIP FIRST N [MODE]: a young croc .casc (baby|adolescent, rig y7) into a young .kclip.
# (1) Cascadeur joints FBX (drafts/job_export_joints.py, casc_lock keyer, behind wait_window) -> (2) fullfbx_r12j.py
# (FBXJAW=1) onto croc_young/work/y{b,a}7.blend -> (3) the young-casc branch's tools/blender/croc_adult3_clips.py <MODE>
# into claw/game_out/young/reptilian_<STAGE>.kclip (a NEW file on the y7 skeleton; the lead reconciles the clip set).
set -u
H=C:/Users/DANTE/cascadeur_bridge/croc_new; C=$H/claw; D=$C/drafts; S=$1; CASC=$2; M=$3; FIRST=$4; N=$5; MODE=${6:-still}
REPO="C:/Users/DANTE/cascadeur_bridge/croc_new/claw/young_rise_tools"; O=$C/game_out/young; mkdir -p $O
RB=C:/Users/DANTE/cascadeur_bridge/croc_young/work/y${S:0:1}7.blend
FBX=$O/${S}_${M}_joints.fbx; BL=$O/${S}_${M}.blend; KC=$O/reptilian_${S}.kclip
if [ -z "${SKIPCASC:-}" ]; then
  rm -f $FBX;   echo "{\"casc\": \"$CASC\", \"fbx\": \"$FBX\"}" > $D/job_export.json
  for i in $(seq 16); do bash C:/kt/wait_window.sh >/dev/null && break; done
  bash C:/kt/casc_lock.sh acquire keyer 5 || exit 1
  timeout 600 C:/Python314/python.exe -I C:/Users/DANTE/cascadeur_bridge/cs.py $D/job_export_joints.py 580 > $O/exp_${S}_$M.log 2>&1; rc=$?
  bash C:/kt/casc_lock.sh release keyer
  grep -E "EXPORTED|AFTER|rror|Trace" $O/exp_${S}_$M.log | cut -c1-300; [ $rc -eq 0 ] && [ -f $FBX ] || { echo "EXPORT FAILED rc=$rc"; exit 1; }
fi
for i in $(seq 16); do bash C:/kt/wait_window.sh >/dev/null && break; done
FBXJAW=1 TAILN=40 bash $H/rig10/bl.sh 900 --python $C/fullfbx_r12j.py -- $RB $FBX $BL > $O/bl_${S}_$M.log 2>&1
grep -o "FULLFBX4 saved.*\|HELPERBAKE.*\|FOOTIK.*\|.*rror.*\|EXIT.*" $O/bl_${S}_$M.log | cut -c1-200; [ -f $BL ] || { echo "NO BLEND"; exit 1; }
TAILN=20 bash $H/rig10/bl.sh 900 $BL --python "$REPO/tools/blender/croc_adult3_clips.py" -- $KC $M $FIRST $N $MODE > $O/clip_${S}_$M.log 2>&1
tail -6 $O/clip_${S}_$M.log; ls -la $KC
