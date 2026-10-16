"""Builds the power sounds (D-026, D-030) into assets/sfx/*.ogg.

Layers come from two places: Kenney CC0 packs (impacts, metal, explosions, slime) decoded
from the raw download folder (kept outside the repo), and sounds synthesized here (hums,
beams, roars, sizzles, whooshes, the ready growl, regeneration bubbles). Everything is
seeded, so a rebuild gives the same files. Needs numpy and ffmpeg (imageio-ffmpeg).

    python tools/sfx/build_sfx.py --kenney <dir with kenney_impact-sounds/, kenney_sci-fi-sounds/>
"""

import argparse
import pathlib
import subprocess
import tempfile
import wave

import imageio_ffmpeg
import numpy as np

RATE = 44100
OUT = pathlib.Path(__file__).resolve().parents[2] / "assets" / "sfx"
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
rng = np.random.default_rng(26)
kenney_root = pathlib.Path(".")


def kenney(name: str) -> np.ndarray:
    """A Kenney ogg by file name, decoded to mono float at RATE."""
    path = next(kenney_root.rglob(name + ".ogg"))
    raw = subprocess.run(
        [FFMPEG, "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(RATE), "-f", "f32le", "-"],
        capture_output=True, check=True,
    ).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def seconds(t: float) -> int:
    return int(t * RATE)


def pitch(x: np.ndarray, factor: float) -> np.ndarray:
    """Resample so it plays `factor` times faster (and higher)."""
    idx = np.arange(0, len(x) - 1, factor)
    return np.interp(idx, np.arange(len(x)), x)


def place(dst: np.ndarray, src: np.ndarray, at: float, gain: float = 1.0) -> None:
    start = seconds(at)
    end = min(len(dst), start + len(src))
    dst[start:end] += src[: end - start] * gain


def env(n: int, attack: float, decay: float) -> np.ndarray:
    """Linear attack then exponential decay (time constant `decay` seconds)."""
    t = np.arange(n) / RATE
    rise = np.clip(t / max(attack, 1e-4), 0.0, 1.0)
    return rise * np.exp(-np.maximum(t - attack, 0.0) / decay)


def hump(n: int, peak: float) -> np.ndarray:
    """Rises to 1 at `peak` (0..1 of the length) and falls back to 0, smoothly."""
    t = np.linspace(0.0, 1.0, n)
    return np.where(t < peak, np.sin(t / peak * np.pi / 2), np.cos((t - peak) / (1 - peak) * np.pi / 2)) ** 2


def highpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    """Removes DC and rumble below `cutoff` (wasted headroom no speaker plays)."""
    return x - lowpass(x, cutoff)


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    a = np.exp(-2 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def bandpass(x: np.ndarray, centre: np.ndarray, q: float) -> np.ndarray:
    """RBJ band-pass whose centre frequency follows the array `centre` (Hz per sample)."""
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(len(x)):
        if i % 32 == 0:
            w = 2 * np.pi * min(centre[i], RATE * 0.45) / RATE
            alpha = np.sin(w) / (2 * q)
            a0 = 1 + alpha
            b0, b2 = alpha / a0, -alpha / a0
            a1, a2 = -2 * np.cos(w) / a0, (1 - alpha) / a0
        out = b0 * x[i] + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, x[i], y1, out
        y[i] = out
    return y


def tone(freq: np.ndarray, harmonics: int, bright: float = 0.6) -> np.ndarray:
    """A buzzy tone following `freq` (Hz per sample): summed harmonics, softer as they rise."""
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    out = np.zeros_like(freq)
    for h in range(1, harmonics + 1):
        out += np.sin(phase * h) * bright ** (h - 1)
    return out


def noise(n: int) -> np.ndarray:
    return rng.uniform(-1.0, 1.0, n)


def crackle(n: int, per_second: float, decay: float) -> np.ndarray:
    """Sparse hot pops thinning out over `decay` seconds: sizzling, crumbling."""
    out = np.zeros(n)
    t = np.arange(n) / RATE
    chance = per_second / RATE * np.exp(-t / decay)
    for i in np.nonzero(rng.random(n) < chance)[0]:
        pop = noise(seconds(0.004)) * env(seconds(0.004), 0.0002, 0.0015) * rng.uniform(0.3, 1.0)
        out[i : i + len(pop)] += pop[: n - i]
    return out


def thump(length: float, top: float, bottom: float) -> np.ndarray:
    """A falling sub-bass hit: the weight under every stomp and landing."""
    n = seconds(length)
    freq = bottom + (top - bottom) * np.exp(-np.arange(n) / RATE / 0.08)
    body = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * env(n, 0.003, length * 0.35)
    click = lowpass(noise(n), 1500) * env(n, 0.0005, 0.012)
    return body + click * 0.6


def reseed(name: str) -> None:
    """Each sound draws its own random stream, so changing one never changes the others."""
    global rng
    rng = np.random.default_rng(sum(ord(c) * (i + 1) for i, c in enumerate(name)))


def save(name: str, x: np.ndarray, peak_db: float = -1.0, loop: bool = False) -> None:
    x = x.copy()
    if not loop:  # a loop must not fade, or it clicks where it wraps
        fade = min(len(x) // 4, seconds(0.01))
        x[:fade] *= np.linspace(0, 1, fade)
        x[-fade:] *= np.linspace(1, 0, fade)
    x *= 10 ** (peak_db / 20) / max(1e-9, np.max(np.abs(x)))
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        path = pathlib.Path(tmp) / "s.wav"
        with wave.open(str(path), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes((x * 32767).astype(np.int16).tobytes())
        subprocess.run(
            [FFMPEG, "-v", "error", "-y", "-i", str(path), "-c:a", "libvorbis", "-q:a", "5",
             str(OUT / (name + ".ogg"))],
            check=True,
        )
    print(f"{name}.ogg  {len(x) / RATE:.2f} s")


def low_share(x: np.ndarray, below: float = 500.0) -> float:
    """Fraction of the energy below `below` Hz."""
    spectrum = np.abs(np.fft.rfft(x)) ** 2
    freqs = np.fft.rfftfreq(len(x), 1 / RATE)
    return float(spectrum[freqs < below].sum() / max(spectrum.sum(), 1e-12))


def build_stomps() -> None:
    """Three tiers, felt more than heard (director: the first ones crinkled like cellophane).
    Each is a sub thump with a fast pitch drop, a concrete thud low-passed hard, a rumble tail
    and, only on the heavier tiers, a quiet late settle of debris. A heavier tier is lower and
    longer, never brighter."""
    reseed("build_stomps")
    for k in range(3):
        length = 1.0 + 0.4 * k
        x = np.zeros(seconds(length))
        n = seconds(length)
        top, bottom = 68 - 5 * k, 40 - 3 * k  # nothing under ~35 Hz: most speakers drop it
        freq = bottom + (top - bottom) * np.exp(-np.arange(n) / RATE / 0.06)
        sub = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * env(n, 0.002, 0.22 + 0.12 * k)
        place(x, sub, 0.0, 1.0)
        # The thud carries the 80-400 Hz body a TV speaker can actually play.
        thud = pitch(kenney(f"impactSoft_heavy_00{k}"), 0.55 - 0.07 * k)
        thud = lowpass(lowpass(thud, 2500), 2500)
        place(x, thud / max(1e-9, np.max(np.abs(thud))), 0.0, 1.0)
        knock_n = seconds(0.18)
        knock_f = (150 - 20 * k) * np.exp(-np.arange(knock_n) / RATE / 0.05) + 70 - 10 * k
        knock = np.sin(2 * np.pi * np.cumsum(knock_f) / RATE) * env(knock_n, 0.001, 0.05)
        place(x, knock, 0.0, 1.1)
        rumble_n = seconds(0.6 + 0.3 * k)
        rumble = lowpass(lowpass(np.cumsum(noise(rumble_n)) * 0.02, 140), 140)
        rumble *= env(rumble_n, 0.03, 0.3 + 0.2 * k)
        place(x, rumble / max(1e-9, np.max(np.abs(rumble))), 0.0, 0.5 + 0.1 * k)
        if k > 0:
            settle = lowpass(lowpass(crackle(seconds(0.6), 120, 0.25), 2500), 2500)
            place(x, settle / max(1e-9, np.max(np.abs(settle))), 0.3, 0.05 * k)
        save(f"stomp_{k}", highpass(highpass(x, 28.0), 28.0), -2.0)
        print(f"  stomp_{k}: {low_share(x) * 100:.0f}% of the energy below 500 Hz")


def build_breath() -> None:
    reseed("build_breath")
    n = seconds(2.3)
    x = np.zeros(n)
    hum_n = seconds(0.45)
    hum_f = np.linspace(70, 150, hum_n)
    place(x, tone(hum_f, 7) * np.linspace(0.0, 1.0, hum_n) ** 2, 0.0, 0.6)
    roar_n = seconds(1.3)
    centre = 900 + 700 * np.sin(np.linspace(0, 3 * np.pi, roar_n)) ** 2
    roar = bandpass(noise(roar_n), centre, 0.9) * 3.0
    roar += tone(np.full(roar_n, 55.0) + 6 * np.sin(np.linspace(0, 40, roar_n)), 9, 0.7) * 0.35
    roar *= hump(roar_n, 0.15) * (0.8 + 0.2 * np.sin(np.linspace(0, 70, roar_n)))
    place(x, roar, 0.3)
    place(x, pitch(kenney("thrusterFire_000"), 0.7), 0.3, 0.7)
    hiss_n = seconds(1.1)
    hiss = bandpass(noise(hiss_n), np.full(hiss_n, 5500.0), 0.7) * env(hiss_n, 0.05, 0.35)
    place(x, hiss + crackle(hiss_n, 600, 0.35) * 0.7, 1.15, 0.6)
    save("breath", x)


def build_leap() -> None:
    reseed("build_leap")
    n = seconds(0.6)
    x = np.zeros(n)
    sweep = np.linspace(250, 1600, n)
    place(x, bandpass(noise(n), sweep, 1.5) * hump(n, 0.6) * 3.0, 0.0)
    place(x, pitch(kenney("impactPlate_light_001"), 1.3), 0.0, 0.6)
    save("leap_whoosh", x, -4.0)
    x = np.zeros(seconds(1.8))
    place(x, kenney("lowFrequency_explosion_000"), 0.0, 1.0)
    place(x, pitch(kenney("explosionCrunch_002"), 0.8), 0.0, 0.7)
    place(x, thump(1.0, 80, 28), 0.0, 0.9)
    place(x, crackle(seconds(1.2), 500, 0.4), 0.05, 0.4)
    save("leap_land", x)


def build_lash() -> None:
    reseed("build_lash")
    x = np.zeros(seconds(1.3))
    swoosh_n = seconds(0.28)
    place(x, bandpass(noise(swoosh_n), np.linspace(400, 2500, swoosh_n), 2.0) * hump(swoosh_n, 0.8) * 3.0, 0.0)
    crack_n = seconds(0.06)
    crack = bandpass(noise(crack_n), np.linspace(2000, 6000, crack_n), 1.2) * env(crack_n, 0.001, 0.012)
    place(x, crack * 4.0, 0.26)
    place(x, kenney("slime_000"), 0.25, 0.9)
    place(x, pitch(kenney("slime_001"), 0.8), 0.42, 0.7)
    save("lash", x)


def build_ready() -> None:
    reseed("build_ready")
    n = seconds(0.7)
    freq = np.linspace(65, 105, n) + 4 * np.sin(np.linspace(0, 45, n))
    growl = tone(freq, 12, 0.8)
    growl = bandpass(growl, np.full(n, 550.0), 2.0) * 2 + bandpass(growl, np.full(n, 1200.0), 3.0)
    growl += bandpass(noise(n), np.full(n, 700.0), 1.0) * 0.5
    growl *= hump(n, 0.4)
    chime_n = seconds(0.5)
    chime = (np.sin(2 * np.pi * 880 * np.arange(chime_n) / RATE)
             + 0.5 * np.sin(2 * np.pi * 1320 * np.arange(chime_n) / RATE)) * env(chime_n, 0.005, 0.15)
    x = np.zeros(seconds(0.8))
    place(x, growl, 0.0)
    place(x, chime, 0.25, 0.25 * np.max(np.abs(growl)))
    save("ready", x, -4.0)


def build_deflect() -> None:
    reseed("build_deflect")
    x = np.zeros(seconds(0.9))
    place(x, kenney("impactMetal_heavy_001"), 0.0, 1.0)
    place(x, pitch(kenney("impactBell_heavy_002"), 1.2), 0.0, 0.35)
    save("deflect", x, -3.0)


def build_regen() -> None:
    """Two seconds of soft bubbling that loops without a seam (bubbles wrap round the end)."""
    reseed("build_regen")
    n = seconds(2.0)
    x = np.zeros(n)
    for _ in range(26):
        length = seconds(rng.uniform(0.03, 0.07))
        start = rng.integers(0, n)
        f0 = rng.uniform(280, 520)
        freq = f0 * (1 + 1.4 * np.linspace(0, 1, length) ** 2)
        bubble = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * hump(length, 0.2) * rng.uniform(0.4, 1.0)
        idx = (start + np.arange(length)) % n
        x[idx] += bubble
    x = lowpass(x, 2500)
    save("regen_loop", x, -6.0, loop=True)


def main() -> None:
    global kenney_root
    parser = argparse.ArgumentParser()
    parser.add_argument("--kenney", required=True, help="folder holding the unzipped Kenney packs")
    kenney_root = pathlib.Path(parser.parse_args().kenney)
    build_stomps()
    build_breath()
    build_leap()
    build_lash()
    build_ready()
    build_deflect()
    build_regen()


if __name__ == "__main__":
    main()
