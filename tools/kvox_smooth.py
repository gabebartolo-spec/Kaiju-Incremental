"""Bakes painted-metal smoothing into a .kvox (first frame): each voxel takes the average colour of
itself and its 26 neighbours whose brightness is within `step`, over `passes` passes, so a
voxelised texture's grain evens out while a stripe's edge (unlike neighbours) stays sharp. Used
on the Kaiju Creation cradle (the director 2026-10-25: "a little less blocky, less speckled, more
smooth").

    python tools/kvox_smooth.py <in.kvox> <out.kvox> [passes=3] [step=0.12]
"""
import struct
import sys


def read(path):
    data = open(path, "rb").read()
    version, frames, height = struct.unpack("<IIH", data[4:14])
    count = struct.unpack("<I", data[14:18])[0]
    cells = {}
    for i in range(count):
        x, y, z, r, g, b, f = struct.unpack("<hhhBBBB", data[18 + i * 10:28 + i * 10])
        cells[(x, y, z)] = [r / 255.0, g / 255.0, b / 255.0, f]
    return version, height, cells


def luma(c):
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def smooth(cells, step):
    out = {}
    for (x, y, z), c in cells.items():
        lum = luma(c)
        acc = [c[0], c[1], c[2]]
        n = 1
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    o = cells.get((x + dx, y + dy, z + dz))
                    if o is None or (dx == dy == dz == 0) or abs(luma(o) - lum) > step:
                        continue
                    acc = [acc[0] + o[0], acc[1] + o[1], acc[2] + o[2]]
                    n += 1
        out[(x, y, z)] = [acc[0] / n, acc[1] / n, acc[2] / n, c[3]]
    return out


def write(path, version, height, cells):
    with open(path, "wb") as f:
        f.write(b"KVOX")
        f.write(struct.pack("<IIH", version, 1, height))
        f.write(struct.pack("<I", len(cells)))
        for (x, y, z), c in cells.items():
            rgb = [int(max(0, min(255, round(v * 255)))) for v in c[:3]]
            f.write(struct.pack("<hhhBBBB", x, y, z, rgb[0], rgb[1], rgb[2], c[3]))


def main():
    src, dst = sys.argv[1], sys.argv[2]
    passes = int(sys.argv[3]) if len(sys.argv) > 3 else 3
    step = float(sys.argv[4]) if len(sys.argv) > 4 else 0.12
    version, height, cells = read(src)
    for _ in range(passes):
        cells = smooth(cells, step)
    write(dst, version, height, cells)
    print(f"smoothed {src}: {len(cells)} voxels, {passes} passes, step {step} -> {dst}")


if __name__ == "__main__":
    main()
