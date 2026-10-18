# Handoff: board (this session: "Kaiju: Load, smoke FX, builds")

Updated: 2026-10-19 01:00
State: awaiting lead (director playtest fixes for demo exe 2, D-083: all four PRs open into claude/look-options)

## Open PRs (each green locally on all suites after syncing look-options)
- Fix 3 frame cap: #77 MERGED.
- Fix 4 less camera smoke: #81, head cb09385. Boards in docs/captures/2026-10-19-less-smoke/ (frames 900/1500/2100).
- Fix 2 sound gate: #82, head f6df6d0. Sfx `live` gate; powers check opens the gate itself.
- Fix 1 faster run load: #84, head fcfe03d. Exported build: results->next rampage 13.0/10.5 -> 4.8/5.1 s (young),
  25.6/18.2 -> 6.8/5.9 s (stage 2); title->stage 2 35.1/20.0 -> 10.0/7.3 s.
  MISSED: title->first young rampage 14.0/8.9 -> 13.5/12.3 s (stadium build on a fresh launch; needs a follow-up).

## Notes
- SHAs could not be sent: no peer session is named lead (ListAgents). They are in each PR and here.
- Auto-fix is on for this session's PRs.
- Floors: every merge into look-options moves flow; resolve to the real count after the merge.
- Worktrees live: fps-cap (merged, remove), sfx-gate, run-load, smoke, integ-a, integ-a-export (lead said keep).
- Load timing method: export with `--export-release "Windows Desktop"`, then
  `godot_console --headless --main-pack K.exe --script <probe.gd> -- --tier=N` (scratch APPDATA).

## Next
Lead review at 2x; follow-up for the first young load if the lead wants it.
