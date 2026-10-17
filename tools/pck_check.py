"""Lists the Godot pack inside an exported game and proves it holds the real assets.

    python tools/pck_check.py out/windows/KaijuIncremental.exe [--list]

The pack is the one embedded at the end of the exe (export_presets.cfg embed_pck) or a
.pck file. Checks, failing loudly with exit 1:
  - every assets/fonts/*.ttf in the checkout is a real font (not a Git LFS pointer) and its
    imported FontFile in the pack carries the font's own bytes;
  - every assets/kaiju/*.kvox in the checkout is in the pack, byte for byte.
--list prints every path in the pack with its size.
"""

import hashlib
import struct
import sys
import zlib
from pathlib import Path

try:
    from compression import zstd  # Python 3.14+
except ImportError:
    zstd = None

MAGIC = b"GDPC"
REL_FILEBASE = 2
DIR_ENCRYPTED = 1
LFS_POINTER = b"version https://git-lfs"
TTF_MAGICS = (b"\x00\x01\x00\x00", b"OTTO", b"true", b"ttcf")


def read_pack(path):
    """Returns {res path: bytes} for every file in the pack at path."""
    data = Path(path).read_bytes()
    if data[:4] == MAGIC:
        start = 0
    elif data[-4:] == MAGIC:
        size = struct.unpack_from("<Q", data, len(data) - 12)[0]
        start = len(data) - 12 - size
        if data[start : start + 4] != MAGIC:
            sys.exit(f"FAIL: {path}: embedded pack trailer found but no pack header")
    else:
        sys.exit(f"FAIL: {path}: no Godot pack (GDPC) at its start or end")
    version, _maj, _min, _pat, flags, file_base = struct.unpack_from("<IIIIIQ", data, start + 4)
    pos = start + 32
    if flags & DIR_ENCRYPTED:
        sys.exit(f"FAIL: {path}: the pack directory is encrypted")
    if version >= 3:
        dir_offset = struct.unpack_from("<Q", data, pos)[0]
        pos = start + dir_offset
    else:
        pos += 16 * 4
    base = start + file_base if flags & REL_FILEBASE else start
    count = struct.unpack_from("<I", data, pos)[0]
    pos += 4
    files = {}
    for _ in range(count):
        n = struct.unpack_from("<I", data, pos)[0]
        pos += 4
        name = data[pos : pos + n].rstrip(b"\x00").decode("utf-8")
        pos += n
        ofs, size = struct.unpack_from("<QQ", data, pos)
        pos += 16 + 16 + 4  # offset, size, md5, flags
        name = name.removeprefix("res://")
        files[name] = data[base + ofs : base + ofs + size]
    return files


def unpack_resource(blob):
    """The bytes of a resource the export stored compressed (RSCC), else blob as is."""
    if blob[:4] != b"RSCC":
        return blob
    mode, block, total = struct.unpack_from("<III", blob, 4)
    blocks = (total + block - 1) // block
    sizes = struct.unpack_from(f"<{blocks}I", blob, 16)
    pos = 16 + 4 * blocks
    out = bytearray()
    for size in sizes:
        chunk = blob[pos : pos + size]
        pos += size
        if mode == 1:  # deflate
            out += zlib.decompress(chunk)
        elif mode == 2 and zstd:
            out += zstd.decompress(chunk)
        elif mode == 3:  # gzip
            out += zlib.decompress(chunk, 31)
        else:
            sys.exit(f"FAIL: RSCC compression mode {mode} not readable here")
    return bytes(out)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    files = read_pack(sys.argv[1])
    if "--list" in sys.argv:
        for name in sorted(files):
            print(f"{len(files[name]):>10}  {name}")
    print(f"pack: {len(files)} files, {sum(len(b) for b in files.values())} bytes")
    bad = []
    fonts = sorted(Path("assets/fonts").glob("*.ttf"))
    kvox = sorted(Path("assets/kaiju").glob("*.kvox"))
    if not fonts or not kvox:
        bad.append("no assets/fonts/*.ttf or assets/kaiju/*.kvox in the checkout")
    for font in fonts:
        raw = font.read_bytes()
        if raw.startswith(LFS_POINTER) or raw[:4] not in TTF_MAGICS:
            bad.append(f"{font.as_posix()} is not a real font (Git LFS pointer? run git lfs pull)")
            continue
        imported = [b for n, b in files.items() if n.startswith(f".godot/imported/{font.name}-")]
        if not imported:
            bad.append(f"{font.as_posix()}: no imported FontFile in the pack")
        elif raw[:4096] not in unpack_resource(imported[0]):
            bad.append(f"{font.as_posix()}: the pack's FontFile does not carry the font's bytes")
        else:
            print(f"ok  {font.as_posix()} ({len(raw)} B) -> imported FontFile ({len(imported[0])} B)")
    for model in kvox:
        name = model.as_posix()
        if name not in files:
            bad.append(f"{name}: not in the pack")
        elif hashlib.md5(files[name]).digest() != hashlib.md5(model.read_bytes()).digest():
            bad.append(f"{name}: differs from the checkout")
        else:
            print(f"ok  {name} ({len(files[name])} B)")
    for line in bad:
        print("FAIL:", line)
    if bad:
        sys.exit(1)
    print(f"pack check passed: {len(fonts)} fonts, {len(kvox)} kaiju models")


if __name__ == "__main__":
    main()
