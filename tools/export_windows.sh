#!/usr/bin/env bash
# Exports the Windows build on this PC and proves the pack holds the real assets, so a
# branch can be checked before it reaches main (build.yml runs on pushes to main only):
#   1. git lfs pull (the display fonts are LFS);
#   2. import the project headless (a script error fails the run);
#   3. export the "Windows Desktop" preset to out/windows/KaijuIncremental.exe (pck embedded;
#      out/ is git-ignored);
#   4. tools/pck_check.py: the fonts in the pack are real TTFs, not LFS pointers, and every
#      assets/kaiju/*.kvox is in it byte for byte.
#
# The run gets its own user data and editor settings (CLAUDE.md "Machine rules"); only the
# Windows release templates are copied in from the real install
# (%APPDATA%/Godot/export_templates/<version>, or TEMPLATES=<dir>).
#
#   GODOT=/path/to/godot_console.exe tools/export_windows.sh
#
# Exits nonzero if any step fails.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

GODOT="${GODOT:-godot}"
EXE="out/windows/KaijuIncremental.exe"
version="$("$GODOT" --version | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?)\.([a-z0-9]+)\..*/\1.\3/')"
TEMPLATES="${TEMPLATES:-$APPDATA/Godot/export_templates/$version}"
for t in windows_release_x86_64.exe windows_release_x86_64_console.exe; do
  [ -f "$TEMPLATES/$t" ] || { echo "FAIL: no $t in $TEMPLATES (install the $version export templates)" >&2; exit 1; }
done

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/Godot/export_templates/$version"
cp "$TEMPLATES"/windows_release_x86_64*.exe "$scratch/Godot/export_templates/$version/"
[ -f "$TEMPLATES/version.txt" ] && cp "$TEMPLATES/version.txt" "$scratch/Godot/export_templates/$version/"
export APPDATA="$scratch" XDG_DATA_HOME="$scratch" XDG_CONFIG_HOME="$scratch" XDG_CACHE_HOME="$scratch"

echo "== git lfs pull"
git lfs pull

echo "== import ($version)"
"$GODOT" --headless --path . --editor --import > "$scratch/import.log" 2>&1 || { cat "$scratch/import.log"; echo "FAIL: import" >&2; exit 1; }
if grep -qE "SCRIPT ERROR|Parse Error|Compile Error" "$scratch/import.log"; then
  cat "$scratch/import.log"; echo "FAIL: script errors during import" >&2; exit 1
fi

echo "== export -> $EXE"
mkdir -p "$(dirname "$EXE")"
rm -f "$EXE"
"$GODOT" --headless --path . --export-release "Windows Desktop" "$EXE" > "$scratch/export.log" 2>&1 || { cat "$scratch/export.log"; echo "FAIL: export" >&2; exit 1; }
[ -s "$EXE" ] || { cat "$scratch/export.log"; echo "FAIL: export wrote no $EXE" >&2; exit 1; }
echo "$EXE: $(wc -c < "$EXE") bytes"

echo "== pack check"
python tools/pck_check.py "$EXE"
