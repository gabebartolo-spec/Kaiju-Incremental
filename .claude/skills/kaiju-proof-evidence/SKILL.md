---
name: kaiju-proof-evidence
description: How to prove a change to Kaiju Incremental actually works before calling it done - the evidence that fits each kind of change, real input through the GUI instead of handler calls, the player-effect fixture, pinned seeds, proving the asset the game actually loaded, new checks shown failing first, and the Not exercised line. Use it when finishing any feature or fix, writing a PR's Evidence section, adding a test, or about to say something works or looks right.
---

# Proof before "done"

"It works" is not evidence; what the game did is. The usual false passes: a test that calls a
button's handler while a panel covers the button, a screenshot of a fallback sprite, a check that
passes on one lucky seed, a green validator on an art change nobody looked at.

## Pick evidence that fits the change

| Change | Evidence that counts |
|---|---|
| Data, copy, docs | touched suites; schema validation; lint |
| Sim rule or balance | seeded paired fixture (same seeds before and after); player-effect fixture |
| UI flow | a real input at the control's screen position through the GUI; capture at 1920x1080 |
| Visual or art | validators green, labelled capture at game scale, art-qa-critic pass, then the director's approval |
| Animation | the assets suite plus a short clip |
| Save or lifecycle | reload, old-save fixture, failure paths, `kaiju-sim-review` |
| Performance | perf suite numbers against floors |

Scale the effort to the change (see the shared `testing-at-milestones` memory).

## A real input, not a handler call

`button.pressed.emit()` proves the handler's logic, not that a player's input reaches the
button. Send the event at the control's on-screen centre through the viewport, assert that
control got it, and report what took it when it did not. If `tests/` has no input helper yet,
write one in the first UI suite and share it.

## The player-effect fixture

Every system change ships a case in `tests/effect/` tagged with the system id: the same seed
with the system on and off gives a visibly different outcome. No fixture, no PR. A system whose
fixture cannot show a difference is decorative: say so and propose cutting it.

## Seeds, assets, new checks

Pin the seed and write it in the PR; a flaky check is a seed to pin. Assert the asset the game
actually loaded, not the file you meant. Show each new check failing on a known-bad input before
trusting its passes.

## A look is the director's

Validators and green suites never approve a look. Labelled capture at game scale, the lead's
art-qa-critic pass, then the director from labelled images (a clip for motion). Never write
"looks right" on your own say-so.

## Write it down

**Evidence:** suites with counts, fixture and seed, capture or clip by path, the player-effect
fixture id. **Not exercised:** what you did not cover, explicitly. After two similar failed fixes,
change the evidence before writing another fix.

## Learnings

Proven findings for this project live in `references/learnings.md`; general ones go to
`ai-game-dev-playbook/references/learnings.md` or `game-architecture`.
