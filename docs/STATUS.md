# Status board

Cap: 150 lines. Edited only by the merge role, in a board PR after each merge, from the merged
PR's "Board and log" section. History rolls to `docs/archive/status_<month>.md`.

## Phase
Current phase: **0 — Foundations** (gate: CI proves it rejects a lowered floor, a missing suite,
an untyped declaration and a planted secret). Gate signer: the lead.

## Agents (2026-10-18 04:10)

| Agent | State | Item | Branch / PR | Since |
|-------|-------|------|-------------|-------|
| Lead (demo session) | working | demo D-050: QA gates, merges, board | claude/look-options (#3 to main on hold) | 2026-10-18 |
| Tripo (old lead session) | working | P3 croc baby + adolescent meshes (refs board r2) | none; sends provenance rows | 2026-10-18 |
| blender-reptile | awaiting lead | P2 D-047 croc titan clips in game; then P3 rig/export | #22 | 2026-10-18 |
| ability-vfx | working | P4 SFX unpaused; dials, roar, army sounds | #8 | 2026-10-18 |
| kaiju-motion | awaiting lead | P5 demo slice (allow-list, end card) | #23 | 2026-10-18 |
| city-calm | working | zebra "hellscape" fix; then P6 local Windows export proof | claude/city-calm-streets, claude/export-windows | 2026-10-18 |

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
1. P1 balance D (D-049): MERGED #21 (81afe80).
2. P2 D-047 croc titan clips in game: #22 (blender-reptile).
3. P3 croc baby + adolescent models: Tripo session -> blender-reptile.
4. P4 SFX: #8 (ability-vfx).
5. P5 demo slice: #23 (kaiju-motion).
6. P6 Windows export from look-options: city-calm (local proof), lead (the build the director plays).
7. P7 director playtest.

### Done ahead of the gate (director asked to "build" the game, 2026-10-16)
- `project.godot`, autoloads, typing as errors; smoke 11, sim 28, flow 9 checks green locally.
- Greybox playable loop: species select (3), voxel rampage with army, results, evolution tree
  (19 nodes, 3 evolutions), versioned save. Captures in `docs/captures/2026-10-16-greybox/`.
- Still open in Phase 0: the deliberately broken PRs; the rest of the document pack.
