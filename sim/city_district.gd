class_name CityDistrict
extends RefCounted
## A real city district, baked offline from OpenStreetMap by tools/osm/bake_district.py into
## data/cities/<name>.json (D-029: cities ship as patches; nothing is fetched at runtime).
## Map data © OpenStreetMap contributors, ODbL 1.0 (docs/LICENSING_REGISTER.md).
##
## Gives the same shapes as CityGen (see CitySource): a street plan and the buildings of the
## playable rect. Footprints were rasterised onto the unit grid and split into boxes at bake
## time, so every building is an ordinary Structure. No randomness: the file is the city.

const DIR := "res://data/cities/"

static var _cache: Dictionary = {}


## The raw baked district (cached; the file never changes while the game runs).
static func data(district: String) -> Dictionary:
	if not _cache.has(district):
		_cache[district] = Content.load_json(DIR + district + ".json")
	var out: Dictionary = _cache[district]
	return out


static func exists(district: String) -> bool:
	return FileAccess.file_exists(DIR + district + ".json")


## The playable buildings: x, z (centre), w, d, h, tier, style, plus osm (id) and name.
static func buildings(district: String, cfg: Dictionary) -> Array[Dictionary]:
	var raw: Array = data(district)["buildings"]
	return _boxes(raw, cfg)


## Buildings outside the playable rect (the skyline round it): drawn, never destroyed.
static func outer_buildings(district: String, cfg: Dictionary) -> Array[Dictionary]:
	var raw: Array = data(district)["outer"]
	return _boxes(raw, cfg)


static func _boxes(raw: Array, cfg: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in raw:
		var h := Num.i(entry["h"])
		var b := {
			"x": Num.f(entry["x"]),
			"z": Num.f(entry["z"]),
			"w": Num.i(entry["w"]),
			"d": Num.i(entry["d"]),
			"h": h,
			"tier": CityGen.tier_for_height(h, cfg),
			"style": Num.i(entry["style"]),
			"osm": Num.i(entry["osm"]),
		}
		if entry.has("name"):
			b["name"] = str(entry["name"])
		out.append(b)
	return out


## The street plan, in CityGen.map()'s shape: nodes, streets {from, to, width, kind, name,
## oneway}, blocks (none: a real district's ground is its streets and areas), sidewalk; plus
## areas {use: water|park|plaza|rail, poly}, rails (polylines), play, bounds, start, credit.
static func plan(district: String) -> Dictionary:
	var raw := data(district)
	var nodes: Array[Vector2] = []
	for p: Array in raw["nodes"]:
		nodes.append(Vector2(Num.f(p[0]), Num.f(p[1])))
	var streets: Array[Dictionary] = []
	for s: Dictionary in raw["streets"]:
		streets.append(
			{
				"from": Num.i(s["from"]),
				"to": Num.i(s["to"]),
				"width": Num.f(s["width"]),
				"kind": str(s["kind"]),
				"name": str(s["name"]),
				"oneway": s["oneway"] == true,
			}
		)
	var bounds: Array = raw["bounds"]
	var areas: Array[Dictionary] = []
	for a: Dictionary in raw["areas"]:
		var flat: Array = a["poly"]
		areas.append({"use": str(a["use"]), "poly": _points(flat)})
	var rails: Array[PackedVector2Array] = []
	for r: Array in raw["rails"]:
		rails.append(_points(r))
	return {
		"nodes": nodes,
		"streets": streets,
		"blocks": [] as Array[Dictionary],
		"sidewalk": Num.f(raw["sidewalk"]),
		"areas": areas,
		"rails": rails,
		"play": play(district),
		"bounds": _rect(bounds),
		"start": start(district),
		"name": str(raw["name"]),
		"credit": str(raw["credit"]),
	}


## The destructible part of the district, centred on the origin.
static func play(district: String) -> Rect2:
	var rect: Array = data(district)["play"]
	return _rect(rect)


## Where the kaiju arrives (Melbourne: in the Yarra by Princes Bridge).
static func start(district: String) -> Vector2:
	var p: Array = data(district)["start"]
	return Vector2(Num.f(p[0]), Num.f(p[1]))


static func _rect(v: Array) -> Rect2:
	return Rect2(Num.f(v[0]), Num.f(v[1]), Num.f(v[2]), Num.f(v[3]))


static func _points(flat: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in range(0, flat.size() - 1, 2):
		out.append(Vector2(Num.f(flat[i]), Num.f(flat[i + 1])))
	return out
