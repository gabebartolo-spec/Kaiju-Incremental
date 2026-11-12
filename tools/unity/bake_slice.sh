#!/usr/bin/env bash
# The Unity slice's data without Godot: tools/unity/slicebake (C#, the generated sim plus
# kaiju_core.dll) writes what export_slice.gd writes, byte for byte, into
# unity/Assets/StreamingAssets/slice/ (or the folder given as --out=<dir>).
#   bash tools/unity/bake_slice.sh [<dir>/reptilian_adult] [--out=<dir>]
# The croc base path may also come from KAIJU_CROC; without one, only the city files are written.
# Needs dotnet 10 and unity/native/build.bat's kaiju_core.dll.
# Relative paths (the croc, --out, KAIJU_CROC) are read against the caller's folder, not the repo root.
set -eu
here="$PWD"
abs() {
	case "$1" in
		/* | [A-Za-z]:*) printf '%s' "$1" ;;
		*) printf '%s/%s' "$here" "$1" ;;
	esac
}
croc="${KAIJU_CROC:-}"
out=""
for arg in "$@"; do
	case "$arg" in
		--out=*) out="--out=$(abs "${arg#--out=}")" ;;
		*) croc="$arg" ;;
	esac
done
if [ -n "$croc" ]; then croc="$(abs "$croc")"; fi
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
set -- -c Release --project tools/unity/slicebake --
if [ -n "$out" ]; then set -- "$@" "$out"; fi
if [ -n "$croc" ]; then
	set -- "$@" "--croc=$croc"
else
	echo "bake_slice: no croc given (argument or KAIJU_CROC); the croc_<stage> files are left as they are" >&2
fi
dotnet run "$@"
