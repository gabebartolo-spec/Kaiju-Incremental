#!/bin/bash
# usage: lbrun.sh <name> <timeout> <godot args...>   (runs in the look-boards worktree, own APPDATA, slot-gated)
W="C:/Users/DANTE/Documents/GitHub/Kaiju Incremental/.claude/worktrees/agent-a1faedbb3831e123e"
G="C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
name=$1; secs=$2; shift 2
mkdir -p "$W/out/lb/ad_$name"
bash ~/.claude/tools/engine_slot.sh || exit 9
cd "$W" || exit 8
APPDATA="$W/out/lb/ad_$name" timeout "$secs" "$G" --path "$W" "$@" > "$W/out/lb/$name.log" 2>&1
echo "exit $? ($name)"
