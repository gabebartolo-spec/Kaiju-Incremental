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

W = 2560
MAIN = (1280, 720)
CROP_OUT = (640, 360)
BAR = 58
TITLE = 110
FOOT = 190
FONT = "C:/Windows/Fonts/calibrib.ttf"
FONT_L = "C:/Windows/Fonts/calibri.ttf"
WHITE = (255, 255, 255)

ROW_LABEL = {
    "a": "A   TODAY: the game as it is now",
    "b": "B   ONE LOOK (mock): cars and trees built from smaller blocks, finer speckle on the ground, distant buildings softened by haze. No flame body in this mock.",
    "c": "C   SMOOTH CROC: the croc as a smooth model, everything else as today",
}
ROW_COLOUR = {"a": (60, 60, 64), "b": (36, 84, 62), "c": (92, 60, 40)}
UNCHANGED = {
    "b": "Buildings and the croc unchanged",
    "c": "Cars, trees, ground and haze unchanged",
}
TIME_LABEL = {"dusk": "Dusk", "noon": "Noon"}
FRAME_LABEL = {
    "f1": "F1   5 seconds into the rampage, croc in the open street. Game camera.",
    "f2": "F2   12 seconds in: a tower topples and a fire burns. Game camera.",
    "f3": "F3   Standing, 4 seconds after the rise, close camera (intro and load-screen distance).",
}
SHOT = {"f1": ("f1", 5), "f2": ("f2", 12), "f3": ("f3", 4)}

# (caption, source shot, centre x, centre y, window width) in 4K pixels; the window is 16:9.
# "props": where A and B differ. "croc": where A and C differ.
CROPS = {
    "f1": {
        "props": [
            ("tree and car", "f1", 830, 1700, 480),
            ("road speckle and a car", "f1", 620, 1590, 480),
        ],
        "croc": [
            ("croc head and neck", "f1", 1560, 830, 640),
            ("croc skin and legs", "f1", 1830, 1040, 480),
        ],
    },
    "f2": {
        "props": [
            ("the fire", "f2", 1342, 1180, 480),
            ("cars and trees", "f2", 2800, 1680, 480),
        ],
        "croc": [
            ("croc and claw swipe", "f2", 1900, 900, 640),
            ("croc head", "f2", 2064, 924, 480),
        ],
    },
    "f3": {
        "props": [
            ("tree and car", "f3", 2520, 1030, 640),
            ("car", "f3", 456, 1416, 480),
        ],
        "croc": [
            ("croc face, front view: closer than play shows it", "f3b", 2207, 640, 560),
            ("croc skin, front view: closer than play shows it", "f3b", 2040, 1008, 480),
        ],
    },
}
NOTES = {
    "f1": "Same city, same route, same moment in all rows. The first stomps have already broken some buildings.",
    "f2": "The fire is lit by the capture at the same spot and second in every row: the game's own fires are small and hide in dust. The smooth model's head and jaw move a little differently from the cube croc at the same moment.",
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


def note_panel(img, d, ox, oy, text):
    d.rectangle((ox, oy, ox + CROP_OUT[0] - 1, oy + CROP_OUT[1] * 2 - 1), fill=(30, 30, 34))
    f = font(40)
    words, line, y = text.split(), "", oy + 250
    for word in words:
        trial = (line + " " + word).strip()
        if d.textlength(trial, font=f) > CROP_OUT[0] - 60:
            d.text((ox + 30, y), line, font=f, fill=WHITE)
            y, line = y + 52, word
        else:
            line = trial
    d.text((ox + 30, y), line, font=f, fill=WHITE)


def board(raw, frame, time, rows):
    h = TITLE + len(rows) * (BAR + MAIN[1]) + FOOT
    img = Image.new("RGB", (W, h), (18, 18, 20))
    d = ImageDraw.Draw(img)
    d.text((24, 10), f"{FRAME_LABEL[frame]}   {TIME_LABEL[time]}", font=font(44), fill=WHITE)
    d.text((24, 66), "A reptilian croc in its city at the Behemoth stage, 4K, HUD on.", font=font(28, False), fill=WHITE)
    y = TITLE
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
            for col, kind in enumerate(("props", "croc")):
                ox = MAIN[0] + col * CROP_OUT[0]
                shown = look == "a" or (look == "b" and kind == "props") or (look == "c" and kind == "croc")
                if not shown:
                    note_panel(img, d, ox, y, UNCHANGED[look])
                    continue
                for row, (cap, shot, cx, cy, cw) in enumerate(CROPS[frame][kind]):
                    src = load(raw, look, time, shot)
                    if src is None:
                        continue
                    oy = y + row * CROP_OUT[1]
                    img.paste(crop(src, cx, cy, cw), (ox, oy))
                    caption(d, (ox + 8, oy + 8), cap)
        y += MAIN[1]
    d.text((24, y + 6), "Buildings break into blocks in all three", font=font(64), fill=(255, 224, 120))
    d.text((24, y + 86), NOT_SHOWN, font=font(30, False), fill=WHITE)
    d.text((24, y + 134), NOTES[frame], font=font(26, False), fill=WHITE)
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
