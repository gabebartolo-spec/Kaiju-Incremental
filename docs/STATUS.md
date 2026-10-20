# Status board

Cap: 150 lines. Edited only by the merge role, in a board PR after each merge, from the merged
PR's "Board and log" section. History rolls to `docs/archive/status_<month>.md`.

## Phase
Current phase: **0 — Foundations** (gate: CI proves it rejects a lowered floor, a missing suite,
an untyped declaration and a planted secret). Gate signer: the lead.

## Lead 10 (2026-10-21): plan = ROADMAP "Post-demo plan" A-H; Phase B boards for the director
Build 4 = Kaiju-Builds/carve-build4-6cc9c77 (demo smoke PASS). Done since build 3: b2-21 stadium far from spawn,
landmarks never boxes (#115) · b2-29/b2-30 no freeze at run start or quit (#116) · claw swipe occlusion + tank crab (#117) ·
CI four shards (#118) · street trees 2.5 m apart (#119).
In flight (branches, no PR yet): turn-weight + walk m2 (comments #16, R 11, R 14) · b2-3 slow frames part 2
`claude/rubble-cap` · R 20.3/20.5/19.1 `claude/handover-fixes` · R 9.1 `claude/tentacle-substep` · R 8.1
`claude/audio-duck` · walkers on pavement `claude/walkers-on-pavement` · R 18.1 `claude/graphics-presets` ·
R 12.1/12.2 `claude/light-pool` · b2-20 board fix `claude/phase-b-boards` (never merged).

## Live PRs (2026-10-21)

| PR | Owner | State | Item | Branch | Since |
|----|-------|-------|------|--------|-------|
| #120 | hygiene | CI | stadium fans fall with their stand | claude/stadium-crowd | 2026-10-21 |
| #121 | hygiene | CI | b2-22 shared walls carry the facade | claude/b2-22-party-facades | 2026-10-21 |
| #3 | lead | on hold | look-options -> main, once the slice ships | claude/look-options | 2026-10-15 |

## Merged into look-options on 2026-10-19 (playtest fixes)
#75 stall fix · #77 frame cap · #78 crowd killable · #79 stadium 1.5x (D-090) · #80 rifle crack · #83 breath from the
snout · #73/#74 Phase 0 lints · #76 stall probe · #81 less camera smoke · #84 faster run load · #87 ElevenLabs SFX
(D-092) · #91 destruction spike (D-094) · #92 Graphics Balanced at 4K (D-093).

## Merged into look-options on 2026-10-18/19 (the demo chain)
#54 croc baby + adolescent (bc324f6, D-073/074b) · #36 army balance, evolve1 400 (cceabba, D-087) ·
#59 stadium matches + full stands (6e2fdbc, D-078/078a) · #66 topple axis + collapse sound cap (329e708) ·
#63 rooftop density + ragged fire (8c24654, D-076a/085) · #64 decisions D-062..D-084 · #65 release smoke.

Lead: "Kaiju: LEAD (demo build, merges, QA)", claude/look-options (#3 to main on hold). Board PRs: "Board & decision log".

States: working · running a check · awaiting director · blocked · available.

## Merged into look-options on 2026-10-17
#15 voxel skin (D-041) · #17 tank, #18 helicopter (D-042) · #16 city grows per evolution (D-039) ·
#20 Apex playability (13 s load, towers screen-door) · #19 croc titan adult on the Blender rig (D-046) ·
#14 game flow (end beat, report, reveal, menus, save v2).

## Assigned items (in order; an item starts only when it is listed here)

### Phase 0
1. Lead: push the scaffold, make the repo private or public per the director, protect `main`
   (`test`, `doc-caps`, `gitleaks` required; squash only; delete branch on merge).
2. Lead: `project.godot` with the autoload list and typing warnings as errors; the smoke suite
   green; the harness self-test green.
3. Lead: the deliberately broken PRs (lowered floor, unregistered suite, untyped script, planted
   `KAIJU_TEST_SECRET_` key); each must go red. Record the result in `docs/audits/`.
4. Lead: the document pack from the playbook kickoff checklist (vision, engine, machine, team,
   guardrails, style bibles, pipeline, roadmap, repo, licence register, open questions).

### Demo (D-050, 2026-10-18; the director's playtest is the Phase 2 gate)
1. P1 balance D (D-049): MERGED #21 (81afe80). Board #24, worktree cap #25, streets #26.
2. P2 D-047 croc titan clips in game: #22 (blender-reptile).
3. P3 croc baby + adolescent models: Tripo session -> blender-reptile.
4. P4 SFX: MERGED #8 (47e1b30; D-052, D-055).
5. P5 demo slice: MERGED #23 (94ebcd8; D-051). Playtest sheet MERGED #29.
6. P6 Windows export: MERGED #28 (local proof) and #30 (CI workflow_dispatch artifact); the director's build after #22.
7. P7 director playtest.

### Done ahead of the gate (director asked to "build" the game, 2026-10-16)
- `project.godot`, autoloads, typing as errors; smoke 11, sim 28, flow 9 checks green locally.
- Greybox playable loop: species select (3), voxel rampage with army, results, evolution tree
  (19 nodes, 3 evolutions), versioned save. Captures in `docs/captures/2026-10-16-greybox/`.
- Still open in Phase 0: the deliberately broken PRs; the rest of the document pack.
