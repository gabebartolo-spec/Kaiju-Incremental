# Status board

Cap: 150 lines. Edited only by the merge role, in a board PR after each merge, from the merged
PR's "Board and log" section. History rolls to `docs/archive/status_<month>.md`.

## Phase
Current phase: **0 — Foundations** (gate: CI proves it rejects a lowered floor, a missing suite,
an untyped declaration and a planted secret). Gate signer: the lead.

## Agents (2026-10-17 20:20)

| Agent | State | Item | Branch / PR | Since |
|-------|-------|------|-------------|-------|
| Lead | awaiting director | integration on look-options; questions in the lead handoff | claude/look-options (#3 to main on hold) | 2026-10-16 |
| blender-reptile | available | croc titan hand rig + clips done (D-045/D-046); stages wait on the director | claude/blender-reptile-f5388e | 2026-10-17 |
| kaiju-motion | paused (D-044) | mantis + octopus locomotion | #11 | 2026-10-17 |
| ability-vfx | paused | power SFX | #8 | 2026-10-17 |

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

### Done ahead of the gate (director asked to "build" the game, 2026-10-16)
- `project.godot`, autoloads, typing as errors; smoke 11, sim 28, flow 9 checks green locally.
- Greybox playable loop: species select (3), voxel rampage with army, results, evolution tree
  (19 nodes, 3 evolutions), versioned save. Captures in `docs/captures/2026-10-16-greybox/`.
- Still open in Phase 0: the deliberately broken PRs; the rest of the document pack.
