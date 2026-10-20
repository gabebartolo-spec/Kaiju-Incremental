# Lead handoff, 2026-10-20 (lead 7 handed off at 202k; next lead: read lines 1-3, then GitHub, then list_sessions)
## State: lead 7 -> lead 8. GOAL "playable build with building carving first draft": DRAFT EXE e0f8c7c smoke PASS, at Kaiju-Builds/carve-draft-e0f8c7c, told to director (not yet played). RULES (director 2026-10-20): NO SUBAGENTS, every helper is a start_session session in sidebar group Kaiju; leads start sessions themselves, never proposal cards ("stop making me approve things"). Helper SESSIONS running (rows in sidebar; notes went to lead 7, read their recaps): carve-play life 3 (2nd build: hitch WIP in ../Kaiju-Incremental-wt/carve-play-wip, split-chunk layer/white bug, WP7 merge, build+smoke+clip; head 415c582 has WP5), carve-wp7 life 2 (pacing, merge #89, military, step cost), carve-wp5 life 5 (splits, flames hover, late landing, split-chunk layers -> PR-ready, no PR), wp6-review (fresh sim review + bridge stills), young-retune (D-098 local, push after #89/#90), stomp-ring #104 lint fix, critic-104 (stomp clips runs 39372265695/39372265557, then heli A/B round 2 review: heli-cam 00d3685, clips Temp/claude/heli-cam2, lead 2x PASS at f180).
## NEXT: (1) #89 head a1bdca1ad58ae2404a02c00704103b0266d14e4c (convoy fix): merge on green, scratchpad mog.sh pattern (lead 7 watcher stopped). (2) then #88 resync/merge, #90, young-retune push+PR. (3) #104 on green + critic SHIP + lead 2x. (4) WP5 PR, WP6 PR (after review), WP7 PR when slots free (3-PR cap; #3 is the standing look-options->main). (5) heli: if critic SHIPs B, ask director A vs B with clips. (6) board PR claude/board-d100 5611fe6 (D-103 lead calls, roadmap chapter 2026-10-20) when a slot frees. (7) carve-play rubble 400->1597 after WP5 merge (823 on one building): check the rubble cap. (8) Lead 6 session may still relay croc89-sync's stand-down then archive.
##  carve-wp3 DONE: #98 head 3ad26fcd (base merged, WP1 in; GlassFrame sim/glass_frame.gd shared sim+view; cells checks on real VoxelSupport; tests 39360777422 + lint 39360777395 GREEN) -> NEXT: fresh re-review #3 (Opus med), merge full sha. Was: #98 lead decision (c) = structural columns inside glass towers (spacing in tuning.json, sim+view parity), fix tests/lib/cells_flood_until_wp1.gd to WP1's rule
##   (fixtures never carry structural), 0 islands every style (probe: lead-5 scratchpad probe_wp3b.gd), before/after glass still -> Temp/claude/wp3-still/frame/ (re-review FIX comment 6281639153) ·
##  #99 head 1f337dd: gdlint + tests GREEN (39356570213/39356570205); doc-caps red only from lead.md 123 lines on the old merge ref (now 119): next push/resync clears it · wp5-recap DONE ·
## MERGED: #97 WP1 (lead 5, after test-gap fix d825e41). #50 cb8bbed (critic-50 FIX filtered: fb4 601-781 shows the reverse). #98 view change (riser, brackets) lead 2x PASS. WP4 slab 8a8780 pushed 609ea71, stills lead 2x OK: PR after #98/#99.
## LEAD DECISIONS today (record in next board PR): slab colour B 8a8780 (director); fixture on grid layer 0 is grounded (shopfront on street); glass towers get structural columns (c).
## WP5: critic-wp5 round 2 FIX (tower slab never breaks up after landing, block towers shear in a regular staircase, debris seen inside glass on swipe). No-marginal-gains: ASK DIRECTOR with clean
##  CLEAN clips (sphere off, head cecfac8, runs tower 39356130302 swipe 39356732686 block 39357091553) in C:/Users/DANTE/AppData/Local/Temp/claude/wp5-recap/ci_<scene>/: one more fix round now (rec) or carry into WP7. Then open WP5 PR. #89 after croc89-fix: lead 2x, merge on green (#89 CI head was d259939; croc89-fix push supersedes).
## Order: #97 + #98 merge on re-review PASS + green at head -> #99 -> WP4 PR -> WP6 PR (resync on #98, fresh sim review) -> WP5 PR. Then #89 -> #88 -> #90 -> young-retune.
## PRs: #97 WP1 d8174d4 review FIX (comment 6279596456: re-flood after topple, adopt guard, dir/pivot in replay) -> carve-wp1 life 2 fixing + fixture rule; WP7 needs a wear rule (tough_mult 0.35, no wear) · #98 WP3 FIX DONE code dec83bc (tests 39342624070 + lint green; head 38ab0d2 handoff-only [skip ci]): islands 0/120, fixtures window/mullion/glass/shop/sign_frame/neon0-3; VIEW CHANGE (water-tank pipe riser, neon sign brackets) -> needs a still + lead 2x, then fresh re-review, merge · #99 WP2 c3c5fec gdlint RED (run 39340822128): fix it · #100 board D-099 MERGED.
## #98 lead call: panes/signs held by edge = material flag "fixture" in data/materials.json; fixture cells ground by 26-neighbour contact, structural 6-neighbour.
##  WP1 must add that rule in sim/voxel_support.gd (batch with review-wp1's findings into one carve-wp1 life). Tank with no contact = generator fix (+BuildingVoxels).
## carve-wp6 DONE claude/carve-wp6 b083346 (LandmarkCells, CellGrid base moved out of BuildingCells, Arcs shed on cells; body pr_body_wp6.md in its worktree). Merges carve-wp3: open after #98 merges, resync first (carve-wp3 life 2 also edits building_cells.gd), then fresh kaiju-sim-review. Lead call: arc_shed_cells 32 kept (= today's trigger; balance is his playtest).
## carve-wp4 DONE claude/carve-wp4 8be4cfc (code a4fe572 tests 39343371928 GREEN); captures docs/captures/2026-10-20-carve-view/ (a_baked, b_promoted, c_carve1-4; lead 2x not done); body pr_body_wp4.md in worktree. PR after #99/#98 merge; lead 2x + motion critic on stills.
## #89 D-099 ALIGNED: code 677718e (head a7d0834 handoff-only), tests 39342572775 + lint GREEN; topples follow the cut dir (58/58; 40 toward kaiju, 2 away; gutted drops go toward the chewing kaiju). Clip 39341631409: lead scratchpad cap/capture-39341631409-0/clip.mp4 (unwatched). Young pacing not rerun.
##  Then: lead 2x on the new tower capture, fresh motion critic, merge full sha -> #88 (4f45ca2) resync/merge -> #90 -> young-retune PR.
## retune-a DONE claude/young-retune 67e0b1a (e1 0.24 h, young defeats 5.4/12; body pr_body_retune.md in its worktree): PR after #89/#90 merge.
## #88 head dca0e988cd4f34c640c2349fc40699c0a40032b3: re-review PASS + notes a/b done. Only 2 expected city reds (tier gate). After #89 merges: resync, CI, merge.
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
