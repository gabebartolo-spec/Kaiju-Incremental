"""Fits a .kclip (scenes/kaiju_clips.gd) to a new rig of the same bones: the header's rest heads become the rig's
from the skin export (its frame: body_height_m tall, origin on the ground under the pelvis, as the clips scripts
bake) and stride_m scales with the leg (hip to ankle), so KaijuClips.fit takes the clips and
the feet keep their stride. Clip turns are world turns away from rest (croc_adult3_clips.py world_pose), so they
replay on the new rest unchanged. First use: the T-rex-bodied croc (croc_trex) on the adult's clips.

    python tools/kaiju_skin/kclip_rehead.py <x.kclip> <stem.skin.json>
"""
import json
import struct
import sys
from pathlib import Path

import numpy as np

LEG = ("leg_l0", "leg_l3")  # hip to ankle: the length a stride scales with


def rehead(data: bytes, skin: dict) -> bytes:
    hl = struct.unpack_from("<I", data, 8)[0]
    header = json.loads(data[12:12 + hl])
    heads = {b["game"]: np.array(b["head"], float) for b in skin["bones"]}
    assert set(heads) == set(header["bones"]), "bones differ"
    k = 1.0  # the skin export is already body_height_m (100 m) tall
    old = np.linalg.norm(np.subtract(*(header["rest_heads_m"][n] for n in LEG)))
    new = np.linalg.norm(heads[LEG[0]] - heads[LEG[1]]) * k
    header["rest_heads_m"] = {n: [round(float(c) * k, 3) for c in heads[n]] for n in header["bones"]}
    s = new / old
    header["stride_m"] = round(header["stride_m"] * s, 4)
    body = data[12 + hl:]
    hb = json.dumps(header).encode()
    return b"KCLP" + struct.pack("<II", 1, len(hb)) + hb + body, old, new


if __name__ == "__main__":
    path = Path(sys.argv[1])
    out, old, new = rehead(path.read_bytes(), json.loads(Path(sys.argv[2]).read_text(encoding="utf-8")))
    path.write_bytes(out)
    print(f"reheaded {path.name}: leg {old:.1f} -> {new:.1f} m")
