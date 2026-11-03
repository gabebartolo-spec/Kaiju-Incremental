"""Drops named clips from a .kclip (scenes/kaiju_clips.gd) without Blender: their frames are cut out and the later
clips' "first" moved down, so the file holds only what the game plays. Used for the croc's claw rake layer clips
(rake_r, rake_l), gone with the rake (D-459). Running it again on a dropped name fails (no such clip).

    python tools/kaiju_skin/kclip_drop.py <x.kclip> <clip> [<clip> ...]
"""
import json
import struct
import sys
from pathlib import Path


def drop(data: bytes, names: list) -> bytes:
    """The kclip bytes without the named clips."""
    hl = struct.unpack_from("<I", data, 8)[0]
    header = json.loads(data[12:12 + hl])
    at0, fb = 12 + hl, header["frame_bytes"]
    missing = set(names) - {c["name"] for c in header["clips"]}
    assert not missing, f"no such clips: {sorted(missing)}"
    frames, clips, first = bytearray(), [], 0
    for clip in sorted(header["clips"], key=lambda c: c["first"]):
        if clip["name"] in names:
            continue
        a = at0 + clip["first"] * fb
        frames += data[a:a + clip["frames"] * fb]
        clips.append(dict(clip, first=first))
        first += clip["frames"]
    header["clips"] = clips
    head = json.dumps(header, separators=(",", ":")).encode()
    return data[:8] + struct.pack("<I", len(head)) + head + bytes(frames)


def main() -> None:
    path = Path(sys.argv[1])
    path.write_bytes(drop(path.read_bytes(), sys.argv[2:]))
    print(f"{path.name}: dropped {', '.join(sys.argv[2:])}")


if __name__ == "__main__":
    main()
