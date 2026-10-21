# dash-burst handoff (builder, branch claude/dash-burst, worktree ../Kaiju-Incremental-wt/dash-burst)

Task: comment #34 (dash bursts through buildings, full 1.5 lengths, kick per wall) then D-118 (walking into big
buildings: visible chunk loss each contact, gives way after <= ~1 s shove). One clip covers both. No PR; push branch.

## Done (uncommitted until the full suite is read)
- sim/dash.gd: `carried` flag (dash moved the body this step); resets burst_through at dash start.
- sim/body_contact.gd: while carried, never held, no dwarf chew: everything overlapped is broken outright (struck
  twice for carved walls); event {"type":"dash_wall","building","at"} once per building per dash.
  D-118: contact with a dwarfing building breaks the `shove_chunks` nearest chunks outright every step and chews the
  rest; after `shove_s` held, `_shoved` latches and the body breaks everything outright until clear of all chunks.
- data/tuning.json: contact.shove_s 0.8, contact.shove_chunks 2; dash.wall_hit_stop 0.04, dash.hit_stop_cap 0.12;
  camera_shake.sources.dash_wall 0.15.
- scenes/rampage.gd: "dash_wall" event -> hit-stop (sim waits _hit_stop s, capped) + add_trauma(dash_wall).
  No hit-stop code existed before; this is the first.
- tests/lib/sim_body_contact.gd: _check_dash_burst (low, dwarfing, landmark, open), _check_walk_through (tiers 2..max),
  swipe-undermine fixture re-pinned to chew-only (shove off in both arms; shove made the tower fall in 1.3 s either way).
- Failing-first proven on old sim for the dash (dwarfing travelled 0.0 of 15.3 m); walk test failed on tier 4
  (hold 1.57 s, 0 chunks in 0.2 s).
- tools/capture/capture_dash_burst.gd written (dash at point-blank, cut, then walk), NOT yet run.

## State 2026-10-22: committed+pushed WIP; full suite NOT yet read (killed on usage stop). Clip rendered:
C:/Users/DANTE/AppData/Local/Temp/clip/burst.avi (+stills/); kaiju visible only with native dll copied into native/bin (untracked). Dash lane + tower
breakup read; baby is mostly engulfed by dust (camera far). Dash toward +z (camera looks south).

## Left
1. Full suite: tools/run_tests.sh --quick (needs GODOT env) -> fix seed-sensitive flips by probing; never loosen thresholds.
2. Clip: local GPU per side-session RULES-NOW.md (override.cfg untracked, --windowed, --write-movie, APPDATA scratch,
   RTX 4070 SUPER device check), check 2x crops, say what still looks wrong.
3. Commit by name, push claude/dash-burst, report to lead. Docs: DESIGN.md/DECISIONS are lead-only; state in report.
