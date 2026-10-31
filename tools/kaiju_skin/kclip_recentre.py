"""Moves named clips of a .kclip (scenes/kaiju_clips.gd) back over the origin, fore-aft, without Blender: the clip's
mean pelvis z is taken off its pelvis offset and both toe tips, every frame, so the body stands where the other clips
stand. The Colossus run and slam_stop (r13f) were baked about 140 m behind it (PR #481 notes: "slam_stop (bake
offset)"). Running it twice changes nothing (the mean is then 0).

    python tools/kaiju_skin/kclip_recentre.py <x.kclip> <clip> [<clip> ...]
"""
import json
import struct
import sys
from pathlib import Path


def recentre(data: bytes, names: list) -> tuple:
    """The kclip bytes with each named clip's pelvis and toes shifted so its mean pelvis z is 0; the shifts (cm)."""
    hl = struct.unpack_from("<I", data, 8)[0]
    header = json.loads(data[12:12 + hl])
    at0, fb, nb = 12 + hl, header["frame_bytes"], len(header["bones"])
    out, shifts = bytearray(data), {}
    for clip in header["clips"]:
        if clip["name"] not in names:
            continue
        frames = [at0 + (clip["first"] + f) * fb + nb * 8 for f in range(clip["frames"])]
        shift = -round(sum(struct.unpack_from("<h", out, a + 4)[0] for a in frames) / len(frames))
        for a in frames:
            for z in (a + 4, a + 10, a + 16):  # pelvis, left toe, right toe: int16 z (cm)
                struct.pack_into("<h", out, z, struct.unpack_from("<h", out, z)[0] + shift)
        shifts[clip["name"]] = shift
    missing = set(names) - set(shifts)
    assert not missing, f"no such clips: {sorted(missing)}"
    return bytes(out), shifts


def main() -> None:
    path = Path(sys.argv[1])
    data, shifts = recentre(path.read_bytes(), sys.argv[2:])
    path.write_bytes(data)
    for name, shift in shifts.items():
        print(f"{path.name} {name}: z {shift / 100:+.2f} m")


if __name__ == "__main__":
    main()
