# croc-contact handoff (builder for the lead), 2026-10-20
## LIFE 6: see agent-handoffs/croc-contact-dash.md (green-up of PR #89: flow + military fixed, pushed).
## LIFE 5 (croc-fix): critic A = the 7 "chunks" were flat BoxMesh+StandardMaterial (pale, unlike voxels); now Ruin.chunk voxel lumps in the building's facade palette. B: lean_deg 3->8, lean_curve 3.2->2.6 (lean visible ~0.6 s). Local Forward+ ok; awaiting CI capture + lead.
## LATEST (life 4, D-099): override removed, head 677718e, tests 39342572775 + lint green, capture 39341631409 ok (clip not reviewed). Topples now follow part[dir] (gutted drop -> toward kaiju). Body updated (update 3). Done; awaiting lead.
## State: pushing claude/croc-contact (PR #89, base claude/look-options) then one capture; fresh life 2.
## Worktree .claude/worktrees/blender-reptile-f5388e. Remaining: capture run, PR body, tests result.

## Life 3 (croc89fix, 2026-10-20): review fixes A (pop) and B (direction), PR #89
- Cause A: chew + D-096 swipe (2 rows at once) ate a 13-floor tower's whole base in one tick
  (capture tower take, physics f241): Structure.settle made the 9 floors above a "drop" of 4, which
  landed 0.5 s later and CityView.fall_land queue_free'd it whole (rubble 12.4 -> 29.2 = clip 505-506).
- Fix A: Collapse._gutted - a non-landmark drop part with nothing under it, taller than its narrower
  side, topples instead; every other drop crumbles over topple_fx.drop_crumble_s (ToppleFx.crumble).
- Cause/fix B: only body-overlapped topples went away; swipe-undermined ones (b95-97) fell toward the
  kaiju. Now every topple goes away from the kaiju (cardinal, from the part's base centre).
- Checks: tests/lib/sim_topple_read.gd (failed first: 13 gutted drops, 6 of 31 topples toward the
  kaiju; now 16 gutted toppled, 58 of 58 away), flow_collapse _check_drop_crumbles (failed first:
  "there after landing false"). _check_topple_crush puts the kaiju east of the tower.
- Swipe fixture mean moved 0.248 -> 0.299 vs 0.239 (more topples); claws-5 498.4 vs 345.4.
- State: commit + push, ONE capture --tower, PR body Evidence; report to lead.

## Lead instructions still open
- PUSH once to claude/croc-contact (lead already said: after topple 1-4 + swipe 1-6 in and local
  suites green). Then ONE capture.yml run with both clips:
  `tools/capture/ci_capture.sh --movie --renderer=gl_compatibility capture_contact.gd -- --both --out=<scratch>`
  (check no capture.yml run is in_progress/queued first; ci_capture needs the pushed branch).
  The script prints "clip part 2: tower topple from physics frame N", "swipe k at take frame f",
  "topple starts at take frame f" (physics 60 Hz; clip 30 fps -> clip frame ~= physics/2).
- Report: full head sha, tests run id, capture run id, clip path, impact frame numbers before
  (run 39266833950: f214 facade -> f216 heap) and after.
- PR body must add: D-096 (director 10-20: swipes undermine towers; undermined towers fall away from
  the kaiju), the grid table, per-seed pairs, honest line "the swipe adds only ~4% mean city
  destruction at these values (balance = director's joint retune after #89/#90)", the changed
  sim_body_contact expectations and why (readability), sparkles finding, cadence finding.

## What changed (local commit)
- Sim: collapse.gd - a topple whose building the body overlaps falls away from the kaiju (cardinal
  dir kaiju->base, pivot on the far edge of its lowest floor); crush strip follows.
  claw_swipe.gd - D-096 _undermine: each swipe chews the face (swipe_chew_rows=2 rows nearest the
  kaiju, full width, floors up to arm height) with swipe_chew_s=1.0 s of contact.bite_dps;
  swipe_windup cue event 0.3 s before each rake (changes no outcome).
- Tests: sim_body_contact _check_falls_away (failed first: "dir (0,1), kaiju->base (0,-3)"),
  _check_swipe_undermines (failed first 3.3 vs 3.3 s; now 2.0 vs 3.3 s); sim_claw_swipe both
  fixtures are 5-seed means, same bars. Swipe mean 0.248 vs 0.239 (0.221/0.233, 0.206/0.223,
  0.266/0.244, 0.266/0.247, 0.277/0.245); claws-5 457.4 vs 392.0 (421/380, 421/342, 601/400,
  422/400, 422/438). Old rule, same 5 seeds: 0.141 vs 0.135.
- Grid (chew_s/rows -> swipe mean vs off | claws-5): 1.0/2 0.248 vs 0.239 | single-seed 421/380
  FAIL then; 0.5/2 0.225 vs 0.239 FAIL; 0.3/2 0.250 vs 0.239 | 369/397 FAIL; 0.5/1.5 0.222 vs
  0.239 FAIL + "longer rampage" FAIL; rows 3 drops the tower (never topples).
- Topple presentation: scenes/topple_fx.gd (new; shudder + crumble + sinh lean inside the sim's
  fall time; impact break-up over breakup_s with debris waves and flatten, pale dust burst at
  the far end, heap slumps from settle_heap, 7 big chunks slide/settle), Ruin.strip chunkier and
  pale (cfg), fx.dust/dust_line tint, RuinYard.build ready callback, FallMotion.topple_turn,
  rampage shake from data. Tuning "topple_fx".
- Swipe presentation: BipedSwing rake data-driven ("claw_fx": wide up pose, fast across, arm
  scaled 1.6 young/1.25 adult), lift starts at swipe_windup so the arm crosses on the sim's rake
  frame; ClawSlash = 3 broad tapered arcs on the shoulder-centred rake arc (fx boost up to 2x on
  a young body), drawn on from the crossing, + dust puff at the strike point; KaijuModel
  tail_sweep returns the claw arc (file at 400-line cap).
- capture_contact.gd: debug label removed; --both = walk-through then tower in one clip.
- Swipe findings: sparkles on the back = army fire hits (rampage._tank_fired sparks at
  kaiju+4*bs up; powers_view heli sparks), not the swipe - left alone. 21-frame spikes =
  stomp_interval 0.7 s; swipes are 2.0 s (interval + windup; no bug, no check added).

## Evidence (local, after the commit)
sim 65 checks, city 53, flow 157, powers 24, growth 31, clips 14: all pass (headless, --quick
after one full import). city/powers/growth check lines identical to base except via sim; flow
event sequences shift (still pass).
Not exercised: any rendered look (no capture yet); arm bone scale on the voxel skin unverified.
