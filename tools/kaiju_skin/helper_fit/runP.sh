#!/bin/bash
# step 2 of the shipped fit: every frame (STEP=1) from runM's M2_l / M1_r, keeping their masks -> opt3_P1_*.json
cd "$(dirname "$0")"; export KAIJU_FIT_DATA="${KAIJU_FIT_DATA:-C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix}"; K=$KAIJU_FIT_DATA
C="TOPK=3 TOPFIX=1 TOPEVERY=0 GAME=1 PUSHQ=1 LCL=1 CLEAN=0 JC=0 CW=10 BW=200 RG=1000 DMAX=6 CAP=0.8 EV=500 KINDS=hip,knee,web,ankle,belly IT=6000 STEP=1 SM=20"
(env $C SIDE=l P0=$K/opt3_M2_l.json SW=50 LR=0.01 OUT=P1 timeout 3500 python opt3.py 2>&1 | grep -v Warn > $K/fit_P1_l.log) &
(env $C SIDE=r P0=$K/opt3_M1_r.json SW=50 LR=0.01 OUT=P1 timeout 3500 python opt3.py 2>&1 | grep -v Warn > $K/fit_P1_r.log) &
wait; grep -H "kept\|^start\|^best" $K/fit_P1_l.log $K/fit_P1_r.log
