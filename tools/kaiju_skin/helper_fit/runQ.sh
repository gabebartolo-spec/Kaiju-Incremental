#!/bin/bash
# step 3 of the shipped fit: left leg from P1_l with a heavier bar weight -> opt3_X1_l.json (shipped with opt3_P1_r.json)
cd "$(dirname "$0")"; export KAIJU_FIT_DATA="${KAIJU_FIT_DATA:-C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix}"; K=$KAIJU_FIT_DATA
C="TOPK=3 TOPFIX=1 TOPEVERY=0 GAME=1 PUSHQ=1 LCL=1 CLEAN=0 JC=0 RG=1000 DMAX=6 CAP=0.8 EV=500 KINDS=hip,knee,web,ankle,belly IT=5000 STEP=1 SM=20 SW=50 LR=0.008"
env $C SIDE=l P0=$K/opt3_P1_l.json CW=10 BW=600 OUT=X1 timeout 3500 python opt3.py 2>&1 | grep -v Warn > $K/fit_X1_l.log
grep -H "kept\|^start\|^best" $K/fit_X1_l.log
