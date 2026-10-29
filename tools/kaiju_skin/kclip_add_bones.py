"""Gives a .kclip (scenes/kaiju_clips.gd) the game bones its skin added since the clips were baked, without Blender:
each new bone is appended still (local identity, so it turns as its parent, which is what the old fold did), so every
clip plays exactly as before until it is re-baked (tools/blender/croc_adult3_clips.py does the same upgrade on its
way in). Lead 2026-10-28 call A: the croc's collar bones (clavicle_l/_r) left spine2; the keyer re-bakes the clips.

    python tools/kaiju_skin/kclip_add_bones.py <x.kclip> <x.skin.json>

The file's bones must be a prefix of the skin's (rig_from_skin.py bone_names); a rest head comes from the skin.json
(the head of the game bone's first Blender bone, skin metres, as the clips' rest_heads_m)."""
import json
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rig_from_skin  # noqa: E402

IDENTITY = struct.pack("<4h", 0, 0, 0, 32767)


def upgrade(data, meta):
    """The kclip bytes with meta's missing game bones appended still, and the number added."""
    hl = struct.unpack_from("<I", data, 8)[0]
    header, body = json.loads(data[12:12 + hl]), data[12 + hl:]
    old, names = header["bones"], rig_from_skin.bone_names(meta)
    assert names[:len(old)] == old, f"bones {old} are not a prefix of {names}"
    add = len(names) - len(old)
    if add == 0:
        return data, 0
    fb, cut = header["frame_bytes"], len(old) * 8
    assert len(body) % fb == 0, "body is not whole frames"
    body = b"".join(body[k:k + cut] + IDENTITY * add + body[k + cut:k + fb] for k in range(0, len(body), fb))
    first, gathers = {}, {}
    for b in meta["bones"]:  # hierarchy order: the first one met is the game bone's root
        first.setdefault(b["game"], b)
        gathers.setdefault(b["game"], []).append(b["name"])
    header["bones"], header["frame_bytes"] = names, fb + add * 8
    header["gathers"] = {g: gathers[g] for g in names}
    header["rest_heads_m"].update({g: [round(c, 3) for c in first[g]["head"]] for g in names[len(old):]})
    head = json.dumps(header, separators=(",", ":")).encode()
    return data[:8] + struct.pack("<I", len(head)) + head + body, add


def main():
    kclip, meta_path = Path(sys.argv[1]), Path(sys.argv[2])
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    data, add = upgrade(kclip.read_bytes(), meta)
    if add:
        kclip.write_bytes(data)
    print(f"{kclip.name}: {add} bones added")


if __name__ == "__main__":
    main()
