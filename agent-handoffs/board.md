# Release smoke handoff, 2026-10-18 19:30
## State: running a check (PR: tools/release/demo_smoke.gd + README; then stand by for the final build's smoke)
Session "Demo build dry-run" (was UI, then Board). Board PR #64 merged (844217a). Dry-run of build run 39106390742 PASS.
Smoke: tools/release/demo_smoke.gd, run with the console editor binary on the exe's embedded pack (the release exe ignores
--script): `godot_console --headless --main-pack KaijuIncremental.exe --script tools/release/demo_smoke.gd`, scratch
APPDATA. 10 checks: title text + our fonts, croc-only species select, rampage with croc + city, Continue -> evolve1 ->
reveal -> DEMO COMPLETE card (our font) -> MAIN MENU -> title. The end uses a SaveFile save one evolution short (as
capture_demo.gd does); no cheat hook.
Next: when the lead dispatches the final build: gh run download <run> -n KaijuIncremental-<sha>, run the smoke, report in
4 lines. Remove the demo-smoke worktree after its PR merges.
