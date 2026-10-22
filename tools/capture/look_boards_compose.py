"""Composes the look boards (capture-only branch, director 2026-10-23) from the 4K stills.

    python tools/capture/look_boards_compose.py <raw dir> <out dir> [rows=abc]

Raw names: <look>_<time>_<shot>_t<NN>.png  (look a|b|c; time dusk|noon; shot f1|f2|f3|f3b).
One board per frame and time (F1, F2, F3 x dusk, noon); one row per look. Each row: a 1280x720 view and
two columns of zoomed crops (a window of the 4K frame, nearest, so the cubes stay cubes). The left column
holds the crops where A and B differ (props, ground, fire); the right column holds the croc crops where A
and C differ. Rows B and C show only the column they change, and say so in the other. Crops sit at the same
pixels in every row: the options share the camera and the sim tick.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

W = 3200
MAIN = (1280, 720)
CROP_OUT = (640, 360)
BAR = 58
TITLE = 110
FOOT = 150
FONT = "C:/Windows/Fonts/calibrib.ttf"
FONT_L = "C:/Windows/Fonts/calibri.ttf"
WHITE = (255, 255, 255)

ROW_LABEL = {
    "a": "A   TODAY: the game as it is now",
    "b": "B   ONE LOOK (mock): cars and trees built from smaller blocks, finer speckle on the ground, distant buildings softened by haze. No flame body in this mock.",
    "c": "C   SMOOTH CROC: the croc as a smooth model, everything else as today",
}
ROW_COLOUR = {"a": (60, 60, 64), "b": (36, 84, 62), "c": (92, 60, 40)}
TIME_LABEL = {"dusk": "Dusk", "noon": "Noon"}
FRAME_LABEL = {
    "f1": "F1   5 seconds into the rampage, croc in the open street. Game camera.",
    "f2": "F2   12 seconds in: a tower topples and a fire burns. Game camera.",
    "f3": "F3   Standing, 4 seconds after the rise, close camera (intro and load-screen distance).",
}
SHOT = {"f1": ("f1", 5), "f2": ("f2", 12), "f3": ("f3", 4)}

# Six crop slots per board, column by column (slot i: column i // 2, row i % 2), each 640x360 and a window of the
# 4K frame (nearest, so the cubes stay cubes): (caption in row A, in row B, in row C, shot, centre x, centre y,
# window width). Columns 0 and 1 are where A and B differ (props, ground, haze, fire); column 2 is the croc,
# where A and C differ. A row shows the slots it does not change too, captioned "same as A".
SAME = "same as A"
CROPS = {
    "f1": [
        ("car", "cars rebuilt from smaller blocks", SAME, "f1", 830, 1700, 240),
        ("road and car", "finer speckle on the road, cars rebuilt", SAME, "f1", 3290, 1620, 240),
        ("distant buildings", "distant buildings softened by haze", SAME, "f1", 1900, 470, 640),
        ("road speckle", "finer speckle on the road", SAME, "f1", 620, 1590, 240),
        ("croc head and neck", "croc: " + SAME, "croc head and neck", "f1", 1560, 830, 640),
        ("croc skin and legs", "croc: " + SAME, "croc skin and legs", "f1", 1830, 1040, 480),
    ],
    "f2": [
        ("staged fire (lit by the capture)", "staged fire (lit by the capture)", "staged fire (lit by the capture)", "f2", 1342, 1180, 320),
        ("car", "cars rebuilt from smaller blocks", SAME, "f2", 2800, 1680, 240),
        ("distant buildings", "distant buildings softened by haze", SAME, "f2", 500, 560, 640),
        ("tree and car", "trees and cars rebuilt from smaller blocks", SAME, "f2", 2400, 1560, 240),
        ("croc and claw swipe", "croc: " + SAME, "C's head is turned differently at this moment", "f2", 1900, 900, 640),
        ("croc head", "croc: " + SAME, "C's head is turned differently at this moment", "f2", 2064, 924, 480),
    ],
    "f3": [
        ("tree and car", "trees and cars rebuilt from smaller blocks", SAME, "f3", 2520, 1030, 300),
        ("car", "cars rebuilt from smaller blocks", SAME, "f3", 456, 1416, 240),
        ("distant buildings", "distant buildings softened by haze", SAME, "f3", 2900, 500, 640),
        ("tree and car", "trees and cars rebuilt from smaller blocks", SAME, "f3", 2400, 1000, 300),
        ("croc face, front view: closer than play shows it", "croc: " + SAME, "croc face, front view: closer than play shows it", "f3b", 2207, 640, 560),
        ("croc skin, front view: closer than play shows it", "croc: " + SAME, "croc skin, front view: closer than play shows it", "f3b", 2040, 1008, 480),
    ],
}
NOTES = {
    "f1": "Same city, same route, same moment in all rows. The first stomps have already broken some buildings.",
    "f2": "The fire is staged: the capture lights it at the same spot and second in every row, because the game's own fires are small and hide in dust.",
    "f3": "The face and skin crops come from a front-view camera at the same moment; the game camera sees the croc's back.",
}
NOT_SHOWN = (
    "Not shown: a fully smooth city with pre-broken buildings "
    "(holes would no longer appear where you bite; months of work)."
)


def font(size, bold=True):
    return ImageFont.truetype(FONT if bold else FONT_L, size)


def load(raw, look, time, shot):
    name, sec = SHOT.get(shot, (shot, 4))
    path = raw / f"{look}_{time}_{name}_t{sec:02d}.png"
    return Image.open(path).convert("RGB") if path.exists() else None


def crop(img, cx, cy, w):
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
    draw.text((x + 8, y + 2), text, font=f, fill=WHITE)


def board(raw, frame, time, rows):
    top = TITLE + 52
    h = top + len(rows) * (BAR + MAIN[1]) + FOOT
    img = Image.new("RGB", (W, h), (18, 18, 20))
    d = ImageDraw.Draw(img)
    d.text((24, 10), f"{FRAME_LABEL[frame]}   {TIME_LABEL[time]}", font=font(44), fill=WHITE)
    d.text((24, 66), "A reptilian croc in its city at the Behemoth stage.", font=font(28, False), fill=WHITE)
    d.text((24, TITLE + 8), NOTES[frame], font=font(28, False), fill=WHITE)
    y = top
    for look in rows:
        d.rectangle((0, y, W, y + BAR), fill=ROW_COLOUR[look])
        d.text((24, y + 8), ROW_LABEL[look], font=font(34 if look == "b" else 38), fill=WHITE)
        y += BAR
        main = load(raw, look, time, frame)
        if main is None:
            d.rectangle((0, y, W, y + MAIN[1]), fill=(30, 30, 34))
            d.text((40, y + 40), "not rendered", font=font(40), fill=(255, 150, 150))
        else:
            img.paste(main.resize(MAIN, Image.LANCZOS), (0, y))
            if look == "b":
                caption(d, (12, y + 130), "haze lightens the whole frame")
            for i, (cap_a, cap_b, cap_c, shot, cx, cy, cw) in enumerate(CROPS[frame]):
                src = load(raw, look, time, shot)
                if src is None:
                    continue
                ox, oy = MAIN[0] + (i // 2) * CROP_OUT[0], y + (i % 2) * CROP_OUT[1]
                img.paste(crop(src, cx, cy, cw), (ox, oy))
                caption(d, (ox + 8, oy + 8), {"a": cap_a, "b": cap_b, "c": cap_c}[look])
        y += MAIN[1]
    d.text((24, y + 6), "Buildings break into blocks in all three", font=font(64), fill=(255, 224, 120))
    d.text((24, y + 90), NOT_SHOWN, font=font(30, False), fill=WHITE)
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
