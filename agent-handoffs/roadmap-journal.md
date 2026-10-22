# roadmap-journal handoff (2026-10-23)

State: built, PR open on claude/look-options. Branch claude/kaiju-roadmap-journal-981cc7.

## What it is
The director asked for "a document, with visuals and interactive features that tracks the development of Kaiju
Incremental from start to finish, basically a roadmap journal I can look at". Asked (2026-10-23): repo page regenerated
by a script; the spine is the roadmap phases; his words as highlights only; captures per day plus progress charts; the
lead keeps a small table of phase items; the page shows the questions waiting on him per phase; PR to
claude/look-options; reader is him only.

## Files
- `docs/roadmap/journal.json`: hand-kept by the lead at each merge. Phases with items (status, PR numbers), milestones,
  builds he played, day narratives, highlighted quotes, captures (source under docs/captures, caption), closed PRs.
- `tools/journal.py`: builds `docs/roadmap/journal/index.html` (open in a browser) and `artifact.html` (same page, no
  skeleton, for the claude.ai artifact). Reads DECISIONS.md + archive, the roadmap note tables, the PR list via `gh`
  (cached in `docs/roadmap/journal-prs.json`, `--no-gh` for offline/CI), resizes captures to `journal/img/*.webp`.
  `--check` fails when a merged PR (>= #4) is in no phase item; the build runs the check too.
- Published artifact: https://claude.ai/artifact/WWrpuzmKwH6GEPr5bMFwa1 (republish from this file after a rebuild:
  Artifact tool, `url` above, `file_path` artifact.html, `root` docs/roadmap/journal, `files` the img/*.webp map).
- `.claude/launch.json`: `journal` serves the folder on 8765 for a browser check.

## Lead habit (the check enforces it)
After each merge: add the PR number to its phase item in journal.json (new item if none fits), update item status,
add a day entry when a new day starts, add a highlight only for a ruling that changed the game, then
`python tools/journal.py` and commit the regenerated folder. Not wired into CI yet: add
`python tools/journal.py --check --no-gh` to a lint job if he wants it enforced on PRs.

## Not done
- No CI job runs the check; `tools/lint/run_all.sh` does not exist, so lint.yml skips project lints.
- Captures from 2026-10-22/23 (UI redesign, turning clips) live in helper worktrees, not docs/captures; none in the journal yet.
