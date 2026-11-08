#!/usr/bin/env bash
# After any change to sim/ or data/: regenerate the C# sim and Godot's logs, then prove they match.
# CI's sim-csharp job fails with this command when either has gone stale (D-470 U2).
#   bash tools/unity/regen_sim.sh
# Needs godot on PATH, gdtoolkit for python, dotnet 10. Rendering plays no part: all of it is headless.
set -eu
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
python tools/unity/gd2cs.py
(
	# APPDATA isolated from the installed game; a subshell, because python needs the real one.
	export APPDATA="${SIM_REGEN_APPDATA:-$PWD/.godot/regen_appdata}"
	mkdir -p "$APPDATA"
	godot --headless --path . --script tools/unity/dump_sim_golden.gd
	godot --headless --path . --script tools/unity/dump_sim_log.gd
)
dotnet run --project unity/SimTests -c Release
