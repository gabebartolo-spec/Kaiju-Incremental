"""Fetch one district's raw OpenStreetMap data from the Overpass API, once.

Offline dev tool (never shipped, never run by the game). One bbox query per district, cached in
tools/osm/cache/<district>.json (gitignored); a cached district is never fetched again unless
--force. Map data (c) OpenStreetMap contributors, ODbL 1.0 (docs/LICENSING_REGISTER.md).

    python tools/osm/fetch_osm.py melbourne_cbd
"""

import json
import pathlib
import sys
import time
import urllib.parse
import urllib.error
import urllib.request

HERE = pathlib.Path(__file__).resolve().parent
# Tried in order; a busy server answers 502/504, so the next public instance gets the one query.
ENDPOINTS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
]
# A busy server asks for exponential backoff: wait, then double the wait (fair use).
BACKOFF_S = [30, 60, 120, 240]
QUERY = """
[out:json][timeout:120];
(
  way["building"]({b});
  relation["building"]({b});
  way["highway"]({b});
  way["railway"~"rail|light_rail|tram"]({b});
  way["leisure"~"park|garden"]({b});
  relation["leisure"~"park|garden"]({b});
  way["landuse"~"grass|recreation_ground|railway"]({b});
  way["natural"="water"]({b});
  relation["natural"="water"]({b});
  way["waterway"~"river|riverbank"]({b});
  relation["waterway"="riverbank"]({b});
  way["place"="square"]({b});
  way["area:highway"]({b});
);
out body geom;
"""


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    name = sys.argv[1]
    district = json.loads((HERE / "districts.json").read_text())[name]
    cache = HERE / "cache" / f"{name}.json"
    if cache.exists() and "--force" not in sys.argv:
        print(f"cached: {cache}")
        return 0
    s, w, n, e = district["bbox"]
    query = QUERY.replace("{b}", f"{s},{w},{n},{e}")
    raw = b""
    for wait in [0] + BACKOFF_S:
        if wait:
            print(f"all busy; waiting {wait} s")
            time.sleep(wait)
        raw = _try_all(query)
        if raw:
            break
    if not raw:
        print("every server refused; try again later")
        return 1
    cache.parent.mkdir(parents=True, exist_ok=True)
    cache.write_bytes(raw)
    print(f"fetched {len(raw) // 1024} KB -> {cache}")
    return 0


def _try_all(query: str) -> bytes:
    for endpoint in ENDPOINTS:
        req = urllib.request.Request(
            endpoint,
            data=urllib.parse.urlencode({"data": query}).encode(),
            headers={"User-Agent": "KaijuIncremental-dev-bake/0.1 (one-off district fetch)"},
        )
        try:
            with urllib.request.urlopen(req, timeout=180) as resp:
                return resp.read()
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError) as err:
            print(f"{endpoint}: {err}, trying the next server")
    return b""


if __name__ == "__main__":
    sys.exit(main())
