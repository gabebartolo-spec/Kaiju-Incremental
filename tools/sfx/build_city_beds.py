#!/usr/bin/env python3
"""build_city_beds.py: placeholder loops for CitySound's beds (D-155), synthesized in-house.

The four loops the city atmosphere needs and the library lacks: city_siren, city_gunfire,
city_fire, city_wind (assets/sfx/<name>.ogg, seamless, mono 44.1 kHz Vorbis). They are stand-ins so
the M1 playtest has a real bed under the rampage; the ElevenLabs takes (D-138) replace them file for
file, so nothing in code changes. city_gunfire is built from our own assets/sfx/rifle.ogg (the
ElevenLabs rifle, CLEARED), pitched down and pushed far away. Everything else is numpy noise and
tones. Each is levelled to a target RMS (the curves in tuning "city_sound" are dB offsets from it).

  python tools/sfx/build_city_beds.py        # writes the four .ogg files; seeded, rebuilds match
"""
import subprocess

import numpy as np

import build_sfx as B

RATE = B.RATE
# RMS each loop is levelled to (dBFS), and its peak ceiling. Sparse gunfire sits lower: its RMS
# is mostly silence between shots.
LEVELS = {"city_siren": -24.0, "city_gunfire": -33.0, "city_fire": -24.0, "city_wind": -26.0}
CEILING = -1.5


def put(name: str, x: np.ndarray) -> None:
    """Saves x as the loop `name` at its target RMS: build_sfx.save normalises the peak, so the
    peak is set to the target RMS plus this loop's crest factor (peak over RMS), under CEILING."""
    crest = 20 * np.log10(np.max(np.abs(x)) / max(1e-9, np.sqrt(np.mean(x**2))))
    B.save(name, x, min(CEILING, LEVELS[name] + crest), loop=True)


def seamless(x: np.ndarray, overlap: float) -> np.ndarray:
    """x (n + overlap long) as an n-long loop: the overrun is crossfaded into the start."""
    m = B.seconds(overlap)
    n = len(x) - m
    loop = x[:n].copy()
    fade = np.linspace(0.0, 1.0, m)
    loop[:m] = x[:m] * fade + x[n:] * (1.0 - fade)
    return loop


def smooth_noise(n: int, hz: float) -> np.ndarray:
    """Slow random wandering 0..1 (gusts, flicker): interpolated noise at `hz` points a second."""
    points = B.rng.random(max(2, int(n / RATE * hz) + 2))
    return np.interp(np.arange(n) / RATE * hz, np.arange(len(points)), points)


def build_siren() -> None:
    """Two far-off city sirens, a rising-falling wail (8 s) and a faster higher one (16/3 s), so
    the loop of 16 s holds whole cycles of both and wraps without a click. Dark and echoing: the
    sirens of a city a few blocks away, not an alarm in your ear."""
    B.reseed("city_siren")
    n = B.seconds(16.0)
    t = np.arange(n) / RATE
    x = np.zeros(n)
    for period, low, high, gain in ((8.0, 620.0, 1010.0, 1.0), (16.0 / 3.0, 780.0, 1250.0, 0.7)):
        sweep = 0.5 - 0.5 * np.cos(2 * np.pi * t / period)  # up then down, one wail per period
        freq = low + (high - low) * sweep
        freq += (np.round(freq.sum() / RATE) - freq.sum() / RATE) * RATE / n  # whole cycles per loop
        x += B.tone(freq, 6, 0.55) * gain
    three = np.tile(x, 3)  # filter three loops and keep the middle one: no start-up transient at the seam
    three = B.lowpass(B.lowpass(three, 2600.0), 2600.0)
    three = three + B.tail(three, 1.6, 0.6, 1800) * 0.5  # an echo off the buildings
    x = B.highpass(three, 250.0)[n : 2 * n]
    put("city_siren", x)


def rifle() -> np.ndarray:
    """assets/sfx/rifle.ogg decoded to mono float at RATE."""
    raw = subprocess.run(
        [B.FFMPEG, "-v", "error", "-i", str(B.OUT / "rifle.ogg"), "-ac", "1", "-ar", str(RATE),
         "-f", "f32le", "-"],
        capture_output=True, check=True,
    ).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def build_gunfire() -> None:
    """Distant gunfire (12 s): the volley from rifle.ogg pitched down and low-passed to a dull
    pop, one or two shots at a time scattered round the loop with an echo off the buildings; a
    few shots fall close together. Shots wrap round the loop's end, so it is seamless."""
    B.reseed("city_gunfire")
    n = B.seconds(12.0)
    volley = B.highpass(B.lowpass(B.pitch(rifle(), 0.55), 1300.0), 80.0)
    x = np.zeros(n)
    starts = np.sort(B.rng.uniform(0.0, 12.0, 15))
    for at in starts:
        shot = volley * B.rng.uniform(0.35, 1.0)
        x[(B.seconds(at) + np.arange(len(shot))) % n] += shot  # wraps past the end
    echo = B.tail(np.concatenate([x, x]), 1.4, 0.5, 1500)[n:]
    x = B.highpass(x + echo * 0.35, 90.0)
    put("city_gunfire", x)


def build_fire() -> None:
    """The roar of a burning city (10 s): low-passed noise swelling and sagging on slow gusts, a
    hollow 120-300 Hz rush under it, and crackle (pops and snaps) on top; crossfaded seamless."""
    B.reseed("city_fire")
    over = 1.0
    n = B.seconds(10.0 + over)
    gust = 0.55 + 0.45 * smooth_noise(n, 0.8)
    roar = B.lowpass(B.lowpass(B.noise(n), 900.0), 900.0) * gust
    rush = B.bandpass(B.noise(n), np.full(n, 190.0) + 90.0 * smooth_noise(n, 0.5), 1.4) * gust
    snaps = B.bandpass(B.crackle(n, 38.0, 1e9), np.full(n, 2100.0), 0.8)
    x = roar * 1.0 + rush * 1.6 + snaps * 0.5
    x = B.highpass(x, 60.0)
    put("city_fire", seamless(x, over))


def build_wind() -> None:
    """Wind through an empty city (12 s): band-passed noise whose pitch and strength wander on slow
    gusts, a faint whistle off the edges, and a low moan; crossfaded seamless."""
    B.reseed("city_wind")
    over = 1.5
    n = B.seconds(12.0 + over)
    gust = smooth_noise(n, 0.35) ** 1.5
    centre = 380.0 + 520.0 * smooth_noise(n, 0.3)
    body = B.bandpass(B.noise(n), centre, 0.9) * (0.25 + gust)
    whistle = B.bandpass(B.noise(n), 1700.0 + 500.0 * smooth_noise(n, 0.25), 9.0) * gust * 0.6
    moan = B.lowpass(B.lowpass(B.noise(n), 160.0), 160.0) * (0.3 + gust)
    x = B.highpass(body + whistle * 1.2 + moan * 3.0, 45.0)
    put("city_wind", seamless(x, over))


if __name__ == "__main__":
    build_siren()
    build_gunfire()
    build_fire()
    build_wind()
