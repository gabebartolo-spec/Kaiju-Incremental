# CPU profile: 1080p Medium on the bulldozer route (2026-10-31)

Follows the preset audit (docs/research/2026-10-30-preset-audit.md). The director judged the audit's route too
light ("mostly the kaiju flapping around on the spot") and picked a scripted bulldozer route.

## Setup
- Route `--route=bulldozer` (tools/capture/bench_lib.gd): the kaiju walks at the building with the most standing
  chunks near it, fires every power when ready, and holds the ultimate. The camera swings ±40° on a 10 s cycle so
  the stream keeps loading new views (director's ask). Deterministic: both runs destroyed the same 25,147 chunks
  with the same tally (23 swipes, 40 breaths, 3 beams, 1,093 falls).
- 1920x1080, Medium, night, clear, stage 3 (Colossus), RTX 4070 SUPER, native DLL md5 6d5ed0e1.
- `--fixed-fps 60`: one physics tick per frame, so every cost is per tick and the whole route is measured. A
  first pair without it is discarded: at 100+ ms frames the engine ran several catch-up ticks per frame, and the
  warm-up swallowed most of the route.
- New CSV columns `phys_span_ms`, `proc_span_ms` and `draw_span_ms`, taken from the engine's frame signals
  (physics_frame, process_frame, frame_pre_draw, frame_post_draw). Performance's TIME_PROCESS and
  TIME_PHYSICS_PROCESS read above wall time and are not used.
- The run ends at frame 3,162 (about 53 s) because the kaiju is defeated; `--tune=kaiju.hp` does not reach the
  body's health, which comes from species.json.

## Result (two runs, 3,162 frames each)

| ms per frame | p50 | mean | p95 | worst 5% mean |
|---|---|---|---|---|
| Wall | 36–38 | 42–44 | 85–95 | 116–134 |
| Physics tick (sim + Jolt + carve) | 10.6–11.4 | 17.3 | 51–56 | 53–82 |
| of which sim.step | 4.7–5.1 | 8.2–8.3 | 27–28 | 41–55 |
| Process (scripts, scene) | 10.0–10.7 | 12.0–12.6 | 22 | 26–28 |
| of which street | 2.8 | 3.0–3.2 | 4.7–5.7 | 2.4–3.3 |
| Draw (render submission) | 9.3–11.8 | 12.2–12.9 | 23 | 19–21 |
| GPU | 22.4–23.6 | 25.3–25.5 | 35.4–35.5 | 25–27 |

Over 16.7 ms: 99.7% of frames. Over 33.4 ms: 59–69%.

## What it says
1. **1080p Medium is CPU-bound under real destruction.** Physics, process and draw run one after another, about
   33 ms at p50 between them, against a GPU at 23 ms. Halving the GPU cost would not reach 60 fps; the CPU work
   needs to drop below ~16 ms first.
2. **No single culprit at p50.** The three CPU phases are about equal (about 11, 10 and 11 ms). Each needs its own
   cut.
3. **The spikes are the sim.** In the worst 5% of frames, sim.step is most of the physics tick (41–55 of 53–82 ms).
   One step at route frame 2042 takes 1.3 s in both runs. It is deterministic, so it can be replayed and found.
4. **Physics outside the sim costs about 6 ms per tick at p50** (Jolt and carve; live debris sits at its 450 cap all
   run).
5. **Process has about 7 ms that nothing names yet** (10 ms minus the street's 3). The next profile needs per-system
   timers there.

## Next (the director's call)
- Find the 1.3 s sim step at frame 2042 (deterministic, cheap to replay).
- Time process per system (kaiju model, debris, HUD, city view) to name the 7 ms.
- Draw: about 5,000 draw calls at p50 (2,400 visible + 2,600 shadow); shadow casters are the first lever to test.
- Raw CSVs: C:/kt/bulldozer/fix1080_r1.csv and fix1080_r2.csv (not in git).
