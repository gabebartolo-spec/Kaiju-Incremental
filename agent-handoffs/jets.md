# Jets handoff, 2026-10-18
## State: awaiting lead (dodge-window question A/B/C sent; captures held until the demo chain)
## Task
D-072 (director): all four jets go in, each its own PR into claude/look-options, report to
"Kaiju: Lead". Director's answers (log under D-072): strikes wreck buildings as collateral but
pay no biomass; jets arrive at Colossus, the bomber is the Apex set-piece; the octopus can grab
a jet. All built.
## Branches (one worktree: ../Kaiju-Incremental-wt/jets), stacked, all pushed
1. claude/jets-interceptor -> PR #58 (DRAFT into look-options, Auto-fix ON (app), packet comment).
2. claude/jets-bombs (on 1) -> PR #61 (DRAFT, base claude/jets-interceptor, packet comment):
   delta + attacker, bombs, kinds per `order`, --jet=<kind> capture.
3. claude/jets-bomber (on 2): bomber kind, per-jet clearance/approach, Apex order, lower fly-by
   pitch, tools/pacing.gd --no-jets / --dodge + jet hits/run. No PR yet (LEAD: carry on).
Sync order after any change: 1 -> merge into 2 -> merge into 3; run suites on each.
## What is built (see PR #58 body and its packet comment)
- sim/strike_wing.gd: call-in (cap), passes across the camera, warning (jet_inbound, rounds +
  bombs + radius), strafe (rounds), bombs (release ahead, fall, blast), collateral via
  damage_chunks with the rubble taken back, clearance over reach_height, hit only by hit_air
  attacks, clear_dead; tentacles grab jets. Kinds: tuning jets.kinds over shared keys.
- scenes/jet_model.gd, scenes/jets_view.gd (via PowersView fallthrough), sounds jet_flyby,
  jet_cannon, jet_bomb (build_sfx.py --only jets), capture_tanks.gd --jets / --jet=<kind>.
- Models: assets/source/vehicles/build_jets.py + tools/blender/vox_jet.py; all four kvox are
  byte-identical to the board LEAD passed (h: interceptor 22, attacker 23, delta 15, bomber 30).
## Evidence so far
Each branch: all 10 suites green locally + self-test (jets 12 / 17 / 18). Known-bad runs fail
the dodge, warning and collateral checks. Headless dry runs (throwaway scripts, not committed):
Colossus interceptor 240->210 hp, 47 roof chunks; attacker bombs land; Apex bomber at 27.4 under
a camera at 40, 12 bombs.
## Open question (LEAD -> director)
Apex kaiju can't dodge (body radius 10.9 u vs a fixed 1.6 s warning; pacing --dodge: 14/19 Apex
runs defeated, all 286 hits mid-dodge). Options sent: (A) warning lead = time to walk clear
(body radius + blast) at its speed + 1 s [recommended]; (B) keep 1.6 s; (C) hit the body's core.
Balance: don't tune against today's numbers; after #36 merges, sync and send LEAD the table
(pacing.gd per species, jets off / on / on+--dodge: Colossus + Apex defeats, hours, jet hits).
## Next
When the watcher says the queue is clear (and nothing is in_progress): one capture at a time,
1080p --movie: PR1 `capture_tanks.gd -- --species=reptilian --jets` (ref jets-interceptor);
then PR2 `--jet=delta` (ref jets-bombs); then PR3 `--jet=bomber` (ref jets-bomber). Then a 2x
crop of one jet, self QA, add evidence to #58 and mark ready; open PR2/PR3 (base: the branch
below until it merges, or look-options after). Report each to LEAD.
## Findings for the lead
- Growth fixture margin: its non-dodging Colossus ends a 70 s rampage at 33/565 hp even with
  jets off; bombs at 12 killed it (64 s), now 8 (11 hp left). Needs a balance pass.
- A line centred on the kaiju gives ~0.25 s of free dodge time before the centre rounds.
- The bomber is 21 u long at Apex: a third of the screen at the game camera. Judge in capture.
## Rules learnt the hard way
- gdlint max-file-lines 400: rampage_sim.gd (400), run_smoke_tests.gd, powers_view.gd are at or
  near it; put new checks/views in their own files.
- Strict typing: no `as Dictionary` on a Variant; type event values into locals first.
- Never raise chunks_destroyed past a tiny test city (it ends the run); lower the threshold.
- Merging stacked test files can drop a closing paren at the hunk edge: compile before commit.
- `git stash` is denied here (even `stash list`); don't use it.
- Before every push: `git ls-files '*.gd' | xargs python -m gdtoolkit.formatter --check` and
  `... gdtoolkit.linter` (CI's gdlint job runs both; gdformat on Windows writes CRLF: sed it).
