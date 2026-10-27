"""fx_pool_compare.py: pool OFF vs ON from the bench_frames CSVs that bench_fx_pool.sh wrote.

  py -3 -I tools/capture/fx_pool_compare.py <OUT dir>

Per phase (walk_in, first_collapses, peak_ruin, whole run) and per mode, over every pass: frames over
16.7 ms and over 33.4 ms (wall_ms), p95, p99 and max frame time, the sum of the 20 worst frames, and
the pipeline-compilation monitors' rise (a first-use hitch). Render plan item 8's bar: frames over
16.7 ms in the collapse phases down 30% or more with the pool ON. Standard library only.
"""
import csv
import glob
import os
import sys

PHASES = ("walk_in", "first_collapses", "peak_ruin")


def percentile(values, q):
    if not values:
        return 0.0
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, int(q * len(ordered)))]


def load(out):
    runs = {"off": [], "on": []}
    for path in sorted(glob.glob(os.path.join(out, "*_pass*", "fxpool_*.csv"))):
        mode = "off" if os.path.basename(path).startswith("fxpool_off") else "on"
        with open(path, newline="", encoding="utf-8") as handle:
            runs[mode].append(list(csv.DictReader(handle)))
    return runs


def stats(rows):
    times = [float(r["wall_ms"]) for r in rows]
    worst = sorted(times)[-20:]
    pipes = ("pipe_canvas", "pipe_mesh", "pipe_surface", "pipe_draw", "pipe_spec")
    rise = 0
    if rows:
        rise = sum(int(float(rows[-1][p])) - int(float(rows[0][p])) for p in pipes if p in rows[0])
    return {
        "frames": len(times),
        "over_16.7": sum(t > 16.7 for t in times),
        "over_33.4": sum(t > 33.4 for t in times),
        "p95": percentile(times, 0.95),
        "p99": percentile(times, 0.99),
        "max": max(times) if times else 0.0,
        "worst20_sum": sum(worst),
        "pipeline_rise": rise,
    }


def main():
    runs = load(sys.argv[1])
    for name in PHASES + ("whole run",):
        print("== " + name)
        for mode in ("off", "on"):
            for index, rows in enumerate(runs[mode]):
                part = rows if name == "whole run" else [r for r in rows if r.get("phase") == name]
                s = stats(part)
                print("  %-3s pass %d  " % (mode, index + 1) + "  ".join("%s=%s" % (k, round(v, 2) if isinstance(v, float) else v) for k, v in s.items()))


if __name__ == "__main__":
    main()
