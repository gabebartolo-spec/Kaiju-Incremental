# Font helper handoff, 2026-10-16
## State: available (PR #4 open into claude/look-options, CI pending, Auto-fix on; awaiting lead)

## Task
Original display font for Kaiju Incremental (brief from the lead session). Three directions built
from one block skeleton; director picked B "Kaiju Claw" from the first proof (2026-10-16, in chat).

## What exists
- tools/fonts/glyphs.py: hand-drawn 10-row cell skeleton (A-Z, 0-9, punctuation incl. > < # * & ;).
- tools/fonts/build_fonts.py: builds assets/fonts/kaiju_{rubble,claw,fault}.ttf (fontTools +
  skia-pathops, deterministic hashes, auto profile kerning in GPOS, lower case maps to capitals,
  slivers < 300 units^2 dropped). B's numbers are the director's pick: do not retune.
- scenes/ui_kit.gd: DISPLAY_FONT_PATH (one-line swap), font_for(size): display face at
  SIZE_HEAD (36) and above, engine default below.
- tools/capture/font_board.gd -> docs/captures/2026-10-16-font/font_board.png.
- docs/LICENSING_REGISTER.md created (fonts CLEARED, ours).

## Evidence
smoke 11, sim 39, flow 9 + self-test green; gdlint/gdformat clean. Headless probe: a 104 px
UiKit label uses res://assets/fonts/kaiju_claw.ttf; a 24 px label has no override.

## Branch and commit
claude/game-font-459bde -> https://github.com/gabebartolo-spec/Kaiju-Incremental/pull/4 (do not merge; lead's call).

## Unfinished changes
None. Not exercised: in-game screenshots of menu/HUD/upgrade screens with the new font.

## Attempts
- Heavier/leaning B (BOLD growth + forward lean): built, then reverted. Director picked the light original B.
- Exporting APPDATA for Godot also hides Python user site-packages (PIL "missing"): set it per command.

## Open decisions
Director's pick recorded in chat only; merge role needs a D-id (PR body has the text).

## Running jobs
None (CI on PR #4 is watched by Auto-fix).

## Next (if asked)
Director may want B on 24 px HUD numbers too (lower DISPLAY_MIN_SIZE), or A/C retired.
