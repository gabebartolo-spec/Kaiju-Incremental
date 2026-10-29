#!/bin/bash
# runTab.sh <left spec> <right spec> <out.md>: the in-game top-3 bar table over all 13 Colossus clips
cd "$(dirname "$0")"; export KAIJU_FIT_DATA="${KAIJU_FIT_DATA:-C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix}"; K=$KAIJU_FIT_DATA
L=${1:-$K/opt3_X1_l.json}; R=${2:-$K/opt3_P1_r.json}; O=${3:-$K/table.md}
CLEAN=0 GAME=1 TOP3=1 SPECS=$L,$R timeout 3000 python heval3.py ad_walk ad_hlt f1_charge f2_charge f3_charge kw4_charge f1_emerge f1_hlt f1_run f1_slam kw4_slam f2_leap f2_beam 2>&1 | grep -v Warn > $O
grep -v "^|---" $O | cut -d'|' -f2,4,5,6,8,9,10,12
