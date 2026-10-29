"""Builds Kaiju Incremental's display fonts from the block skeleton in glyphs.py.

    python tools/fonts/build_fonts.py            # writes assets/fonts/*.ttf
    python tools/fonts/build_fonts.py --preview DIR   # also a PIL proof sheet per font

Three styles share one skeleton so the director compares a finish, not three alphabets:
  A  Rubble: solid voxel blocks with chipped corners and the odd crack, like broken concrete.
  B  Claw:   tall condensed blocks raked by three tapering claw gashes, a monster-poster title.
  C  Fault:  each letter snapped along a jagged crack, the top half lifted off its base.
  D  Block:  the bare skeleton, solid and undamaged: the body-text face for small sizes, where
             chips, gashes and cracks turn to noise.

Deterministic: every chip, gash and crack comes from a hash of the glyph and cell, never a
clock or global RNG, so a rebuild gives the same bytes. Needs fontTools (MIT) and
skia-pathops (BSD-3), development tools only; nothing of theirs ships in the font.
"""

import argparse
import hashlib
import math
import os
import sys

import pathops
from fontTools.feaLib.builder import addOpenTypeFeaturesFromString
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

sys.path.insert(0, os.path.dirname(__file__))
from glyphs import ABOVE, GLYPHS  # noqa: E402

UPM = 1000
CELL = 70  # cap height = 10 cells = 700 units
SIDE = 40  # side bearing each side; two of these is the normal gap between letters
SPACE = 260
ROWS = 10
HEAVY = round(CELL * 0.28)  # A and C: every cell grows this much each way (heavier strokes)
BOLD = 0  # set per style by build()
# head.created / head.modified, pinned so a rebuild gives the same bytes (fontTools stamps "now"
# by default); the value the first fonts were built with (2026-10-16).
STAMP = 3874984571


def rnd(*key: object) -> float:
    """A stable 0..1 number for this key."""
    h = hashlib.sha1(repr(key).encode()).digest()
    return int.from_bytes(h[:4], "little") / 0xFFFFFFFF


def rect(x0: float, y0: float, x1: float, y1: float) -> pathops.Path:
    p = pathops.Path()
    p.moveTo(x0, y0)
    p.lineTo(x1, y0)
    p.lineTo(x1, y1)
    p.lineTo(x0, y1)
    p.close()
    return p


def poly(points: list[tuple[float, float]]) -> pathops.Path:
    p = pathops.Path()
    p.moveTo(*points[0])
    for pt in points[1:]:
        p.lineTo(*pt)
    p.close()
    return p


def union(paths: list[pathops.Path]) -> pathops.Path:
    out = pathops.Path()
    for p in paths:
        out = pathops.op(out, p, pathops.PathOp.UNION)
    return out


def sub(a: pathops.Path, b: pathops.Path) -> pathops.Path:
    return pathops.op(a, b, pathops.PathOp.DIFFERENCE)


def inter(a: pathops.Path, b: pathops.Path) -> pathops.Path:
    return pathops.op(a, b, pathops.PathOp.INTERSECTION)


def translate(p: pathops.Path, dx: float, dy: float) -> pathops.Path:
    out = pathops.Path()
    for verb, pts in p:
        moved = [(x + dx, y + dy) for x, y in pts]
        if verb == pathops.PathVerb.MOVE:
            out.moveTo(*moved[0])
        elif verb == pathops.PathVerb.LINE:
            out.lineTo(*moved[0])
        elif verb == pathops.PathVerb.CLOSE:
            out.close()
    return out


class Skeleton:
    """One glyph's cell grid with helpers to find its cells and outer corners."""

    def __init__(self, ch: str, rows: list[str], top: int = 0):
        widths = {len(r) for r in rows}
        assert len(widths) == 1, f"{ch!r}: ragged rows {widths}"
        self.ch = ch
        self.rows = rows
        self.top = top  # rows above the cap height (accents): they get negative row numbers
        self.w = widths.pop()

    def row_range(self) -> range:
        return range(-self.top, len(self.rows) - self.top)

    def filled(self, r: int, c: int) -> bool:
        rr = r + self.top
        return 0 <= rr < len(self.rows) and 0 <= c < self.w and self.rows[rr][c] == "#"

    def cells(self) -> list[tuple[int, int]]:
        return [(r, c) for r in self.row_range() for c in range(self.w) if self.filled(r, c)]

    def corners(self) -> list[tuple[int, int, int, int]]:
        """Convex outer corners as (r, c, dx, dy): dx/dy = +1 right/up from the cell centre."""
        out = []
        for r, c in self.cells():
            for dx in (-1, 1):
                for dy in (-1, 1):
                    side = self.filled(r, c + dx)
                    vert = self.filled(r - dy, c)
                    diag = self.filled(r - dy, c + dx)
                    if not side and not vert and not diag:
                        out.append((r, c, dx, dy))
        return out


def cell_box(r: int, c: int, sx: float, sy: float) -> tuple[float, float, float, float]:
    """Cell (r, c) in font units, grown by BOLD; sx/sy scale the cell (B is condensed and tall).
    The grid starts at x = BOLD so ink begins at 0; it sits on the baseline (y >= 0)."""
    x0 = c * CELL * sx
    y0 = (ROWS - 1 - r) * CELL * sy + BOLD
    return x0, y0 - BOLD, x0 + CELL * sx + 2 * BOLD, y0 + CELL * sy + BOLD


def solid(sk: Skeleton, sx: float = 1.0, sy: float = 1.0) -> pathops.Path:
    return union([rect(*cell_box(r, c, sx, sy)) for r, c in sk.cells()])


def corner_point(r: int, c: int, dx: int, dy: int, sx: float, sy: float) -> tuple[float, float]:
    x0, y0, x1, y1 = cell_box(r, c, sx, sy)
    return (x1 if dx > 0 else x0, y1 if dy > 0 else y0)


def transform(p: pathops.Path, fn) -> pathops.Path:
    out = pathops.Path()
    for verb, pts in p:
        moved = [fn(x, y) for x, y in pts]
        if verb == pathops.PathVerb.MOVE:
            out.moveTo(*moved[0])
        elif verb == pathops.PathVerb.LINE:
            out.lineTo(*moved[0])
        elif verb == pathops.PathVerb.CLOSE:
            out.close()
    return out


def bites(sk: Skeleton, sx: float, sy: float, tag: str, square: float, chip: float) -> list:
    """Damage at the outer corners: square bites (a voxel knocked out) and diagonal chips."""
    cuts = []
    for r, c, dx, dy in sk.corners():
        roll = rnd(tag, sk.ch, r, c, dx, dy)
        cx, cy = corner_point(r, c, dx, dy, sx, sy)
        a = CELL * sx * (0.42 + 0.3 * rnd(tag + "a", sk.ch, r, c, dx, dy))
        b = CELL * sy * (0.42 + 0.3 * rnd(tag + "b", sk.ch, r, c, dx, dy))
        if roll < square:
            cuts.append(rect(min(cx, cx - dx * a), min(cy, cy - dy * b),
                             max(cx, cx - dx * a), max(cy, cy - dy * b)))
        elif roll < square + chip:
            cuts.append(poly([(cx + dx, cy + dy), (cx - dx * a * 1.3, cy + dy),
                              (cx + dx, cy - dy * b * 1.3)]))
    return cuts


def crack(sk: Skeleton, sx: float, sy: float, tag: str) -> list:
    """At most one crack: a narrow wedge into a long top or bottom edge, leaning a little."""
    edges = []
    for r, c in sk.cells():
        for dy in (1, -1):
            if sk.filled(r - dy, c) or not sk.filled(r, c - 1) or not sk.filled(r, c + 1):
                continue
            edges.append((r, c, dy))
    if not edges or rnd(tag + "?", sk.ch) > 0.7:
        return []
    r, c, dy = edges[int(rnd(tag, sk.ch) * len(edges)) % len(edges)]
    x0, y0, x1, y1 = cell_box(r, c, sx, sy)
    edge_y = y1 if dy > 0 else y0
    mid = x0 + (x1 - x0) * (0.3 + 0.4 * rnd(tag + "x", sk.ch))
    half = CELL * 0.2
    tip = mid + CELL * (rnd(tag + "t", sk.ch) - 0.5) * 0.7
    return [poly([(mid - half, edge_y + dy * 2), (mid + half, edge_y + dy * 2),
                  (tip, edge_y - dy * CELL * 1.25)])]


def style_rubble(sk: Skeleton) -> pathops.Path:
    """A: heavy blocks with voxels knocked off the corners, a few chips and the odd crack."""
    cuts = bites(sk, 1, 1, "rub", 0.32, 0.22) + crack(sk, 1, 1, "rcrack")
    shape = solid(sk)
    return sub(shape, union(cuts)) if cuts else shape


B_SX, B_SY = 0.84, 1.18  # condensed and tall


def style_claw(sk: Skeleton) -> pathops.Path:
    """B: tall condensed blocks raked by three thin tapering claw gashes through the upper body.
    Director's pick, 2026-10-16: keep these numbers as they are."""
    shape = solid(sk, B_SX, B_SY)
    width = sk.w * CELL * B_SX
    top = ROWS * CELL * B_SY
    if sk.w < 4 or sk.ch in "-_=#*":  # gashes turn these small symbols to mush
        return shape
    if sk.ch.isdigit():  # numerals stay solid: a gash through a 0 read as a bar on the TV
        return shape
    slant = 0.42  # x travel per unit of y: a raking swipe, not a vertical cut
    length = top * (0.55 + 0.12 * rnd("clen", sk.ch))
    y_top = top * (0.98 - 0.1 * rnd("ctop", sk.ch))
    gap = CELL * 0.95
    centre = width * (0.42 + 0.22 * rnd("cx", sk.ch))
    cuts = []
    for i in (-1, 0, 1):
        x_top = centre + i * gap + slant * length * 0.5
        y_bot = y_top - length * (0.9 if i else 1.0)
        x_bot = x_top - slant * (y_top - y_bot)
        half = CELL * 0.2
        # The widest point sits a third of the way down, as a claw bites in then drags out.
        mx = x_top + (x_bot - x_top) * 0.35
        my = y_top + (y_bot - y_top) * 0.35
        nx, ny = 1 / math.hypot(1, slant), slant / math.hypot(1, slant)
        cuts.append(poly([(x_top, y_top), (mx + nx * half, my - ny * half), (x_bot, y_bot),
                          (mx - nx * half, my + ny * half)]))
    return sub(shape, union(cuts))


def style_fault(sk: Skeleton) -> pathops.Path:
    """C: each letter snapped along a jagged fault, the top slab lifted and tipped over."""
    shape = solid(sk)
    width = sk.w * CELL + 2 * BOLD
    if sk.w < 3 or len(sk.cells()) < 10:
        return shape
    base = CELL * (4.6 + 1.0 * rnd("fy", sk.ch))
    fall = CELL * (0.8 + 0.8 * rnd("ff", sk.ch)) * (1 if rnd("fd", sk.ch) < 0.5 else -1)
    teeth = max(3, sk.w // 2 + 2)
    line = []
    for i in range(teeth + 1):
        t = i / teeth
        jag = (rnd("fj", sk.ch, i) - 0.5) * CELL * 1.1
        line.append((-CELL + t * (width + 2 * CELL), base + fall * (0.5 - t) + jag))
    gap = CELL * 0.2
    below = poly([(-CELL, -3 * CELL)] + [(x, y - gap) for x, y in line] +
                 [(width + CELL, -3 * CELL)])
    above = poly([(-CELL, 14 * CELL)] + [(x, y + gap) for x, y in line] +
                 [(width + CELL, 14 * CELL)])
    lower = inter(shape, below)
    # The top slab slides off along the fault and tips toward the low side.
    tilt = math.radians(4.0) * (1 if fall > 0 else -1)
    px, py = (width if fall > 0 else 0), base
    cos, sin = math.cos(tilt), math.sin(tilt)

    def tip(x: float, y: float) -> tuple[float, float]:
        rx, ry = x - px, y - py
        return (px + rx * cos - ry * sin + CELL * 0.3 * (1 if fall < 0 else -1) * 0.5,
                py + rx * sin + ry * cos + CELL * 0.18)

    upper = transform(inter(shape, above), tip)
    return union([lower, upper])


D_SX = 0.85  # a little condensed: the tree's longest node names fit at the TV's 125% UI scale


def style_block(sk: Skeleton) -> pathops.Path:
    """D: the skeleton's cells, solid, nothing knocked off: reads at body-text sizes."""
    return solid(sk, D_SX)


STYLES = {
    "A": ("Kaiju Rubble", "kaiju_rubble", style_rubble, 1.0, HEAVY),
    "B": ("Kaiju Claw", "kaiju_claw", style_claw, B_SX, 0),
    "C": ("Kaiju Fault", "kaiju_fault", style_fault, 1.0, HEAVY),
    "D": ("Kaiju Block", "kaiju_block", style_block, D_SX, 0),
}


def glyph_name(ch: str) -> str:
    if ch.isascii() and ch.isalnum():
        return ch if ch.isalpha() else "digit" + ch
    return "u%04X" % ord(ch) if ch.isascii() else "uni%04X" % ord(ch)


def to_ttglyph(path: pathops.Path, dx: float):
    clean = pathops.simplify(translate(path, dx, 0), clockwise=True)
    contours, cur = [], []
    for verb, pts in clean:
        p = [(round(x), round(y)) for x, y in pts]
        if verb == pathops.PathVerb.MOVE:
            cur = [p[0]]
        elif verb == pathops.PathVerb.LINE:
            cur.append(p[0])
        elif verb == pathops.PathVerb.CLOSE:
            contours.append(cur)
        else:
            raise ValueError(f"unexpected verb {verb}")
    pen = TTGlyphPen(None)
    for pts in contours:
        if contour_area(pts) < SLIVER:  # sub-pixel shards and pinholes left by the cuts
            continue
        pen.moveTo(pts[0])
        for pt in pts[1:]:
            pen.lineTo(pt)
        pen.closePath()
    return pen.glyph()


SLIVER = 300  # units^2: about 0.1 px across at the 104 px title, invisible at any game size


def contour_area(pts: list[tuple[int, int]]) -> float:
    n = len(pts)
    return 0.5 * abs(sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1]
                         for i in range(n)))


def profiles(sk: Skeleton, sx: float) -> dict[int, tuple[float, float]]:
    """Per row: (left ink x, right ink x) in units, before the side bearing."""
    out = {}
    for r in sk.row_range():
        cols = [c for c in range(sk.w) if sk.filled(r, c)]
        if cols:
            out[r] = (cols[0] * CELL * sx, (cols[-1] + 1) * CELL * sx + 2 * BOLD)
    return out


def kerning(skels: dict[str, Skeleton], sx: float, adv: dict[str, int]) -> list[tuple[str, str, int]]:
    """Tighten pairs whose facing profiles leave a hole (LT, AV, T., ...); never loosen."""
    prof = {ch: profiles(sk, sx) for ch, sk in skels.items()}
    normal = 2 * SIDE
    pairs = []
    for a, pa in prof.items():
        for b, pb in prof.items():
            gaps = []
            for r, (_, right) in pa.items():
                for rr in (r - 1, r, r + 1):
                    if rr in pb:
                        gaps.append(adv[a] - SIDE - right + SIDE + pb[rr][0])
            if not gaps:
                continue
            extra = min(gaps) - normal
            k = -round(min(extra * 0.75, CELL * 1.6) / 5) * 5
            if k <= -20:
                pairs.append((a, b, k))
    return pairs


def build(key: str, out_dir: str) -> str:
    global BOLD
    family, stem, fn, sx, BOLD = STYLES[key]
    skels = {ch: Skeleton(ch, rows, ABOVE.get(ch, 0)) for ch, rows in GLYPHS.items()}
    order = [".notdef", "space"] + [glyph_name(ch) for ch in skels]
    glyphs = {}
    metrics = {}
    adv = {}
    for ch, sk in skels.items():
        g = glyph_name(ch)
        adv[ch] = round(sk.w * CELL * sx + 2 * BOLD + 2 * SIDE)
        glyphs[g] = to_ttglyph(fn(sk), SIDE)
    pen = TTGlyphPen(None)
    for x0, y0, x1, y1 in ((60, 0, 440, 700), (120, 60, 380, 640)):
        pts = [(x0, y0), (x0, y1), (x1, y1), (x1, y0)] if x0 == 60 else \
            [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
        pen.moveTo(pts[0])
        for p in pts[1:]:
            pen.lineTo(p)
        pen.closePath()
    glyphs[".notdef"] = pen.glyph()
    glyphs["space"] = TTGlyphPen(None).glyph()

    fb = FontBuilder(UPM, isTTF=True)
    fb.setupGlyphOrder(order)
    cmap = {32: "space", 0xA0: "space"}
    for ch in skels:
        cmap[ord(ch)] = glyph_name(ch)
        if ch.isalpha():
            cmap[ord(ch.lower())] = glyph_name(ch)  # one case: lower case shows the capitals
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(glyphs)
    for g in order:
        ch = next((c for c in skels if glyph_name(c) == g), None)
        width = adv[ch] if ch else (SPACE if g == "space" else 500)
        glyph = glyphs[g]
        glyph.recalcBounds(fb.font["glyf"])
        metrics[g] = (width, getattr(glyph, "xMin", 0) if glyph.numberOfContours else 0)
    fb.setupHorizontalMetrics(metrics)
    asc, desc = 900, -240
    fb.setupHorizontalHeader(ascent=asc, descent=desc, lineGap=0)
    fb.setupNameTable({
        "familyName": family,
        "styleName": "Regular",
        "uniqueFontIdentifier": f"KaijuIncremental:{stem}:1.0",
        "fullName": f"{family} Regular",
        "psName": family.replace(" ", "") + "-Regular",
        "version": "Version 1.000",
        "copyright": "Copyright 2026 Kaiju Incremental. Original design, drawn in code.",
        "licenseDescription": "Proprietary: made for and owned by Kaiju Incremental.",
    })
    fb.setupOS2(sTypoAscender=asc, sTypoDescender=desc, sTypoLineGap=0, usWinAscent=asc,
                usWinDescent=-desc, sCapHeight=ROWS * CELL, sxHeight=ROWS * CELL,
                achVendID="KAIJ", fsType=0)
    fb.setupPost()
    pairs = kerning(skels, sx, adv)
    if pairs:
        lines = [f"    pos {glyph_name(a)} {glyph_name(b)} {k};" for a, b, k in pairs]
        fea = "languagesystem DFLT dflt;\nlanguagesystem latn dflt;\nfeature kern {\n" + \
            "\n".join(lines) + "\n} kern;\n"
        addOpenTypeFeaturesFromString(fb.font, fea)
    path = os.path.join(out_dir, stem + ".ttf")
    fb.font["head"].created = fb.font["head"].modified = STAMP
    fb.font.recalcTimestamp = False
    fb.save(path)
    print(f"{key} {family}: {len(skels)} glyphs, {len(pairs)} kern pairs -> {path}")
    return path


def preview(path: str, out_png: str) -> None:
    from PIL import Image, ImageDraw, ImageFont

    img = Image.new("RGB", (1800, 760), (18, 22, 28))
    d = ImageDraw.Draw(img)
    y = 20
    for size, text in ((110, "KAIJU INCREMENTAL"), (64, "ABCDEFGHIJKLM"), (64, "NOPQRSTUVWXYZ"),
                       (64, "0123456789 .,:;!?-+=%/()'\"<>#*&"), (36, "RUBBLE 1,250  CITY DESTROYED 34%  EVOLVE >"),
                       (24, "THE QUICK BROWN FOX: LAVA, TOWERS, WAVE AVATAR LT TA YA P. F, 7/11")):
        d.text((20, y), text, font=ImageFont.truetype(path, size), fill=(238, 241, 244))
        y += int(size * 1.35)
    img.save(out_png)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "..", "..", "assets", "fonts"))
    ap.add_argument("--preview", default="")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    for key in STYLES:
        path = build(key, args.out)
        if args.preview:
            os.makedirs(args.preview, exist_ok=True)
            preview(path, os.path.join(args.preview, f"proof_{key}.png"))


if __name__ == "__main__":
    main()
