# carve-wp2 (builder) handoff
Branch claude/carve-wp2 (worktree ../Kaiju-Incremental-wt/carve-wp2), from origin/claude/look-options. No PR (lead opens).
State: toolchain + KaijuCarve done and tested locally on Windows; Linux/CI path unproven until pushed run.
Done: godot-cpp submodule (godot-4.5-stable, no 4.7 tag); native/{SConstruct,kaiju_carve.gdextension,src/}; KaijuCarve
(set_grid, get_grid, carve_sphere, ground_flood; stateful because a PackedByteArray argument is a copy); tests/run_native_tests.gd
(5 functions, 16 checks, passes vs GDScript oracle); tests.yml `native` job + artifact to shards/extras; build.yml builds the
Windows release dll and uploads it beside the exe; LICENSING_REGISTER rows.
Local: build via a vcvars64 .bat then `python -m SCons platform=windows target=template_debug -j8` in native/.
Left: CI run result; capture.yml/lint.yml not touched (Godot there logs a missing-library error only).
