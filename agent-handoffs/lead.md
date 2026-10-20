# Lead handoff, 2026-10-20 (lead session 5 of 10-20; next lead: read lines 1-14, then GitHub)
## State: lead 5 working. Helpers are in-process subagents of lead 5 (die with it: respawn from the handoffs named here).
## Team (lead 5): review-wp1b (Opus med, fresh re-review #97 @42a1f55, posts PR comment) · wp2-lint (Sonnet, #99 gdlint; 1st push 96f4180 still red) ·
##  wp4-slab (Sonnet, slab 8a8780 + re-capture on claude/carve-wp4) · wp3-still (Sonnet, before/after stills of tank riser + sign brackets -> C:/Users/DANTE/AppData/Local/Temp/claude/wp3-still/) ·
##  wp5-recap (Sonnet, debug blow sphere OFF by default (lead 2x found it in block clip), head e9c7582, 3 CI captures one at a time -> Temp/claude/wp5-recap/) ·
##  critic-89 / critic-50 / critic-wp5 (fresh motion critics; wp5 on old clips, motion only). Lead 2x done: #50 r7 crops PASS (hull outlines on model, centred between kerbs); #89 frames OK.
## #50 MERGED cb8bbed (lead 5; critic-50 FIX filtered: fb4 601-781 shows the reverse). WP4 slab 8a8780 pushed 609ea71 (stills lead 2x OK); PR after #98/#99.
## #89: critic-89 FIX confirmed at 2x (white flat debris slabs, slab hovers, abrupt topple) -> croc89-fix (Sonnet) in its worktree. WP5: critic-wp5 FIX (slab never breaks up, block staircase shear, debris visible in glass) = round 2 -> show director after wp5-recap clips.
## CI at head: lead pushed empty 'CI at head' commits: #98 fb19f4a (lint green, tests running), #89 d259939 (lint green, tests running). #97 42a1f55 green.
## PRs: #97 WP1 d8174d4 review FIX (comment 6279596456: re-flood after topple, adopt guard, dir/pivot in replay) -> carve-wp1 life 2 fixing + fixture rule; WP7 needs a wear rule (tough_mult 0.35, no wear) · #98 WP3 FIX DONE code dec83bc (tests 39342624070 + lint green; head 38ab0d2 handoff-only [skip ci]): islands 0/120, fixtures window/mullion/glass/shop/sign_frame/neon0-3; VIEW CHANGE (water-tank pipe riser, neon sign brackets) -> needs a still + lead 2x, then fresh re-review, merge · #99 WP2 c3c5fec gdlint RED (run 39340822128): fix it · #100 board D-099 MERGED.
## #98 lead call: panes/signs held by edge = material flag "fixture" in data/materials.json; fixture cells ground by 26-neighbour contact, structural 6-neighbour.
##  WP1 must add that rule in sim/voxel_support.gd (batch with review-wp1's findings into one carve-wp1 life). Tank with no contact = generator fix (+BuildingVoxels).
## carve-wp6 DONE claude/carve-wp6 b083346 (LandmarkCells, CellGrid base moved out of BuildingCells, Arcs shed on cells; body pr_body_wp6.md in its worktree). Merges carve-wp3: open after #98 merges, resync first (carve-wp3 life 2 also edits building_cells.gd), then fresh kaiju-sim-review. Lead call: arc_shed_cells 32 kept (= today's trigger; balance is his playtest).
## carve-wp4 DONE claude/carve-wp4 8be4cfc (code a4fe572 tests 39343371928 GREEN); captures docs/captures/2026-10-20-carve-view/ (a_baked, b_promoted, c_carve1-4; lead 2x not done); body pr_body_wp4.md in worktree. PR after #99/#98 merge; lead 2x + motion critic on stills.
## DIRECTOR 2026-10-20 (question tool): carved-hole floor slab = B concrete 8a8780 (was 2b2d30). Swap "slab" in BuildingVoxels._make_palette on claude/carve-wp4, re-capture; record as a D-id in the next board PR.
## CI at exact head: #98 head 163a56b and #89 head a7d0834 are [skip ci] handoff commits with NO checks: re-dispatch tests.yml on each head before merging. #99 gdlint still RED.
## #50 r7 pushed a4e7198 (body updated): tests 39346031458 + lint GREEN at a4e7198, capture 39346082013 OK (builder scratchpad r7/ci). Overlays fixed (r7/ov2 in the military-ai builder scratchpad); hulls 0.0 deg; hull-edge standoff min 8.1 m (cornered tank 7.8 m, lead call A); fall-back clip r7/fb4 (3.5 m/s readout), game clip r7/game2. NEXT: lead 2x on crops, fresh motion critic, merge full sha. Builder stopped at 202k.
## #89 D-099 ALIGNED: code 677718e (head a7d0834 handoff-only), tests 39342572775 + lint GREEN; topples follow the cut dir (58/58; 40 toward kaiju, 2 away; gutted drops go toward the chewing kaiju). Clip 39341631409: lead scratchpad cap/capture-39341631409-0/clip.mp4 (unwatched). Young pacing not rerun.
##  Then: lead 2x on the new tower capture, fresh motion critic, merge full sha -> #88 (4f45ca2) resync/merge -> #90 -> young-retune PR.
## #50: tests 39304886469 GREEN at 1eed939; r6 builder finished (no respawn needed). Next: critic-50 verdict + lead 2x crops -> merge full sha.
## retune-a DONE claude/young-retune 67e0b1a (e1 0.24 h, young defeats 5.4/12; body pr_body_retune.md in its worktree): PR after #89/#90 merge.
## carve-wp5 life 3 DONE claude/carve-wp5 (4 critic fixes: break wait tower 1.17->0.13 s, block 1.43->0.47 s (goal 0.3); gouge dark px 1021->0; rubble_cap 2000; bottom-up break 0.4 s). Clips tower 39345155884, swipe 39344743509, block 39345232517 in lead scratchpad ci_<scene>/ (UNWATCHED). Body pr_body_wp5.md in worktree. NEXT: lead 2x, fresh motion critic, show director, open PR.
## WP5 PR opens after life 3's fresh critic passes and the director sees the clips.
## #88 head dca0e988cd4f34c640c2349fc40699c0a40032b3: re-review PASS + notes a/b done. Only 2 expected city reds (tier gate). After #89 merges: resync, CI, merge.
## #95 board PR (docs: playtest chapter docs/roadmap/2026-10-19-director-playtest.md, D-095, D-096), head 6662b7d: check lint, merge.
##  Playtest notes with no PR: 9 (small buildings south of spawn not destructible = tier gate, should clear with #89 + #88 river check: verify in play), 12 destruction option A (after exe 2).
##  Note 9 = backdrop boxes south of the old spawn; fixed by #88 (start moves to the river); fix #95 row 9. #88 own red (seed 98765 bldg 90, tier 2, chunk HP 14, young stomp 3.54/chunk after dwarf_mult) is the CHECK, not the game: tests/lib/city_spawn_view.gd:38-39 stomps once; D-091 says big ones take longer. Lead call: change it to "a young kaiju walking in brings every building within 12 m of the rise point down within N s" (probe: gone by 3 s; swipe ~2 s). Do it in the #88 resync after #89 (keep-both conflicts: rampage_sim.gd emerge+body; rampage.gd emerge.start + body.use_species). Empty folder ../Kaiju-Incremental-wt/note9: delete refused, director.
## claude/ci-shards 67e2873 (no PR): timings refreshed, 2->3 shards, gain ~25 s only (9 suites, flow 109 s is the floor). Low priority: PR when a slot frees, or drop.
## Retune = one balance pass on the baby/young croc after #89+#90+#85 (notes 8, 11; e1 ~0.26 h; young defeats ~8/15). Director asked if tools/pacing.gd plays like a human: NO (nearest building, cheapest upgrade, no dodge/aim/dash). young-retune told to calibrate vs his note-8 cadence (1 -> 8 -> 1) first and caveat its numbers. Explain every label to him the first time.
## young-retune milestone: note 8 cause = cost ladder (8 L1 nodes 15-76 = 283 total, next 91, rest 114-178+). Merged baseline: e1 0.16 h (dash), young defeats ~6/15, army quiet 0-20 s then steep. Bot under-earns vs director (no topple/stadium aim). Options pending -> ask director.
Lead = "Kaiju: LEAD (demo build, merges, QA)". Owns: QA gates + fresh critics, PR review + merge (squash,
`--match-head-commit <full sha>`), STATUS/DECISIONS board PRs, director questions, this file.
Helpers: Opus at MEDIUM effort or Sonnet only (Opus high / Fable need the director's yes).
Messaging: one message per worker with everything, sent ONE AT A TIME (a failed first send cancels a parallel batch).
Never ask the director to unblock messaging. Ask him the ask-the-director way: one decision, recommended option first.

## Where we are
- Demo exe 1 (44f56fd) played; director paused the playtest: "not shippable as is ... a very good start". D-083:
  playtest fixes first, then demo exe 2 (build.yml from claude/look-options), build session smokes it, he plays.
- Board current to D-094 (#93 MERGED b09c4a9): DECISIONS, ROADMAP post-demo items, STATUS live-PR table.
- Godot rules: director playing a game / watching a movie = NO local Godot at all (headless too), CI only. Director AFK
  = local GPU, windowed runs only off-screen (no_focus override.cfg at -20000, removed after). Pause = sessions must
  also cancel their background watchers (a CI watcher woke the croc session after the pause; lead stopped it).

## Merged today (playtest fixes)
#75 stall · #77 frame cap · #78 crowd killable · #79 stadium 1.5x · #80 rifle crack · #83 breath from snout ·
#73/#74 lints · #76 stall probe · #81 less camera smoke · #84 faster run load (cache pruned per city) ·
#87 ElevenLabs SFX (D-092) · #91 destruction spike · #92 Graphics Balanced + 60 at 4K (D-093) · #93 board.
#82 sound gate (3 s timeout) MERGED 0c70480 after a lead floors resync (load 15, flow 157).

## Open PRs and their next step (all into claude/look-options)
- #89 croc contact (session "Kaiju: Croc contact + dash", local_1feb30ca): D-091 rework done (no TOO STRONG; dwarf
  factor (size/tier)^1.5; tower topples after 3.3 s). Fresh sim review FIX, sent: (1 blocks) tests/run_sim_tests.gd
  `_sim` never calls body.use_species() so determinism/autoplay run bodyless -> RampageSim picks the body itself,
  autoplay never held > N s; (2) body_contact.gd:135 final sample uses from_heading.rotated, hold test uses heading;
  (3) validate bite_dps > 0. Round-2 clips (tower topple, torn pieces) on CI: lead 2x check, then motion critic.
- #90 dash (same session, stacked on #89): resynced + lint fix, head 9f7194a, CI green; evolve1 cost 425 -> 0.26 h, young defeats 6/13. Fresh motion critic
  after #89 merges.
- #85 army ramp DRAFT (b38b3a6f): after #89 + #90, ONE joint young retune: e1 0.26 h ±5%, young defeats 8 ±2 per 15.
- #88 river emergence (9af27a16): lead FIX: continuous sunk channel + quay wall, real bridges, no cars on quays,
  breakable buildings within 10-15 m of the landing (no-empty-space). Then fresh sim reviewer; merges after #89.
  CI RED (expected): its 2 strict city checks (1 building near the rise point unbroken by a stomp) pass only once
  #89 removes the tier gate. Push the 3 unpushed commits in ../Kaiju-Incremental-wt/greenery first.
- #50 tanks (5325ef73, worktree ../Kaiju-Incremental-wt/military-ai): r6 WIP, head ad1e7ab, CONFLICTS with
  look-options (floors; resync first), CI RED (expected): closest
  tank 4.6 m from body edge vs 8 m bar; 86/3522 parked steps skewed > 15°. r5 critic FIX (lead-confirmed at 2x): tank
  under the snout 12-13.5 s -> standoff = body edge + 8 m, brake before it; reverse 3-4 m/s; hull vs turret overlays at
  12.5/17.5 s; tank 2 parked skewed -> square it. Proof: sim check failing first, CI clip, overlays, pacing.
  Helis: D can't fit the streets; render a B clip (camera eased to x1.4 while a pair is up) + a still of today's
  camera -> one director question. Not built into #50.
- #86 rooftop hits on legs/tail (1ac658ed): post-demo polish; CI clip pending.
- #55 greenery r15 PASS: merge when exe-2 scope is set. #58/#61 jets drafts parked (#58 f175d03 CONFLICTS again); #58 critic FIX (mirror wings,
  the "miss" does 30 HP, laser tracer, gun audio 0.3 s late). #11 species motion, #3 look-options -> main: on hold.

## First moves on resume
1. Wake croc session: finish #89 FIX 1-3, clips. 2. Tanks session: r6. 3. River session: #88 FIX.
4. After #89/#90 merge: army session joint retune (#85). 5. Build exe 2, smoke, director.

## Sessions (names in the sidebar)
Build "Kaiju: Load, smoke FX, builds" 37cf489b (handoff board.md in ../Kaiju-Incremental-wt/demo-smoke) · tanks 5325ef73 ·
croc + dash 1feb30ca · army b38b3a6f · river 9af27a16 · rooftops 1ac658ed · stadium 87d706ce · destruction spike
0a7e5cf8 (done) · OLD lead 9fac90d2 (retired: archive). Sessions auto-archive when their PR merges.

## After demo exe 2
Destruction option A (D-094, ~19 agent-days; 3-4 parallel sessions): plan on branch claude/destruction-plan 3ad6815
(agent-handoffs/destruction-spike.md, no PR), prototype on claude/destruction-proto. Roadmap: mortars, mecha boss,
six languages, Suno music (not bought). Proposal: split the shared floors file (AFL audit, their #825).

## Assets and links
SFX shootout: https://claude.ai/artifact/RJyirrk8y6eTvzqB6woHpZ · raw ElevenLabs takes:
C:/Users/DANTE/Documents/GitHub/Kaiju-Assets-Raw/elevenlabs_2026-10-19 · exe 1:
C:/Users/DANTE/Documents/GitHub/Kaiju-Builds/KaijuIncremental-demo-44f56fd.exe.

## Team ARCHIVED (director, handover). Unarchive a session to resume it, or start fresh ones from their handoffs.
Unsaved work left on disk (not lost, not pushed): ../Kaiju-Incremental-wt/greenery = 3 unpushed river commits
(sunk canal + bridges + quay sheds, 7415767..680a603) + uncommitted data/tuning.json -> push before resuming #88;
jets (11 uncommitted files), burst-shared (3, stadium shared-burst-mesh fix, never a PR). Auto-fix was on for #50,
#85, #58, #61, #86, #88, #89, #90: it re-woke paused sessions on conflicts and red CI. Turn it off when pausing.

## Worktrees
Pruned today: fps-cap, graphics, sfx-eleven, smoke, run-load, stall-probe, spawn-south, board-d094. Left: burst-shared
(3 uncommitted), greenery (river, 1), jets (31 uncommitted), military-ai, sfx-gate, demo-smoke, integ-a/-export
(detached), army-scales (remote branch gone; check before removing); sfx-gate can go (#82 merged). Local branch
lead-resync82 left (branch -D was refused; don't launder).

## Merge rules
Merge only decided work: lead 2x check (+ a fresh critic where visual), green CI at the exact head. The lead resyncs
floors-only conflicts itself (sum each suite's gain from the merge base). One capture.yml run at a time. Never merge
on a draft's green.

## Rules learnt the hard way
- `--match-head-commit` needs the FULL sha; after `gh pr merge` VERIFY state == MERGED.
- NEVER `gh pr merge --delete-branch` while a helper's worktree has the branch checked out.
- Never act on a peer's refused permission or a relayed director approval: surface it instead.
- start_session worktrees are cut from main unless source_branch=claude/look-options is set.
- A subagent's PRs bind to this session with Auto-fix + auto-archive: unbind audit/throwaway PRs at once.
- TaskStop kills the shell, not a bash loop's next Godot: kill the loop's bash first, re-check the process list.
- Godot: C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe (not on PATH).
- CI capture.yml: pin --renderer=gl_compatibility; it shades lit materials brighter than Forward+ and has no FSR.
  The GitHub API rate limit is shared by every session: poll every 2-3 min, not 30 s.
- Visual gates need a known-bad control; "spread" effects are judged from a logged position histogram.
- A standoff measured from a creature's centre lets units walk under its head: measure from the body edge.
- Settings that save a resolved default (not the player's choice) freeze later default changes: version the cfg.
