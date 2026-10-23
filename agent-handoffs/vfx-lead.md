# vfx-lead handoff (VFX lead, the lead's second in command), 2026-10-23

## State
Split (director 2026-10-23, via lead): I own EVERY visual item end to end (decide, brief my own Sonnet builders in
their own worktrees, art QA, SHIP final); the lead owns sim, gameplay, UI layout/flow, tests, merges, docs. Tell
the lead before touching a file its builders are in (fire.gd: UI branch; sim + Taskforce: explosions PR 1). The
lead's explosions + UI builders keep their visual work; the lead relays proof/verdicts verbatim. Every session and
helper keeps the app checklist (update_plan) current; say so in every brief. Director 2026-10-23: at most 2
engine-running builders for me (4 team-wide); NO full suite on this PC (touched suites only, GitHub runs full).

## Task
Director 2026-10-23: VFX oversight (builder + art critic) for fire, smoke, explosions, city destruction, ability
effects, Taskforce effects, post effects. Rule above all: one look per kind ("consistency is absolutely key").

## Branch and commit
Worktree .claude/worktrees/vfx-lead-c37456 on claude/vfx-lead-2 (handoff branch only). #166 = claude/heli-deaths.

## What exists
- docs/VFX_STYLE.md: 10 families (owner files, material, ramp, scale), "Two looks today" table, review checklist.
- tools/capture/capture_vfx_sheet.gd (every family at the game camera, --run=1 night / 3 noon, side camera for
  breath and ultimate, run clock set to 600 s) + tools/capture/vfx_sheet.py (one labelled sheet, night|noon pairs).
- docs/captures/2026-10-23-vfx/vfx_families.png (the sheet).
- Reviews in side-session-notes/local_a16cd984-.../vfx-lead/reviews-2026-10-23.md.

## Director rulings 2026-10-23 (asked in my session with a labelled board; sent to the lead to log as D-n)
Blast = a sudden burst of Fire's own rising flames + the Fire left burning; gas = smoke shader tinted; smoke lit
from below everywhere; title burning windows orange with flames out of the openings; Lightning Breath/Thunder
Beam rework in M1; Taskforce = one electric blue nobody else uses (deflect flash -> white); blast/Taskforce hits
use the street dust; I fix the base mismatches (tail ring, tree puff, shell sparks) now, in PR #154.

Second batch, 12 visual-direction answers (cinematic fire, escalating haze, dust walls, block-wide stomp waves,
debris rain, rare slow-mo, glass, blackouts, bloodless, crushed kills, lightning charge-up on the body, clean
Taskforce tech): recorded in VFX_STYLE.md "Visual direction"; sent to the lead to log.

## Standing queue (lead 2026-10-23; my SHIP is final for effects; report <= 6 lines per item, name the next)
1 VFX_STYLE + sheet (done, #154) · 2 verdicts: explosions r8 FIX, title FIX x2 (notes reviews-2026-10-23.md) ·
3 helicopter deaths (ROADMAP #86, D-140/141/145), build sim+view, own branch, PR · 4 BuildingView.lift_piece
collapse defect (scenes/building_view.gd:204) · 5 Taskforce effects as its sim lands · 6 textured-surfaces board
(one building, three detail styles) · 7 graphics preview scene · 8 load-screen board (~20 shots).
Bar: three pillars (beauty, consistency, scale/power); SHIP only if the director will love it.

## Unfinished changes / my builders (Agent subagents, own worktrees; cap 2 engine builders)
- #154 PASS sent (8a3049d7, r4: self-lit street dust, visible rings, orange sparks, white deflect). Follow-up item
  "dust billows" (mine): every dust effect from Fx.dust puffs (rings = expanding chains of lobed puffs), deflect
  gaussian 60 px; also a stray gold 4-point star on the kaiju in some stills, source unknown.
- Thunder Beam (claude/thunder-beam 6dbe10e5 pushed, round 6 of builder adb19422): breath close (head silhouette
  + small arcs, blob-chain glows killed the kink wedge, white-hot strike); breath critic still FIX (a slab edge in
  f032, strike not the climax from the game camera, head smear, onset pop, weak noon); BEAM regressed (thin line, no
  lashes; try thunder halo width/blob share). Rulings: face can't show from the behind camera; pre-fire aim wedge is
  real UI. Halo question NOT in interview until SHIP. Old base shows ATOMIC BREATH: sync before its PR.
- Croc standing: SHIP ca148fd7 (mine after 3 critic rounds), queued for a PR by the lead.
- Voxel boards (claude/look-boards 76f6b59a, capture-only): in the lead's interview question with my read (mock
  barely changes the game camera; smooth croc wins up close) and a middle option (smooth croc in close shots only).
- Heads/skins (claude/heads-skins 9781f0a0, provenance rows only; Tripo 1500/8000): boards
  vfx-lead/heads/heads_board_interview.png (Python own shape, Komodo fits skull, Komodo own shape; Python-fits-skull
  dropped) + skins/skins_board.png, both questions in interview.md. Models in ~/Downloads/kaiju_tripo/heads_*.
- Explosions r10 (brief scratchpad brief_r9.md): #160 merged 06:17, fire.gd free; next free slot.
- #160 title merged (aad7e485) after my measured round-2 SHIP (crest 95 px clear, head ~1.65x, rim 7 px).
- D-155 atmosphere looks: mine, after #156; sim side = demo-end local_d3ef25ef.

## Open findings
- The stray gold 4-ray star = AbilityFx.deflect() (tank_fx.gd:18 calls it when stat "armor" > 0; a 4.5x-body
  flare.gdshader quad at the shell's hit) + ready_pulse at the head (ability_fx.gd:237). Deflect thus has TWO looks
  (this star vs the sheet's round white core): unify in the dust-billows follow-up.
- CityView.ring still draws the cephalopod's ink ring (octopus paused, D-124); deflect flash moves to white.
- Charcoal smoke invisible at night; a fire-lit underside for the shared smoke (D-141 "lit from below").
- fire.gd edited on fire-spread, ui-redesign and city-explosives-v2: merge #152 first.

## Lead board
Director questions while he's away go to Kaiju-Incremental-wt/lead-board/interview.md (README there);
lead replies in to-vfx-lead.md. Every Godot run: `bash ~/.claude/tools/engine_slot.sh && timeout ...`.

## Running jobs (resumed after the interview: D-163..D-170 on look-options df5309de, ROADMAP "Interview answers")
D-177 "Motion first" (director 13:5x): gait fix -> motion gate suite -> motion pass per stage -> D-165 -> one-look.
Slot ledger = scratchpad slots.md (source of truth). Director 13:29: no Godot until 14:14 (lead's watcher).
- slot 1 now CLAW RAKE (building, claude/claw-rake on gait-fix, notes claw_rake/PLAN.md). r6 9f311538 critics FIX (no hot core/red edges, burst smoke core; claimed swipe/spin/kicks absent from clip) -> r7 in slot 2 (scratchpad brief_heli_r7.md). Was fire-heli-r6 (brief_fire_heli_r6.md): Part 1 Fire family hot ramp for ALL fires (ember
  heat 1.4 blooms cores to cream) -> Part 2 heli r6. r5 (heli-look-r4 89b569eb, city-explosives-v2 9158d219,
  blast_parts byte-identical) critics FIX: rotor X mid-air, fried-egg burst, dark night hull, hull screen-door,
  no swat/impact beat, spawn pops (notes heli_look_r5/critic_*.md).
- slot 2 now r7. Phase A DONE claude/living-predator a1504242 (period 4.07/6.17/8.23 s, push 0.50/0.54/0.45 %H; Colossus breath ~2 px), motion critic running. Was living-predator: D-165 PHASE A only (breath/idle life/blink), claude/living-predator. Director (base): breath
  "way too much ... too fast, should be deep and slow like a behemoth": bars period 4/6/8 s, back/flank peak <=
  0.8/0.6/0.5% body height (>=0.25%), <=0.6%/s, damp the idle clip's baked breath at runtime (no re-bake); B/C wait for the gait
  merge + the lead's strike events. Night fog SHIP claude/night-fog 4524e90c sent to the lead 16:30 (fresh critic
  SHIP, notes night_glow/critic_verdict.md). Queued from that critic: tower see-through fade cross-hatch follows the
  camera; weak kaiju silhouette at night; D-154 rampage haze unbuilt. one-look phase 1 parked 849d9e06 (cut haze).
- Claw rake: no-engine PREP builder (PLAN.md in notes claw_rake/, base gait-fix), builds in the next free slot (director: swipe 'laughable, not dangerous', chose 'Heavy raking arc'; brief_claw_rake.md: telescoping arm scale, arm-only, 0.62 s toy timing, high flap, linear legs; bars at 3 stages; sim windup 0.3 s fixed; per-stage windup = his question only if the critic needs it). Order: gait -> claw rake -> motion pass -> D-165 B/C -> D-183 view -> Thunder Beam r7.
- D-183 "Stand-off gunships" (f8d108a0): lead's sim builder claude/heli-standoff (pos/vel/heading, stand-off ring, strafing passes); MY view part AFTER the gait work: bank into turns, pitch with acceleration, no rotor/body snaps, motion critic at game speed; heli.pos stays the interface (lead sends sim sha).
- slot 3 LENT until the motion gate merges: gait-2 (Opus). claude/gait-fix c661d731 = merge of the lead's gait-step-len
  841f93e2: MOTION GATE ALL GREEN (motion 30/0, smoke 47/0, clips 14/0, gait 10/0; jerk young 2.7 / Behemoth 4.3).
  681ce75c PR #175: critic FIX. Turn 260/311/278 deg/s peak is SIM (step rate x turn_ease x slice bell): lead takes to director, no sim edits. gait-2 doing view items (stop settle, tail, river-wall foot, bare-road recapture).
- heads-r2 stood down. Skins r6 (315c1998) REJECTED by the director (D-180: too much colour, reads black/white/green, not a
  cohesive range): redo post-demo + after motion as variations within the croc family, eye glow per skin yes, START with a cheap 2-3 treatment direction sketch, polish only after he picks (lesson filed in art-qa-critic); heads PARKED post-demo (D-171) after r4 grafts failed (seams, mask, disc hood); notes
  vfx-lead/heads/HEADS_PARKED.md (branch 3406ada0); head hidden from the game camera; 580/6500 credits used.
- Motion gate: claude/gait-fix b73b2ad4 red on base (18/29 fail); lead's sim part on claude/gait-step-len merges
  first (by merge commit); ours: re-bake (Behemoth lift 0.07, young <= 5%), soft IK + stable pole, young catch steps.
- D-166/D-175 accepted: sim holds breath/ultimate to young 0.8 / Behemoth 1.1 / Colossus 1.4 s, stomp 0.45 s; strike
  time comes in events (lead sends keys + sha); dash crouch view-only. Table: notes vfx-lead/strike_times.md.
Stall watcher = scratchpad stall_watch_copy.sh over subagents/agent-<id>.jsonl.

## Item 4 (collapse defect, BuildingView.lift_piece): diagnosed, brief scratchpad brief_item4.md
Lead's v5 frames (fire_clip/v5f f_083-087; my crop scratchpad v5_lattice.png): a toppling piece is an open box.
lift_piece reuses the whole building's shell (outside faces only) + slabs, masked per piece, so every side where it
broke off has no face: you see floor slabs + dark back faces = the "lattice" (not FallFade; kaiju not behind it).
Fix: bake the piece its own mesh from its cells, cut faces in carved slab colour 8a8780 (D-101). (e) not
reproduced. Chunks-inside-body: sim-side, the lead's. Builder slot after the croc bugs.

## Rules learnt the hard way
- A fresh worktree needs `git lfs pull`, the carve dll copied into native/bin (gitignored; newest build from a
  worktree whose native/src matches) and a headless --import before captures.
- The default rampage clock ends a long capture: set sim.time_left.
- override.cfg (no_focus, off-screen) is written in its own Bash call; gitignored.
- GDScript warnings are errors: no `int(Variant)` (use Num.i), no `as Fire` on a Variant (typed var assign).
- Agent subagent transcripts: <session>/subagents/agent-<id>.jsonl (tasks/<id>.output stays 0 bytes); point
  stall_watch.sh at the .jsonl.
