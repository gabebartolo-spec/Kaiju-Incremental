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


def build_footstep() -> None:
    """The plain walking step on every foot plant: a short low thud, quieter and drier than a
    stomp. The game re-pitches it per size tier (baby higher, Behemoth lower)."""
    reseed("build_footstep")
    x = np.zeros(seconds(0.7))
    place(x, thump(0.6, 62, 38), 0.0, 1.0)
    thud = lowpass(lowpass(pitch(kenney("impactSoft_heavy_003"), 0.6), 1800), 1800)
    place(x, thud / max(1e-9, np.max(np.abs(thud))), 0.0, 0.7)
    grit = lowpass(crackle(seconds(0.25), 90, 0.08), 2200)
    place(x, grit / max(1e-9, np.max(np.abs(grit))), 0.02, 0.06)
    save("footstep", highpass(highpass(x, 28.0), 28.0), -3.0)
    print(f"  footstep: {low_share(x) * 100:.0f}% of the energy below 500 Hz")
    # Three more steps the game takes turns with, so a walk never repeats one sound: each has a
    # different concrete thud and a slightly different sub drop and grit (same weight, same
    # low end).
    for k, (layer, top, bottom, grit_rate) in enumerate(
        [("impactSoft_heavy_000", 60, 36, 70), ("impactSoft_heavy_001", 65, 40, 110),
         ("impactSoft_heavy_004", 58, 37, 85)], start=1):
        x = np.zeros(seconds(0.7))
        place(x, thump(0.6, top, bottom), 0.0, 1.0)
        thud = lowpass(lowpass(pitch(kenney(layer), 0.55 + 0.04 * k), 1800), 1800)
        place(x, thud / max(1e-9, np.max(np.abs(thud))), 0.0, 0.7)
        grit = lowpass(crackle(seconds(0.25), grit_rate, 0.08), 2200)
        place(x, grit / max(1e-9, np.max(np.abs(grit))), 0.015 + 0.01 * k, 0.06)
        save(f"footstep_{k}", highpass(highpass(x, 28.0), 28.0), -3.0)
        print(f"  footstep_{k}: {low_share(x) * 100:.0f}% of the energy below 500 Hz")


def build_stomp_crack() -> None:
    """The ground splitting under a heavy stomp, on top of the stomp thump: rock grinding
    open, then grit trickling into the cracks. Low-passed so it rumbles rather than ticks."""
    reseed("build_stomp_crack")
    x = np.zeros(seconds(1.6))
    for i, at in enumerate([0.0, 0.07, 0.16]):
        rock = lowpass(pitch(kenney(f"impactMining_00{i}"), 0.5 - 0.05 * i), 3500)
        place(x, rock / max(1e-9, np.max(np.abs(rock))), at, 0.8 - 0.15 * i)
    grind_n = seconds(0.9)
    grind = bandpass(noise(grind_n), np.linspace(420, 160, grind_n), 1.2) * env(grind_n, 0.02, 0.3)
    place(x, grind / max(1e-9, np.max(np.abs(grind))), 0.03, 0.6)
    trickle = lowpass(crackle(seconds(1.2), 160, 0.45), 3000)
    place(x, trickle / max(1e-9, np.max(np.abs(trickle))), 0.25, 0.15)
    save("stomp_crack", highpass(x, 40.0), -4.0)


def build_collapse() -> None:
    """A building coming down (sim fall_land): a crunch of concrete, a deep impact, glass
    bursting, then a long rumble with debris raining for a couple of seconds."""
    reseed("build_collapse")
    x = np.zeros(seconds(3.2))
    place(x, pitch(kenney("explosionCrunch_000"), 0.6), 0.0, 0.9)
    place(x, kenney("lowFrequency_explosion_001"), 0.0, 0.9)
    place(x, thump(1.4, 70, 30), 0.0, 1.0)
    for i, at in enumerate([0.05, 0.18, 0.4]):
        glass = lowpass(pitch(kenney(f"impactGlass_heavy_00{i}"), 0.85), 6000)
        place(x, glass, at, 0.18 - 0.04 * i)
    rumble_n = seconds(2.8)
    rumble = lowpass(lowpass(np.cumsum(noise(rumble_n)) * 0.02, 180), 180)
    rumble *= hump(rumble_n, 0.12) * np.exp(-np.arange(rumble_n) / RATE / 1.2)
    place(x, rumble / max(1e-9, np.max(np.abs(rumble))), 0.05, 0.7)
    rain = lowpass(crackle(seconds(2.4), 220, 0.9), 3500)
    place(x, rain / max(1e-9, np.max(np.abs(rain))), 0.2, 0.3)
    for i, at in enumerate([0.5, 0.9, 1.4]):
        chunk = lowpass(pitch(kenney(f"impactMining_00{i + 1}"), 0.45), 2500)
        place(x, chunk / max(1e-9, np.max(np.abs(chunk))), at, 0.35 - 0.08 * i)
    save("collapse", highpass(highpass(x, 30.0), 30.0), -1.5)


def tail(x: np.ndarray, length: float, decay: float, cutoff: float) -> np.ndarray:
    """A city-sized echo: x convolved with dark, decaying noise (a cheap reverb)."""
    n = seconds(length)
    ir = lowpass(noise(n), cutoff) * np.exp(-np.arange(n) / RATE / decay)
    size = len(x) + n
    wet = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[: len(x)]
    return wet / max(1e-9, np.max(np.abs(wet)))


def build_roar() -> None:
    """The croc titan's roar (demo end card and evolution reveal, D-050), timed to the biped
    head's roar: a breath in while the head goes back (0.32 s), then a 1.7 s bellow from the
    lunge and a long echo off the city. A crocodile bellow is a low, rough rumble rather than a
    lion's tone: a 38-52 Hz buzz with many harmonics through three throat formants, a half-rate
    rasp, a hiss of breath, and a sub-bass push under the lunge."""
    reseed("build_roar")
    x = np.zeros(seconds(4.2))
    inhale_n = seconds(0.34)
    inhale = bandpass(noise(inhale_n), np.linspace(400, 1100, inhale_n), 1.0)
    place(x, inhale * hump(inhale_n, 0.85) * 0.4, 0.0)
    n = seconds(2.1)
    t = np.arange(n) / RATE
    shape = hump(n, 0.1) * np.exp(-np.maximum(t - 1.3, 0.0) / 0.35)
    freq = 38 + 14 * np.sin(np.pi * np.clip(t / 1.7, 0, 1)) + 2.0 * np.sin(2 * np.pi * 5.0 * t)
    buzz = tone(freq, 28, 0.85)
    buzz *= 0.6 + 0.4 * np.sign(np.sin(2 * np.pi * np.cumsum(freq * 0.5) / RATE))
    throat = (bandpass(buzz, np.full(n, 280.0), 2.5) * 1.6
              + bandpass(buzz, np.full(n, 650.0), 3.0) * 0.9
              + bandpass(buzz, np.linspace(1300, 950, n), 3.5) * 0.4
              + lowpass(buzz, 180) * 1.6)
    breath = bandpass(noise(n), np.full(n, 1500.0), 0.8) * 0.3
    body = (throat + breath) * shape
    body /= max(1e-9, np.max(np.abs(body)))
    place(x, body, 0.32, 1.0)
    push = lowpass(pitch(kenney("lowFrequency_explosion_000"), 0.5), 400)
    place(x, push / max(1e-9, np.max(np.abs(push))), 0.32, 0.45)
    place(x, thump(1.6, 55, 30), 0.32, 0.6)
    dry = x.copy()
    x = dry + lowpass(tail(dry, 2.5, 0.7, 900), 900) * 0.35
    save("roar", highpass(highpass(x, 28.0), 28.0), -1.0)
    print(f"  roar: {low_share(x) * 100:.0f}% of the energy below 500 Hz")


def build_ui() -> None:
    """Menu sounds: a dry click on every button, a two-note confirm (with a soft low thump, the
    kaiju's weight) when an upgrade is bought, and a low buzz when it can't be."""
    reseed("build_ui")
    n = seconds(0.07)
    tick = bandpass(noise(n), np.full(n, 2200.0), 1.5) * env(n, 0.0005, 0.008)
    body = np.sin(2 * np.pi * 420 * np.arange(n) / RATE) * env(n, 0.001, 0.02)
    save("ui_click", tick * 2.0 + body * 0.5, -6.0)
    x = np.zeros(seconds(0.45))
    for at, f in [(0.0, 523.0), (0.08, 784.0)]:
        m = seconds(0.3)
        t = np.arange(m) / RATE
        note = (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * 2 * f * t)) * env(m, 0.004, 0.09)
        place(x, note, at, 0.6)
    place(x, thump(0.3, 90, 50), 0.0, 0.5)
    save("ui_confirm", x, -5.0)
    n = seconds(0.18)
    t = np.arange(n) / RATE
    buzz = tone(np.full(n, 110.0), 10, 0.7) * hump(n, 0.2)
    save("ui_deny", lowpass(buzz, 1500), -8.0)
def build_army() -> None:
    """The army (D-050): a tank's cannon, a shell slamming into the kaiju's hide, and the
    attack helicopter's rotor as a seamless loop the game fades in and out."""
    reseed("build_army")
    x = np.zeros(seconds(1.6))
    crack_n = seconds(0.08)
    crack = bandpass(noise(crack_n), np.full(crack_n, 1800.0), 0.6) * env(crack_n, 0.0005, 0.02)
    place(x, crack * 3.0, 0.0)
    place(x, pitch(kenney("explosionCrunch_001"), 0.75), 0.0, 0.8)
    place(x, kenney("lowFrequency_explosion_001"), 0.0, 0.7)
    place(x, thump(0.7, 90, 45), 0.0, 0.6)
    echo = tail(x.copy(), 1.2, 0.35, 1200)
    # High-passed at 120 Hz so the cannon's thump stays off the stomps' band (mix report).
    save("tank_fire", highpass(highpass(x + echo * 0.25, 120.0), 120.0), -2.0)
    x = np.zeros(seconds(0.9))
    place(x, pitch(kenney("impactPunch_heavy_001"), 0.7), 0.0, 1.0)
    place(x, pitch(kenney("impactMetal_light_002"), 0.8), 0.0, 0.35)
    place(x, thump(0.5, 110, 55), 0.0, 0.6)
    place(x, lowpass(crackle(seconds(0.5), 300, 0.15), 3000), 0.02, 0.3)
    save("shell_hit", x, -3.0)
    # Rotor: main-blade slaps at 19 Hz and a tail-rotor buzz at 4x (whole cycles in 2 s), over
    # a turbine whine. Built 0.5 s long and the overrun crossfaded into the start: no seam.
    n = seconds(2.0)
    m = seconds(0.5)
    t = np.arange(n + m) / RATE
    slap_phase = (t * 19.0) % 1.0
    slap = np.exp(-slap_phase / 0.035) * (1 - np.exp(-slap_phase / 0.002))
    chop = lowpass(noise(n + m), 700) * slap * 4.0 + lowpass(slap, 300) * 2.0
    tail_rotor = bandpass(noise(n + m), np.full(n + m, 1100.0), 2.0) * (0.5 + 0.5 * np.sin(2 * np.pi * 76 * t))
    whine = (np.sin(2 * np.pi * 2400 * t) * 0.05 + np.sin(2 * np.pi * 3600 * t) * 0.02)
    hum = np.sin(2 * np.pi * 57 * t) * 0.3
    full = chop + tail_rotor * 0.6 + whine + hum
    loop = full[:n].copy()
    fade = np.linspace(0.0, 1.0, m)
    loop[:m] = full[:m] * fade + full[n:] * (1.0 - fade)
    save("heli_rotor", loop, -4.0, loop=True)
    # Chin gun: a five-round burst at 11 rounds a second, each a sharp crack over a short thud.
    reseed("build_heli_gun")
    x = np.zeros(seconds(0.75))
    for k in range(5):
        shot_n = seconds(0.09)
        crack = bandpass(noise(shot_n), np.full(shot_n, 2600.0), 0.8) * env(shot_n, 0.0005, 0.012)
        body = lowpass(noise(shot_n), 600) * env(shot_n, 0.001, 0.03)
        place(x, crack * 2.5 + body * 2.0, k / 11.0, 1.0 - 0.06 * k)
    place(x, tail(x.copy(), 0.6, 0.18, 1500), 0.0, 0.2)
    save("heli_gun", x, -3.0)
    # Helicopter down: the turbine whine falling away, a blast, and metal raining on the street.
    reseed("build_heli_crash")
    x = np.zeros(seconds(2.6))
    whine_n = seconds(0.6)
    whine = np.sin(2 * np.pi * np.cumsum(np.linspace(2400, 700, whine_n)) / RATE) * np.linspace(0.3, 0.0, whine_n)
    place(x, whine, 0.0, 0.5)
    place(x, kenney("lowFrequency_explosion_000"), 0.15, 0.9)
    place(x, pitch(kenney("explosionCrunch_003"), 0.85), 0.15, 0.8)
    place(x, thump(0.9, 85, 40), 0.15, 0.6)
    for i, at in enumerate([0.45, 0.7, 1.0, 1.35]):
        clang = pitch(kenney(f"impactMetal_heavy_00{i}"), 0.75 + 0.05 * i)
        place(x, clang, at, 0.4 - 0.07 * i)
    save("heli_crash", x, -1.5)


def build_crowd() -> None:
    """The city panicking (D-050), as a 6 s loop the game fades with how many people flee and how
    fast the city falls: a far-off murmur of many voices, shouts, and screams that rise and
    break, with a hint of running feet. High-passed at 300 Hz and kept mid-heavy, so it sits above
    the stomps (almost all below 500 Hz) instead of on them."""
    reseed("build_crowd")
    n = seconds(6.0)
    m = seconds(1.0)
    total = n + m
    t = np.arange(total) / RATE
    x = np.zeros(total)
    for _ in range(14):  # murmur: voices as formant-filtered noise with a syllable rhythm
        rate = rng.uniform(3.0, 6.0)
        syl = np.clip(np.sin(2 * np.pi * rate * t + rng.uniform(0, 6.28)), 0, 1) ** 2
        voice = bandpass(noise(total), np.full(total, rng.uniform(450, 900)), 2.0) * 0.6
        voice += bandpass(noise(total), np.full(total, rng.uniform(1300, 2200)), 3.0) * 0.4
        x += voice * syl * rng.uniform(0.3, 0.7)
    for _ in range(9):  # screams and shouts: a rising, wavering tone through a mouth formant
        length = seconds(rng.uniform(0.5, 1.1))
        f0 = rng.uniform(500, 850)
        glide = f0 * (1 + 0.5 * hump(length, 0.3)) + 25 * np.sin(np.linspace(0, 40, length))
        scream = bandpass(tone(glide, 8, 0.6), np.full(length, rng.uniform(1100, 1700)), 2.0)
        scream *= hump(length, 0.25)
        place(x, scream * rng.uniform(0.25, 0.55), rng.uniform(0.0, 6.0 - 1.1))
    feet = bandpass(crackle(total, 18, 0.03), np.full(total, 1500.0), 1.0)
    x += feet * 0.15
    x = lowpass(x, 3500)
    x = x + tail(x.copy(), 1.2, 0.5, 2000) * 0.4  # off the buildings: far away, not in your ear
    x = highpass(highpass(x, 300.0), 300.0)
    loop = x[:n].copy()
    fade = np.linspace(0.0, 1.0, m)
    loop[:m] = x[:m] * fade + x[n:] * (1.0 - fade)
    save("crowd_panic", loop, -6.0, loop=True)
    print(f"  crowd_panic: {low_share(loop) * 100:.0f}% of the energy below 500 Hz")


def build_rifle() -> None:
    """A rooftop squad's volley (D-063): four or five rifles cracking within a quarter second,
    each a sharp high crack with a small body, then a short slap off the buildings. Lighter,
    higher and shorter than a tank's cannon, so the two never blur."""
    reseed("build_rifle")
    x = np.zeros(seconds(0.9))
    for k in range(5):
        shot_n = seconds(0.07)
        crack = bandpass(noise(shot_n), np.full(shot_n, rng.uniform(2800, 3800)), 0.9)
        crack *= env(shot_n, 0.0003, 0.008)
        body = bandpass(noise(shot_n), np.full(shot_n, 380.0), 1.2) * env(shot_n, 0.001, 0.02)
        place(x, crack * 3.0 + body * 1.5, rng.uniform(0.0, 0.22), rng.uniform(0.6, 1.0))
    slap = tail(x.copy(), 0.6, 0.15, 2500)
    save("rifle", x + slap * 0.25, -4.0)


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
    build_footstep()
    build_stomp_crack()
    build_collapse()
    build_roar()
    build_ui()
    build_crowd()
    build_rifle()
    build_army()
    build_breath()
    build_leap()
    build_lash()
    build_ready()
    build_deflect()
    build_regen()


if __name__ == "__main__":
    main()
