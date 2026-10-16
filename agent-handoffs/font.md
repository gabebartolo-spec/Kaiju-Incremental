# Font helper handoff, 2026-10-16
## State: available (PR open into claude/look-options, awaiting lead)

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

## Next (if asked)
Director may want B on 24 px HUD numbers too (lower DISPLAY_MIN_SIZE), or A/C retired.
