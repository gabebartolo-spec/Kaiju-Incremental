# Render baseline at 4K, 2026-10-26 (Phase 0 of the render plan)

ROADMAP G. performance audit; plan `~/.claude/handoffs/kaiju/research/plan.md` section 2. Every pass bar in the render
plan is "versus this table, same machine, same game sha". Nothing here is a verdict on how the game looks.

**Game under test:** origin/main `a5b22ede` (D-277 beachfront round 2; includes #212 strike delay, #213 far insectoid, #246 VIP
heli, #247). Branch `claude/perf-baseline`, tool commits on top, no game code touched. Native DLL: the CI release build of
main run 40276612966 renamed to the debug key, md5 `42d5f4f1`, ClassDB has `KaijuSettle` (logged by every run; the tool refuses to
measure without it).

## What was measured

- Machine: RTX 4070 SUPER (every log says `Vulkan 1.4.357 - Forward+ - Using Device #0: NVIDIA`), Godot 4.7.2 editor binary
  (console build, not the release export template), window borderless **3840x2160 on screen at 0,0**, viewport checked at 3840x2160
  before every run (the tool refuses otherwise). Preset Medium (the 4K default, D-109) and High.
- Scene: adult city, `--stage=3`, city seed 0, army seed 0, reptilian with the stage-3 body (`Kit.STAGE_LEVELS[2]`), 2,842
  buildings. Run A: night, clear. Run B: dusk, rain. Run C (escalation smoke FogVolume) waits for atm-escalation-2 and is **not measured**.
- Route: `capture_one_look.gd --route=record` (headless, sim-only, so independent of timing) on this main; replayed with
  `--route=replay`. The autoplay kaiju is defeated at route step 3360 (56 s), so a run is 120 warm-up frames plus **3,240
  measured frames (54 s)**, not 3,600; "peak ruin" is the last 600 frames. Route tally: 60 stomps, 27 claw swipes, 8 breath
  uses, 466 fall events; it does **not** fire the beam ultimate (the stage-3 body has no beam upgrade): see the beam scenario below.
- `--fixed-fps 60 --disable-vsync` (the GPU-time run). Per-frame CSV columns: wall ms, GPU and render-CPU ms, process and
  physics ms, draw calls / primitives / objects, visible vs shadow pass, VRAM / texture / buffer memory, the five pipeline-
  compilation monitors, debris, rubble, Jolt bodies, node count, sim.step ms, street-life ms. Phases: walk-in = measured frames
  0-600, first collapses = 600-1200, peak ruin = last 600.
- Two passes per configuration in ABAB order (A_medium, A_high, B_medium, B_high, then again). `A_medium_1` was taken in an
  earlier driver batch on the same build (the first attempt at that batch overlapped other windowed GPU jobs and was discarded).
- Gate: each run starts only when no other windowed / movie / capture / bench Godot is running, checked twice 20 s apart; the
  "other Godot processes" list is empty at the start of every run in the logs. Headless suites of other builders may have run
  beside the A/B batch (not logged per run). Beam pass 2 also required no other Godot of any kind; the beam batch logged CPU 3-26% and
  GPU 0% at run starts.

## Headline

The 4K frame is **GPU-bound and over 16.7 ms in every frame at both presets**: GPU p50 24.5 ms (Medium) and 30.1 ms (High) in
run A, 26.3 ms and 32.1 ms in run B; frame p50 31-38 ms (about 27-32 fps). Render-CPU p95 is about 3 ms, so the render thread on
the CPU is not the limit. Medium costs about 20% less GPU time than High. Visible primitives are about 25 M and **shadow-pass
primitives about 56-68 M, more than twice the visible ones**, at about 3,200-3,900 draw calls a frame. The beam ultimate is the
worst moment measured: GPU p50 48-63 ms (below).

Hitches: four frames are identical in every run (the sim is deterministic): measured frame 2074 costs **2.8 s** of wall time while
GPU is 19 ms and `sim.step` is 66 ms, and frames 386, 1652 and 2134 cost 0.5-0.7 s. The CPU cause is not attributed in the
CSV, which logs only `sim.step` per frame (the summaries list the worst handler of each event kind: `chunks_broken` 610 ms is the
largest, which does not explain 2.8 s); a per-frame event-handler column is the first follow-up for the CPU items. The pipeline
monitors rise by 3-4 (`pipe_draw`, `pipe_spec`) at measured frame 1231 (20 s in): a first-use compile hitch. The
process+physics monitor (`Performance.TIME_PROCESS`) reads 300+ ms at p95, more than the frame itself, so it is **not trusted** and
not used here (it stays in the CSVs and summaries).

Jolt active bodies, carve bodies and static rubble read 0 in every run (the debris is the 450-600 body debris pool,
`debris_live`), so no physics-body figure exists at this build.

## Pass agreement (whole run)

Pairs of passes agree to 4% on frame p50 and 1% on GPU p50 (list at the end); none is over 10% apart.


## Beam scenario (a separate phase)

The route never fires the beam, so each preset also has a beam run: the same city, seed, camera and route, but the kaiju owns
Tail Sweep, Momentum, Shearing Tail and Beam level 1 (`--levels=r_tail=1,r_momentum=1,r_shear=1,r_beam=1`, so its tail stats differ
slightly from the baseline body) and the ultimate is pressed **once at route step 1800 (30 s in)** through the scripted input the
rampage reads, as the normal route does (no debug overlay). 600 frames are measured from 60 frames before the press (warm-up 1740).
The tally is identical in all four runs: 1 beam, 37 stomps, 19 swipes, 6 breaths. The beam table is below, with the others.

## Ablation matrix

**Pending.** `tools/capture/ablate.gd` (rows: baseline, buildings, kaiju cubes, kaiju filler, kaiju cube shadows, ground flat,
sun shadows, SSAO, SSIL, far DOF, glow, smoke/fire/rain hidden; volumetric fog is run C only) is written and its rows were
shown to apply headless (sun shadows 2 lights, filler 1 mesh, ground 69 slabs) but are not measured: the GPU is held for the
phase 1 benches. Each row is one process, 5 s at peak ruin, with a 120-frame same-process control, one row per bench window.
The attribution questions (kaiju rows 2 ms or more? ground row over 1.5 ms?) are open.

## Not exercised

- Run C (escalation smoke), the real-time pacing run (PresentMon, 60 fps cap, watts via `nvidia-smi`), the RenderDoc / Nsight
  per-draw capture, the editor Visual Profiler, a release-export-template run.
- The ablation matrix; GPU ms per kaiju or ground draw is unknown until it runs.
- Vsync-on pacing (the window was borderless on screen, vsync off).
- The route never fires the beam (separate scenario above) and the kaiju is defeated at 56 s.

## Known defect found while measuring: self_list error flood on High

2 of about 15 High runs (A_high_1, night clear; B_high_2, dusk rain) hung the window with millions of
`ERROR: Condition "p_elem->_root != this"` (`core/templates/self_list.h:80` remove, `:46` add) starting right after
`BENCH renderer=forward_plus`; 0 of about 9 Medium runs. It did not reproduce in 10 further High runs (as is, skyline rampage off,
Medium-then-High order, two full-length runs). Heads of both logs: `render-baseline-2026-10-26/flood_*.log`. Build `a5b22ede` plus
tools, DLL `42d5f4f1`, Godot 4.7.2. Both flooded runs were rerun clean for the tables. Not fixed here; reported to the lead.

## Reproduce

```
GODOT=<console exe> ROUTE=<route.json> OUT=<dir> tools/capture/baseline_runs.sh bench     # A and B, Medium and High, twice
GODOT=... ROUTE=... OUT=... tools/capture/beam_runs.sh                                    # the beam scenario
GODOT=... ROUTE=... OUT=... tools/capture/baseline_runs.sh ablate                         # the matrix
py -3 -I tools/capture/baseline_table.py docs/research/render-baseline-2026-10-26         # tables from the summaries
py -3 -I tools/capture/pixel_diff.py before.png after.png [--out diff.png]               # zero-pixel items
```

Needs the untracked off-screen / no_focus `override.cfg` (see `Kit.window_ok`), a `route.json` from
`capture_one_look.gd --route=record --route-file=<f> --seconds=70` (headless, `--fixed-fps 60`), and the gate in
`baseline_runs.sh` (no other Godot, no League of Legends). The per-frame CSVs (about 0.8 MB each) are not committed; the
`*_summary.txt` files are.

## Tables

### whole

| run | frames | frame ms p50 / p95 / p99 / max | GPU ms p50 / p95 / p99 | render CPU p95 | >16.7 / >33.4 ms | draw calls | vis prims | shadow prims | VRAM MB |
|---|---|---|---|---|---|---|---|---|---|
| A_high_1 | 3240 | 35.1 / 55.3 / 146.5 / 2777 | 30.1 / 35.1 / 35.6 | 3.0 | 3240 / 2102 | 3532 | 26.1 M | 58.4 M | 2771 |
| A_high_2 | 3240 | 35.3 / 55.2 / 146.9 / 2878 | 30.1 / 35.4 / 35.8 | 3.0 | 3240 / 2159 | 3534 | 26.1 M | 58.6 M | 2739 |
| A_medium_1 | 3240 | 31.3 / 49.4 / 140.7 / 2745 | 24.7 / 28.9 / 29.5 | 3.0 | 3239 / 1252 | 3227 | 24.9 M | 55.6 M | 2120 |
| A_medium_2 | 3240 | 31.1 / 49.2 / 138.6 / 2777 | 24.5 / 29.2 / 29.9 | 2.9 | 3240 / 1162 | 3227 | 24.9 M | 55.6 M | 2120 |
| B_high_1 | 3240 | 36.4 / 56.1 / 150.1 / 2795 | 32.0 / 36.4 / 36.9 | 3.3 | 3240 / 2400 | 3810 | 26.3 M | 65.0 M | 2763 |
| B_high_2 | 3240 | 37.9 / 59.9 / 157.8 / 2915 | 32.1 / 36.6 / 37.1 | 4.0 | 3240 / 2597 | 3826 | 26.3 M | 65.1 M | 2777 |
| B_medium_1 | 3240 | 31.4 / 49.2 / 140.1 / 2767 | 26.4 / 30.2 / 30.8 | 3.1 | 3240 / 1191 | 3500 | 25.1 M | 61.7 M | 2132 |
| B_medium_2 | 3240 | 31.9 / 49.9 / 145.9 / 2789 | 26.3 / 30.0 / 30.4 | 3.2 | 3240 / 1317 | 3503 | 25.1 M | 61.8 M | 2148 |

### walk_in

| run | frames | frame ms p50 / p95 / p99 / max | GPU ms p50 / p95 / p99 | render CPU p95 | >16.7 / >33.4 ms | draw calls | vis prims | shadow prims | VRAM MB |
|---|---|---|---|---|---|---|---|---|---|
| A_high_1 | 600 | 31.0 / 41.6 / 68.3 / 720 | 27.9 / 35.3 / 35.5 | 3.0 | 600 / 208 | 3348 | 23.2 M | 51.2 M | 2312 |
| A_high_2 | 600 | 30.8 / 41.6 / 61.0 / 722 | 28.0 / 35.3 / 35.6 | 3.0 | 600 / 197 | 3351 | 23.3 M | 51.3 M | 2278 |
| A_medium_1 | 600 | 25.9 / 38.1 / 60.6 / 530 | 22.4 / 28.7 / 28.9 | 2.9 | 599 / 65 | 2949 | 21.9 M | 47.6 M | 1665 |
| A_medium_2 | 600 | 26.1 / 39.1 / 61.3 / 541 | 22.2 / 28.6 / 28.8 | 2.9 | 600 / 74 | 2952 | 21.9 M | 47.6 M | 1665 |
| B_high_1 | 600 | 31.1 / 41.7 / 64.6 / 721 | 28.4 / 35.9 / 36.3 | 3.3 | 600 / 213 | 3375 | 23.4 M | 51.5 M | 2305 |
| B_high_2 | 600 | 32.2 / 47.0 / 72.5 / 755 | 28.4 / 36.2 / 36.5 | 3.7 | 600 / 251 | 3393 | 23.4 M | 51.5 M | 2322 |
| B_medium_1 | 600 | 25.8 / 38.0 / 58.3 / 519 | 22.5 / 29.4 / 29.5 | 2.9 | 600 / 66 | 3005 | 22.1 M | 48.1 M | 1669 |
| B_medium_2 | 600 | 26.4 / 38.1 / 61.7 / 530 | 22.6 / 29.3 / 29.5 | 2.9 | 600 / 74 | 2988 | 22.1 M | 48.1 M | 1693 |

### first_collapses

| run | frames | frame ms p50 / p95 / p99 / max | GPU ms p50 / p95 / p99 | render CPU p95 | >16.7 / >33.4 ms | draw calls | vis prims | shadow prims | VRAM MB |
|---|---|---|---|---|---|---|---|---|---|
| A_high_1 | 600 | 35.4 / 47.5 / 87.1 / 307 | 33.8 / 35.2 / 35.8 | 3.1 | 600 / 462 | 3753 | 28.8 M | 63.2 M | 2315 |
| A_high_2 | 600 | 35.5 / 45.0 / 86.1 / 302 | 34.1 / 35.5 / 36.1 | 3.1 | 600 / 470 | 3755 | 28.8 M | 63.2 M | 2275 |
| A_medium_1 | 600 | 29.6 / 42.4 / 79.5 / 303 | 27.6 / 28.7 / 29.1 | 3.1 | 600 / 134 | 3386 | 27.4 M | 59.7 M | 1664 |
| A_medium_2 | 600 | 29.3 / 41.5 / 77.0 / 307 | 27.4 / 28.6 / 29.1 | 3.0 | 600 / 114 | 3389 | 27.4 M | 59.7 M | 1664 |
| B_high_1 | 600 | 36.8 / 48.3 / 87.2 / 302 | 35.3 / 36.7 / 36.9 | 3.4 | 600 / 521 | 4128 | 28.9 M | 69.1 M | 2307 |
| B_high_2 | 600 | 37.4 / 49.4 / 91.6 / 422 | 35.4 / 37.0 / 37.3 | 4.2 | 600 / 535 | 4124 | 28.9 M | 69.0 M | 2321 |
| B_medium_1 | 600 | 30.6 / 41.8 / 79.0 / 298 | 28.8 / 30.3 / 32.0 | 3.1 | 600 / 145 | 3774 | 27.5 M | 65.5 M | 1668 |
| B_medium_2 | 600 | 30.5 / 41.8 / 80.2 / 301 | 28.9 / 30.1 / 30.4 | 3.2 | 600 / 137 | 3772 | 27.5 M | 65.5 M | 1692 |

### peak_ruin

| run | frames | frame ms p50 / p95 / p99 / max | GPU ms p50 / p95 / p99 | render CPU p95 | >16.7 / >33.4 ms | draw calls | vis prims | shadow prims | VRAM MB |
|---|---|---|---|---|---|---|---|---|---|
| A_high_1 | 600 | 37.6 / 60.2 / 108.9 / 450 | 32.9 / 35.0 / 35.6 | 3.0 | 600 / 545 | 3640 | 25.3 M | 65.3 M | 2771 |
| A_high_2 | 600 | 37.9 / 61.1 / 111.1 / 453 | 33.2 / 35.4 / 35.9 | 3.1 | 600 / 565 | 3618 | 25.3 M | 65.3 M | 2739 |
| A_medium_1 | 600 | 37.2 / 54.9 / 113.3 / 462 | 26.9 / 29.3 / 29.5 | 3.2 | 600 / 465 | 3270 | 24.3 M | 62.2 M | 2120 |
| A_medium_2 | 600 | 35.1 / 52.8 / 108.3 / 454 | 27.3 / 29.7 / 29.9 | 3.0 | 600 / 381 | 3268 | 24.3 M | 62.2 M | 2120 |
| B_high_1 | 600 | 39.1 / 63.0 / 113.2 / 454 | 34.4 / 36.3 / 37.0 | 3.3 | 600 / 580 | 3864 | 25.4 M | 67.9 M | 2763 |
| B_high_2 | 600 | 41.4 / 66.8 / 118.5 / 472 | 34.3 / 36.3 / 36.7 | 3.9 | 600 / 598 | 3894 | 25.3 M | 67.5 M | 2777 |
| B_medium_1 | 600 | 35.4 / 53.2 / 115.0 / 444 | 28.6 / 30.4 / 30.6 | 3.1 | 600 / 377 | 3574 | 24.5 M | 64.3 M | 2132 |
| B_medium_2 | 600 | 36.5 / 55.3 / 108.3 / 458 | 28.4 / 30.3 / 30.4 | 3.3 | 600 / 449 | 3579 | 24.5 M | 64.3 M | 2148 |

### beam scenario (600 frames from 60 before the press)

| run | frame ms p50 / p95 / p99 / max | GPU ms p50 / p95 / p99 | draw calls | shadow prims |
|---|---|---|---|---|
| beam_high_1 | 72.3 / 202.2 / 540.3 / 2115 | 63.0 / 154.6 / 230.3 | 7634 | 117.0 M |
| beam_high_2 | 71.0 / 147.8 / 428.4 / 2248 | 57.2 / 118.0 / 121.6 | 7625 | 117.2 M |
| beam_medium_1 | 59.2 / 133.5 / 334.7 / 1960 | 49.0 / 90.1 / 102.5 | 7388 | 114.5 M |
| beam_medium_2 | 60.7 / 132.4 / 340.1 / 1970 | 48.4 / 90.4 / 102.0 | 7345 | 114.1 M |

### pass agreement (whole run, frame p50 and GPU p50; flag over 10%)

- A_high frame p50: 35.1 vs 35.3 ms (1% apart)
- A_high GPU p50: 30.1 vs 30.1 ms (0% apart)
- A_medium frame p50: 31.3 vs 31.1 ms (0% apart)
- A_medium GPU p50: 24.7 vs 24.5 ms (1% apart)
- B_high frame p50: 36.4 vs 37.9 ms (4% apart)
- B_high GPU p50: 32.0 vs 32.1 ms (0% apart)
- B_medium frame p50: 31.4 vs 31.9 ms (2% apart)
- B_medium GPU p50: 26.4 vs 26.3 ms (0% apart)
- beam_high frame p50: 72.3 vs 71.0 ms (2% apart)
- beam_high GPU p50: 63.0 vs 57.2 ms (9% apart)
- beam_medium frame p50: 59.2 vs 60.7 ms (3% apart)
- beam_medium GPU p50: 49.0 vs 48.4 ms (1% apart)
