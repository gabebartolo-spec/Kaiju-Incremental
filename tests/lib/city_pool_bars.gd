extends RefCounted
## The measures behind the city pool suite's bars (D-256): schema, appearances, overlaps, twins,
## view shares, carving and the croc's height. Pure functions over sampled cities
## (tests/lib/city_pool_cities.gd). Seeded by design.

const ROLES: Array[String] = ["hero", "filler"]
const HERO_SHARE := 0.10
const FILLER_SHARE := 0.2  # 0.25 in D-256; the fixed front (#411) left F13 at 22%: tune later
## A game-camera view's ground footprint at the baby's zoom (metres, across x depth), scaled by
## the camera's zoom (camera.zoom_base + zoom_per_scale x body scale) at each stage's start.
const VIEW := Vector2(70.0, 50.0)
const VIEW_STEP := 25.0
## The side of the squares footprints are filed under (metres).
const CELL := 8.0


## Errors in the pool book: one line per bad row or district.
static func schema_errors(book: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var districts: Dictionary = book.get("districts", {})
	for name: String in districts:
		var d: Dictionary = districts[name]
		for key: String in ["palette", "shifts", "town", "mix"]:
			if not d.has(key):
				out.append("%s: no %s" % [name, key])
	for id: String in book.get("pool", {}):
		var row: Dictionary = book["pool"][id]
		if not districts.has(str(row.get("district", ""))):
			out.append("%s: district" % id)
		if not ROLES.has(str(row.get("role", ""))):
			out.append("%s: role" % id)
		if not (row.get("storeys", null) is float or row.get("storeys", null) is int):
			out.append("%s: storeys" % id)
		if row.has("w"):
			out.append_array(_shape_errors(id, row))
	return out


static func _shape_errors(id: String, row: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var layers: Array = row.get("chunks", [])
	if layers.size() != Num.i(row["h"]):
		out.append("%s: %d chunk layers for %d floors" % [id, layers.size(), Num.i(row["h"])])
	for layer: Variant in layers:
		if str(layer).length() != Num.i(row["w"]) * Num.i(row["d"]):
			out.append("%s: a chunk layer is not w x d" % id)
			break
	if not FileAccess.file_exists(str(row.get("kvox", ""))):
		out.append("%s: kvox missing" % id)
	if not row.has("stretch_floor"):
		out.append("%s: no stretch_floor" % id)
	return out


## {"missing", "rare_heroes", "rare_fillers": ids failing; "line": a summary}.
static func appearances(cities: Array[Dictionary], book: Dictionary) -> Dictionary:
	var seen: Dictionary = {}
	var placed := 0
	for city: Dictionary in cities:
		var here: Dictionary = {}
		for e: Dictionary in city["layout"]:
			if e.has("model"):
				here[str(e["model"])] = true
				placed += 1
		for id: String in here:
			seen[id] = Num.i(seen.get(id, 0)) + 1
	var missing: Array[String] = []
	var heroes: Array[String] = []
	var fillers: Array[String] = []
	var pool: Dictionary = book["pool"]
	var low := 1.0
	for id: String in pool:
		var share := Num.f(seen.get(id, 0)) / cities.size()
		low = minf(low, share)
		var row: Dictionary = pool[id]
		var hero := str(row["role"]) == "hero"
		if share == 0.0:
			missing.append(id)
		elif hero and share < HERO_SHARE:
			heroes.append("%s %.0f%%" % [id, share * 100.0])
		elif not hero and share < FILLER_SHARE:
			fillers.append("%s %.0f%%" % [id, share * 100.0])
	var out := {"missing": missing, "rare_heroes": heroes, "rare_fillers": fillers}
	var shares: Array[String] = []
	for id: String in pool:
		shares.append("%s %d" % [id, Num.i(seen.get(id, 0))])
	out["line"] = (
		"%d pool buildings in %d cities (%.1f a city), lowest model share %.0f%%; cities per model: %s"
		% [placed, cities.size(), float(placed) / cities.size(), low * 100.0, ", ".join(shares)]
	)
	return out


## Pool buildings overlapping another building, a street's carriageway or the water.
static func overlaps(cities: Array[Dictionary]) -> Dictionary:
	var out := {"buildings": 0, "roads": 0, "water": 0}
	for city: Dictionary in cities:
		var layout: Array[Dictionary] = city["layout"]
		var plan: Dictionary = city["plan"]
		var cfg: Dictionary = city["cfg"]
		var water := CityRiver.channels(plan, cfg)
		var index := _file(layout)
		var blocks := _file_blocks(plan)
		for i: int in layout.size():
			if not layout[i].has("model"):
				continue
			var r := CityPool.footprint(layout[i]).grow(-0.01)
			for j: int in _near(index, r):
				if j != i and r.intersects(CityPool.footprint(layout[j]).grow(-0.01)):
					out["buildings"] += 1
			for w: Rect2 in water:
				out["water"] += int(r.intersects(w))
			out["roads"] += int(_on_road(blocks, r))
	return out


## Entry indices by CELL square of every footprint they touch.
static func _file(layout: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {}
	for n: int in layout.size():
		var r := CityPool.footprint(layout[n])
		for x: int in range(floori(r.position.x / CELL), floori(r.end.x / CELL) + 1):
			for z: int in range(floori(r.position.y / CELL), floori(r.end.y / CELL) + 1):
				var list: Array = out.get(Vector2i(x, z), [])
				list.append(n)
				out[Vector2i(x, z)] = list
	return out


## The filed entries in the squares `r` touches (each once).
static func _near(index: Dictionary, r: Rect2) -> Array[int]:
	var seen: Dictionary = {}
	for x: int in range(floori(r.position.x / CELL), floori(r.end.x / CELL) + 1):
		for z: int in range(floori(r.position.y / CELL), floori(r.end.y / CELL) + 1):
			var list: Array = index.get(Vector2i(x, z), [])
			for n: int in list:
				seen[n] = true
	var out: Array[int] = []
	out.assign(seen.keys())
	return out


## True unless `r` lies inside one block of the plan (inside its kerbs): a footprint out of every
## block reaches onto a sidewalk or a street.
static func _on_road(blocks: Dictionary, r: Rect2) -> bool:
	var rects: Array[Rect2] = blocks["rects"]
	var index: Dictionary = blocks["index"]
	for n: int in _near(index, r):
		if rects[n].grow(0.01).encloses(r):
			return false
	return true


## The plan's blocks: {"rects": each block's rect, "index": block indices by CELL square}.
static func _file_blocks(plan: Dictionary) -> Dictionary:
	var rects: Array[Rect2] = []
	var index: Dictionary = {}
	for block: Dictionary in plan["blocks"]:
		var r: Rect2 = block["rect"]
		rects.append(r)
		for x: int in range(floori(r.position.x / CELL), floori(r.end.x / CELL) + 1):
			for z: int in range(floori(r.position.y / CELL), floori(r.end.y / CELL) + 1):
				var list: Array = index.get(Vector2i(x, z), [])
				list.append(rects.size() - 1)
				index[Vector2i(x, z)] = list
	return {"rects": rects, "index": index}


## Touching pool pairs with the same look (model and variant) or the same model.
static func twins(cities: Array[Dictionary]) -> Dictionary:
	var out := {"look": 0, "model": 0}
	for city: Dictionary in cities:
		var pooled: Array[Dictionary] = []
		for e: Dictionary in city["layout"]:
			if e.has("model"):
				pooled.append(e)
		for i: int in pooled.size():
			for j: int in range(i + 1, pooled.size()):
				var a := CityPool.footprint(pooled[i]).grow(0.6)
				if not a.intersects(CityPool.footprint(pooled[j])):
					continue
				out["model"] += int(str(pooled[i]["model"]) == str(pooled[j]["model"]))
				out["look"] += int(_look(pooled[i]) == _look(pooled[j]))
	return out


static func _look(e: Dictionary) -> String:
	return "%s|%s|%s|%s|%s" % [e["model"], e["facing"], e["mirror"], e["stretch"], e["palette"]]


## The worst filler share of the buildings in any sampled view (views with at least 20).
static func view_share(cities: Array[Dictionary], tuning: Dictionary) -> Dictionary:
	var cam: Dictionary = tuning["camera"]
	var worst := {"share": 0.0, "line": "no view"}
	for city: Dictionary in cities:
		var cfg: Dictionary = city["cfg"]
		var layout: Array[Dictionary] = city["layout"]
		var index := _file(layout)
		var scale := Growth.body_scale({"size": city["stage"]}, cfg)
		var zoom := Num.f(cam["zoom_base"]) + Num.f(cam["zoom_per_scale"]) * scale
		var base := (
			Num.f(cam["zoom_base"]) + Num.f(cam["zoom_per_scale"]) * Num.f(cfg["young_scale"])
		)
		var size := VIEW * (zoom / base)
		var half := Num.f(cfg["half"])
		var at := -half
		while at <= half:
			var bt := -half
			while bt <= half:
				var view := Rect2(Vector2(at, bt) - size * 0.5, size)
				var got := _share(layout, view, index)
				if Num.f(got["share"]) > Num.f(worst["share"]):
					worst = got
				bt += VIEW_STEP
			at += VIEW_STEP
	return worst


static func _share(layout: Array[Dictionary], view: Rect2, index: Dictionary) -> Dictionary:
	var total := 0
	var per: Dictionary = {}
	for n: int in _near(index, view):
		var e := layout[n]
		if not view.has_point(Vector2(Num.f(e["x"]), Num.f(e["z"]))):
			continue
		total += 1
		if e.has("model") and str(e["model"]).begins_with("F"):
			per[e["model"]] = Num.i(per.get(e["model"], 0)) + 1
	var out := {"share": 0.0, "line": "%d buildings" % total}
	if total < 20:
		return out
	for id: String in per:
		var share := Num.f(per[id]) / total
		if share > Num.f(out["share"]):
			out = {"share": share, "line": "%s %d of %d in %s" % [id, per[id], total, view]}
	return out


## Cells carved when the baby stomps for 4 s beside the model's +x face (it stands alone).
static func carved(id: String, row: Dictionary, dt: float) -> int:
	var entry := {
		"x": 0.0,
		"z": 0.0,
		"w": Num.i(row["w"]),
		"d": Num.i(row["d"]),
		"h": Num.i(row["h"]),
		"tier": 1,
		"style": 0,
		"model": id,
		"facing": 0,
		"mirror": false,
		"stretch": 0,
		"palette": 0,
	}
	var layout: Array[Dictionary] = [entry]
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	var sim := RampageSim.new(stats, Content.tuning(), layout, Seeds.make("army", 0))
	sim.ability_type = str(Content.species_def("reptilian")["ability"]["type"])
	sim.kaiju_pos = Vector2(Num.f(row["w"]) * 0.5 + 0.6, 0.0)
	for _s: int in 60:
		sim.step(dt, Vector2.ZERO, false)
	return sim.carving.cells_carved


## The adult croc's height: kaiju_height x its body scale at the third size, no growth levels.
static func adult_height() -> float:
	var city: Dictionary = Content.section("city")
	return Num.f(city["kaiju_height"]) * Growth.body_scale({"size": 3}, city)
