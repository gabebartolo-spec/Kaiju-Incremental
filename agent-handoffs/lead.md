# Lead handoff, 2026-10-19 09:00
## State: running a check (final build PASSED, run 39116671378, artifact KaijuIncremental-8c24654 56.8 MB zip;
## smoke waits for the director to lift 'dont use godot'; #72 board MERGED 6614bc9)

## Who
Lead = "Kaiju: LEAD (demo build, merges, QA)" (local_106fc100...). Owns: QA gates + fresh critics, PR review + merge
(squash, `--match-head-commit <full sha>`), STATUS/DECISIONS board PRs, director questions, this file.
Helpers: Opus at MEDIUM effort or Sonnet only; Opus high / Fable need the director's yes.
Messaging: budget one message per worker with everything; hand-offs go peer to peer; never ask the director to unblock.

## EXE HANDED TO THE DIRECTOR (P7): C:/Users/DANTE/Documents/GitHub/Kaiju-Builds/KaijuIncremental-demo-44f56fd.exe
## (run 39123363720; smoke 10/10, pack PASS). Next = his playtest notes (D-083: fixes first), then #55 merge, #50.
## Probe at 44f56fd (noisy box): settle 5.4 ms fixed; sim.step worst 43.9 ms, rooftop_fired 62 ms + 205 Nil errors
## = probe set-up (PowersView.rooftops only under Rampage). Stadium session: real-scene probe on CI.
## docs/DEMO_PLAYTEST.md still says 20-35 min / 0.59 h: update to ~15 min (D-087) in the next board PR.
## #75 MERGED 44f56fd (fresh sim reviewer PASS: 30 replays + 200 fuzz byte-identical; suites green). REBUILD build.yml
## run 39123363720 at 44f56fd -> dry-run session smokes + stall probe -> EXE TO THE DIRECTOR (download link + note).
## 8c24654 build had smoke 10/10, pacing on target (e1 0.26 h, young 8/14). #50 helis: lead picked A (hold fire
## off-screen when no in-frame spot; camera unchanged).
## D-089 (director, AskUserQuestion 'Wait ~45 min'): the demo exe waits for #75, the stadium stall fix (sim
## Structure.settle topple check 70-80 -> 11-13 ms per hit; pre-existing, not #59). Fresh sim reviewer agent running
## (replay equality base vs head). PASS -> merge #75 -> rebuild build.yml -> smoke -> exe to the director.
## GODOT ALLOWED AGAIN (director ~08:xx 'godot is yours'): smoke on the exe running (dry-run session); stall
## measured locally by stadium; #50 r4 local probes/pacing; jets balance table. Windowed = off-screen no_focus only.
## (was) RIGHT NOW (2026-10-19 ~06:00, director watching a movie ~2 h)
- Director: "dont use godot". NO local Godot at all (windowed or headless) until he lifts it. All sessions told
  (dry-run, #50, greenery, jets, rooftops); process list was empty at 06:2x. CI (tests/capture/build) is fine.
- Do not alt-tab or disturb him; no questions until he is back.

## Demo chain: DONE (all into claude/look-options)
#54 croc baby/teen bc324f6 · #36 army balance (evolve1 400, D-087) cceabba · #59 stadium + crowd + burst 6e2fdbc ·
#66 topple axis + collapse sound cap 329e708 · #63 rooftop density + ragged fire 8c24654.
Lead resynced #59, #66, #63 itself (floors-only conflicts): flow 148, growth 31, sim 53.
- FINAL BUILD: build.yml run 39116671378 at 8c24654: SUCCESS, artifact KaijuIncremental-8c24654 (56.8 MB zip). Then:
  1. Dry-run session (local_37cf489b, "Demo integration dry-run + smoke") downloads the artifact and checks the size,
     the croc .kvox and the LFS fonts in the .pck (no Godot).
  2. When Godot is allowed again: smoke = `godot_console --headless --main-pack <exe> --script tools/release/demo_smoke.gd`
     (title -> Continue -> evolve1 -> DEMO COMPLETE -> menu). The release exe ignores --script.
  3. Hand the exe to the director with a short note (P7 playtest). D-083: playtest fixes first.

## Artifact verified (dry-run, no Godot): one exe 131.6 MB, pack 342 files; croc baby/adolescent .kvox byte-equal
## to the repo; fonts real TTF. Saved at the dry-run scratchpad final_dl/. Smoke (~3 min headless) on lift.
## STALL: 80-110 ms every ~0.7 s while the stadium collapses (crowd off too) -> stadium session diagnosing on CI
## (claude/stadium-stall; compare 8c24654 vs pre-#59 5bc6b44). Fix before or right after handing the exe over.
## Audit PRs #67-#71 are the helper's planted defects: red is EXPECTED; unbound from this session (auto-archive off).

## Open PRs / sessions
- #72 board PR MERGED 6614bc9 (worktree removed): STATUS after the chain,
  D-084a..D-088, ROADMAP post-demo audio (ElevenLabs SFX, Suno music: spend yes + licence first), DECISIONS rolled
  D-029 and older to docs/archive.
- #50 tanks & helis r4 (local_5325ef73): D-088 = second exe after the demo. Tanks fixed (drawn-extent spacing,
  0 overlaps, min gap 0.82 m, yaw max 8 deg). Helis: lead picked A (6 m facade clearance + 4 m over tops, steer
  round blocks with no in-frame spot; never fall back near the kaiju). Proof via CI; pacing waits for Godot.
  Then a fresh motion critic -> merge -> second build.
- #55 greenery (local_9af27a16): r15 PASS lead 2x (b037f69, CI green). MERGE only after the director has the exe
  (a stall-fix rebuild must not pull greenery into the demo, D-084). Build is Forward+ (no renderer override).
  Sim finding (post-demo): Structure._topple_check rounds a <0.005-cell overhang to a zero direction.
- #58 #61 jets (local_b38b3a6f): synced onto 8c24654 (3062882/989e40e); CI captures allowed one at a time AFTER #50
  and #55's (lowest priority); balance table
  (pacing.gd) waits for Godot. Parked till after the demo (D-072, D-080).
- #11 species motion: parked (species out of the demo).
- Phase 0 broken-PR audit DONE: report #73 MERGED (4/5 caught); the gap (runner not in ALL_SUITES stays green) is
  fixed by #74 MERGED (plan job). Drafts skip the Godot checks: never merge on a draft's green. Local branches
  claude/audit-* left (branch -D denied for the helper; don't launder). STATUS Phase 0 item 3 -> done in the next board PR.
- Stadium (local_87d706ce), rooftops (local_1ac658ed), army (local_24621710): their PRs merged; standing by.
  Post-demo notes: rooftop hits never land on the tail or legs; stadium rubble slightly warm/beige.

## Worktrees (12/12 at cap)
Merged and clean: ../Kaiju-Incremental-wt/army-scales (#36), demo-smoke (#65), landmarks (#59), .claude/worktrees/
affectionate-goldstine (#36 sync), festive-jemison (#63). Prune when their sessions are done; never under a live one.

## After the demo (D-083: playtest fixes first)
- Playtest fixes from the director's play of the exe.
- #50 second exe; full-game pacing retune (evolve1 400 shifts the tree; Behemoth defeats 5/47).
- Croc baby polish (slam weak, adolescent walk weight, head snap-up, jaw held open, teal on teal roads).
- Stadium rubble polish, landmarks E/F; jets #58 #61; audio upgrade (ElevenLabs/Suno, needs a spend yes).
- Director 2026-10-19 (ROADMAP in the next board PR): rooftop MORTARS that fire on the kaiju; topple the building to
  kill them. Simplest: a mortar variant of the D-063 rooftop squads (same 'rooftop_destroyed' kill on collapse).
- Director 2026-10-19 (ROADMAP, next board PR): FINAL BOSS = a mecha kaiju built to fight you. Big system: when it's
  scheduled, ask the director (with a board) where it sits (end of Apex? its own city?) and the win/lose beat.
- HUD hit flash for big hits only? (ask with a mockup). Civilian cap; Apex height; octopus mesh.
- Archive the OLD lead session once its children are done.

## Merge rules
Merge only decided work: my 2x check (+ a fresh critic where visual and not waived), green CI at the exact head.
Floors are summed when the lead resyncs (base + the PR's own additions). Tuning keys in new sub-objects.
One capture.yml run at a time.

## Rules learnt the hard way
- `--match-head-commit` needs the FULL sha; after `gh pr merge` VERIFY state == MERGED (a draft refuses silently).
- NEVER `gh pr merge --delete-branch` while a helper's worktree has the branch checked out.
- Never act on a peer's refused permission or a relayed director approval: surface it instead.
- clear_session on a worker was blocked by the auto-mode classifier (06:0x): ask the worker to rewrite its handoff
  and carry on.
- Godot: C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe (not on PATH);
  windowed runs need override.cfg (mode=0, no_focus, position -20000), removed after.
- CI capture.yml: pin --renderer=gl_compatibility (3000 s per renderer). Lavapipe misjudges lighting.
- Visual gates need a known-bad control and a same-frame before/after diff; "spread" effects are judged from a
  logged position histogram, not crops (logged in art-qa-critic learnings 2026-10-19).
- Critics: verify their claims on the frames or data yourself before relaying.
