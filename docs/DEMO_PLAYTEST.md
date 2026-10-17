# Demo playtest (P7)

The demo: you play the croc titan from hatchling to Behemoth, about 20-35 min. It ends on a
"DEMO COMPLETE" card. Play it as a player would, then send the notes below to the lead.

## Install
1. Copy `KaijuIncremental.exe` anywhere, for example the Desktop. It is one file, with the game
   data packed inside it.
2. Run it. If Windows SmartScreen warns, choose More info, then Run anyway (the build is unsigned).
3. It opens in a window; F11 or Settings switches to fullscreen. If any menu text is blank, stop
   and tell the lead: the fonts are missing from the build.

## Controls
WASD or left stick: move. Space / A: signature attack (Atomic Breath). E / Y: ultimate.
Esc / Start: pause (End Rampage is in the pause menu). Enter / A: confirm and skip.

## The path
1. Title -> NEW KAIJU. The select screen shows the reptilian only. Press CHOOSE.
2. Rampage: flatten the city until the clock runs out or you fall. The results screen shows
   your rubble against your best.
3. EVOLVE -> evolution tree: spend rubble, then press START for the next rampage. Repeat.
4. Buy EVOLVE: Behemoth. The reveal plays (BEHEMOTH, how tall you now stand), then the demo end
   card: the adult croc titan, TITLE / QUIT. Continue from the title comes back to this card.
The pacing bot reaches Behemoth in about 35 min (0.59 h, PR #21); the target is 20-30 min.

## What to note (time into the session, and what happened)
- Hitches: stutters, long loads, a frozen frame, a crash (also note the last thing you pressed).
- Confusing moments: what you could not find, did not understand, or pressed by mistake.
- Any rampage that did NOT feel bigger than the one before it, and why you think so.
- When you first wanted to stop, and when you wanted one more rampage.
- How long you took to reach Behemoth.

## Known issues (open PRs on 2026-10-18; the path above needs #23, the demo slice)
- #22 croc titan clips not in yet: the adult walks procedurally, and the end card holds idle
  with no roar. The select card crops the croc (#22 reframes it).
- #8 SFX not in yet: powers, stomps and collapses may be silent (P4).
- The hatchling and adolescent are the old models; the new ones come in P3.
- A save from an older dev build of another species is hidden (no Continue) in the demo.
