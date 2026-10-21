# Street-life handoff, 2026-10-16 19:58
## State: available (PR #5 open into claude/look-options, CI pending, Auto-fix on; not merged)

## Task
Side session from the lead (local_9fac90d2): civilians on the pavements and moving traffic;
director added mid-task "cops in the street vainly resisting and attempting to blockade
streets" and "feel free to use tripo". Presentation only.

## Branch and commit
claude/street-life-b59ef8, commit 7d49745 (+ this handoff), pushed.
PR: https://github.com/gabebartolo-spec/Kaiju-Incremental/pull/5 (base claude/look-options).

## What exists
- scenes/street_life.gd (StreetLife = CityView.street): ~363 civilians, 3 per lot, on a
  pavement graph (4 corners per lot, linked round the lot and across streets); flee greedily
  inside panic_radius 25, calm past 32; one MultiMesh per (outfit, pose). crush(at, r) removes
  people (one dust puff per call) and crushes moving cars. Owns Traffic and Police; times its
  own cost (worst_usec, total_usec, frames) for the bench.
- scenes/traffic.gd: 36 cars on one-way centre lanes (parked rows leave only one lane),
  turns, queues, U-turns when stuck; brake/back away/flee near the kaiju; police cruisers
  with light bars that swap red/blue meshes.
- scenes/police.gd: blockades every 9 s (max 2) at a crossing 14-26 u ahead of the kaiju:
  two cruisers nose to nose across the street, siren OmniLight, 4 officers firing (muzzle
  flashes + glints on the kaiju from one flash MultiMesh), scatter inside 7 u.
- scenes/voxel_person.gd: 11 cells at 0.065 (~0.72 u); walk A/B, run A/B (arms up), aim.
- VoxelBuilder.bake(): small model -> one face-culled ArrayMesh. Fx.puff(). CityDecor.car static.
- data/tuning.json "street" holds the tunables. Seeds: civilians, traffic, police.
- capture_looks.gd --street (close-ups); bench_rampage.gd prints slow frames + street cost.

## Unfinished changes
None uncommitted. Not done: people walk through rubble; cars do not yield at crossings;
no clip, no 4K bench.

## Attempts
- Officer ricochets via Fx.sparks cost 2-7 ms per call (GPU particle node + material
  duplicate); replaced by the flash MultiMesh. Puffs capped at one per crush for the same
  reason. Frame gaps then level with base.
- Same-outfit civilians fled in lockstep and overlapped; fixed with per-person pace +/-20%
  and side offset 0.2.

## Open decisions (for the lead)
- People at city scale (~0.72 u), not the briefed 1.8 u (1 floor = 1 u; 1.8 = two storeys).
- Tripo not used: at 11 voxels tall it voxelizes to the same blocks.

## Evidence
Tests smoke 11, sim 39, flow 14 (+5) + self-test green; gdlint/gdformat clean.
Bench 1080p 40 s: frames over 33 ms 0/17/1/1/1 (the 17 a 2 s burst, street worst 6.9 ms then);
base 1/0. Street life avg ~1.0 ms, worst 5-9 ms. Captures docs/captures/2026-10-16-street-life/.

## Running jobs
CI on PR #5 (Auto-fix watching). No local Godot; override.cfg deleted.
