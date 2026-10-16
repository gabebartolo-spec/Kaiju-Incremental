---
name: kaiju-sim-review
description: The review for changes that touch Kaiju Incremental's save schema, world or season tick, shared simulation rules, recruitment or generation of entities, injury or removal, and identity - the review packet an author writes, the transitions and invariants a reviewer walks, and how the verdict is recorded. Extends the general game-architecture skill (its lifecycle review section) with this game's transitions. Use it when asked to review such a PR, when you open one, or when a change you are making turns out to reach one of these areas, even if nobody said sim review.
---

# Sim review

The procedure is `game-architecture` §4; this file lists Kaiju Incremental's own transitions. One
reviewer, never the author; the PR's [MERGE NOTE] says "Review needed: kaiju-sim-review by
<agent>", and the merge role will not merge without the reviewer's comment on the PR.

## Author: the packet (in the PR under Evidence)

Transitions affected; invariants that must hold across each; evidence per invariant and what is
not exercised; for persisted state: the save version bump, a default for every new key, a
migration plus old-save fixture for every rename, and a save -> reload -> continue round trip.

## Reviewer: the transitions

Read the packet, put it aside, derive the transitions from the diff yourself, then walk them:

| Transition | Typical questions |
|---|---|
| Save and reload | New state saved under a version? Old save loads with a default? Rename has a migration and fixture? Corrupt file fails safe? Reload-then-continue matches an uninterrupted run from the same seed? |
| Tick / rollover | Advanced once, in a fixed order, from seeded streams, nothing reading the clock? |
| Generation of new entities | Do generated entities actually reach the thresholds a new rule reads? Caps enforced on every path that adds one? |
| Move between owners / removal | Does state follow the entity, stay with the owner, or get cleared? Is a removed entity gone from every list, market and selection while its history stays? |
| Injury or status | Do selection, actions and appearance treat it consistently, with the sim deciding and presentation reading? |
| Identity | Every reference keyed by stable id, never display name; ids never change once a save can contain them |

Then determinism and parity (all randomness from the RNG wrapper; the AI gets only information
it could plausibly have); for rule or balance changes the seeded paired fixture and the
player-effect fixture; and a reproduction for anything you suspect before you report it.

## The report

A comment on the PR: per area **fine** or **defect** with the reproduction, what goes wrong for
the player and the smallest fix. Name what you did not check. One line to the owner. If the PR
already merged, a defect goes straight to a small fix PR whose test is the reproduction.

## Learnings

Proven findings for this project live in `references/learnings.md`; general ones go to
`game-architecture/references/learnings.md`.
