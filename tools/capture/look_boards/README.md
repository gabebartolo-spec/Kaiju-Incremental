Look-boards capture helpers (capture-only branch, not for merge). Run from the worktree root:
`bash ./lbq.sh <a|b|c> <dusk|noon> <f1|f2|f3|f3b|clip|rec|scan>` (a = today, b = ONE LOOK mock, c = smooth croc),
`bash ./lbmany.sh jobs.txt 2` for a list of lbq lines, then `python tools/capture/look_boards_compose.py out/lb/raw <out> abc`
and `bash tools/capture/look_boards_clip.sh ...`. Copy the four helper files to the worktree root first (paths are
relative to it); they use the off-screen no_focus override.cfg and `~/.claude/tools/engine_slot.sh`.
