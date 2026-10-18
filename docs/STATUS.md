# Status board

Cap: 150 lines. Edited only by the merge role, in a board PR after each merge, from the merged
PR's "Board and log" section. History rolls to `docs/archive/status_<month>.md`.

## Phase
Current phase: **0 — Foundations** (gate: CI proves it rejects a lowered floor, a missing suite,
an untyped declaration and a planted secret). Gate signer: the lead.

## Live PRs (2026-10-18 18:30; demo order: #50 -> P3 #54 -> rooftops #63 -> landmarks -> matches #59 -> #36 -> build)

| PR | Owner session | State | Item | Branch | Since |
|----|---------------|-------|------|--------|-------|
| #63 | Rooftop fire | awaiting lead | D-076a rooftop density; sim review PASS; clip on the local GPU | claude/rooftop-density | 2026-10-18 |
| #59 | Stadium matches + crowd | working | D-078 matches + D-078a full stands; AFL re-clip with the crowd | claude/stadium-matches | 2026-10-18 |
| #54 | Croc baby & teen | awaiting lead | P3 bodies (D-073, D-074b); sim review PASS; gate: clean baby jaw crop | claude/croctitan-p3 | 2026-10-18 |
| #55 | Greenery + trample | working | D-065(a) greenery; trample last round (D-084), else ships without | claude/greenery | 2026-10-18 |
| #50 | Tanks & helis | working | D-066 military AI; last round (D-082); conflicts with base | claude/military-ai | 2026-10-18 |
| #36 | Army balance + SFX | working | D-069 army scales + D-069a soften young; lands last before the build | claude/army-scales | 2026-10-18 |
| #58 | Jets | available (parked) | D-072 interceptor, D-080 warning; draft, after the demo | claude/jets-interceptor | 2026-10-18 |
| #61 | Jets | available (parked) | D-072 delta + ground-attack bombs; draft, after the demo | claude/jets-bombs | 2026-10-18 |

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
