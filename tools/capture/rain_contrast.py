"""Kaiju contrast in rain against clear, per time of day (capture_rain.gd --nokaiju stills).
  python tools/capture/rain_contrast.py <dir>
Same method as escalation_sheet.py: the kaiju's pixels are what differs when he is hidden (clear
frame, inside a box round him); his contrast is the mean luma difference over those pixels between
the frame and the same frame with him hidden. The rain frame's contrast over the clear frame's is
the ratio (bar: >= 0.9). Needs <time>_clear.png, <time>_clear_nokaiju.png, <time>_rain.png and
<time>_rain_nokaiju.png in <dir>."""

import os
import sys

import numpy as np
from PIL import Image

TIMES = ["night", "dusk", "morning", "noon"]


def luma(a):
    return a[..., 0] * 0.2126 + a[..., 1] * 0.7152 + a[..., 2] * 0.0722


def load(d, name):
    return np.asarray(Image.open(os.path.join(d, name + ".png")).convert("RGB"), dtype=np.float32) / 255.0


def main():
    d = sys.argv[1]
    for t in TIMES:
        if not os.path.exists(os.path.join(d, t + "_rain_nokaiju.png")):
            continue
        cw, cn = load(d, t + "_clear"), load(d, t + "_clear_nokaiju")
        rw, rn = load(d, t + "_rain"), load(d, t + "_rain_nokaiju")
        h, w = cw.shape[:2]
        box = np.zeros((h, w), bool)
        box[int(h * 0.30) : int(h * 0.92), int(w * 0.38) : int(w * 0.62)] = True
        mask = (np.abs(cw - cn).sum(axis=2) > 0.08) & box
        c_clear = float(np.abs(luma(cw) - luma(cn))[mask].mean())
        c_rain = float(np.abs(luma(rw) - luma(rn))[mask].mean())
        print(
            "%s kaiju_px %d clear %.4f rain %.4f ratio %.3f"
            % (t, mask.sum(), c_clear, c_rain, c_rain / c_clear)
        )


main()
