"""Bake one cached OpenStreetMap district into data/cities/<district>.json for the game.

Offline dev tool, standard library only. Reads tools/osm/cache/<district>.json (fetch_osm.py),
writes the district in sim units, ready for CityDistrict (sim/city_district.gd):

  - the map is rotated so the district's street grid runs along x and z, scaled by
    metres_per_unit (uniform, so towers keep their true proportions), and centred on the
    playable rect;
  - roads become a street graph (nodes + straight street edges with a width and a kind);
  - building footprints are rasterised onto the unit grid (one cell = one sim chunk column),
    each cell owned by one building, and every building split into a few axis-aligned
    rectangles (a Structure is a box of chunks; L-shapes become two boxes side by side);
  - heights come from height, then building:levels, then a rule by building type that grows
    toward the district centre;
  - water, parks, squares and rail yards become ground areas; rail lines become polylines.

Same input, same output: everything is sorted, nothing is random.
Map data (c) OpenStreetMap contributors, ODbL 1.0 (docs/LICENSING_REGISTER.md).

    python tools/osm/bake_district.py melbourne_cbd
"""

import json
import math
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
M_PER_DEG_LAT = 110_574.0
M_PER_DEG_LON_EQ = 111_320.0

# Road classes -> the game's street kinds, and a default full corridor width in metres
# (kerb to kerb plus footpaths) when OSM has no width tag.
ROADS = {
    "motorway": ("avenue", 30.0),
    "trunk": ("avenue", 30.0),
    "primary": ("avenue", 30.0),
    "secondary": ("avenue", 30.0),
    "tertiary": ("street", 20.0),
    "unclassified": ("street", 15.0),
    "residential": ("street", 15.0),
    "living_street": ("alley", 10.0),
    "service": ("alley", 8.0),
    "pedestrian": ("alley", 10.0),
}
LINKS = {"motorway_link", "trunk_link", "primary_link", "secondary_link", "tertiary_link"}
# Building tag -> (style, default levels). Styles are BuildingVoxels archetypes:
# 0 office, 1 brick residential, 2 glass tower, 3 stone classic.
BUILDING_TYPES = {
    "office": (0, 12),
    "commercial": (0, 8),
    "retail": (0, 3),
    "hotel": (2, 14),
    "apartments": (1, 14),
    "residential": (1, 6),
    "house": (1, 2),
    "terrace": (1, 2),
    "church": (3, 4),
    "cathedral": (3, 6),
    "civic": (3, 4),
    "public": (3, 4),
    "government": (3, 5),
    "university": (3, 6),
    "train_station": (3, 3),
    "transportation": (3, 2),
    "parking": (0, 6),
    "yes": (0, 6),
}
TOWER_UNITS = 15  # anything this tall (sim units) is drawn as a glass tower unless it is stone
LEVEL_M = 3.5
DECIMALS = 2


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    name = sys.argv[1]
    district = json.loads((HERE / "districts.json").read_text())[name]
    raw = json.loads((HERE / "cache" / f"{name}.json").read_text(encoding="utf-8"))
    baked = bake(district, raw["elements"])
    baked["district"] = name
    out = ROOT / "data" / "cities" / f"{name}.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(_dump(baked), encoding="utf-8", newline="\n")
    s = baked["stats"]
    print(
        f"{out.relative_to(ROOT)}: {s['buildings']} building boxes from {s['footprints']}"
        f" footprints ({s['outer']} outer), {s['chunks']} chunks, {len(baked['nodes'])} nodes,"
        f" {len(baked['streets'])} streets, {len(baked['areas'])} areas, play {baked['play']}"
    )
    return 0


class Frame:
    """lat/lon -> rotated, scaled sim units (x east-ish along the grid, z south-ish)."""

    def __init__(self, origin: list, mpu: float) -> None:
        self.lat0, self.lon0 = origin
        self.kx = M_PER_DEG_LON_EQ * math.cos(math.radians(self.lat0))
        self.mpu = mpu
        self.angle = 0.0
        self.shift = (0.0, 0.0)

    def metres(self, lat: float, lon: float) -> tuple:
        return ((lon - self.lon0) * self.kx, -(lat - self.lat0) * M_PER_DEG_LAT)

    def unit(self, lat: float, lon: float) -> tuple:
        x, z = self.metres(lat, lon)
        c, s = math.cos(-self.angle), math.sin(-self.angle)
        x, z = x * c - z * s, x * s + z * c
        return (x / self.mpu - self.shift[0], z / self.mpu - self.shift[1])


def bake(district: dict, elements: list) -> dict:
    frame = Frame(district["origin"], float(district["metres_per_unit"]))
    ways = [e for e in elements if e["type"] == "way" and "geometry" in e]
    rels = [e for e in elements if e["type"] == "relation"]
    roads = [w for w in ways if _road_kind(w.get("tags", {})) is not None]
    frame.angle = _grid_angle(frame, roads)
    play = _play_rect(frame, roads, district)
    frame.shift = ((play[0] + play[2]) * 0.5, (play[1] + play[3]) * 0.5)
    half = ((play[2] - play[0]) * 0.5, (play[3] - play[1]) * 0.5)
    play_rect = [-half[0], -half[1], half[0] * 2.0, half[1] * 2.0]
    bounds = _bounds(frame, district)
    if not _covers(frame, district, play_rect):
        raise SystemExit("the bbox does not cover the playable rect: widen bbox and re-fetch")
    nodes, streets = _street_graph(frame, roads, bounds)
    areas = _areas(frame, ways, rels, bounds)
    rails = _rails(frame, ways, bounds)
    buildings, outer, footprints = _buildings(frame, ways, rels, district, play_rect, bounds)
    start = _start(district, frame, play_rect)
    chunks = sum(b["w"] * b["d"] * b["h"] for b in buildings)
    return {
        "name": district["name"],
        "credit": "Map data © OpenStreetMap contributors, ODbL 1.0",
        "metres_per_unit": district["metres_per_unit"],
        "grid_deg": round(math.degrees(frame.angle), 3),
        "play": [round(v, DECIMALS) for v in play_rect],
        "bounds": [round(v, DECIMALS) for v in bounds],
        "start": [round(start[0], DECIMALS), round(start[1], DECIMALS)],
        "sidewalk": district["sidewalk_units"],
        "nodes": [[round(x, DECIMALS), round(z, DECIMALS)] for x, z in nodes],
        "streets": streets,
        "areas": areas,
        "rails": rails,
        "buildings": buildings,
        "outer": outer,
        "stats": {
            "buildings": len(buildings),
            "outer": len(outer),
            "footprints": footprints,
            "chunks": chunks,
        },
    }


def _road_kind(tags: dict):
    hw = tags.get("highway")
    if hw in LINKS:
        hw = hw.replace("_link", "")
    if hw not in ROADS or tags.get("area") == "yes" or "tunnel" in tags:
        return None
    if tags.get("service") in ("parking_aisle", "driveway", "drive-through"):
        return None
    return ROADS[hw]


def _grid_angle(frame: Frame, roads: list) -> float:
    """The street grid's bearing: length-weighted circular mean of 4 * segment angle."""
    sx = sy = 0.0
    for w in roads:
        if _road_kind(w["tags"])[0] == "alley":
            continue
        pts = [frame.metres(p["lat"], p["lon"]) for p in w["geometry"]]
        for a, b in zip(pts, pts[1:]):
            dx, dz = b[0] - a[0], b[1] - a[1]
            length = math.hypot(dx, dz)
            th = math.atan2(dz, dx) * 4.0
            sx += math.cos(th) * length
            sy += math.sin(th) * length
    return math.atan2(sy, sx) / 4.0


def _named_line(frame: Frame, roads: list, name: str, axis: int) -> float:
    """Median coordinate (0 = x, 1 = z) of the named street's points, in rotated units."""
    vals = sorted(
        frame.unit(p["lat"], p["lon"])[axis]
        for w in roads
        if w["tags"].get("name") == name
        for p in w["geometry"]
    )
    if not vals:
        raise SystemExit(f"street not found: {name}")
    return vals[len(vals) // 2]


def _play_rect(frame: Frame, roads: list, district: dict) -> tuple:
    """The playable rect (x0, z0, x1, z1) between the named edge streets' centre lines, plus
    a margin; the south edge can instead be the middle of the river (play_south_m)."""
    edges = district["play_streets"]
    m = district["play_margin_m"] / frame.mpu
    west = _named_line(frame, roads, edges["west"], 0)
    east = _named_line(frame, roads, edges["east"], 0)
    north = _named_line(frame, roads, edges["north"], 1)
    south = _named_line(frame, roads, edges["south"], 1)
    x0, x1 = sorted((west, east))
    z0, z1 = sorted((north, south))
    return (x0 - m, z0 - m, x1 + m, z1 + district["play_south_m"] / frame.mpu)


def _bounds(frame: Frame, district: dict) -> list:
    """The baked area: the rect round the rotated bbox (its corners hold no data)."""
    s, w, n, e = district["bbox"]
    pts = [frame.unit(lat, lon) for lat in (s, n) for lon in (w, e)]
    xs = [p[0] for p in pts]
    zs = [p[1] for p in pts]
    return [min(xs), min(zs), max(xs) - min(xs), max(zs) - min(zs)]


def _covers(frame: Frame, district: dict, rect: list) -> bool:
    """Whether the fetched bbox (a rotated rect in units) holds every corner of rect."""
    s, w, n, e = district["bbox"]
    quad = [frame.unit(s, w), frame.unit(s, e), frame.unit(n, e), frame.unit(n, w)]
    corners = [
        (rect[0] + dx * rect[2], rect[1] + dz * rect[3]) for dx in (0, 1) for dz in (0, 1)
    ]
    for c in corners:
        signs = set()
        for i in range(4):
            a, b = quad[i], quad[(i + 1) % 4]
            signs.add((b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]) > 0)
        if len(signs) > 1:
            return False
    return True


def _inside(p: tuple, rect: list, pad: float = 0.0) -> bool:
    return (
        rect[0] - pad <= p[0] <= rect[0] + rect[2] + pad
        and rect[1] - pad <= p[1] <= rect[1] + rect[3] + pad
    )


def _street_graph(frame: Frame, roads: list, bounds: list) -> tuple:
    """Junction-to-junction street edges. A way is split at every node another road shares,
    shape points are kept only where the road bends (Douglas-Peucker, 0.3 units)."""
    uses = {}
    for w in roads:
        for nid in w["nodes"]:
            uses[nid] = uses.get(nid, 0) + 1
    index = {}
    nodes = []
    streets = []
    seen = set()

    def node(p: tuple) -> int:
        key = (round(p[0] * 20), round(p[1] * 20))
        if key not in index:
            index[key] = len(nodes)
            nodes.append(p)
        return index[key]

    for w in sorted(roads, key=lambda w: w["id"]):
        kind, default_m = _road_kind(w["tags"])
        width_m = _metres(w["tags"].get("width"), default_m)
        lanes = w["tags"].get("lanes")
        if "width" not in w["tags"] and lanes and lanes.isdigit():
            width_m = max(width_m, int(lanes) * 3.5 + 6.0)
        pts = [frame.unit(p["lat"], p["lon"]) for p in w["geometry"]]
        ids = w["nodes"]
        start = 0
        for k in range(1, len(pts)):
            if k == len(pts) - 1 or uses.get(ids[k], 0) > 1:
                run = _simplify(pts[start : k + 1], 0.3)
                for a, b in zip(run, run[1:]):
                    if not (_inside(a, bounds, 2.0) or _inside(b, bounds, 2.0)):
                        continue
                    if math.dist(a, b) < 0.05:
                        continue
                    na, nb = node(a), node(b)
                    if na == nb or (min(na, nb), max(na, nb)) in seen:
                        continue
                    seen.add((min(na, nb), max(na, nb)))
                    streets.append(
                        {
                            "from": na,
                            "to": nb,
                            "width": round(width_m / frame.mpu, DECIMALS),
                            "kind": kind,
                            "name": w["tags"].get("name", ""),
                            "oneway": w["tags"].get("oneway") == "yes",
                        }
                    )
                start = k
    return nodes, streets


def _metres(value, default: float) -> float:
    try:
        return float(str(value).replace("m", "").strip())
    except ValueError:
        return default


def _simplify(pts: list, tol: float) -> list:
    if len(pts) < 3:
        return pts
    a, b = pts[0], pts[-1]
    far, at = 0.0, 0
    for i in range(1, len(pts) - 1):
        d = _seg_dist(pts[i], a, b)
        if d > far:
            far, at = d, i
    if far <= tol:
        return [a, b]
    return _simplify(pts[: at + 1], tol)[:-1] + _simplify(pts[at:], tol)


def _seg_dist(p: tuple, a: tuple, b: tuple) -> float:
    dx, dz = b[0] - a[0], b[1] - a[1]
    ll = dx * dx + dz * dz
    t = 0.0 if ll == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / ll))
    return math.dist(p, (a[0] + t * dx, a[1] + t * dz))


def _rings(frame: Frame, el: dict) -> list:
    """Outer rings of a way or multipolygon relation, in units (inner rings are dropped)."""
    if el["type"] == "way":
        return [[frame.unit(p["lat"], p["lon"]) for p in el["geometry"]]]
    parts = [
        [(p["lat"], p["lon"]) for p in m["geometry"]]
        for m in el.get("members", [])
        if m.get("role") == "outer" and m.get("geometry")
    ]
    return [[frame.unit(lat, lon) for lat, lon in ring] for ring in _join(parts)]


def _join(parts: list) -> list:
    """Joins open way pieces of a multipolygon into closed rings, end to end."""
    rings = []
    parts = [list(p) for p in parts]
    while parts:
        ring = parts.pop(0)
        grown = True
        while ring[0] != ring[-1] and grown:
            grown = False
            for i, p in enumerate(parts):
                if p[0] == ring[-1]:
                    ring += p[1:]
                elif p[-1] == ring[-1]:
                    ring += p[-2::-1]
                elif p[-1] == ring[0]:
                    ring = p[:-1] + ring
                elif p[0] == ring[0]:
                    ring = p[:0:-1] + ring
                else:
                    continue
                parts.pop(i)
                grown = True
                break
        if len(ring) >= 4:
            rings.append(ring)
    return rings


def _clip(poly: list, rect: list) -> list:
    """Sutherland-Hodgman clip of a polygon to an axis-aligned rect."""
    x0, z0, x1, z1 = rect[0], rect[1], rect[0] + rect[2], rect[1] + rect[3]
    edges = [
        (lambda p: p[0] >= x0, lambda a, b: _cut(a, b, 0, x0)),
        (lambda p: p[0] <= x1, lambda a, b: _cut(a, b, 0, x1)),
        (lambda p: p[1] >= z0, lambda a, b: _cut(a, b, 1, z0)),
        (lambda p: p[1] <= z1, lambda a, b: _cut(a, b, 1, z1)),
    ]
    out = poly[:-1] if poly and poly[0] == poly[-1] else poly
    for keep, cut in edges:
        src, out = out, []
        for i, cur in enumerate(src):
            prev = src[i - 1]
            if keep(cur):
                if not keep(prev):
                    out.append(cut(prev, cur))
                out.append(cur)
            elif keep(prev):
                out.append(cut(prev, cur))
        if not out:
            return []
    return out


def _cut(a: tuple, b: tuple, axis: int, v: float) -> tuple:
    t = (v - a[axis]) / (b[axis] - a[axis])
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def _area_use(tags: dict):
    if tags.get("natural") == "water" or tags.get("waterway") in ("riverbank", "river"):
        return "water"
    if tags.get("leisure") in ("park", "garden") or tags.get("landuse") in (
        "grass",
        "recreation_ground",
    ):
        return "park"
    if tags.get("landuse") == "railway":
        return "rail"
    if tags.get("place") == "square" or tags.get("area:highway") == "pedestrian":
        return "plaza"
    return None


def _areas(frame: Frame, ways: list, rels: list, bounds: list) -> list:
    out = []
    for el in sorted(ways + rels, key=lambda e: (e["type"], e["id"])):
        tags = el.get("tags", {})
        use = _area_use(tags)
        if use is None or "building" in tags:
            continue
        if el["type"] == "way" and tags.get("waterway") == "river":
            continue  # the river's centre line; its banks come as natural=water areas
        if el["type"] == "way" and el["nodes"][0] != el["nodes"][-1]:
            continue
        for ring in _rings(frame, el):
            poly = _clip(ring, bounds)
            if len(poly) >= 3 and abs(_area(poly)) > 1.0:
                out.append({"use": use, "poly": _flat(_simplify_ring(poly, 0.15))})
    return out


def _simplify_ring(poly: list, tol: float) -> list:
    if len(poly) < 8:
        return poly
    half = len(poly) // 2
    return _simplify(poly[: half + 1], tol)[:-1] + _simplify(poly[half:] + [poly[0]], tol)[:-1]


def _flat(poly: list) -> list:
    return [round(v, DECIMALS) for p in poly for v in p]


def _area(poly: list) -> float:
    return 0.5 * sum(
        poly[i - 1][0] * poly[i][1] - poly[i][0] * poly[i - 1][1] for i in range(len(poly))
    )


def _rails(frame: Frame, ways: list, bounds: list) -> list:
    out = []
    for w in sorted(ways, key=lambda w: w["id"]):
        tags = w.get("tags", {})
        if tags.get("railway") != "rail" or "tunnel" in tags or tags.get("service") == "spur":
            continue
        pts = [frame.unit(p["lat"], p["lon"]) for p in w["geometry"]]
        pts = [p for p in _simplify(pts, 0.3) if _inside(p, bounds)]
        if len(pts) >= 2:
            out.append(_flat(pts))
    return out


def _height_units(tags: dict, style_levels: int, from_centre: float, mpu: float) -> int:
    """height tag, else building:levels, else the type's levels scaled toward the centre."""
    h = tags.get("height")
    if h is not None:
        metres = _metres(h, -1.0)
        if metres > 0:
            return max(1, round(metres / mpu))
    levels = tags.get("building:levels")
    if levels is not None:
        n = _metres(levels, -1.0)
        if n > 0:
            return max(1, round((n * LEVEL_M + 2.0) / mpu))
    # No data: the type's usual levels, up to 1.6x in the core, 0.6x at the edge.
    scale = 1.6 - min(from_centre, 1.0)
    return max(1, round(style_levels * scale * LEVEL_M / mpu))


def _style(tags: dict, h: int) -> tuple:
    kind = tags.get("building", "yes")
    style, levels = BUILDING_TYPES.get(kind, BUILDING_TYPES["yes"])
    if tags.get("heritage") or tags.get("historic") or tags.get("building:architecture"):
        style = 3
    if h >= TOWER_UNITS and style != 3:
        style = 2
    return style, levels


def _cells(poly: list) -> set:
    """Unit cells (integer x, z of the cell's low corner) whose centre is inside poly."""
    xs = [p[0] for p in poly]
    zs = [p[1] for p in poly]
    out = set()
    for cz in range(math.floor(min(zs)), math.ceil(max(zs))):
        zc = cz + 0.5
        cross = []
        for i in range(len(poly)):
            a, b = poly[i - 1], poly[i]
            if (a[1] > zc) != (b[1] > zc):
                cross.append(a[0] + (zc - a[1]) * (b[0] - a[0]) / (b[1] - a[1]))
        cross.sort()
        for k in range(0, len(cross) - 1, 2):
            for cx in range(math.ceil(cross[k] - 0.5), math.floor(cross[k + 1] - 0.5) + 1):
                if cx < max(xs) + 1:
                    out.add((cx, cz))
    return out


def _rects(cells: set) -> list:
    """Greedy split of a cell set into axis-aligned rects (x, z, w, d), biggest rows first."""
    left = set(cells)
    out = []
    while left:
        z0 = min(c[1] for c in left)
        x0 = min(c[0] for c in left if c[1] == z0)
        w = 1
        while (x0 + w, z0) in left:
            w += 1
        d = 1
        while all((x, z0 + d) in left for x in range(x0, x0 + w)):
            d += 1
        for x in range(x0, x0 + w):
            for z in range(z0, z0 + d):
                left.discard((x, z))
        out.append((x0, z0, w, d))
    return out


def _buildings(frame, ways, rels, district, play, bounds) -> tuple:
    centre = frame.unit(*district["centre_for_heights"])
    reach = district["centre_reach_m"] / frame.mpu
    found = []
    for el in ways + rels:
        tags = el.get("tags", {})
        if "building" not in tags or tags.get("building") in ("no", "roof", "construction"):
            continue
        if tags.get("location") == "underground" or tags.get("layer", "0").startswith("-"):
            continue
        if el["type"] == "way" and el["nodes"][0] != el["nodes"][-1]:
            continue
        for ring in _rings(frame, el):
            poly = _clip(ring, bounds)
            if len(poly) < 3:
                continue
            cx = sum(p[0] for p in poly) / len(poly)
            cz = sum(p[1] for p in poly) / len(poly)
            from_centre = math.dist((cx, cz), centre) / reach
            _, levels = _style(tags, 0)
            h = _height_units(tags, levels, from_centre, frame.mpu)
            style, _ = _style(tags, h)
            found.append((h, el["type"], el["id"], poly, style, tags.get("name", "")))
    # Tallest first: where footprints overlap (a tower on a podium, duplicate outlines) the
    # cell belongs to the tallest building.
    found.sort(key=lambda f: (-f[0], f[1], f[2]))
    owner = {}
    boxes = []
    outer = []
    for h, _, osm_id, poly, style, name in found:
        cells = {c for c in _cells(poly) if c not in owner}
        if not cells:
            continue
        for c in cells:
            owner[c] = osm_id
        for x, z, w, d in sorted(_rects(cells)):
            entry = {
                "x": x + w * 0.5,
                "z": z + d * 0.5,
                "w": w,
                "d": d,
                "h": h,
                "style": style,
                "osm": osm_id,
            }
            if name:
                entry["name"] = name
            if _inside((entry["x"], entry["z"]), play):
                boxes.append(entry)
            else:
                outer.append(entry)
    key = lambda b: (b["z"], b["x"])
    return sorted(boxes, key=key), sorted(outer, key=key), len(found)


def _start(district: dict, frame: Frame, play: list) -> tuple:
    lat, lon = district["start"]
    p = frame.unit(lat, lon)
    return (
        min(max(p[0], play[0] + 1.0), play[0] + play[2] - 1.0),
        min(max(p[1], play[1] + 1.0), play[1] + play[3] - 1.0),
    )


def _dump(baked: dict) -> str:
    """One item per line: diffs of a re-bake stay readable and the file stays small."""
    lines = ["{"]
    keys = list(baked.keys())
    for i, k in enumerate(keys):
        v = baked[k]
        comma = "," if i < len(keys) - 1 else ""
        if isinstance(v, list) and v and isinstance(v[0], (dict, list)):
            lines.append(f'\t"{k}": [')
            for j, item in enumerate(v):
                sep = "," if j < len(v) - 1 else ""
                lines.append("\t\t" + json.dumps(item, ensure_ascii=False, separators=(",", ":")) + sep)
            lines.append("\t]" + comma)
        else:
            lines.append(f'\t"{k}": ' + json.dumps(v, ensure_ascii=False) + comma)
    lines.append("}")
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    sys.exit(main())
