"""Counts lit-window FLASHES in a clip's frames (the director, 2026-10-27: "theres still
flashing/stuttering lit windows").

A flash: a pixel group at a lit window whose brightness jumps more than --jump (30%) for 1 to 3
frames and comes back. Frames are full<NNN>.png from capture_window_bars.gd --full (or any sorted
frame folder). With a moving camera each neighbour frame is warped onto frame t by dense optical
flow (OpenCV DIS) first, so a window sliding across the screen is not a flash; pixels whose flow
fails a forward-backward check (occlusion edges) are left out. --still skips the flow (camera held
still: any flash is something toggling in the game, not the camera).

For each frame t and duration d in 1..3: before = frame t-1, after = frame t+d (both warped onto t).
A pixel flashes when before and after agree (within --jump), every frame t..t+d-1 differs from
their mean by more than --jump (relative) and --floor (absolute, 0..255 luma) in the same
direction and clears the 3x3 neighbourhood of both (so a sub-pixel slip of the warp at an edge is
not a flash), and the pixel is lit (luma >= --lit) before and after (a window going dark) or in the
flashing frames (a window lighting up). Groups of at least --min-area such pixels (8-connected) are
counted once.

Prints "window_flash: N flashes in F frames (X per second) ..." and, with --crops, saves the
--worst biggest flashes as 2x crops (frame number in the name and on the crop's label).

  python tools/capture/window_flash_count.py <frames dir> [--still] [--rect x,y,w,h]
      [--crops out_dir] [--worst 20] [--json out.json]
"""

import argparse
import glob
import json
import os
import sys

import cv2
import numpy as np
from PIL import Image, ImageDraw

MAX_DUR = 3


def luma(path: str) -> np.ndarray:
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    return rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114


def frames_in(folder: str) -> list[str]:
    paths = sorted(glob.glob(os.path.join(folder, "full[0-9][0-9][0-9].png")))
    if not paths:
        paths = sorted(glob.glob(os.path.join(folder, "*.png")))
    return paths


class Warper:
    """Warps frame t+k onto frame t by DIS optical flow between consecutive frames, chained (a
    window grid repeats every few pixels: a direct flow over several frames can lock onto the
    next window), with a forward-backward check at every step."""

    def __init__(self, frames: list[np.ndarray], still: bool, fb_px: float) -> None:
        self.frames = frames
        self.still = still
        self.fb_px = fb_px
        self.u8 = [np.clip(f, 0, 255).astype(np.uint8) for f in frames]
        self.dis = cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM)
        h, w = frames[0].shape
        self.gx, self.gy = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
        self.steps: dict[tuple[int, int], tuple[np.ndarray, np.ndarray]] = {}
        self.cache: dict[tuple[int, int], tuple[np.ndarray, np.ndarray]] = {}

    def _remap(self, img: np.ndarray, mx: np.ndarray, my: np.ndarray) -> np.ndarray:
        return cv2.remap(img, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)

    def _step(self, i: int, j: int) -> tuple[np.ndarray, np.ndarray]:
        """(flow from frame i to j = i +- 1 on frame i's pixels, its forward-backward error)."""
        key = (i, j)
        if key not in self.steps:
            fw = self.dis.calc(self.u8[i], self.u8[j], None)
            bw = self.dis.calc(self.u8[j], self.u8[i], None)
            back = self._remap(bw, self.gx + fw[..., 0], self.gy + fw[..., 1])
            err = np.hypot(fw[..., 0] + back[..., 0], fw[..., 1] + back[..., 1])
            self.steps[key] = (fw, err)
        return self.steps[key]

    def get(self, t: int, k: int) -> tuple[np.ndarray, np.ndarray]:
        """(frame t+k as seen from t, valid mask)."""
        if self.still or k == 0:
            return self.frames[t + k], np.ones(self.frames[t].shape, bool)
        key = (t, k)
        if key not in self.cache:
            mx, my = self.gx.copy(), self.gy.copy()
            ok = np.ones(self.frames[t].shape, bool)
            sign = 1 if k > 0 else -1
            for s in range(abs(k)):
                i = t + s * sign
                flow, err = self._step(i, i + sign)
                if s > 0:
                    flow = self._remap(flow, mx, my)
                    err = self._remap(err, mx, my)
                ok &= err <= self.fb_px
                mx = mx + flow[..., 0]
                my = my + flow[..., 1]
            h, w = ok.shape
            ok &= (mx >= 0) & (mx <= w - 1) & (my >= 0) & (my <= h - 1)
            self.cache[key] = (self._remap(self.frames[t + k], mx, my), ok)
        return self.cache[key]

    def drop_before(self, t: int) -> None:
        for key in [k for k in self.cache if k[0] < t]:
            del self.cache[key]
        for key in [k for k in self.steps if min(k) < t - 1]:
            del self.steps[key]


def flashes_at(warp: Warper, t: int, d: int, args: argparse.Namespace) -> list[dict]:
    before, ok_b = warp.get(t, -1)
    after, ok_a = warp.get(t, d)
    hi = np.maximum(before, after)
    agree = np.abs(before - after) <= args.jump * np.maximum(hi, 1.0)
    base = (before + after) * 0.5
    # A flash must clear the neighbour frames' whole 3x3 neighbourhood: a sub-pixel slip of the
    # warp at an edge is not a flash.
    kernel = np.ones((3, 3), np.uint8)
    hi3 = np.maximum(cv2.dilate(before, kernel), cv2.dilate(after, kernel))
    lo3 = np.minimum(cv2.erode(before, kernel), cv2.erode(after, kernel))
    valid = ok_b & ok_a & agree
    up = valid & (base >= 0.0)
    down = valid & (lo3 >= args.lit)
    for j in range(d):
        m, ok_m = warp.get(t, j)
        up &= ok_m & (m > hi3 * (1.0 + args.jump)) & (m - hi3 > args.floor) & (m >= args.lit)
        down &= ok_m & (m < lo3 * (1.0 - args.jump)) & (lo3 - m > args.floor)
    mask = up | down
    if args.rect:
        x, y, w, h = args.rect
        keep = np.zeros_like(mask)
        keep[y : y + h, x : x + w] = True
        mask &= keep
    count, labels, stats, _ = cv2.connectedComponentsWithStats(mask.astype(np.uint8), connectivity=8)
    out = []
    for i in range(1, count):
        x, y, w, h, area = (int(v) for v in stats[i])
        if area < args.min_area:
            continue
        sel = labels[y : y + h, x : x + w] == i
        m0, _ = warp.get(t, 0)
        jump = float(np.abs(m0[y : y + h, x : x + w] - base[y : y + h, x : x + w])[sel].mean())
        out.append(
            {
                "frame": t,
                "dur": d,
                "dir": "up" if up[y + h // 2, x + w // 2] or up[y : y + h, x : x + w][sel].any() else "down",
                "x": x,
                "y": y,
                "w": w,
                "h": h,
                "area": area,
                "jump": round(jump, 1),
            }
        )
    return out


def save_crops(paths: list[str], worst: list[dict], out_dir: str, first: int) -> None:
    os.makedirs(out_dir, exist_ok=True)
    for rank, f in enumerate(worst):
        img = Image.open(paths[f["frame"]]).convert("RGB")
        cx, cy = f["x"] + f["w"] // 2, f["y"] + f["h"] // 2
        half = 24
        box = (cx - half, cy - half, cx + half, cy + half)
        tiles = []
        for k in (-1, 0, 1):
            t = min(max(f["frame"] + k, 0), len(paths) - 1)
            tile = Image.open(paths[t]).convert("RGB").crop(box).resize((half * 4, half * 4), Image.NEAREST)
            tiles.append((t, tile))
        sheet = Image.new("RGB", (half * 4 * 3 + 8, half * 4 + 16), (0, 0, 0))
        draw = ImageDraw.Draw(sheet)
        for i, (t, tile) in enumerate(tiles):
            sheet.paste(tile, (i * (half * 4 + 4), 16))
            draw.text((i * (half * 4 + 4) + 2, 2), "f%03d" % (t + first), fill=(255, 255, 0))
        name = "%02d_f%03d_%s%d_a%d.png" % (rank + 1, f["frame"] + first, f["dir"], f["dur"], f["area"])
        sheet.save(os.path.join(out_dir, name))
        del img


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("folder")
    ap.add_argument("--still", action="store_true", help="no flow: the camera is held still")
    ap.add_argument("--fps", type=float, default=60.0)
    ap.add_argument("--jump", type=float, default=0.3, help="relative brightness jump (0.3 = 30%%)")
    ap.add_argument("--floor", type=float, default=24.0, help="least absolute jump, 0..255 luma")
    ap.add_argument("--lit", type=float, default=160.0, help="lit-window luma, 0..255")
    ap.add_argument("--min-area", type=int, default=3)
    ap.add_argument("--fb-px", type=float, default=0.75, help="forward-backward flow error allowed")
    ap.add_argument("--rect", default="", help="x,y,w,h: count only inside")
    ap.add_argument("--first", type=int, default=0, help="frame number of the first file")
    ap.add_argument("--limit", type=int, default=0, help="only the first N frames")
    ap.add_argument("--crops", default="")
    ap.add_argument("--worst", type=int, default=20)
    ap.add_argument("--json", default="")
    args = ap.parse_args()
    args.rect = tuple(int(v) for v in args.rect.split(",")) if args.rect else ()
    paths = frames_in(args.folder)
    if args.limit:
        paths = paths[: args.limit]
    if len(paths) < MAX_DUR + 2:
        print("window_flash: need at least %d frames in %s" % (MAX_DUR + 2, args.folder))
        return 2
    frames = [luma(p) for p in paths]
    warp = Warper(frames, args.still, args.fb_px)
    found: list[dict] = []
    per_frame = [0] * len(frames)
    for t in range(1, len(frames) - 1):
        for d in range(1, MAX_DUR + 1):
            if t + d >= len(frames):
                break
            hits = flashes_at(warp, t, d, args)
            found += hits
            per_frame[t] += len(hits)
        warp.drop_before(t)
    seconds = (len(frames) - 2) / args.fps
    ups = sum(1 for f in found if f["dir"] == "up")
    print(
        "window_flash: %d flashes in %d frames (%.2f per second; %d up, %d down; frames with any %d)%s"
        % (
            len(found),
            len(frames),
            len(found) / seconds,
            ups,
            len(found) - ups,
            sum(1 for c in per_frame if c),
            " [still]" if args.still else "",
        )
    )
    worst = sorted(found, key=lambda f: f["area"] * f["jump"], reverse=True)[: args.worst]
    for f in worst[:5]:
        print("  worst f%03d %s%d at (%d,%d) %dx%d area %d jump %.0f" % (
            f["frame"] + args.first, f["dir"], f["dur"], f["x"], f["y"], f["w"], f["h"], f["area"], f["jump"]))
    if args.crops:
        save_crops(paths, worst, args.crops, args.first)
    if args.json:
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump({"flashes": len(found), "frames": len(frames), "per_second": len(found) / seconds,
                       "per_frame": per_frame, "list": found}, fh)
    return 0


if __name__ == "__main__":
    sys.exit(main())
