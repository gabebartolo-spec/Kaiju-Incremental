"""Mix report (D-050): rebuilds one stem per sound category from a capture_mix_log.gd log and
measures each: integrated loudness (LUFS, ffmpeg ebur128), true peak, share of the total, and
the moments where one category masks another. Stems leave out the SFX compressor and the
Master limiter (they are what the mix is measured against); the real master mix from the same
run is measured beside them.

    python tools/sfx/mix_report.py <mix_log.txt> <mix.avi> <out_dir>
"""

import pathlib
import re
import subprocess
import sys
import wave

import imageio_ffmpeg
import numpy as np

RATE = 48000
FPS = 60
SFX_DIR = pathlib.Path(__file__).resolve().parents[2] / "assets" / "sfx"
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
# The buses at their defaults: Master 0.8 (PlayerSettings.volume), SFX 0.9 (tuning default).
BUS_GAIN = 0.8 * 0.9
CATEGORIES = {
    "stomps": lambda s: re.fullmatch(r"stomp_\d", s) is not None,
    "crack": lambda s: s == "stomp_crack",
    "footsteps": lambda s: s.startswith("footstep"),
    "collapse": lambda s: s == "collapse",
    "breath": lambda s: s == "breath",
    "army": lambda s: s in ("tank_fire", "shell_hit", "heli_gun", "heli_crash", "heli_rotor"),
    "rifle": lambda s: s == "rifle",
    "crowd": lambda s: s == "crowd_panic",
    "powers": lambda s: s in ("ready", "deflect", "regen_loop", "roar"),
    "ui": lambda s: s.startswith("ui_"),
}
LOW = ("stomps", "footsteps")  # judged in the band below 300 Hz; the rest at 300 Hz-4 kHz
LOOPS = ["regen_loop", "heli_rotor", "crowd_panic"]


def decode(path: pathlib.Path, mono: bool = True) -> np.ndarray:
    raw = subprocess.run(
        [FFMPEG, "-v", "error", "-i", str(path), "-vn", "-ac", "1" if mono else "2",
         "-ar", str(RATE), "-f", "f32le", "-"],
        capture_output=True, check=True,
    ).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def category(sound: str) -> str:
    for name, test in CATEGORIES.items():
        if test(sound):
            return name
    return "other"


def build_stems(log: pathlib.Path) -> tuple[dict, list, int]:
    events, loops = [], []
    for line in log.read_text().splitlines():
        parts = line.split()
        if parts[0] == "SND":
            events.append((int(parts[1]), parts[2], float(parts[3]), float(parts[4])))
        elif parts[0] == "LOOP":
            loops.append((int(parts[1]), [(float(parts[2 + 2 * i]), parts[3 + 2 * i] == "1")
                                          for i in range(3)]))
    frames = max([e[0] for e in events] + [l[0] for l in loops]) + 1
    n = int(frames / FPS * RATE) + RATE * 5
    cache: dict = {}
    stems: dict = {}
    hits: list = []
    for frame, sound, vol_db, pitch in events:
        if sound not in cache:
            cache[sound] = decode(SFX_DIR / f"{sound}.ogg")
        src = cache[sound]
        idx = np.arange(0, len(src) - 1, pitch)
        x = np.interp(idx, np.arange(len(src)), src) * 10 ** (vol_db / 20) * BUS_GAIN
        start = int(frame / FPS * RATE)
        cat = category(sound)
        stem = stems.setdefault(cat, np.zeros(n))
        end = min(n, start + len(x))
        stem[start:end] += x[: end - start]
        hits.append((start, cat, sound))
    step = int(3 / FPS * RATE)
    for li, sound in enumerate(LOOPS):
        src = decode(SFX_DIR / f"{sound}.ogg")
        tiled = np.resize(src, n)
        gain = np.zeros(n)
        for frame, states in loops:
            vol_db, on = states[li]
            s = int(frame / FPS * RATE)
            gain[s:s + step] = (10 ** (vol_db / 20)) if on else 0.0
        if gain.any():
            stem = stems.setdefault(category(sound), np.zeros(n))
            stem += tiled * gain * BUS_GAIN
    return stems, hits, n


def save_wav(path: pathlib.Path, x: np.ndarray) -> None:
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        st = np.repeat(np.clip(x, -1, 1)[:, None], 2, axis=1)
        w.writeframes((st * 32767).astype(np.int16).tobytes())


def loudness(path: pathlib.Path) -> tuple[float, float]:
    """Integrated loudness (LUFS) and true peak (dBTP), from ffmpeg's ebur128."""
    out = subprocess.run(
        [FFMPEG, "-hide_banner", "-nostats", "-i", str(path), "-af", "ebur128=peak=true",
         "-f", "null", "-"], capture_output=True, text=True,
    ).stderr
    summary = out[out.rfind("Summary:"):]
    i = re.search(r"I:\s+(-?[\d.]+|-inf) LUFS", summary)
    tp = re.search(r"Peak:\s+(-?[\d.]+|-inf) dBFS", summary)
    as_f = lambda m: float(m.group(1)) if m and m.group(1) != "-inf" else float("-inf")
    return as_f(i), as_f(tp)


def band_energy(x: np.ndarray, lo: float, hi: float) -> float:
    spec = np.abs(np.fft.rfft(x)) ** 2
    f = np.fft.rfftfreq(len(x), 1 / RATE)
    return float(spec[(f >= lo) & (f < hi)].sum()) + 1e-12


def masking(stems: dict, hits: list) -> list:
    """Each sound's first 300 ms against everything else in its own band: a hit is masked when
    the rest is within 3 dB of it (signal-to-mask ratio under 3 dB)."""
    win = int(0.3 * RATE)
    found = []
    for start, cat, sound in hits:
        lo, hi = (20.0, 300.0) if cat in LOW else (300.0, 4000.0)
        own = band_energy(stems[cat][start:start + win], lo, hi)
        rest = {c: band_energy(s[start:start + win], lo, hi) for c, s in stems.items() if c != cat}
        total = sum(rest.values())
        smr = 10 * np.log10(own / total)
        if smr < 3.0:
            worst = max(rest, key=rest.get)
            found.append((start / RATE, sound, cat, smr, worst))
    return found


def main() -> None:
    log, movie, out = map(pathlib.Path, sys.argv[1:4])
    out.mkdir(parents=True, exist_ok=True)
    stems, hits, n = build_stems(log)
    rows = []
    mix = np.zeros(n)
    for cat, x in sorted(stems.items()):
        mix += x
        path = out / f"stem_{cat}.wav"
        save_wav(path, x)
        lufs, tp = loudness(path)
        count = sum(1 for h in hits if h[1] == cat)
        rows.append((cat, lufs, tp, float(np.sum(x ** 2)), count))
    save_wav(out / "stem_sum.wav", mix)
    sum_lufs, sum_tp = loudness(out / "stem_sum.wav")
    real_lufs, real_tp = loudness(movie)
    energy = sum(r[3] for r in rows)
    lines = ["| Category | Plays | Integrated LUFS | True peak dBTP | Share of energy |",
             "|---|---|---|---|---|"]
    for cat, lufs, tp, e, count in sorted(rows, key=lambda r: -r[3]):
        lines.append(f"| {cat} | {count} | {lufs:.1f} | {tp:.1f} | {100 * e / energy:.0f}% |")
    lines.append(f"| **sum of stems (no dynamics)** | | {sum_lufs:.1f} | {sum_tp:.1f} | |")
    lines.append(f"| **real master mix (with compressor + limiter)** | | {real_lufs:.1f} | {real_tp:.1f} | |")
    masked = masking(stems, hits)
    by_pair: dict = {}
    for t, sound, cat, smr, worst in masked:
        by_pair.setdefault((cat, worst), []).append((t, smr))
    mlines = ["| Masked category | By | Times | Worst SMR dB | First at s |", "|---|---|---|---|---|"]
    for (cat, worst), items in sorted(by_pair.items(), key=lambda kv: -len(kv[1])):
        mlines.append(f"| {cat} | {worst} | {len(items)} | {min(i[1] for i in items):.1f} | "
                      f"{items[0][0]:.1f} |")
    totals = {c: sum(1 for h in hits if h[1] == c) for c in stems}
    (out / "levels.md").write_text("\n".join(lines) + "\n\n" + "\n".join(mlines) + "\n\n"
                                   + "Plays per category: " + str(totals) + "\n")
    print("\n".join(lines))
    print()
    print("\n".join(mlines))


if __name__ == "__main__":
    main()
