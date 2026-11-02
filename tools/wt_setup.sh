#!/usr/bin/env bash
# wt_setup.sh: make a fresh worktree ready for Godot runs in one command.
#
# A new worktree has no .godot cache, no native DLL and no override.cfg. By hand that was four steps
# every handoff repeated, and a headless --import from a cold cache segfaults on the six
# scenes/ocean/*.glsl, so the first import must be windowed (through C:/kt/gpu_slot.sh, D-376).
#
#   bash tools/wt_setup.sh            do what is missing, then report
#   bash tools/wt_setup.sh --check    report only (exit 1 if anything is missing)
#   bash ../other-wt/tools/wt_setup.sh   from a worktree that has no copy yet: sets up this one
#
# Steps (each skipped when already done):
#   1. override.cfg: the off-screen no_focus window (Kit.window_ok needs it for windowed captures).
#   2. native DLL: tools/native_dll.sh fetch (main's CI build).
#   3. import: windowed `godot --editor --import` via gpu_slot when any scenes/ocean/*.glsl has no
#      imported .res or the class cache is missing; the import rewrites project.godot, so it is
#      restored afterwards.
# Env: GODOT (default: godot on PATH, else C:/kt/godotbin/godot), GPU_SLOT (default C:/kt/gpu_slot.sh).
set -u
# The worktree is the one you run it in (the git root of $PWD), not the one the script sits in.
cd "$(git rev-parse --show-toplevel)" || exit 1
CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1
GODOT="${GODOT:-$(command -v godot || echo C:/kt/godotbin/godot)}"
GPU_SLOT="${GPU_SLOT:-C:/kt/gpu_slot.sh}"
missing=0

have_override() { grep -q "no_focus=true" override.cfg 2> /dev/null; }
have_dll() { [ -f native/bin/libkaiju_carve.windows.template_release.x86_64.dll ]; }
# Every ocean .glsl has an imported .res, and the class cache exists.
have_import() {
	[ -f .godot/global_script_class_cache.cfg ] || return 1
	local f
	for f in scenes/ocean/*.glsl; do
		ls .godot/imported/"$(basename "$f")"-*.res > /dev/null 2>&1 || return 1
	done
}

report() { # name, test-function
	if "$2"; then echo "ok      $1"; else echo "MISSING $1"; missing=1; fi
}

if [ "$CHECK" = 0 ]; then
	if ! have_override; then
		cat > override.cfg << 'EOF'
[display]
window/size/mode=0
window/size/no_focus=true
window/size/initial_position_type=0
window/size/initial_position=Vector2i(-20000,-20000)
window/size/borderless=true
window/size/window_width_override=3840
window/size/window_height_override=2160
EOF
		echo "wrote   override.cfg"
	fi
	if ! have_dll; then
		bash tools/native_dll.sh fetch || echo "native_dll.sh fetch failed (see above)"
	fi
	if ! have_import; then
		echo "import: windowed via gpu_slot (about 1-3 min)"
		mkdir -p out
		GPU_SLOT_OWNER="$(basename "$PWD")-setup" bash "$GPU_SLOT" "$GODOT" --path . --editor --import \
			> out/wt_setup_import.log 2>&1
		git checkout -- project.godot 2> /dev/null
		# A windowed import prints no "[ DONE ]" line (headless does); the cache check below is the proof.
		grep -E -A3 "SCRIPT ERROR|Parse Error|Compile Error" out/wt_setup_import.log | head -20
	fi
fi

report "override.cfg (no_focus)" have_override
report "native DLL" have_dll
report "import cache (class cache + ocean .glsl)" have_import
if git diff --quiet -- project.godot; then echo "ok      project.godot unchanged"; else
	echo "MISSING project.godot was rewritten (git checkout -- project.godot)"
	missing=1
fi
exit $missing
