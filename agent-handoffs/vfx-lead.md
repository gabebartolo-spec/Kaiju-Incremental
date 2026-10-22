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
Worktree .claude/worktrees/vfx-lead-c37456 on claude/vfx-lead-2 (my handoff branch; heli-deaths is free for its builder).
claude/heli-deaths = item 3 = PR #166. Sim review fixes pushed 31a77e99 (coat kill spins, check red/green;
wrecks hurt only the city via StrayShell.hit_buildings, revert if the director wants army crushed; view leak).
LOOK = REJECT by a fresh critic: rework brief scratchpad brief_heli_look.md at the next builder slot (ledger
scratchpad slots.md). No 'SHIP #166' to the lead until the reworked look passes.

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

## Item 3 helicopter deaths (claude/heli-deaths, 78222347)
sim/air_wing.gd: blow_apart share decides burst vs spin; Falling list, own stream Seeds.derive(rng,0xFA11);
crash ignites the nearest building (City Ablaze) then smashes crash_floors (never the kaiju, air excluded via
_crashing); tentacle grabs clear_dead(true). scenes/heli_wreck.gd draws it (Fire burst / trail, debris, dust,
ripple, crew under arched canopies). tests/run_helideaths_tests.gd 6 fn 17 checks green; blow_apart 0 -> 6 red.
Proof: notes vfx-lead/heli_deaths_proof.png. A toppling tower tall enough sweeps helis over its strip down.
Not built: killable parachutists (they only drift down).

## Unfinished changes / my builders (Agent subagents, own worktrees; cap 2 engine builders)
- #154 PASS sent (8a3049d7, r4: self-lit street dust, visible rings, orange sparks, white deflect). Follow-up item
  "dust billows" (mine): every dust effect from Fx.dust puffs (rings = expanding chains of lobed puffs), deflect
  gaussian 60 px; also a stray gold 4-point star on the kaiju in some stills, source unknown.
- Thunder Beam (claude/thunder-beam 54127e06 pushed; 686ad611 local = r4: round soft flares without rays, strike
  2x + 12 m ring, beam = jagged channel held on one facade with lashes climbing it). 3 critic rounds FIX so far
  (reviews file). Builder adb19422 waits for my "go" (engine slot). Rulings: face can't show from the behind camera;
  pre-fire aim wedge is real UI. On SHIP: tell the lead (PR, sync first: old base shows ATOMIC BREATH), halo stills
  to interview.md.
- Croc standing (claude/croc-standing 67c0862f, builder af945700 running suites + --log capture): stomp now lands
  on a foot (11/11) with ring/cracks; critic r1 FIX minor -> bigger lift, body dip, camera kick, ±10% variation,
  old-crack fade, rake arc past the silhouette; item 7 = an unexplained 18 px camera jump (being traced). Idle clip
  attached to the lead's interview question.
- Voxel boards (claude/look-boards, builder a1faedbb): A boards done (F1 must move to an unfaded moment); B mock
  then C, notes vfx-lead/look_boards/; critics then interview.md.
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

## Overnight 2026-10-23 (director asleep, then at work; lead's plan 03:2x)
No AskUserQuestion: director questions go to Kaiju-Incremental-wt/lead-board/interview.md (read its README);
lead's replies in to-vfx-lead.md, my fallback reports in from-vfx-lead.md. Every Godot run starts with
`bash ~/.claude/tools/engine_slot.sh && timeout ...`. Open PRs over cap: push branches, report sha, the lead's
GitHub helper opens PRs. Thunder sound = the lead's.
- D-162 asset worker (Agent "claude" type, Sonnet, own worktree, branch claude/heads-skins): Tripo python x2 +
  Komodo x2 heads, skins as Blender gradient maps; done (see above). Tripo downloads: Save dialogs belong to the
  Claude app and nobody can press them; fetch the viewer's signed tripo-data FBX via performance entries + curl.
- Idle audit (lead's, scratchpad idle_audit.md): director asked an AUDIT only, no idle layer before he answers.
  Brief scratchpad brief_idle.md = the 2 bugs (standing stomp has no foot/ring; claw-rake pose never plays) +
  ONE 6 s clip of today's standing croc for the lead's interview question.
- Voxel look (director 03:34; report lead scratchpad research_voxel_look.md: keep voxels, unify grain/ground/
  fire/DoF): I render A TODAY / B ONE LOOK (mock, ~1 day) / C SMOOTH CROC, 6 boards + 6 s 3-pane clip per its
  section 5, capture-only branch, critics first, then interview.md. After #154 PASS and Thunder Beam.
- Slot order now: voxel boards (brief scratchpad brief_voxel_boards.md) -> item 4 fix (brief_item4.md) -> dust
  billows -> explosions r10 once #160 merges.

## Running jobs
Builders croc-standing + voxel-boards hold my 2 engine slots; Thunder waits for "go". Stall watcher (scratchpad
stall_watch_copy.sh, SKIP_PIDS for foreign runs) over the 3 builders' subagents/*.jsonl; lead-board watcher on
to-vfx-lead.md (re-arm both after each wake).

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
