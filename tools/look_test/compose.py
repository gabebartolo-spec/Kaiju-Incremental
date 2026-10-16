"""Look test (throwaway): lays the six look_test.gd runs side by side, and cuts the joint crops.

    python tools/look_test/compose.py <clips_dir> <stills_dir> <out_dir> <ffmpeg>

clip: A | B | C, each the middle 960 px of its 1920x1080 run (the cameras follow the kaiju),
gameplay camera first, then the side camera -> <out>/look_test_abc.mp4 (2880x1080, 60 fps).
crops: the side still where the near (right) knee is most bent, hip and knee for each panel,
cropped 300 px square and enlarged 2x (nearest, so voxels stay sharp) -> <out>/joints_hip.png,
<out>/joints_knee.png.
"""
import json
import math
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

clips, stills, out, ffmpeg = (Path(a) for a in sys.argv[1:5])
out.mkdir(parents=True, exist_ok=True)

segments = []
for cam in ("game", "side"):
    seg = out / f"seg_{cam}.mp4"
    inputs = []
    for v in "ABC":
        inputs += ["-i", str(clips / f"{v}_{cam}.avi")]
    filt = ";".join(f"[{i}:v]crop=960:1080:480:0[p{i}]" for i in range(3))
    filt += ";[p0][p1][p2]hstack=inputs=3,drawbox=x=958:y=0:w=4:h=1080:color=black@1:t=fill," \
            "drawbox=x=1918:y=0:w=4:h=1080:color=black@1:t=fill[v]"
    subprocess.run([str(ffmpeg), "-y", "-loglevel", "error", *inputs, "-filter_complex", filt, "-map", "[v]",
                    "-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p", "-r", "60", str(seg)], check=True)
    segments.append(seg)
listing = out / "segments.txt"
listing.write_text("".join(f"file '{s.as_posix()}'\n" for s in segments), encoding="utf-8")
subprocess.run([str(ffmpeg), "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(listing),
                "-c", "copy", str(out / "look_test_abc.mp4")], check=True)

# Joint crops: the frame with the most bent near knee (same frame in all three runs).
data = {v: json.loads((stills / f"stills_{v}.json").read_text(encoding="utf-8")) for v in "ABC"}


def pt(s):
    a = [float(x) for x in s.strip("()").split(",")]
    return a[0], a[1]


def bend(rec):
    h, k, a = pt(rec["leg_r0"]), pt(rec["leg_r1"]), pt(rec["leg_r2"])
    u = (h[0] - k[0], h[1] - k[1])
    w = (a[0] - k[0], a[1] - k[1])
    cos = (u[0] * w[0] + u[1] * w[1]) / (math.hypot(*u) * math.hypot(*w) + 1e-9)
    return math.acos(max(-1.0, min(1.0, cos)))


best = min(range(len(data["A"])), key=lambda i: bend(data["A"][i]))
print("joint crops at frame", data["A"][best]["frame"])
font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 34)
titles = {"A": "A  current voxels", "B": "B  smooth skin", "C": "C  voxel lattice skin"}
for joint, bone in (("hip", "leg_r0"), ("knee", "leg_r1")):
    tiles = []
    for v in "ABC":
        rec = data[v][best]
        img = Image.open(rec["png"]).convert("RGB")
        x, y = pt(rec[bone])
        box = (int(x - 150), int(y - 150), int(x + 150), int(y + 150))
        tiles.append(img.crop(box).resize((600, 600), Image.NEAREST))
    sheet = Image.new("RGB", (600 * 3 + 8, 660), "black")
    draw = ImageDraw.Draw(sheet)
    for i, (v, tile) in enumerate(zip("ABC", tiles)):
        sheet.paste(tile, (i * 604, 60))
        draw.text((i * 604 + 12, 12), f"{titles[v]}: {joint} (2x)", fill="white", font=font)
    sheet.save(out / f"joints_{joint}.png")
print("wrote", out)
