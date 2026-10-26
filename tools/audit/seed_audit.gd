extends RefCounted
## SEEDS audit (D-265: "audit that seeds are actually meaningfully different from one another").
## For each stage, pairwise over N run indices, how much of the city changes between two runs:
##   lots      share of lots (a building's ground position) whose building differs: a lot only
##             one city has, or a different footprint, height, style or pool model there
##   landmarks share of landmarks standing somewhere else (or only in one city)
##   sites     the same for explosive sites (layout entries with "hazard"; none until they merge)
##   roads     road graph edit distance: street pieces (by their rounded ends) in one plan and not
##             the other, over all pieces in either (0 same plan .. 1 nothing shared)
## Bars (D-261's city blocks brief): every pair of indices differs on >= LOTS_BAR of its lots;
## the same index twice gives a byte-identical layout (hash).
## Two ways of choosing a run's city are measured: "game", the game's own (CitySeed: what a
## player gets today), and "seeded", the map seed and the building stream both varied, which is
## what the generator alone can do once runs are seeded.

const Roads := preload("res://tools/audit/road_audit.gd")
const LOTS_BAR := 0.5
const MOVED_M := 1.0


## The city of run `index` at stage `tier`: {layout, plan}. mode "game" or "seeded".
static func city(base: Dictionary, tier: int, index: int, mode: String) -> Dictionary:
	if mode == "game":
		var cfg: Dictionary = CitySeed.tuning(base, tier, 0, index)["city"]
		return {"layout": CitySeed.layout(base, tier, 0, index), "plan": CityGen.map(cfg)}
	var seeded := Roads.city(base, tier, Roads.seeds(index + 1)[index])
	var layout := CityGen.generate(Seeds.make(CitySeed.STREAM, index), seeded)
	return {"layout": layout, "plan": CityGen.map(seeded)}


## A hash of everything a city places: its layout and its street pieces.
static func layout_hash(c: Dictionary) -> int:
	var plan: Dictionary = c["plan"]
	return hash(JSON.stringify([c["layout"], plan["nodes"], plan["streets"]]))


## How two cities differ: {lots, landmarks, sites, roads}, each a share 0..1.
static func compare(a: Dictionary, b: Dictionary) -> Dictionary:
	var la: Array = a["layout"]
	var lb: Array = b["layout"]
	var pa: Dictionary = a["plan"]
	var pb: Dictionary = b["plan"]
	return {
		"lots": _lots(la, lb),
		"landmarks": _moved(la, lb, "landmark"),
		"sites": _moved(la, lb, "hazard"),
		"roads": _roads(pa, pb),
	}


static func _lot_key(e: Dictionary) -> Vector2i:
	return Vector2i(roundi(Num.f(e["x"]) * 2.0), roundi(Num.f(e["z"]) * 2.0))


static func _signature(e: Dictionary) -> String:
	var parts := [e["w"], e["d"], e["h"], e["style"], e.get("model", ""), e.get("landmark", "")]
	return JSON.stringify(parts)


static func _lots(a: Array, b: Array) -> float:
	var in_a := {}
	for e: Dictionary in a:
		in_a[_lot_key(e)] = _signature(e)
	var keys := in_a.duplicate()
	var same := 0
	for e: Dictionary in b:
		var key := _lot_key(e)
		keys[key] = true
		if str(in_a.get(key, "")) == _signature(e):
			same += 1
	return 1.0 - float(same) / maxf(1.0, keys.size())


## Share of the entries carrying `field` (by its value, in order) that moved or are only in one.
static func _moved(a: Array, b: Array, field: String) -> float:
	var where_a := _where(a, field)
	var where_b := _where(b, field)
	var names := where_a.keys()
	for name: Variant in where_b:
		if not name in names:
			names.append(name)
	if names.is_empty():
		return -1.0  # nothing of this kind in either city
	var moved := 0
	for name: Variant in names:
		if not where_a.has(name) or not where_b.has(name):
			moved += 1
		else:
			var pa: Vector2 = where_a[name]
			var pb: Vector2 = where_b[name]
			moved += 1 if pa.distance_to(pb) > MOVED_M else 0
	return float(moved) / names.size()


## Where each entry with `field` stands, keyed "<value>#<n>" (the nth of that value).
static func _where(entries: Array, field: String) -> Dictionary:
	var out := {}
	var seen := {}
	for e: Dictionary in entries:
		if not e.has(field):
			continue
		var value := str(e[field])
		var n := Num.i(seen.get(value, 0))
		seen[value] = n + 1
		out["%s#%d" % [value, n]] = Vector2(Num.f(e["x"]), Num.f(e["z"]))
	return out


static func _edges(plan: Dictionary) -> Dictionary:
	var out := {}
	var nodes: Array[Vector2] = plan["nodes"]
	for s: Dictionary in plan["streets"]:
		var a := Vector2i((nodes[Num.i(s["from"])] * 10.0).round())
		var b := Vector2i((nodes[Num.i(s["to"])] * 10.0).round())
		var key := [a, b] if a < b else [b, a]
		out[str(key)] = true
	return out


static func _roads(a: Dictionary, b: Dictionary) -> float:
	var ea := _edges(a)
	var eb := _edges(b)
	var shared := 0
	for key: String in ea:
		if eb.has(key):
			shared += 1
	var union := ea.size() + eb.size() - shared
	return 1.0 - float(shared) / maxf(1.0, union)


## The audit on every stage and both modes: {data, markdown, summary}.
static func run_all(base: Dictionary, count: int) -> Dictionary:
	var data := {}
	var lines: Array[String] = [
		(
			"| stage | mode | lots differ min / mean | landmarks moved mean |"
			+ " sites moved mean | road edit distance min / mean | same index identical |"
		)
	]
	lines.append("|---|---|---|---|---|---|---|")
	var worst := 1.0
	for tier: int in [1, 2, 3]:
		for mode: String in ["game", "seeded"]:
			var got := stage(base, tier, mode, count)
			data["stage%d_%s" % [tier, mode]] = got
			if mode == "game":
				worst = minf(worst, Num.f(got["lots_min"]))
			lines.append(
				(
					"| %d | %s | %.0f%% / %.0f%% | %s | %s | %.2f / %.2f | %s |"
					% [
						tier,
						mode,
						Num.f(got["lots_min"]) * 100.0,
						Num.f(got["lots_mean"]) * 100.0,
						_share(got["landmarks_mean"]),
						_share(got["sites_mean"]),
						got["roads_min"],
						got["roads_mean"],
						"yes" if got["deterministic"] else "NO"
					]
				)
			)
	var summary := (
		"seeds: worst pair of game runs differs on %.0f%% of lots (bar %.0f%%)"
		% [worst * 100.0, LOTS_BAR * 100.0]
	)
	return {"data": data, "markdown": "\n".join(lines) + "\n", "summary": summary}


static func _share(v: Variant) -> String:
	return "n/a (none)" if Num.f(v) < 0.0 else "%.0f%%" % (Num.f(v) * 100.0)


## One stage, one mode: pairwise over `count` indices, and index 0 built twice.
static func stage(base: Dictionary, tier: int, mode: String, count: int) -> Dictionary:
	var cities: Array[Dictionary] = []
	for i: int in count:
		cities.append(city(base, tier, i, mode))
	var again := city(base, tier, 0, mode)
	var sums := {"lots": [], "landmarks": [], "sites": [], "roads": []}
	for i: int in count:
		for j: int in range(i + 1, count):
			var d := compare(cities[i], cities[j])
			for key: String in sums:
				var list: Array = sums[key]
				list.append(Num.f(d[key]))
	var out := {"deterministic": layout_hash(again) == layout_hash(cities[0]), "pairs": 0}
	for key: String in sums:
		var list: Array = sums[key]
		out["pairs"] = list.size()
		out[key + "_min"] = list.min() if not list.is_empty() else 0.0
		out[key + "_mean"] = _mean(list)
	return out


static func _mean(list: Array) -> float:
	if list.is_empty():
		return 0.0
	var total := 0.0
	for v: float in list:
		total += v
	return total / list.size()
