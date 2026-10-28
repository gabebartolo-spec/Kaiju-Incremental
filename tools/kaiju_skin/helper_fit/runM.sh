# runM.sh : refit with the fixed top-3 mask saved in the spec (M = mask), from the G3b/G4 specs
cd "$(dirname "$0")"; export KAIJU_FIT_DATA="${KAIJU_FIT_DATA:-C:/Users/DANTE/cascadeur_bridge/croc_young/skinfix}"
C="TOPK=3 TOPFIX=1 TOPEVERY=0 GAME=1 PUSHQ=1 LCL=1 CLEAN=0 JC=0 CW=10 BW=200 RG=1000 DMAX=6 CAP=0.8 EV=500 KINDS=hip,knee,web,ankle,belly IT=${IT:-8000} STEP=2 SM=20"
(env $C SIDE=l P0=$KAIJU_FIT_DATA/opt3_G4a_l.json SW=100 LR=0.01 OUT=M1 timeout 3000 python opt3.py 2>&1 | grep -v Warn > $KAIJU_FIT_DATA/fit_M1_l.log) &
(env $C SIDE=l P0=$KAIJU_FIT_DATA/opt3_G4b_l.json SW=50 LR=0.02 OUT=M2 timeout 3000 python opt3.py 2>&1 | grep -v Warn > $KAIJU_FIT_DATA/fit_M2_l.log) &
(env $C SIDE=r P0=$KAIJU_FIT_DATA/opt3_G3b_r.json SW=50 LR=0.01 OUT=M1 timeout 3000 python opt3.py 2>&1 | grep -v Warn > $KAIJU_FIT_DATA/fit_M1_r.log) &
wait; grep -H "^start\|^best" $KAIJU_FIT_DATA/fit_M*.log
