# Lead handoff, 2026-10-20 late (lead 8, session b5e2e23e, registered lead: hands off at 500k)
## State: lead 8 running, ~310k. Director's /goal: playable build with building carving first draft. Plan = docs/ROADMAP.md
## "Post-demo plan" phases A-H; every director comment in docs/roadmap/2026-10-20-build2-playtest.md (30 notes) and
## docs/roadmap/2026-10-20-director-comments.md (rows 1-18). Director answered "No, I'll do Phase A": NO builder helper now;
## the lead builds. Asset session (voxel density) archived by him: density comparison not running.

## NEXT (in order)
1. MERGED today: #109 WP7 carving, #110 b2-6 real band, #111 (breath trees, tail reach, rubble ruins), #112 (Cinematic
   D-104, camera C D-105, times of day D-106). Open: #113 river rise along the channel (head 29d3c61, mog armed).
2. Stadium past the baby's edge (b2-21, director picked "A past the edge"): worktree ../Kaiju-Incremental-wt/stadium-north
   (branch claude/b2-21-stadium-north, uncommitted): data/tuning.json stadium anchor [-24,-57] + districts[1] 70->72 (the
   stadium is 22 m deep; ring 42..70 left 20 m), test tests/lib/city_stadium_far.gd (failed first: 75-78 m, inside the
   baby's area; now 106-110 m, just past it, inside stage 2). Wide suites were running (city growth flow sim
   landmarkcells load military smoke). Then add the edge marker (3) to the same PR.
3. Play-area edge marker (comments #18, "not too loud"): scenes/arena_edge.gd written (dashed amber line on the street
   at sim.arena_half, none over water). TODO: tuning "arena_edge" {dash 1.6, gap 1.2, width 0.3, color "c9a24a",
   glow 0.25}; CityView._ready adds ArenaEdge.new(sim) after CityGround; a capture at dusk and night, lead 2x.
4. Phase A leftovers: p1-9 confirm south-of-spawn buildings gone (#88/#110 likely cover it); sim check "armoured scales
   cut the damage"; worktree cleanup (res4, res16, carve-wp7, camera-opts, b2-26, river-rise once merged). Gate: build 3
   (build.yml from claude/look-options), he plays.
5. Then Phase C (destruction core), D (body feel: turning weight + head leads the body #16, tail autonomous limb,
   intro shot, reactive water), E tree, F UI, G perf.

## Findings this session (evidence in PR bodies)
- Tail sweep fired but cut 0 chunks in the real city: reach ended short of its own tip. Smooth stick turns never sweep
  (Phase D autonomous limb fixes that).
- Breath crushed props only round the feet; BreathCone.cover now covers the cone.
- Ruin wall stubs rose above the heap = the "burning buildings" he saw.
- Kaiju rose facing the bank: head over the quay/road. Now along the channel.
- Headless Godot returns empty MultiMesh transforms and AABBs: test cells, not meshes.
- A fresh worktree after a new class_name needs `--editor --import` before scripts run.
- [skip ci] on a PR head leaves no checks for the watcher: push an empty commit.

## Tools
- mog.sh (scratchpad b5e2e23e/scratchpad/mog.sh <pr> <full sha>): polls 150 s, squash-merges with --match-head-commit.
- Captures: tools/capture/capture_shaders.gd (--shader --time), capture_framing.gd (--offset --fov). override.cfg in the
  worktree first (separate call). Sheets: scratchpad cam/sheet.py.
- Probes: tests/_probe/ (untracked) in b2-26 and stadium-north worktrees: tail_probe.gd, map_dump.gd, anchor_scan2.gd.

Lead = "Kaiju: LEAD". Owns QA gates, merges, DECISIONS/STATUS, director questions, this file. Ask him the
ask-the-director way: one decision, recommended option first, a labelled image for anything visual.
