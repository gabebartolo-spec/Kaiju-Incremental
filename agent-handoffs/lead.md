# Lead handoff, 2026-10-16
## State: awaiting director
Asked: which look (A Toy Diorama / B Monster Movie Night / C Concrete Realism). PR #3 is HELD on it;
on the answer set data/looks.json "default", log the decision, merge.

## Task
Kickoff of Kaiju Incremental: decisions D-002..D-007 (active not idle, short rampages, move + auto
attacks, Godot PC + web, voxels, 3 species incl. Cephalopod), scaffold, greybox slice, CI green.

## Branch and commit
claude/look-options -> PR #3 (looks, rounder kaiju, camera pulled back). main @ 532fb0c (scaffold + slice + PR #1 CI fixes). Protected: test, doc-caps, gitleaks required.
This file rides on claude/lead-handoff.

## Unfinished changes
None in code. Phase 0 item 3 open: deliberately broken PRs (lowered floor, unregistered suite,
untyped script, KAIJU_TEST_SECRET_ + 16 chars), each red then closed; results to docs/audits/.

## Evidence so far
Local: smoke 11, sim 28, flow 9 + harness self-test green; gdlint/gdformat clean. PR #1: 8/8 green.
Captures: docs/captures/2026-10-16-greybox/ (greybox, not a look proposal).

## Attempts (fix-loop record)
- First main CI red: tools/*.sh lacked exec bit (exit 126), no export preset, spaced name in paths;
  then gitleaks 403 (needs pull-requests: read). All fixed in PR #1.

## Open decisions (director)
- Next assignment (playtest notes vs art direction). Cities count / endgame. Customisation beyond species.
- Repo visibility never answered: private by default (D-002a).

## Look work notes
- Capture: tools/capture/capture_looks.gd + scratchpad board.py (PIL); board in docs/captures/2026-10-16-looks/.
- Three fresh realism-critic rounds; remaining open taste point: octopus vs squid read (director's call).

## Running jobs
None.

## Findings for the lead
- project-kickoff template bugs (spaced name, exec bit, export preset, gitleaks perms): fixed in the
  templates, logged in project-kickoff learnings.
- Tests via `--script` compile before autoloads exist: logged in game-architecture learnings.

## Rules learnt the hard way
- Code reachable from tests must not name autoloads; use Content/Seeds statics, EventBus via get_node.
- int()/float() on a Variant fails strict typing: use Num.i / Num.f.
- MultiMesh vertex colours need vertex_color_is_srgb = true.
- docs/.gdignore keeps captures out of the Godot import.
- Capture override.cfg (no_focus, off-screen) must be deleted after, or F5 opens off-screen.
- gdlint/gdformat live in C:\Users\DANTE\AppData\Roaming\Python\Python314\Scripts.
