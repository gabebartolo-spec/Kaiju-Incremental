"""Cuts the Suno music (D-114, D-125, D-184, D-189) into the game's loops in assets/music/*.ogg.

Each city track is the director's pick (docs/provenance/music.md), split by Suno's Auto split into 10-12 stems. Every
stem goes into one of four layers, so the four layers add up to the whole take; they fade in with the ruin in D-189's
order: low strings and bass first, drums at the first big collapses, brass and the full theme at the peak. Every layer
is cut on the same sample range, so the four files are exactly the same length and stay locked on the
AudioStreamSynchronized (tuning "music" "lock_tolerance_s").

The loop is a stretch of the take that repeats: LOOPS holds its start and length, found by tools/music/find_loop.py
(the similarity of the take's spectrum at the seam). Here the length is trimmed to the sample by matching the waveform
across the seam, and the stretch just past the loop end is crossfaded into its start, so the seam plays through.

Suno's own tag on each source ("made with suno; created=...; id=<song>", the WAV's INFO comment) is copied into the
COMMENT tag of every file cut from it, so the files keep Suno's metadata (register: never strip it). The theme's C2PA
chunk has no place in an Ogg file; it stays on the source WAV, kept with the provenance.

The menu theme (his remaster R) plays its opening once and then loops a stretch: its file ends at the loop end and the
loop starts at tuning "title" "ambience" "theme" "loop_offset_s" (scenes/title_ambience.gd).

Needs numpy, soundfile and ffmpeg (imageio-ffmpeg). The source WAVs stay outside the repo (D-114):

    python tools/music/cut_loops.py --src C:/Users/DANTE/Downloads/kaiju_music
"""

import argparse
import json
import pathlib
import subprocess
import tempfile

import imageio_ffmpeg
import numpy as np
import soundfile as sf

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "music"
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
RATE = 48000
## Seconds of the crossfade at the seam, and how far (s) the seam may slide to match the waveform.
XFADE = 0.25
SLIDE = 0.02
## Where the four layers summed peak (-1 dBFS; the stems summed run over full scale).
PEAK = 0.89
## Vorbis quality (0-10); 4 is about 128 kbit/s stereo.
QUALITY = 4

## The four layers in fade-in order (D-189), and the Suno stem names in each. Every stem is in one layer.
LAYERS = {
    "low": ["Strings", "Bass"],
    "drums": ["Drums", "Percussion"],
    "brass": ["Brass", "Woodwinds", "Guitar"],
    "full": ["Keyboard", "Synth", "Other", "Lead Vocals", "Backing Vocals"],
}

## Per city: the stems folder, the loop's start and length in seconds (find_loop.py), and the tempo measured from the
## take's beat (bpm), which only names the bar count; the file length is what locks.
LOOPS = {
    "city_1": {"song": "city1_young_croc_C1a_51ffbd31.wav", "stems": "stems_city1_C1a", "start": 44.71, "length": 74.24, "bpm": 67.88},
    "city_2": {"song": "city2_behemoth_C2a_d658bf8f.wav", "stems": "stems_city2_C2a", "start": 103.72, "length": 63.19, "bpm": 65.69},
    "city_3": {"song": "city3_colossus_C3a_88095979.wav", "stems": "stems_city3_C3a", "start": 54.91, "length": 113.19, "bpm": 68.0},
}
THEME = {"file": "theme_remaster_of_G2_798f3c13.wav", "start": 90.62, "length": 45.87}


def read(path: pathlib.Path) -> np.ndarray:
    data, rate = sf.read(path, dtype="float32", always_2d=True)
    assert rate == RATE, f"{path.name}: {rate} Hz, expected {RATE}"
    return data


def suno_tag(path: pathlib.Path) -> str:
    """The WAV's RIFF INFO comment (ICMT), where Suno writes "made with suno; created=...; id=..."."""
    data = path.read_bytes()
    at = data.find(b"ICMT")
    assert at > 0, f"{path.name}: no Suno comment"
    size = int.from_bytes(data[at + 4 : at + 8], "little")
    return data[at + 8 : at + 8 + size].rstrip(b"\0").decode()


def stem_name(path: pathlib.Path) -> str:
    """'7 Strings.wav' -> 'Strings'."""
    return path.stem.split(" ", 1)[1]


def snap_length(mix: np.ndarray, start: int, length: int) -> int:
    """The loop length, slid by up to SLIDE s, where the waveform just past the loop end best matches its start."""
    probe = int(0.5 * RATE)
    head = mix[start : start + probe].mean(1)
    slide = int(SLIDE * RATE)
    best, best_len = -np.inf, length
    for d in range(-slide, slide + 1):
        tail = mix[start + length + d : start + length + d + probe].mean(1)
        score = float(np.dot(head, tail) / (np.linalg.norm(head) * np.linalg.norm(tail) + 1e-9))
        if score > best:
            best, best_len = score, length + d
    return best_len


def fold(audio: np.ndarray, start: int, length: int) -> np.ndarray:
    """audio[start : start + length] with the XFADE s past its end faded into its start (equal power)."""
    n = int(XFADE * RATE)
    out = audio[start : start + length].copy()
    t = np.linspace(0.0, np.pi / 2, n, dtype=np.float32)[:, None]
    out[:n] = out[:n] * np.sin(t) + audio[start + length : start + length + n] * np.cos(t)
    return out


def write_ogg(audio: np.ndarray, path: pathlib.Path, tag: str) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        wav = pathlib.Path(tmp) / "x.wav"
        sf.write(wav, np.clip(audio, -1.0, 1.0), RATE, subtype="PCM_16")
        cmd = [FFMPEG, "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", str(QUALITY)]
        cmd += ["-metadata", f"comment={tag}", str(path)]
        subprocess.run(cmd, check=True)


def cut_city(src: pathlib.Path, track: str, row: dict) -> dict:
    folder = src / row["stems"]
    stems = {stem_name(p): read(p) for p in sorted(folder.glob("*.wav"))}
    placed = [s for names in LAYERS.values() for s in names if s in stems]
    assert sorted(placed) == sorted(stems), f"{track}: stems in no layer: {set(stems) - set(placed)}"
    mix = sum(stems.values())
    start = int(row["start"] * RATE)
    length = snap_length(mix, start, int(row["length"] * RATE))
    layers = {layer: fold(sum(stems[s] for s in names if s in stems), start, length) for layer, names in LAYERS.items()}
    gain = PEAK / float(np.abs(sum(layers.values())).max())  # one gain for all four: the full stack peaks at PEAK
    for layer, audio in layers.items():
        write_ogg(audio * gain, OUT / f"{track}_{layer}.ogg", suno_tag(src / row["song"]))
    seconds = length / RATE
    bars = round(seconds * row["bpm"] / 240.0)
    return {"id": track, "seconds": seconds, "bars": bars, "bpm": round(bars * 240.0 / seconds, 4), "gain_db": 20 * np.log10(gain)}


def cut_theme(src: pathlib.Path) -> dict:
    audio = read(src / THEME["file"])
    start = int(THEME["start"] * RATE)
    length = snap_length(audio, start, int(THEME["length"] * RATE))
    looped = fold(audio, start, length)
    write_ogg(np.concatenate([audio[:start], looped]), OUT / "theme.ogg", suno_tag(src / THEME["file"]))
    return {"id": "theme", "loop_offset": start / RATE, "seconds": (start + length) / RATE}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True, type=pathlib.Path, help="folder of the Suno downloads (provenance)")
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    rows = [cut_city(args.src, track, row) for track, row in LOOPS.items()]
    rows.append(cut_theme(args.src))
    print(json.dumps(rows, indent=1))


if __name__ == "__main__":
    main()
