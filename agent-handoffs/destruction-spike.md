# Destruction-spike handoff, 2026-10-19
## State: awaiting lead (docs-only PR open into claude/look-options; do not merge)
## Task
Research spike for the full game's destruction (director 2026-10-19: "real dynamic destruction, actual
physics and buildings that can be carved"). Deliver docs/research/DESTRUCTION_SPIKE.md (3 options,
rules 2-3, 4K cost, effort), a throwaway prototype, headless timing and an off-screen 10 s clip.
## Branch and commit
- Report: claude/destruction-spike (docs only) -> PR into claude/look-options.
- Prototype (never merge): claude/destruction-proto d49d241, folder spike/.
- Worktree: ../Kaiju-Incremental-wt/destruction (remove when the PR merges).
## Unfinished changes
None. override.cfg removed after the windowed runs.
## Evidence so far
- Replay: identical at RES 4 and 8 (601 entries). Native C++ port gives the same islands.
- 4K GPU: one tower 4.1/6.8 ms avg/p95; block of 6 steady 4.3 ms with 5.2k bodies.
- Native tick (block of 6, RES 8): 7.2 ms p95 one thread; GDScript 488 ms p95.
- Clips + sheets + 2x crops: side-session-notes/local_106fc100-.../destruction-spike/.
## Attempts (fix-loop record)
- Clip r1: inverted normals (building near black), island shattered whole into uniform cubes.
  r2: outward normals, island keeps cell materials, breaks only within 2.5 units of its lowest point.
## Round 2 (lead, 2026-10-19)
- Survey of proven voxel destruction (Teardown, RFG Geo-Mod 2.0, Instruments of Destruction, CityV, godot_voxel,
  Terabase, Jolt determinism) added as section 1 with 17 sources; options re-based on it. Effort A 18 -> ~19 days
  (RFG support rule added to A). CityV: no public tech found (cited the footage). Worktree base verified = look-options.
## Open decisions
Director: option A (recommended, ~18 days) vs the 6-day cosmetic step vs B/C. Lead builds the board.
## Running jobs
None.
## Findings for the lead
- GPU timings taken while GDScript stalls the CPU are inflated (clocks drop): a --hold run that stops
  the CPU work isolates the scene's real GPU cost (28 ms "spikes" -> 4.3 ms steady).
- Jolt in Godot has a 10,240 body default limit; a block with 2,500 debris per building hits it.
- MSVC 2022 is on this PC (vcvars64.bat): a quick C++ port is the fastest way to price native code.
## Rules learnt the hard way (under 10 lines)
- Exporting APPDATA to a scratch dir hides Python's user site-packages (cv2): run Python without it.
- focus-guard needs --windowed on the command line and override.cfg present.
