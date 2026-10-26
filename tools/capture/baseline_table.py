"""Turns the *_summary.txt files of tools/capture/bench_frames.gd into the baseline tables.

    py -3 -I tools/capture/baseline_table.py <dir with A_medium_1_summary.txt ...>

Prints one markdown table per phase (whole, walk_in, first_collapses, peak_ruin, beam), a row per run
(scene, preset, pass), and flags a pair of passes whose frame p50 or GPU p50 differ by more than 10%.
"""

import re
import sys
from pathlib import Path

FIELDS = [
    ("wall p50", r"wall p50 ([\d.]+) p95 ([\d.]+) p99 ([\d.]+) max ([\d.]+)", ("p50", "p95", "p99", "max")),
    ("gpu", r"gpu p50 ([\d.]+) p95 ([\d.]+) p99 ([\d.]+)", ("gpu50", "gpu95", "gpu99")),
    ("rcpu", r"rcpu p95 ([\d.]+)", ("rcpu95",)),
    ("over", r"over16\.7 (\d+) over33\.4 (\d+)", ("o16", "o33")),
    ("draws", r"draws p50 (\d+) vis_draws (\d+) sh_draws (\d+) vis_prims (\d+) sh_prims (\d+)", ("draws", "vis_d", "sh_d", "vis_p", "sh_p")),
    ("vram", r"vram_mb (\d+)", ("vram",)),
    ("n", r" n=(\d+)", ("n",)),
]


def parse(path: Path) -> dict:
    out: dict = {}
    for line in path.read_text().splitlines():
        m = re.match(r"BENCH_PHASE (\w+) ", line)
        if not m:
            continue
        row: dict = {}
        for _, pat, names in FIELDS:
            f = re.search(pat, line)
            if f:
                row.update({n: float(v) for n, v in zip(names, f.groups())})
        out[m.group(1)] = row
    return out


def main() -> int:
    runs = {}
    for p in sorted(Path(sys.argv[1]).glob("*_summary.txt")):
        runs[p.name.removesuffix("_summary.txt")] = parse(p)
    phases = ["whole", "walk_in", "first_collapses", "peak_ruin"]
    for phase in phases:
        print(f"\n### {phase}\n")
        print("| run | frames | frame ms p50 / p95 / p99 / max | GPU ms p50 / p95 / p99 | render CPU p95 | >16.7 / >33.4 ms | draw calls | vis prims | shadow prims | VRAM MB |")
        print("|---|---|---|---|---|---|---|---|---|---|")
        for name, ph in runs.items():
            r = ph.get(phase)
            if not r or name.startswith("beam"):
                continue
            print(
                f"| {name} | {r['n']:.0f} | {r['p50']:.1f} / {r['p95']:.1f} / {r['p99']:.1f} / {r['max']:.0f} "
                f"| {r['gpu50']:.1f} / {r['gpu95']:.1f} / {r['gpu99']:.1f} | {r['rcpu95']:.1f} "
                f"| {r['o16']:.0f} / {r['o33']:.0f} | {r['draws']:.0f} | {r['vis_p'] / 1e6:.1f} M | {r['sh_p'] / 1e6:.1f} M | {r['vram']:.0f} |"
            )
    beams = {n: ph for n, ph in runs.items() if n.startswith("beam")}
    if beams:
        print("\n### beam scenario (600 frames from 60 before the press)\n")
        print("| run | frame ms p50 / p95 / p99 / max | GPU ms p50 / p95 / p99 | draw calls | shadow prims |")
        print("|---|---|---|---|---|")
        for name, ph in beams.items():
            r = ph.get("whole", {})
            if r:
                print(f"| {name} | {r['p50']:.1f} / {r['p95']:.1f} / {r['p99']:.1f} / {r['max']:.0f} | {r['gpu50']:.1f} / {r['gpu95']:.1f} / {r['gpu99']:.1f} | {r['draws']:.0f} | {r['sh_p'] / 1e6:.1f} M |")
    print("\n### pass agreement (whole run, frame p50 and GPU p50; flag over 10%)\n")
    for name in runs:
        if name.endswith("_1") and name[:-2] + "_2" in runs:
            a = runs[name].get("whole", {})
            b = runs[name[:-2] + "_2"].get("whole", {})
            if not a or not b:
                continue
            for key, label in (("p50", "frame p50"), ("gpu50", "GPU p50")):
                d = abs(a[key] - b[key]) / max(a[key], b[key], 1e-9) * 100
                flag = "  FLAG >10%" if d > 10 else ""
                print(f"- {name[:-2]} {label}: {a[key]:.1f} vs {b[key]:.1f} ms ({d:.0f}% apart){flag}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
