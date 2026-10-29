"""Finds where a music take repeats, for the loops in tools/music/cut_loops.py (LOOPS, THEME).

The take's spectrum in 64 log-spaced bands, one frame every 2048 samples; for every loop length from 40 to 130 s,
how alike the frames are a loop length apart, averaged over 6 s each side of the seam. Prints the best seams and the
best one of 60 s or longer (a longer loop repeats less often). Skips the first 15 s and the last 12 s (intro, ending).

    python tools/music/find_loop.py <take.wav>
"""

import argparse
import pathlib

import numpy as np
import soundfile as sf

HOP, NFFT, BANDS = 2048, 4096, 64
SIDE_S, MIN_S, MAX_S, SKIP_HEAD_S, SKIP_TAIL_S, LONG_S = 6.0, 40.0, 130.0, 15.0, 12.0, 60.0


def bands(mono: np.ndarray, rate: int) -> np.ndarray:
    n = (len(mono) - NFFT) // HOP
    frames = np.lib.stride_tricks.as_strided(mono, (n, NFFT), (mono.strides[0] * HOP, mono.strides[0]))
    spec = np.abs(np.fft.rfft(frames * np.hanning(NFFT).astype(np.float32), axis=1))
    freqs = np.fft.rfftfreq(NFFT, 1 / rate)
    edges = np.geomspace(30, 12000, BANDS + 1)
    out = np.stack([spec[:, (freqs >= a) & (freqs < b)].sum(1) for a, b in zip(edges[:-1], edges[1:])], 1)
    out = np.log1p(out * 10)
    out -= out.mean(1, keepdims=True)
    return out / (np.linalg.norm(out, axis=1, keepdims=True) + 1e-9)


def search(path: pathlib.Path) -> list[tuple[float, float, float]]:
    """(score, length s, start s): the best seam for each loop length; score 1 is identical."""
    audio, rate = sf.read(path, dtype="float32", always_2d=True)
    feat = bands(np.ascontiguousarray(audio.mean(1)), rate)
    n, fps = len(feat), rate / HOP
    side = int(SIDE_S * fps)
    first, last = int(SKIP_HEAD_S * fps), n - int(SKIP_TAIL_S * fps)
    out = []
    for lag in range(int(MIN_S * fps), int(MAX_S * fps)):
        if first + lag >= last:
            break
        alike = (feat[: n - lag] * feat[lag:]).sum(1)
        around = np.convolve(alike, np.ones(2 * side) / (2 * side), "valid")  # around[i]: mean of alike[i : i + 2 side]
        starts = np.arange(max(first, side), min(last - lag, len(around) + side))
        score = around[starts - side]
        j = int(score.argmax())
        out.append((float(score[j]), lag / fps, starts[j] / fps))
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("take", type=pathlib.Path)
    rows = search(ap.parse_args().take)
    for score, length, start in sorted(rows, reverse=True)[:3]:
        print(f"score {score:.3f}  length {length:6.2f} s  start {start:6.2f} s")
    score, length, start = max((r for r in rows if r[1] >= LONG_S), key=lambda r: r[0])
    print(f"best of {LONG_S:.0f} s or longer: score {score:.3f}  length {length:6.2f} s  start {start:6.2f} s")


if __name__ == "__main__":
    main()
