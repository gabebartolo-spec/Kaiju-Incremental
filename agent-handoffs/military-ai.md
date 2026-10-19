# Military AI handoff, 2026-10-19 (r6 paused)
## State: paused (director, account handover). #50 head 085410a = WIP r6, CI red as expected; Auto-fix OFF (re-enable at r6 start). Local handoff commits not pushed.

## Task
D-066 (director 2026-10-18): "make sure the tanks and helicopters path finding is logical and
not unnatural, they should look and operate like a professional military". LEAD = session
"Kaiju: LEAD" (local_106fc100...). #50 is tanks only; helicopters on claude/heli-flight.
CI only while the director plays (no local Godot). capture.yml one at a time (gh run list -w
capture.yml first). LEAD merges.

## Branch
claude/military-ai (worktree ../Kaiju-Incremental-wt/military-ai), PR #50 into
claude/look-options, synced to c64fa34. r5 verified head 98d21cc (CI green, clip_r5, pacing).

## r6 (LEAD's fresh-critic FIX of r5, 2026-10-19) - where it stands
Standoff rule (replaces LEAD's earlier head-only call): a tank's centre >= 8 m from the
kaiju's BODY EDGE. #89 body_contact is not in look-options, so the body = the line from
kaiju_pos (the croc's tail root) to the head (BreathCone origin: breath_snout_ahead x body
scale along facing), body_radius x body scale wide.
1. Lead tank charges under the snout at 12-13.5 s: CODE WRITTEN, NOT VERIFIED.
   - Convoy.danger() = max(reach x danger, body_radius x bs + edge_gap 8), from the body line.
   - FiringPosts.head()/to_body()/roads_by_body(); urgent, near-kaiju road cost, post validity
     (band and ring posts), _goal_good, crosses_danger and fall_back all use it.
   - _drive brakes: a non-retreating move whose next point is inside the line clears the path.
2. Creeping back reads as stuck: CODE WRITTEN, NOT VERIFIED. A retreating tank inside the line
   reverses at army.convoy.retreat_speed 3.5 m/s, then at speed x reverse.
3. Hull swing 25-30 deg at 12.5 / 17.5 s: NOT DONE. capture_military.gd now logs OUTLINE lines
   (frame, tank, part, screen points) at every still, including 750 and 1050. Run the CI clip,
   then draw the overlays with scratchpad overlay.py (reads POLY lines: adapt the prefix to
   OUTLINE). If it is the hull, clamp hull yaw to the road tangent on straights.
4. Second tank skewed at the snout, 13.5-18 s: NOT DONE. Same standoff rule; overlay it too;
   square it to the street once parked.
Proof still owed: the check failing first (4e8da0c pushed with the check only; its CI run was
in progress, and pushing 0b8f625 probably cancelled it: re-run it with gh run rerun), CI suites
green at the fix, a new CI clip of the same moment, both tanks' overlays, pacing on CI.
- CI at the WIP head 085410a (run 39144397528, expected red, not fixed: paused): 3 military
  fails. Body edge closest 4.6 m (bar 8); parked skewed 86 of 3522 tank-steps past 15 deg;
  standoff 90% of 162 in band (bar 95%, sample floor 40 ok), danger 0.9 s ok. The wider
  standoff leaves few in-band posts (8301 reserve) and more tanks mid-pivot: next to tackle.
  The failing-first runs (1ce1cee, 4e8da0c) were both cancelled by later pushes.
- Check: tests/lib/military_view.gd: got["edge"] (tank centre to body edge) >= EDGE_GAP 8 over
  the seeded clip run (Clip.walk stride), plus no hull on a car.
- Pacing on CI: scratchpad pacing_military.gd (pacing.gd + damage tally) goes into
  tools/capture/ on a throwaway branch (plumbing commit, no checkout), dispatched via
  ci_capture.sh; the log has the DMG/evolve lines. Base numbers (83af6d6, snapB6): evolve1
  0.26 h, young 6/8, tree 4.82 h, tank dmg/run 167 / 299 / 656 / 660. The r6 standoff will cut
  tank damage again: retune growth.stages tank_damage after.
- Firing range is still measured from kaiju_pos (tail root); not changed.

## Helicopters (LEAD 2026-10-19 call 2): B clip, NOT YET RUN
claude/heli-flight head 20b06ff adds tools/capture/capture_heli_b.gd: camera eased to x1.4
while a pair is up (capture only; air.space.view zoom pulled with it), roof-cleared pair.
Dispatch (when captures are allowed):
  ci_capture.sh --ref=claude/heli-flight --movie --fps=60 --resolution=1920x1080
    capture_heli_b.gd -- --pull=1.4 --seconds=15 --out=<notes>/heli_b
  then the same with --pull=1.0 and no --movie, for today's camera stills at the same frames.
Design note sent: notes military-ai/heli-design-note.md (D can't be built: 8 m facades).

## Findings for the lead
- Screen-space part outlines settle "hull or turret" at once (r5 item 1 was the turret).
- kaiju_pos is the croc's tail root; anything "near the kaiju" must use the body line.
- A new class_name needs an --editor --import before a headless script can see it.
- Pushing to the PR branch cancels the running tests.yml run (concurrency): push a
  failing-first commit and wait for its result before the fix.

## Rules learnt the hard way
- gdformat on Windows writes CRLF: sed -i 's/\r$//' after it. Python: open(..., newline='').
- Warnings are errors: Variant from a Dictionary/Array into a typed param needs a typed var.
- Kill orphaned Godot children by PID after TaskStop (match start time).
