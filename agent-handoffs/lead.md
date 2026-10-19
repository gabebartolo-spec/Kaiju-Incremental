# Lead handoff, 2026-10-20 (resumed on the other account)
## State: working. Lead resumed 2026-10-20; old team sessions are on the other account (not visible here).
## Since the pause: #94 (function-count tests, no floors, shards from timings), #86, #55 MERGED; #85 CLOSED.
## All 4 work PRs (#89 #90 #88 #50) CONFLICTING since #94 deleted tests/expected_checks.txt.
## Local headless Godot ON (director 2026-10-20): touched suites, --quick; windowed + full suite on CI.
## Builders running (subagents of this lead): croc-contact (#89 resync + FIX 1-3 +
## clips, opus), river-start (#88 push 3 commits + resync + FIX, sonnet), military-ai (#50 resync + r6, opus).
## #90 resync after #89. PR cap: 5 open (#3 integration + 4) > 3: merge #89 then #90 first.

## Who
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
