# Status board

Cap: 150 lines. Edited only by the merge role, in a board PR after each merge, from the merged
PR's "Board and log" section. History rolls to `docs/archive/status_<month>.md`.

## Phase
Current phase: **0 — Foundations** (gate: CI proves it rejects a lowered floor, a missing suite,
an untyped declaration and a planted secret). Gate signer: the lead.

## Agents (2026-10-18 05:30)

| Agent | State | Item | Branch / PR | Since |
|-------|-------|------|-------------|-------|
| LEAD | working | demo D-050: QA gates, merges, board, GPU slot | claude/look-options (#3 to main on hold) | 2026-10-18 |
| Tripo (old lead session) | available | P3 meshes delivered (D-059); octopus six-view check | none; provenance rows via the lead | 2026-10-18 |
| blender-reptile | working | #22 round 2 evidence; then P3 baby/adolescent rig + export | #22 | 2026-10-18 |
| ability-vfx | working | SFX bus + volume slider PR; UI sounds; army sounds PR | claude/sfx-bus | 2026-10-18 |
| city-calm | awaiting lead | #30 artifact smoke; then available | claude/ci-export | 2026-10-18 |
| UI | working | #27 look A (D-061), biomass (D-056), body font (D-058) | #27 | 2026-10-18 |
| Performance | working | hitch fixes PR (prewarm angle, VehicleParts cache) | claude/perf-hitches | 2026-10-18 |
| lighting | working | legacy breath voxel jet removal; fixed-fps still captures | new branch | 2026-10-18 |
| voxel-edges | running a check | edge-shading A/B board for the director | claude/voxel-edge-shading | 2026-10-18 |
| species-plan | available | plan only (D-060); worktree species-a parked | none | 2026-10-18 |

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
