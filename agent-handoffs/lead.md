# Lead handoff, 2026-10-16 16:40
## State: blocked (GPU): director is gaming; captures and FPS tuning wait for a free GPU
Then: capture, fresh critic, reach 60 fps, show the director the detailed look.

## Task
Art direction. Director picked look C (Concrete Realism) and asked for far more voxels (D-008), real
light sources (D-010), and a young kaiju outscaled by the city that grows as you play (D-009).

## Branch and commit
claude/look-options -> PR #3 (HOLD until the director sees the detailed look). Latest 82534b4.

## Unfinished changes
None uncommitted. Built and test-green, NOT yet seen by a critic or the director:
- scenes/voxel_builder.gd (shared voxel shapes + bottom-up MultiMesh), building_voxels.gd (RES 4,
  archetypes, sills/balconies/awnings, roof gear), city_decor.gd + prop_field.gd (lane markings,
  cars, trees, streetlights with real OmniLights; props flatten under stomps), tank_model.gd,
  fire.gd (burning ruins/wrecks with flickering lights), kaiju_model.gd (RES 5, teeth, claws, scales,
  plates, compound eyes, suckers). Evening light, SSAO + SSIL, glow. SDFGI and volumetric fog off.

## Evidence so far
Headless: smoke 11, sim 32 (growth fixture added), flow 9, harness self-test green; lint clean.
Captures det2 (taken while the GPU was busy): looks right, evening city with lit windows.
FPS 36-49 at 1080p with 313k voxels, measured while League of Legends used the GPU: not trustworthy.

## Attempts (fix-loop record)
- FPS: toggled SDFGI / volumetric fog / SSIL / SSAO / lamps / shadow splits: all within noise
  because of the game. Re-measure with a free GPU before optimising. Candidate cuts: floor slabs
  (hidden until broken), shadow casting on far buildings, 2 shadow splits.

## Open decisions (director)
- Time of day: evening chosen by the lead so lights read; director may move it.
- Life-stage models (hatchling to adult) beyond scaling: follow-up.

## Running jobs
None.

## Findings for the lead
- Check nvidia-smi for a game before windowed runs (memory-shared/shared-machine-rules.md).

## Rules learnt the hard way
- Test runners compile before autoloads exist: sim/scenes use Content/Seeds statics.
- int()/float() on a Variant fails strict typing: Num.i / Num.f.
- Buried-voxel culling or gaps show inner cells as a smear. Delete override.cfg after captures.
