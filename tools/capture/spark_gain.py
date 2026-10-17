"""Measures, in a recorded rooftops clip, how much each hit spark brightens its spot.

capture_rooftops.gd logs every spark's physics frame and screen spot in rooftops.json; the
viewport image it could read lags the sim, so the proof comes from the movie the player sees.
For each on-screen spark: the brightest luminance (0..1) within RADIUS px of its spot over the
frames it burns, minus the dimmest over the frames just before. The movie's frame offset against
the physics frames is found by trying a small range and keeping the best fit.

    python tools/capture/spark_gain.py <capture dir with clip.avi and rooftops.json> <ffmpeg>
"""

import bisect
import json
import pathlib
import subprocess
import sys

import numpy as np
from PIL import Image

RADIUS = 4
BEFORE = 3  # frames before a spark that set its baseline
BURN = 7  # frames a spark burns (RooftopView.SPARK_FRAMES)
OFFSETS = range(-6, 7)


def main() -> None:
    out = pathlib.Path(sys.argv[1])
    frames = out / "frames"
    frames.mkdir(exist_ok=True)
    if not any(frames.iterdir()):
        subprocess.run(
            [sys.argv[2], "-y", "-loglevel", "error", "-i", str(out / "clip.avi"),
             str(frames / "f%04d.png")],
            check=True,
        )
    count = len(list(frames.glob("f*.png")))
    data = json.loads((out / "rooftops.json").read_text())
    cache: dict[int, np.ndarray] = {}

    def lum(k: int) -> np.ndarray:
        if k not in cache:
            rgb = np.asarray(Image.open(frames / f"f{k:04d}.png").convert("RGB"), np.float32)
            cache[k] = (rgb / 255.0) @ np.array([0.2126, 0.7152, 0.0722], np.float32)
        return cache[k]

    def peak(k: int, x: int, y: int) -> float:
        area = lum(k)[max(0, y - RADIUS):y + RADIUS + 1, max(0, x - RADIUS):x + RADIUS + 1]
        return float(area.max())

    def measure(offset: int) -> list[dict]:
        rows = []
        for spark in data["sparks"]:
            if not spark["on_screen"]:
                continue
            f = spark["frame"] + offset
            base = [peak(k, spark["x"], spark["y"]) for k in range(f - BEFORE, f) if 1 <= k <= count]
            lit = [peak(k, spark["x"], spark["y"]) for k in range(f, f + BURN) if 1 <= k <= count]
            if base and lit:
                rows.append(dict(spark, gain=round(max(lit) - min(base), 3), peak=round(max(lit), 3)))
        return rows

    offset = max(OFFSETS, key=lambda o: float(np.mean([r["gain"] for r in measure(o)] or [0.0])))
    rows = measure(offset)
    volleys = data["volley_frames"]
    groups: dict[int, list[float]] = {}
    for row in rows:
        groups.setdefault(volleys[max(0, bisect.bisect_right(volleys, row["frame"]) - 1)], []).append(row["gain"])
    print(f"movie frame offset {offset}; {len(rows)} on-screen sparks")
    for volley in sorted(groups):
        print(f"volley at frame {volley}: spark gains {groups[volley]}")
    gains = [r["gain"] for r in rows]
    print(f"all sparks: min gain {min(gains):.3f}, median {float(np.median(gains)):.3f}")
    (out / "spark_gain.json").write_text(json.dumps(rows, indent=1))


if __name__ == "__main__":
    main()
