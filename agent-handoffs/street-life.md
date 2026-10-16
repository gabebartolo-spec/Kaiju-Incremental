# Street-life handoff, 2026-10-16
## State: awaiting lead review (PR into claude/look-options, not merged)

## Task
Side session from the lead: civilians on the pavements, moving traffic, and (director, mid-task)
"cops in the street vainly resisting and attempting to blockade streets". Presentation only.

## Branch
claude/street-life-b59ef8 -> PR into claude/look-options.

## What exists
- scenes/street_life.gd (StreetLife, child of CityView as `street`): ~363 civilians, 3 per lot,
  walk a pavement graph (4 corners per lot, linked round the lot and across streets); flee
  greedily from the kaiju inside panic_radius 25, calm past 32. Drawn as one MultiMesh per
  (outfit, pose). crush(at, r) removes people (one dust puff per call) and crushes cars.
- scenes/traffic.gd (Traffic): 36 cars, one-way centre lane (parked rows leave room for only
  one), turns at crossings, queues, U-turns when stuck 2.5 s; near the kaiju: brake, back away,
  flee. Police cruisers (light bars swap red/blue meshes) drive in and park.
- scenes/police.gd (Police): every 9 s (max 2 live) a blockade at a crossing 14-26 units ahead
  of the kaiju: two cruisers nose to nose across the street, siren OmniLight, 4 officers at posts
  firing (muzzle flashes, glints on the kaiju), scatter inside 7 units.
- scenes/voxel_person.gd: 11-cell people at 0.065 (0.72 units); poses walk A/B, run A/B (arms
  up), aim. VoxelBuilder.bake() merges a small model into one ArrayMesh (culled faces).
- Tunables: data/tuning.json "street". Fx.puff() small dust.
- Tools: capture_looks.gd --street (close-ups); bench_rampage.gd prints street-life cost.

## Decisions taken (lead to confirm)
- Civilians sized to the city (1 floor = 1 unit, car 1.5 long), not the briefed 1.8 units
  (that would be two storeys tall).
- Tripo (director: "feel free to use tripo"): not used; at 11 voxels tall a Tripo model
  voxelizes to the same blocks. Worth it only for a close camera.

## Evidence
Tests smoke 11, sim 39, flow 14 (+5) + self-test green; gdlint/gdformat clean.
Bench 1080p, 40 s, 4070 SUPER: runs 0/1/1/1 frames over 33 ms (one outlier run of 17 in a 2 s
burst while street life's own worst was 6.9 ms); base 1/0. Street life avg ~1.0 ms, worst 5-9 ms.
Captures: docs/captures/2026-10-16-street-life/.

## Next
Lead review; possible: pedestrians avoid ruins/rubble, cars avoid crossing traffic.
