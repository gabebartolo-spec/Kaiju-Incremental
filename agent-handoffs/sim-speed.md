# Sim-speed handoff, 2026-10-23
## State: measurement done and pushed; speed-ups NOT started (they wait for the director's return)
## Task
ROADMAP "Engineering upkeep (D-159)", "Sim speed": measure where a sim step's time goes so balance answers take
minutes, not the 2-hour tools/pacing.gd run. Any speed-up must keep a 10-run-per-growth-step checksum identical;
a change that alters results is a game change and goes to the director.

## Branch and commit
claude/sim-speed (from origin/claude/look-options edae0df3). Probes only, no sim code touched. Sha: see the report.

## The probes (tools/, none reads a clock inside sim/)
- sim_probe.gd: shared set-up: a growth step's stats, grown city and pacing.gd's scripted player (15 Hz); LEVELS = the
  upgrades owned per growth step (young / Behemoth / Colossus / Apex Titan), reptilian.
- sim_profile.gd: plain run vs the same run with a stopwatch round each sub-system (sim_timed.gd, sim_timed_convoy.gd
  swap the sub-systems for timed subclasses built from the same args and seeds; sim_prof.gd is the stopwatch: nested
  spans, inclusive and exclusive). Prints whether the two fingerprints agree (they did, every run). Flags: --runs=3
  --tiers=1,2,3,4 --gd (GDScript path) --drill (convoy and body volume inside) --micro (plain us per call, no stopwatch).
- sim_checksum.gd: N seeded rampages per growth step, a fingerprint of result(), chunks_destroyed, steps, final kaiju
  state; prints a checksum per step and "CHECKSUM <overall>". Run it before and after any change, both paths.
  `godot --headless --path . --script tools/sim_checksum.gd -- --runs=10 [--gd]` (about 14 min native, 10 runs).

## Baseline checksums (10 seeded runs per growth step, reptilian, city seed 0, army streams 0..9)
Native path (what CI runs: the tests job builds the extension and requires it; DLL = Kaiju-Builds/carve-build5-60fad6b,
native/src changed after it only in comments):
  young c7f06a1e7c488d9d (5650 steps) | Behemoth af65a5967c68b293 (8700) | Colossus ccf6ffdbb80712d3 (8254)
  | Apex Titan ee2fc77427d9af29 (8597) | CHECKSUM 2c712cc6589535dd | wall 849 s.
GDScript path (VoxelSupport.use_native off): young, Behemoth and Colossus checksums are IDENTICAL to native. Apex Titan
did not finish in the 55 min limit (the GDScript path takes about 385 ms/step there); not run to the end, CI and the
export run the native path.

## Where a step's time goes (native, 3 seeded runs per growth step, ms per sim step at 15 Hz)
Plain 3.5 / 10.1 / 25.1 / 69.1 (young / Behemoth / Colossus / Apex); timed run 3.9 / 10.2 / 26.1 / 71.3.
Top spans by exclusive time (share of a step):
- Convoy.step (the tanks' road driving, inside Army): 46% / 61% / 56% / 38% (1.8 / 6.2 / 14.6 / 27.3 ms).
- body.sweep + body.inside (the body's chew/hold): 14% / 9% / 14% / 14%.
- carving settle+hit+apply+warm: 24% / 20% / 14% / 24%. collapse.land 1-3%.
- the scripted player's own nearest_standing lookup: 6% / 4% / 7% / 7% (a harness cost; the game's auto-walk calls it too).
- powers.speed_mult (blocked scan) 3% / 2% / 3% / 3%; powers.step 6% at Apex (fire.step 0.2, tentacles, glide).
- Taskforce, air wing, brood, claw swipe, fire spread, army squads: each under 2%.
GDScript path (2 runs): 15.5 / 44.6 / 105.5 / 384.8 ms/step (4.4x, 4.4x, 4.2x, 5.6x the native steps); carving is 80-85% of
it (carving.settle alone 60% / 56% / 47% / 41%, then apply and hit), Convoy only 6-12%. The native extension moves the
carving cost out, so Convoy and the body lead on the shipped path. Candidates 1-3 below are native-path wins; on the
GDScript path they are 1-3% and carving.settle is the target (CI and the export run native, so it is not proposed).

## Convoy breakdown (--drill, 2 runs, Behemoth / Colossus / Apex; stopwatch adds about 5 us per span so use --micro)
posts.body 249 / 541 / 856 calls per step; plain cost 8.4 / 9.3 / 9.4 us per call (--micro). to_body and near_body
cost 9-11.5 us per call, of which body() is 85-90%: the kaiju's body polygon is rebuilt (BreathCone.of: about 15
dictionary lookups, a Dictionary and an array) on every call, though it cannot change inside one Convoy.step.
Also per step: roads_by_body 1 call (visits 170-600 roads, each near_body); posts.choose + search.search 0.8-1.7 calls
(1.6 / 3.7 / 5.7 ms incl); convoy.drive 15 / 28 / 39 calls (graph.drivable 18-52 calls, 28 / 15 / 9 us);
spacing.open_up 1.8 / 3.4 / 9.6 calls, 0.4 / 0.9 / 4.8 ms (O(tanks^2), a routes lookup and a clash test per pair).
Body volume: volume.near 2.1 calls (linear over all buildings) 0.4 / 1.1 / 3.9 ms; volume.collect 7-13 calls 0.3 / 2.0 / 4.4;
powers.blocked 76-130 us a call at Colossus/Apex (linear over all buildings).

## Top 3 speed-up candidates (all keep results bit-identical by construction; each needs the checksum proof)
1. Compute the kaiju body polygon once per Convoy step (FiringPosts.body() cached; refreshed when kaiju_pos, facing or
   kaiju_vel differ, so it is exact), and let roads_by_body skip roads that cannot be within `near` before near_body.
   Saves 249 / 541 / 856 body() calls x 8.4-9.4 us = 2.1 / 5.0 / 8.0 ms per step = about 25% / 23% / 12% of a step
   (Behemoth / Colossus / Apex), measured by --micro. Young not drilled (Convoy is 46% there). Lowest risk.
2. Building scans: BodyVolume.near, SpeciesPowers.blocked and nearest_standing each walk every building every call. A
   fixed cell-bucket index of the (never moving) buildings, visited in ascending building index so ties resolve the same,
   cuts them to the few near the kaiju. Per step 0.95 / 3.2 / 10.1 ms (near + blocked + the player's lookup) = 11% / 14% /
   15%; expect to remove most of it: about 9% / 11% / 12%. (nearest_standing's share is the harness's, still real for pacing.)
3. spacing.open_up / blocker: skip a pair by id order and distance before the routes lookup and the clash geometry (a true
   upper bound on hull + gun + follow, so no pair that could clash is skipped). 0.7 / 1.5 / 6.4 ms = 3% / 3% / 9% of a
   step; expect about 2% / 2% / 6%.
Together roughly a third off the Behemoth..Apex steps (not additive to the cent: 1 and 2 overlap on roads_by_body's
roads). Not worth it yet: carving native (15-24%), body.collect, search.search; each under 8% on the shipped path.
Files near the line cap that these touch: sim/convoy.gd is exactly 400 lines (split before adding), sim/firing_posts.gd 314.

## Pacing sample (wall time, before any speed-up, native path)
`godot --headless --path . --script tools/pacing.gd -- --species=reptilian --runs=60`: 13 min 40 s wall (60 runs: young 7,
Behemoth 48, Colossus 5; tree 79/96 levels, 1.40 h of play). The full 400-run, 3-species run is the 2-hour one. Rerun the
same line after a speed-up and compare; the printed table must be identical (pacing is seeded).

## Open decisions
None for the director yet. The speed-ups change no result; if one cannot, it stops and is described, not merged.

## Running jobs
None (the pacing sample, below, ran in the background; its result is in the final report).

## Findings for the lead
- A span-level profile (nested exclusive times) found the real cost in minutes; the guess ("carving") was wrong on the
  shipped native path: the tanks' pathing geometry was.
- The extension DLL path in the handoff (carve-play) did not exist; builds live in Kaiju-Builds/.
- The scratchpad path in a Bash command trips the worktree isolation guard; scripts live in untracked .bc/.

## Rules learnt the hard way (under 10 lines)
- A stopwatch costs about 5 us per span: use --micro for hot helpers, spans for the split.
- Fingerprint with var_to_bytes (floats keep every bit), and compare plain vs timed runs before trusting a profile.
- gdlint: 100-column comment lines and 400-line files apply to tools/ too.
