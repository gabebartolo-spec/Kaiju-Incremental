#!/bin/bash
# Look-boards clip: A | B | C, 6 s at 60 fps (close camera, croc walking an open street, 13 s to 19 s on the route), three 1280x720 panes.
# usage: look_boards_clip.sh <dir with a_dusk.avi b_dusk.avi c_dusk.avi> <log dir with <look>_dusk_clip.log> <out.mp4>
# Each pane is trimmed at its own "risen at drawn frame N" + 13 s, so timer and biomass match frame for frame.
FF="C:/Users/DANTE/AppData/Roaming/Python/Python314/site-packages/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe"
FONT="C\\:/Windows/Fonts/calibrib.ttf"
raw=$1; logs=$2; out=$3
args=(); filt=""; i=0
for look in a b c; do
	n=$(grep -h "risen at drawn frame" "$logs/${look}_dusk_clip.log" | sed 's/.*frame //')
	start=$(python -c "print(($n + 780) / 60.0)")
	case $look in
		a) label="A  TODAY";;
		b) label="B  ONE LOOK (mock)";;
		c) label="C  SMOOTH CROC";;
	esac
	args+=(-ss "$start" -t 6 -i "$raw/${look}_dusk.avi")
	filt+="[$i:v]drawtext=fontfile='$FONT':text='$label':x=16:y=h-96:fontsize=64:fontcolor=white:box=1:boxcolor=black@0.7:boxborderw=12[v$i];"
	i=$((i + 1))
done
filt+="[v0][v1][v2]hstack=inputs=3[out]"
"$FF" -y "${args[@]}" -filter_complex "$filt" -map "[out]" -r 60 -c:v libx264 -crf 23 -pix_fmt yuv420p "$out"
