#!/bin/bash
# Look-boards job runner (untracked helper). usage: lbq.sh <a|b|c> <dusk|noon> <f1|f3|f2|clip|rec> [extra script args...]
SCR="out/lb"
look=$1; time=$2; shot=$3; shift 3
RAW="out/lb/raw"
mkdir -p "$RAW/clip"
flags=()
[ "$look" = b ] && flags+=(--one-look)
[ "$look" = c ] && flags+=(--smooth-croc)
FACE="--route=idle --face=1,0,0"
RES="--resolution ${LBRES:-3840x2160}"
MOVIE=()
name="${look}_${time}_${shot}"
case $shot in
	f1) args="--route=replay --route-file=$RAW/route.json --stills=5" ;;
	f3) args="$FACE --cam=0,7,13 --stills=4" ;;
	f3b) args="$FACE --cam=3,6,-14 --stills=4" ;;
	f2) args="--route=replay --route-file=$RAW/route.json --stills=12 --fire=-54,26.5,9,1.2" ;;
	scan) args="--route=replay --route-file=$RAW/route.json --scan" ;;
	rec) args="--route=record --route-file=$RAW/route.json --stills=12" ;;
	clip) args="--route=replay --route-file=$RAW/route.json --seconds=6 --skip=9 --fire=-54,26.5,7,1.2"
	      RES="--resolution 1280x720"
	      MOVIE=(--write-movie "$RAW/clip/${look}_${time}.avi") ;;
esac
bash ./lbrun.sh "$name" 1800 $RES --windowed --fixed-fps 60 "${MOVIE[@]}" --script tools/capture/capture_look_boards.gd -- "${flags[@]}" $args --time=$time --out="$RAW" --label="$name" "$@"
grep -h -E "LOOKB|NVIDIA" "out/lb/$name.log" | head -8
