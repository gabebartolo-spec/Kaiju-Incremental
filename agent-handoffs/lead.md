# Lead handoff, 2026-10-19 10:30
## State: running a check (demo playtest PAUSED by the director; 12 playtest fixes in flight -> demo exe 2)

## Who
Lead = "Kaiju: LEAD (demo build, merges, QA)" (local_106fc100...). Owns: QA gates + fresh critics, PR review + merge
(squash, `--match-head-commit <full sha>`), STATUS/DECISIONS board PRs, director questions, this file.
Helpers: Opus at MEDIUM effort or Sonnet only; Opus high / Fable need the director's yes.
Messaging: one message per worker with everything; never ask the director to unblock. Send briefs ONE AT A TIME:
a failed first send in a parallel batch cancels the rest.

## River (9daef55, claude/river-start): far-bank park, emergence; lands AFTER the croc-contact D-091 PR (its 2 strict
## checks need the tier gate gone). #50 r4 critic FIX (lead-confirmed: drawn hull ~35-40 deg off the N-S street at 9-10.5 s,
## on police cars; hull swings at the post) -> r5 list sent: lane-locked hull, car keep-out, turret-only, standoff.
## RESUMED (director): all sessions told (river notes, stadium shared-burst-mesh fix approved: hits 40-48 ms windowed,
## fall_start makes new render resources per burst). Rifle-fire PR + breath snout fix queued at rooftops.
## Sessions renamed: Gun audio + breath aim (1ac658ed), Stadium + frame probe (87d706ce), Load, smoke FX, builds
## (37cf489b), River spawn + greenery (9af27a16), Biomass + army ramp (b38b3a6f), Tanks + helis #50 (5325ef73),
## Croc contact + dash (1feb30ca), OLD lead (retired) (9fac90d2), this = Kaiju: LEAD.

## Where we are
- Demo exe 1 (44f56fd, #75 stall fix in; smoke 10/10; pacing e1 0.26 h) given to the director at
  C:/Users/DANTE/Documents/GitHub/Kaiju-Builds/KaijuIncremental-demo-44f56fd.exe. He paused the playtest:
  "not shippable as is ... a very good start, well done". D-083: playtest fixes first.
- Local Godot: allowed (headless; windowed only off-screen no_focus override.cfg, removed after). During a director
  playtest or movie: NO local Godot at all, every session (and a heads-up to the AFL lead, local_8cceb00a).

## Playtest fixes (director's words; owner session; each its own PR into claude/look-options; lead 2x + critic)
1 "rooftop gun chatter sounds like a type writer" -> rooftops (local_1ac658ed): <=3-4 cracks/s, gap 0.25 s, falloff.
2 kaiju phasing through buildings; KEEP the hollowing-out ("feels really cool") but the body breaks every voxel it
  overlaps -> NEW session croc-contact-dash (local_1feb30ca; told to reset from main onto look-options).
3 "atomic breath doesnt feel aimed" -> rooftops: ground reticle = sim target.
4 "need a charge/dash" -> croc-contact-dash: Shift / B, ~0.4 s, cooldown ~4 s, smashes its path, "dash" tuning.
5 "stadium audience shouldnt disappear so suddenly, let us kill them" -> stadium (local_87d706ce).
6 run-start load times; 7 gunfire audio before the visuals; 10 loud GPU fan (vsync_mode=2, no fps cap -> max_fps +
  setting 60/120/unlimited); 12 "still too much smoke on camera" -> dry-run session (local_37cf489b).
8 biomass cadence (1, then ~8, then 1 upgrade): the stadium's 4x rubble_bonus. D-090 (director): stadium 1.5x;
  the wheel gets the highest value <= 1.5 keeping runs <= 2x the one before -> jets session (local_b38b3a6f).
9 "smaller buildings south of the spawn dont seem destructible": they're skyline stand-ins (spawn (0,42), playable
  edge z=44.5). Lead call A: widen the playable area one block south, make that row real -> greenery (local_9af27a16),
  together with:
11 "military response too high from the word go ... emerge from a river" -> greenery: the river + emergence, event
  "kaiju_emerged"; jets session: the army alert ramps over ~20-40 s from that event.
MERGED: #79 D-090 stadium + wheel 1.5x (2nd Behemoth run 2.5x spike -> full-game retune, past the demo); #78 crowd
killable + gradual flee (f0634ee).
MERGED: #77 frame cap (ce6648c; 60/120 default/unlimited, menus <= 60) -> exe-2 smoke must capture the Settings screen.
#50 split: tanks-only PR + helis to claude/heli-flight with a D (street canyons) vs B (camera pull-back) note -> director.
Then: lead checks every PR at 2x (+ a fresh critic for visuals), merges, builds demo exe 2 (build.yml), the dry-run
session smokes it, and the director plays again.

## Other open work
- #50 tanks & helis r4 (local_5325ef73): tanks fixed (drawn-extent spacing, yaw <= 8 deg); helis A = hold fire
  off-screen when no in-frame spot (camera unchanged, lead call). CI fixes in progress. Fresh critic when done.
- #55 greenery r15 PASS (b037f69): merge once the exe-2 scope is set (D-084 kept it out of exe 1). D-075 green lots
  (lattice, no RNG) is on claude/green-lots behind the playtest fixes; it needs a fresh sim reviewer.
- #58 jets critic FIX: wings read forward-swept (mirror them), the "miss" does 30 HP (hit flash or a real miss),
  the tracer reads as a laser (6-10 streaks/s), gun audio 0.3 s late -> send to jets after its playtest fixes.
- #76 stall probe (tools only) -> merge on green.
- Roadmap (next board PR): ElevenLabs SFX + Suno music (spend yes + licence first); rooftop MORTARS (topple to
  kill; a variant of the rooftop squads); FINAL BOSS mecha kaiju (board for the director when scheduled).
  LANGUAGES (director 2026-10-19): Spanish, Japanese, French, German, Russian, Italian. Needs: one text table (all UI
  strings by key), fallback fonts with Cyrillic + CJK glyphs (licence CLEARED; our display fonts are Latin-only?),
  AI-drafted translations reviewed by a native speaker before shipping; a language option in Settings.
  Board PR also: STATUS Phase 0 item 3 done (#73, #74); DEMO_PLAYTEST.md -> ~15 min (D-087); D-089, D-090.
- AFL lead's test-suite audit (their PR #825): one shared floors file causes merge conflicts on every resync and
  never caught a truncation; shards planned from real timings; a 3 s "every runner compiles" preflight. Kaiju has
  the same floors shape (expected_checks.txt conflicted on every merge tonight): propose it to the director post-demo.

## MERGED: #83 breath from the SNOUT (BreathCone.of; Beh/Col defeats up -> full-game retune), #80 rifle crack/pop (5d1a892).
## #85 army ramp DRAFT: young defeats 8->2; one joint young retune AFTER D-091 (croc-contact). Order: D-091 -> #85+retune -> river.
## SFX PASS (D-092) DONE: director picked 12 (shell_hit kept) on https://claude.ai/artifact/RJyirrk8y6eTvzqB6woHpZ ->
## PR #87 (14 ogg loudness-matched +-0.5 dB to the old files, rifle start_s 0, LICENSING row + provenance). Auto-fix on;
## merge on green. Raw takes: C:/Users/DANTE/Documents/GitHub/Kaiju-Assets-Raw/elevenlabs_2026-10-19 (outside repo).
## #86 rooftop hits on legs/tail (post-demo polish) open; its CI clip pending.
## Decisions to log (next board PR)
D-092 (director 2026-10-19, AskUserQuestion): SFX via ElevenLabs Starter ($1 first month, then $6/mo, commercial
licence; the free plan has NO commercial licence). Suno music deferred (free = no commercial rights, no downloads; Pro
$12/mo). He subscribes himself in the browser pane; then the SFX pass, with LICENSING_REGISTER CLEARED per file.
D-091 (director): no building is 'too strong' for the baby; big ones just take longer, and he can tear out the base
and topple them (replaces the tier gate + 'TOO STRONG'; evolve1 text changes). Owner: croc-contact-dash.
D-089 (director): the demo exe waited for the #75 stall fix. D-090 (director): stadium rubble_bonus 4x -> 1.5x
(replaces D-081). Lead calls: #50 helis A; playtest fix 9 option A (real south row).

## Sessions
Live: rooftops, stadium, dry-run, greenery, jets, #50, croc-contact-dash (new). ARCHIVED on PR merge: army
(local_24621710), croc (local_bce75838). OLD lead (local_9fac90d2): archive once its children are done.
Sessions auto-archive when their PR merges: check list_sessions before briefing.

## Worktrees
Merged and clean, prune when their sessions are done: ../Kaiju-Incremental-wt/army-scales, demo-smoke, landmarks;
.claude/worktrees/affectionate-goldstine, festive-jemison. Local branches claude/audit-* and claude/collapse-cap
are left (helpers' branch -D was denied; don't launder).

## Merge rules
Merge only decided work: my 2x check (+ a fresh critic where visual), green CI at the exact head. The lead resyncs
floors-only conflicts itself (sum the floors). One capture.yml run at a time. Never merge on a draft's green.

## Rules learnt the hard way
- `--match-head-commit` needs the FULL sha; after `gh pr merge` VERIFY state == MERGED.
- NEVER `gh pr merge --delete-branch` while a helper's worktree has the branch checked out.
- Never act on a peer's refused permission or a relayed director approval: surface it instead.
- start_session worktrees are cut from main unless source_branch is set: pass source_branch=claude/look-options.
- A subagent's PRs bind to this session with Auto-fix + auto-archive: unbind audit/throwaway PRs at once.
- TaskStop kills the shell, not a bash loop's next Godot: kill the loop's bash first, re-check the process list.
- Godot: C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe (not on PATH).
- CI capture.yml: pin --renderer=gl_compatibility; it shades lit materials brighter than Forward+ (the build is
  Forward+). The GitHub API rate limit is shared by every session: poll every 2-3 min, not 30 s.
- Visual gates need a known-bad control; "spread" effects are judged from a logged position histogram.
