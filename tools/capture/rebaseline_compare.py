"""Phase 0 (2026-10-26) against now: per config, the mean of the two passes, from the per-frame CSVs.

    py -3 -I tools/capture/rebaseline_compare.py <phase0 bench dir> <phase0 beam dir> <now dir>
Percentiles are nearest-rank on the same CSV columns for both sets, so the two columns are computed the same way.
"""

import csv
import sys
from pathlib import Path

CFG = ["A_medium", "A_high", "B_medium", "B_high"]
BEAM = ["beam_medium", "beam_high"]


def pct(xs, p):
    s = sorted(xs)
    return s[min(len(s) - 1, max(0, int(round(p / 100.0 * len(s))) - 1))]


def stats(path: Path, phase: str = "", limit: int = 0):
    rows = list(csv.DictReader(path.open()))
    if limit:
        rows = rows[:limit]
    if phase:
        rows = [r for r in rows if r["phase"] == phase]
    w = [float(r["wall_ms"]) for r in rows]
    g = [float(r["gpu_ms"]) for r in rows]
    c = [float(r["rcpu_ms"]) for r in rows]
    sim = [float(r["sim_step_ms"]) for r in rows]
    vram = [float(r["vram_mb"]) for r in rows]
    return {
        "n": len(rows),
        "f50": pct(w, 50), "f95": pct(w, 95), "f99": pct(w, 99), "fmax": max(w),
        "g50": pct(g, 50), "g95": pct(g, 95),
        "c50": pct(c, 50), "c95": pct(c, 95), "sim95": pct(sim, 95),
        "vram": max(vram),
        "s100": sum(1 for x in w if x > 100), "s250": sum(1 for x in w if x > 250),
        "o33": sum(1 for x in w if x > 33.4),
        "worst": sorted(range(len(w)), key=lambda i: -w[i])[:4],
        "worst_ms": sorted(w, reverse=True)[:4],
    }


def mean2(d: Path, cfg: str, phase: str = "", limit: int = 0):
    runs = [stats(d / f"{cfg}_{p}.csv", phase, limit) for p in (1, 2) if (d / f"{cfg}_{p}.csv").exists()]
    if not runs:
        return None
    out = {k: sum(r[k] for r in runs) / len(runs) for k in runs[0] if k not in ("worst", "worst_ms")}
    out["passes"] = len(runs)
    out["worst"] = runs[0]["worst"]
    out["worst_ms"] = runs[0]["worst_ms"]
    return out


def delta(a, b):
    return f"{(b - a) / a * 100:+.0f}%" if a else "n/a"


def table(title, cfgs, d0, d1, phase="", limit=0):
    print(f"\n### {title}\n")
    print("| config | set | frames | frame ms p50 / p95 / p99 / max | GPU ms p50 / p95 | render CPU ms p50 / p95 "
          "| sim.step p95 | VRAM MB max | >33.4 ms | spikes >100 / >250 ms |")
    print("|---|---|---|---|---|---|---|---|---|---|")
    for cfg in cfgs:
        a, b = mean2(d0, cfg, phase, limit), mean2(d1, cfg, phase, limit)
        for name, s in (("Phase 0", a), ("now", b)):
            if s is None:
                print(f"| {cfg} | {name} | missing |||||||||")
                continue
            print(f"| {cfg} | {name} | {s['n']:.0f} | {s['f50']:.1f} / {s['f95']:.1f} / {s['f99']:.1f} / {s['fmax']:.0f} "
                  f"| {s['g50']:.1f} / {s['g95']:.1f} | {s['c50']:.2f} / {s['c95']:.2f} | {s['sim95']:.1f} "
                  f"| {s['vram']:.0f} | {s['o33']:.0f} | {s['s100']:.1f} / {s['s250']:.1f} |")
        if a and b:
            print(f"| {cfg} | change | | {delta(a['f50'], b['f50'])} / {delta(a['f95'], b['f95'])} / "
                  f"{delta(a['f99'], b['f99'])} / {delta(a['fmax'], b['fmax'])} | {delta(a['g50'], b['g50'])} / "
                  f"{delta(a['g95'], b['g95'])} | {delta(a['c50'], b['c50'])} / {delta(a['c95'], b['c95'])} "
                  f"| {delta(a['sim95'], b['sim95'])} | {delta(a['vram'], b['vram'])} | {delta(a['o33'], b['o33'])} | |")


def worst(cfgs, d0, d1):
    print("\n### worst four frames (pass 1, measured frame index: wall ms)\n")
    print("| config | Phase 0 | now |\n|---|---|---|")
    for cfg in cfgs:
        cells = []
        for d in (d0, d1):
            s = mean2(d, cfg)
            cells.append("missing" if s is None else ", ".join(f"{i}: {m:.0f}" for i, m in zip(s["worst"], s["worst_ms"])))
        print(f"| {cfg} | {cells[0]} | {cells[1]} |")


if __name__ == "__main__":
    p0, p0beam, now = (Path(x) for x in sys.argv[1:4])
    table("whole run (mean of two passes)", CFG, p0, now)
    table("first 3240 measured frames, the Phase 0 run length (mean of two passes)", CFG, p0, now, "", 3240)
    table("peak ruin, last 600 frames (mean of two passes)", CFG, p0, now, "peak_ruin")
    table("beam scenario, 600 frames from 60 before the press (mean of two passes)", BEAM, p0beam, now)
    worst(CFG, p0, now)
