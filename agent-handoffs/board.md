# Release smoke handoff, 2026-10-18 21:00
## State: awaiting lead (final build checked without Godot; demo_smoke waits for "dont use godot" to lift)
Session "Demo build dry-run" (was UI, then Board). Role file: board.md.
## Task
Smoke-test the final demo build for the lead. Final build: build.yml run 39116671378 at look-options 8c24654 (#54 #36
#59 #66 #63 in). Artifact downloaded to my scratchpad final_dl/KaijuIncremental-8c24654/KaijuIncremental.exe
(131,568,168 B). tools/pck_check.py PASS (4 real fonts, 9 kvox byte-identical incl. croc P3 baby/adolescent).
## Running jobs
None. Director (via lead, ~20:40): "dont use godot" -> no local Godot, headless included, until the lead says so.
## Next
When the lead lifts it: `APPDATA=<scratch> godot_console --headless --main-pack <exe> --script tools/release/demo_smoke.gd`
(the release exe ignores --script), expect `DEMO_SMOKE PASS (0 failures)`, report in 4 lines.
## Done today
#51 D-077 stats (merged), #64 board D-062..D-084 (merged), #65 tools/release/demo_smoke.gd + README (merged).
Integration dry-runs (local, scratch only): A = #54 #63 #59 #36 and B = +#55 #50 all suites green; pacing A e1 0.26 h,
young 8/14; B e1 0.28 h, young 6/15. At 329e708: suites green (flow 148), local export + smoke 10/10.
## Open findings for the lead
- Stadium collapse stalls 80-110 ms every ~0.7 s while it falls (crowd on or off), measured windowed before the ban.
- One import segfault (exit 139) under machine-wide import contention; 8/8 serial fresh imports clean.
- 130-run pacing at 329e708/8c24654 not done (stopped by the ban): run on CI or later.
## Worktrees / branches
../Kaiju-Incremental-wt/integ-a (scratch/integration-a, local), integ-a-export (detached 8c24654): keep until the build
ships, then remove. Local branch scratch/integration-b remains (my delete was denied). This worktree: demo-smoke.
