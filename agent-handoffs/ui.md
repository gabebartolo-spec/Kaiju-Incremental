# UI handoff, 2026-10-18
## State: awaiting lead (#51 head 50a9061; capture sent for a fresh screen-critic; lead merges after #50 and #56, then pings me to resync)
Capture: docs/captures/2026-10-18-plain-stats/ (CI run 39097041004, gl_compatibility at 1440p: the lead's rule, because
lavapipe hangs in forward_plus). Open nits for the critic: the stat lines sit before the evolution note; the panel has empty space
below "Press to buy".
Branch claude/plain-stats (worktree ../Kaiju-Incremental-wt/plain-stats, off look-options 2d66383).
D-077: the tree's side panel shows the cost plus only the stats the selected node changes, each one written in plain words
from data/tuning.json "stat_text" (line, fmt, unit; "size" is hidden). The 12-number summary panel is gone.
New flow checks are in tests/lib/flow_stats.gd: no raw stat terms on the tree, and each node's panel names exactly the
stats it changes. Both were shown failing first. Flow floor goes 130 -> 132.
Next steps: suites green -> commit and push -> PR (body in my scratchpad, pr_body_stats.md) -> check that no capture run is
in progress -> capture_flow --ui-scale=1.25 --ui-only at 3840x2160 -> my own 2x pass -> send the paths to the lead for a
fresh screen-critic. Remove the worktree after the merge.
Earlier: look A "Emergency Broadcast" (D-061), BIOMASS (D-056), our fonts (D-058), merged in #27 (c3b7306).
Kit: scenes/ui_kit.gd (palette, contrast(), hazard(), ink(), panel/button/bar/tape/backdrop/slider_look), hazard_box.gd,
news_ticker.gd; the crawl copy lives in data/tuning.json "news"; fonts are built by tools/fonts/build_fonts.py (STAMP pinned).
Follow-ups worth proposing: a HUD crawl that reacts to rampage events; species cards as threat dossiers; a "THREAT LEVEL
RAISED" line on the reveal.
Findings (the lead decides what gets recorded):
- A draft PR blocks the merge silently, so check isDraft before merging.
- Timed-out or cancelled captures still download their finished shots.
- Concurrent lavapipe captures double each other's run time.
- fontTools stamps the current time into the font head unless it is pinned.
- A label moved into a shared strip needs an overlap check.
