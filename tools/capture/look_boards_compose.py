"""Composes the look boards (capture-only branch, director 2026-10-23) from the 4K stills.

    python tools/capture/look_boards_compose.py <raw dir> <out dir> [rows=abc]

Raw names: <look>_<time>_<shot>_t<NN>.png  (look a|b|c; time dusk|noon; shot f1|f2|f3|f3b).
One board per frame and time (F1, F2, F3 x dusk, noon); one row per look; each row a 1280x720
view and four zoomed crops (a 480x270 or 640x360 window of the 4K frame, nearest, so the cubes stay cubes). The crops sit
at the same pixels in every row: the options share the camera and the sim tick.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

W = 2560
MAIN = (1280, 720)
CROP_SRC = (480, 270)  # the default source window (4K pixels); a crop may name its own width
CROP_OUT = (640, 360)
BAR = 54
TITLE = 96
FOOT = 84
FONT = "C:/Windows/Fonts/calibrib.ttf"
FONT_L = "C:/Windows/Fonts/calibri.ttf"

ROW_LABEL = {
    "a": "A   TODAY: the game as it is now",
    "b": "B   ONE LOOK (mock): props, ground, haze and fire brought into the city's block size",
    "c": "C   SMOOTH CROC: the croc as a smooth textured model, everything else as today",
}
ROW_COLOUR = {"a": (60, 60, 64), "b": (36, 84, 62), "c": (92, 60, 40)}
TIME_LABEL = {"dusk": "Dusk", "noon": "Noon"}
FRAME_LABEL = {
    "f1": "F1   Standing, 4 seconds after the rise from the river. Game camera.",
    "f2": "F2   12 seconds in: a tower topples and a fire burns. Game camera.",
    "f3": "F3   Same moment as F1, close camera (the intro and load-screen distance).",
}
SHOT = {"f1": ("f1", 4), "f2": ("f2", 12), "f3": ("f3", 4)}

# (caption, source shot, centre x, centre y) in 4K pixels; 2x crops of 320x180.
CROPS = {
    "f1": [
        ("croc from behind", "f1", 1920, 800, 640),
        ("croc skin and tail", "f1", 2016, 1060, 480),
        ("tree and car", "f1", 2860, 1620, 640),
        ("car", "f1", 384, 1824, 480),
    ],
    "f2": [
        ("the fire", "f2", 1342, 1180, 480),
        ("croc and claw swipe", "f2", 1900, 900, 640),
        ("tree and car", "f2", 2400, 1560, 480),
        ("toppling tower", "f2", 3100, 800, 640),
    ],
    "f3": [
        ("croc face (front view)", "f3b", 2207, 640, 560),
        ("croc skin (front view)", "f3b", 2040, 1008, 480),
        ("tree and car", "f3", 2520, 1030, 640),
        ("car", "f3", 456, 1416, 480),
    ],
}
NOTES = {
    "f1": "Same city seed, same moment in all rows.",
    "f2": "The fire is placed by the capture at the same spot and second in every row: the natural fires are small and hide in dust.",
    "f3": "Face and skin crops come from a front-view camera at the same moment (the game camera looks at the croc's back).",
}


def font(size, bold=True):
    return ImageFont.truetype(FONT if bold else FONT_L, size)


def load(raw, look, time, shot):
    name, sec = SHOT.get(shot, (shot, 4))
    path = raw / f"{look}_{time}_{name}_t{sec:02d}.png"
    return Image.open(path).convert("RGB") if path.exists() else None


def crop(img, cx, cy, w=CROP_SRC[0]):
    h = w * 9 // 16
    x0 = max(0, min(img.width - w, cx - w // 2))
    y0 = max(0, min(img.height - h, cy - h // 2))
    part = img.crop((x0, y0, x0 + w, y0 + h))
    return part.resize(CROP_OUT, Image.NEAREST if w < 640 else Image.LANCZOS)


def caption(draw, xy, text):
    x, y = xy
    f = font(26)
    w = draw.textlength(text, font=f)
    draw.rectangle((x, y, x + w + 16, y + 36), fill=(0, 0, 0))
    draw.text((x + 8, y + 2), text, font=f, fill=(255, 255, 255))


def board(raw, frame, time, rows):
    h = TITLE + len(rows) * (BAR + MAIN[1]) + FOOT
    img = Image.new("RGB", (W, h), (18, 18, 20))
    d = ImageDraw.Draw(img)
    d.text((24, 12), f"{FRAME_LABEL[frame]}   {TIME_LABEL[time]}", font=font(44), fill=(255, 255, 255))
    d.text((24, 62), "Reptilian, Behemoth body and its city, seed 0, Medium preset at 4K, HUD on.", font=font(26, False), fill=(200, 200, 200))
    y = TITLE
    for look in rows:
        d.rectangle((0, y, W, y + BAR), fill=ROW_COLOUR[look])
        d.text((24, y + 6), ROW_LABEL[look], font=font(36), fill=(255, 255, 255))
        y += BAR
        main = load(raw, look, time, frame)
        if main is None:
            d.rectangle((0, y, W, y + MAIN[1]), fill=(30, 30, 34))
            d.text((40, y + 40), "not rendered", font=font(40), fill=(200, 120, 120))
        else:
            img.paste(main.resize(MAIN, Image.LANCZOS), (0, y))
            for i, (cap, shot, cx, cy, cw) in enumerate(CROPS[frame]):
                src = load(raw, look, time, shot)
                if src is None:
                    continue
                ox, oy = MAIN[0] + (i % 2) * CROP_OUT[0], y + (i // 2) * CROP_OUT[1]
                img.paste(crop(src, cx, cy, cw), (ox, oy))
                caption(d, (ox + 8, oy + 8), cap)
        y += MAIN[1]
    d.text((24, y + 10), "Buildings break into blocks in all three.", font=font(40), fill=(255, 224, 120))
    d.text((24, y + 56), NOTES[frame], font=font(24, False), fill=(200, 200, 200))
    return img


def main():
    raw, out = Path(sys.argv[1]), Path(sys.argv[2])
    rows = sys.argv[3] if len(sys.argv) > 3 else "abc"
    out.mkdir(parents=True, exist_ok=True)
    for frame in ("f1", "f2", "f3"):
        for time in ("dusk", "noon"):
            if not any(load(raw, r, time, frame) is not None for r in rows):
                continue
            img = board(raw, frame, time, rows)
            path = out / f"board_{frame}_{time}.png"
            img.save(path)
            print(path, img.size)


main()
