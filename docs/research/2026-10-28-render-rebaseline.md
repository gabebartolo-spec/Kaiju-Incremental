# Render re-baseline at 4K, 2026-10-28 (render plan item 15, D-312)

ROADMAP: the render plan (D-276, D-300), item 15. D-312 says the savings should buy "a quieter, cooler PC": the same look
at 60 fps, with the GPU working less and no rise in render scale. This file measures current main against the Phase 0 table
(`docs/research/2026-10-26-render-baseline.md`), using the same runs and settings. Nothing here is a verdict on how the game looks.

**Game under test:** origin/main `4be64711` (roads landed; it includes 9c #355, 13 #354 and 8 #349). Branch
`claude/render-rebaseline` adds one tool commit, `31ba7a84`: `baseline_runs.sh` and `beam_runs.sh` accept `HELD_BY=gq`, so they
can run as a gq speed job. Without it they wait forever on the queue's own `BENCH_WINDOW_gq`. No game code is touched. The
native DLL is main's CI build (run 40583106997), md5 `850d064b`, installed with `tools/native_dll.sh fetch`.

## What was measured, and what differs from Phase 0

- **Same as Phase 0:** the RTX 4070 SUPER under Forward+ Vulkan; the Godot 4.7.2 console editor binary; a borderless
  3840x2160 window on screen at 0,0 with no_focus; `--fixed-fps 60 --disable-vsync`; stage 3, city seed 0, army seed 0, the
  reptilian. Runs A (night, clear) and B (dusk, rain) at Medium and High, two passes each in ABAB order, then the beam scenario
  (Medium and High, two passes each). The drivers are `tools/capture/baseline_runs.sh bench` and `beam_runs.sh`. The route
  file is the same one Phase 0 recorded (md5 `42806a67`).
- **Gate (D-299):** one gq speed job held the PC from 12:38 to 13:17. Other Godot processes and League of Legends were sampled
  every 4 s (`render-rebaseline-2026-10-28/runs.md`): all 12 runs are **VALID**, with others = 0 and League = 0 throughout.
  No run had the self_list error flood. The passes agree to 1% on GPU p50 and to 3% on frame p50 (list at the end).
- **The city is different, so the replayed route plays out differently.** Main now has 3,298 buildings (2,842 in Phase 0) and
  roads. Phase 0's recorded inputs, replayed on this city, give:
  - Normal route: 3,695 route steps against 3,360, because the kaiju is defeated later, so a run measures 3,575 frames
    against 3,240. The tally is 39 stomps, 27 swipes and 8 breaths, against 60, 27 and 8 in Phase 0. There are **160 falls
    against 466**.
  - Beam route: 27 stomps against 37, and **522 falls against 2,362**.

  The destruction load is lighter than in Phase 0. Some of the CPU and spike gains below may come from that, not only from
  the plan items. The GPU numbers are less affected: they track buildings on screen more than falls. A table limited to the
  first 3,240 frames (Phase 0's run length) is included, so run length is not a factor in it.
- **Percentiles** in the comparison tables are recomputed from the per-frame CSVs for both sets, nearest-rank, as the mean of
  the two passes (`tools/capture/rebaseline_compare.py`). Run against Phase 0 itself, it gives +0% everywhere. The Phase 0
  CSVs are the ones behind its committed summaries (the summaries match exactly).
- **Watts:** the GPU power, temperature and fan speed were sampled every 4 s (frames with GPU load over 50%): 144-172 W, 66-70 C,
  fan 41-51%. Phase 0 logged no watts, and an uncapped run keeps the GPU flat out, so these numbers say nothing about a quieter PC.
  The D-312 / item 15 watts bar needs the 60 fps capped pacing run, which is not exercised.

## Headline

- **GPU: no headroom freed at 4K.** Over the whole run, GPU p50 is **5-13% higher** than Phase 0 (A Medium 24.6 to 27.8 ms,
  B Medium 26.4 to 28.2 ms) and GPU p95 is flat (+0-3%). At peak ruin, GPU p50 is +1-6% and GPU p95 is 1-3% lower. The city
  draws more (16% more buildings, about 3,480 draws against 3,230 at Medium). Items 6, 12 and 13 spend GPU time by design.
- **Item 15 pass bar missed** (plan: GPU p95 at Medium at or under Phase 0's Medium p95). The Medium row is unchanged, and its
  whole-run GPU p95 is **29.9 against 29.0 ms (run A, +0.9)** and **30.4 against 30.1 ms (run B, +0.3)**. At peak ruin it
  passes (29.1 against 29.5, 29.3 against 30.4). Reported as is, not re-run.
- **Frame time (wall): much better.** Frame p95 is 23-26% lower and p99 is 48-53% lower. Frames over 33.4 ms are down 15-64%,
  and sim.step p95 is down 26-37%. Peak ruin frame p50 is 9-18% lower. Render-CPU p95 is up from about 3.0 to 3.9 ms at A and
  at B Medium (B High flat).
- **VRAM is 12-18% lower** (A Medium 2,120 to 1,812 MB).
- **Spikes:** frames over 100 ms fell from about 43-48 to 26-28 per run, and over 250 ms from 19 to 12. The worst frames are
  still 1.8-2.1 s:
  - Measured frame 1230 (about 1.9 s, CPU) is new in this city: GPU 27 ms, sim.step 101 ms, the `chunks_broken` handler
    worst 1,092 ms.
  - Frame 2074 is down from 2.8 s to 1.8 s.
  - Frames 1688 and 2918 cost about 1.1 s each.
- **Beam scenario: GPU p50 is 28-32% lower** (Medium 48.7 to 35.3 ms) and GPU p95 is 50-60% lower. Frame p95 is 53-62% lower.
  This is on a route with 78% fewer falls, so how much of it comes from the plan items is not separable here.

## Not exercised

- The 60 fps capped pacing run with watts (the D-312 "quieter, cooler" measure itself); PresentMon.
- A freshly recorded route on this city, which would give a destruction load comparable to Phase 0's (466 falls).
  Phase 0's route was used, as briefed.
- Run C (escalation smoke), the ablation matrix, RenderDoc / Nsight, a release export template, gl_compatibility.

## Reproduce

```
GODOT=<console exe> ROUTE=<Phase 0 route.json> OUT=<dir> HELD_BY=gq tools/capture/baseline_runs.sh bench   # inside one gq speed job
GODOT=... ROUTE=... OUT=... HELD_BY=gq tools/capture/beam_runs.sh
py -3 -I tools/capture/rebaseline_compare.py <Phase 0 bench CSV dir> <Phase 0 beam CSV dir> <OUT>
py -3 -I tools/capture/baseline_table.py docs/research/render-rebaseline-2026-10-28   # per-run tables from the summaries
```

The per-frame CSVs (about 0.9 MB each) are not committed. The `*_summary.txt` files and `runs.md` (the gate for each run) are.

## Tables: Phase 0 against now

### whole run (mean of two passes)

| config | set | frames | frame ms p50 / p95 / p99 / max | GPU ms p50 / p95 | render CPU ms p50 / p95 | sim.step p95 | VRAM MB max | >33.4 ms | spikes >100 / >250 ms |
|---|---|---|---|---|---|---|---|---|---|
| A_medium | Phase 0 | 3240 | 31.2 / 49.3 / 139.7 / 2761 | 24.6 / 29.0 | 2.27 / 2.97 | 19.8 | 2120 | 1207 | 43.5 / 19.0 |
| A_medium | now | 3575 | 28.8 / 37.6 / 73.3 / 1912 | 27.8 / 29.9 | 2.69 / 3.99 | 14.5 | 1812 | 483 | 27.0 / 12.5 |
| A_medium | change | | -8% / -24% / -48% / -31% | +13% / +3% | +18% / +34% | -27% | -15% | -60% | |
| A_high | Phase 0 | 3240 | 35.2 / 55.3 / 146.7 / 2827 | 30.1 / 35.2 | 2.33 / 3.00 | 19.6 | 2755 | 2130 | 45.5 / 19.0 |
| A_high | now | 3575 | 33.5 / 42.4 / 74.1 / 1882 | 32.7 / 35.3 | 2.72 / 3.91 | 13.7 | 2424 | 1816 | 28.0 / 12.0 |
| A_high | change | | -5% / -23% / -49% / -33% | +9% / +0% | +17% / +30% | -30% | -12% | -15% | |
| B_medium | Phase 0 | 3240 | 31.7 / 49.5 / 143.0 / 2778 | 26.4 / 30.1 | 2.38 / 3.14 | 19.5 | 2140 | 1254 | 42.0 / 18.5 |
| B_medium | now | 3575 | 29.3 / 37.1 / 70.5 / 1977 | 28.2 / 30.4 | 2.66 / 3.80 | 13.8 | 1825 | 484 | 26.0 / 12.5 |
| B_medium | change | | -8% / -25% / -51% / -29% | +7% / +1% | +12% / +21% | -29% | -15% | -61% | |
| B_high | Phase 0 | 3240 | 37.1 / 58.0 / 153.9 / 2855 | 32.1 / 36.5 | 2.82 / 3.64 | 20.5 | 2770 | 2498 | 48.5 / 19.5 |
| B_high | now | 3575 | 34.3 / 43.2 / 73.0 / 1891 | 33.6 / 36.4 | 2.69 / 3.69 | 12.9 | 2442 | 2039 | 26.5 / 12.0 |
| B_high | change | | -8% / -26% / -53% / -34% | +5% / -0% | -5% / +1% | -37% | -12% | -18% | |

### first 3240 measured frames, the Phase 0 run length (mean of two passes)

| config | set | frames | frame ms p50 / p95 / p99 / max | GPU ms p50 / p95 | render CPU ms p50 / p95 | sim.step p95 | VRAM MB max | >33.4 ms | spikes >100 / >250 ms |
|---|---|---|---|---|---|---|---|---|---|
| A_medium | Phase 0 | 3240 | 31.2 / 49.3 / 139.7 / 2761 | 24.6 / 29.0 | 2.27 / 2.97 | 19.8 | 2120 | 1207 | 43.5 / 19.0 |
| A_medium | now | 3240 | 28.8 / 37.7 / 73.3 / 1912 | 27.8 / 29.9 | 2.66 / 3.98 | 14.7 | 1812 | 440 | 23.0 / 10.5 |
| A_medium | change | | -8% / -23% / -48% / -31% | +13% / +3% | +17% / +34% | -26% | -15% | -64% | |
| A_high | Phase 0 | 3240 | 35.2 / 55.3 / 146.7 / 2827 | 30.1 / 35.2 | 2.33 / 3.00 | 19.6 | 2755 | 2130 | 45.5 / 19.0 |
| A_high | now | 3240 | 33.4 / 42.1 / 74.1 / 1882 | 32.7 / 35.4 | 2.70 / 3.92 | 13.9 | 2424 | 1632 | 24.0 / 10.0 |
| A_high | change | | -5% / -24% / -49% / -33% | +9% / +0% | +16% / +30% | -29% | -12% | -23% | |
| B_medium | Phase 0 | 3240 | 31.7 / 49.5 / 143.0 / 2778 | 26.4 / 30.1 | 2.38 / 3.14 | 19.5 | 2140 | 1254 | 42.0 / 18.5 |
| B_medium | now | 3240 | 29.3 / 37.2 / 70.5 / 1977 | 28.2 / 30.4 | 2.65 / 3.81 | 14.0 | 1825 | 448 | 22.0 / 10.5 |
| B_medium | change | | -8% / -25% / -51% / -29% | +7% / +1% | +12% / +21% | -28% | -15% | -64% | |
| B_high | Phase 0 | 3240 | 37.1 / 58.0 / 153.9 / 2855 | 32.1 / 36.5 | 2.82 / 3.64 | 20.5 | 2770 | 2498 | 48.5 / 19.5 |
| B_high | now | 3240 | 34.3 / 43.0 / 72.9 / 1891 | 33.6 / 36.4 | 2.66 / 3.67 | 13.1 | 2442 | 1844 | 22.5 / 10.0 |
| B_high | change | | -8% / -26% / -53% / -34% | +5% / -0% | -6% / +1% | -36% | -12% | -26% | |

### peak ruin, last 600 frames (mean of two passes)

| config | set | frames | frame ms p50 / p95 / p99 / max | GPU ms p50 / p95 | render CPU ms p50 / p95 | sim.step p95 | VRAM MB max | >33.4 ms | spikes >100 / >250 ms |
|---|---|---|---|---|---|---|---|---|---|
| A_medium | Phase 0 | 600 | 36.2 / 53.9 / 110.8 / 458 | 27.1 / 29.5 | 2.39 / 3.09 | 22.4 | 2120 | 423 | 8.0 / 3.0 |
| A_medium | now | 600 | 29.5 / 37.7 / 66.0 / 494 | 28.7 / 29.1 | 2.93 / 3.87 | 12.4 | 1743 | 90 | 5.5 / 2.0 |
| A_medium | change | | -18% / -30% / -40% / +8% | +6% / -1% | +23% / +25% | -45% | -18% | -79% | |
| A_high | Phase 0 | 600 | 37.8 / 60.6 / 110.0 / 451 | 33.1 / 35.2 | 2.33 / 3.06 | 21.8 | 2755 | 555 | 8.0 / 3.0 |
| A_high | now | 600 | 34.4 / 43.3 / 60.0 / 437 | 33.7 / 34.5 | 2.94 / 3.85 | 11.7 | 2349 | 388 | 6.0 / 2.0 |
| A_high | change | | -9% / -29% / -45% / -3% | +2% / -2% | +26% / +25% | -46% | -15% | -30% | |
| B_medium | Phase 0 | 600 | 35.9 / 54.2 / 111.7 / 451 | 28.5 / 30.4 | 2.43 / 3.21 | 22.2 | 2140 | 413 | 7.5 / 3.0 |
| B_medium | now | 600 | 29.7 / 36.4 / 61.1 / 449 | 28.9 / 29.3 | 2.72 / 3.67 | 11.7 | 1756 | 79 | 5.0 / 2.0 |
| B_medium | change | | -17% / -33% / -45% / -0% | +1% / -3% | +12% / +14% | -48% | -18% | -81% | |
| B_high | Phase 0 | 600 | 40.2 / 64.9 / 115.8 / 463 | 34.4 / 36.3 | 2.85 / 3.63 | 22.9 | 2770 | 589 | 8.5 / 3.0 |
| B_high | now | 600 | 35.5 / 44.4 / 67.6 / 460 | 34.7 / 35.4 | 2.93 / 3.82 | 11.7 | 2366 | 420 | 5.5 / 2.0 |
| B_high | change | | -12% / -32% / -42% / -1% | +1% / -2% | +3% / +5% | -49% | -15% | -29% | |

### beam scenario, 600 frames from 60 before the press (mean of two passes)

| config | set | frames | frame ms p50 / p95 / p99 / max | GPU ms p50 / p95 | render CPU ms p50 / p95 | sim.step p95 | VRAM MB max | >33.4 ms | spikes >100 / >250 ms |
|---|---|---|---|---|---|---|---|---|---|
| beam_medium | Phase 0 | 600 | 60.0 / 133.0 / 337.4 / 1965 | 48.7 / 90.3 | 6.43 / 10.26 | 40.5 | 2121 | 492 | 86.5 / 13.5 |
| beam_medium | now | 600 | 42.3 / 62.4 / 140.7 / 1769 | 35.3 / 45.1 | 5.60 / 8.48 | 14.8 | 1859 | 421 | 13.0 / 4.0 |
| beam_medium | change | | -29% / -53% / -58% / -10% | -28% / -50% | -13% / -17% | -63% | -12% | -14% | |
| beam_high | Phase 0 | 600 | 71.6 / 175.0 / 484.4 / 2181 | 60.1 / 136.3 | 7.20 / 11.84 | 46.3 | 2720 | 586 | 186.0 / 15.0 |
| beam_high | now | 600 | 48.6 / 65.7 / 138.0 / 1750 | 41.1 / 55.1 | 5.69 / 8.06 | 15.2 | 2474 | 467 | 12.5 / 4.0 |
| beam_high | change | | -32% / -62% / -72% / -20% | -32% / -60% | -21% / -32% | -67% | -9% | -20% | |

### worst four frames (pass 1, measured frame index: wall ms)

| config | Phase 0 | now |
|---|---|---|
| A_medium | 2074: 2745, 1652: 730, 2134: 557, 386: 530 | 1230: 1908, 2074: 1812, 1688: 1133, 2918: 1065 |
| A_high | 2074: 2777, 1652: 743, 386: 720, 2134: 562 | 1230: 1886, 2074: 1802, 1688: 1133, 2918: 1118 |
| B_medium | 2074: 2767, 1652: 722, 2134: 557, 386: 519 | 1230: 2066, 2074: 1834, 1688: 1171, 2918: 1095 |
| B_high | 2074: 2795, 1652: 746, 386: 721, 2134: 567 | 1230: 1909, 2074: 1812, 2918: 1143, 1688: 1089 |

### runs and gate (others = other Godot processes, sampled every 4 s)

| run | start | end | samples | max others | League | verdict | GPU W mean (util>50%) | GPU temp max | fan % max |
|---|---|---|---|---|---|---|---|---|---|
| A_medium_1 | 12:39:39 | 12:42:18 | 32 | 0 | 0 | VALID | 151 | 67 | 43 |
| A_high_1 | 12:43:05 | 12:46:02 | 36 | 0 | 0 | VALID | 160 | 70 | 49 |
| B_medium_1 | 12:46:49 | 12:49:34 | 34 | 0 | 0 | VALID | 144 | 68 | 45 |
| B_high_1 | 12:50:06 | 12:53:05 | 36 | 0 | 0 | VALID | 162 | 70 | 49 |
| A_medium_2 | 12:53:32 | 12:56:14 | 32 | 0 | 0 | VALID | 157 | 69 | 45 |
| A_high_2 | 12:56:47 | 12:59:48 | 36 | 0 | 0 | VALID | 160 | 69 | 51 |
| B_medium_2 | 13:00:27 | 13:03:05 | 32 | 0 | 0 | VALID | 159 | 68 | 45 |
| B_high_2 | 13:03:40 | 13:06:36 | 36 | 0 | 0 | VALID | 172 | 69 | 49 |
| beam_medium_1 | 13:07:06 | 13:09:05 | 25 | 0 | 0 | VALID | 146 | 67 | 43 |
| beam_high_1 | 13:09:36 | 13:11:47 | 27 | 0 | 0 | VALID | 164 | 68 | 47 |
| beam_medium_2 | 13:12:31 | 13:14:36 | 25 | 0 | 0 | VALID | 147 | 66 | 41 |
| beam_high_2 | 13:15:19 | 13:17:30 | 27 | 0 | 0 | VALID | 163 | 68 | 46 |

### now: pass agreement (whole run, frame p50 and GPU p50; flag over 10%)

- A_high frame p50: 33.4 vs 33.5 ms (0% apart)
- A_high GPU p50: 32.7 vs 32.7 ms (0% apart)
- A_medium frame p50: 28.9 vs 28.7 ms (1% apart)
- A_medium GPU p50: 27.8 vs 27.8 ms (0% apart)
- B_high frame p50: 34.3 vs 34.4 ms (0% apart)
- B_high GPU p50: 33.6 vs 33.6 ms (0% apart)
- B_medium frame p50: 29.4 vs 29.2 ms (1% apart)
- B_medium GPU p50: 28.1 vs 28.2 ms (0% apart)
- beam_high frame p50: 49.3 vs 47.9 ms (3% apart)
- beam_high GPU p50: 41.1 vs 41.1 ms (0% apart)
- beam_medium frame p50: 41.9 vs 42.7 ms (2% apart)
- beam_medium GPU p50: 35.4 vs 35.2 ms (1% apart)
