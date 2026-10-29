extends RefCounted
## ASSETS audit (D-265: "audit that all assets appear often, none never appearing"). The
## inventory of every placeable asset the city can spawn is read from data and the builders'
## tables, so a new row counts the day it lands:
##   building    the four facade archetypes (BuildingLayout, style % 4)
##   facade      the look's wall colours (Look.styles; CityView picks one per building)
##   pool        data/city_buildings.json rows (Tripo heroes and fillers, cfg.building_pool), once
##               merged; a placed entry carries "model"
##   landmark    data/landmarks.json baked landmarks (allowed where city.landmarks lists them)
##   hazard      explosive-site kinds (cfg.hazards.kinds), once merged; entries carry "hazard"
##   sport       data/sports.json, one per stadium per run (StadiumMatch)
##   car         the parked cars' paints (city.car_colors)
##   prop        CityDecor's prop kinds, told apart by their palette keys (PROP_KEYS)
##   civilian    the civilians' outfits (VoxelPerson.OUTFITS, the police uniform excluded)
##   sign        the shops' neon signs (BuildingLayout._sign: its own roll, read here as an upper
##               bound, since a sign also needs a street face with no neighbour)
## Bars: a hero (landmark, sport, pool hero) appears in at least 1 seed of every stage it is
## allowed in; every other asset in at least COMMON_SHARE of the seeds of each stage.
## Seeds: the generator's own variety (tools/audit/seed_audit.gd "seeded" mode: map seed,
## building stream, decor, civilians and sport streams all at index i), since the game plays one
## city per stage today (D-261).

const Roads := preload("res://tools/audit/road_audit.gd")
const AssetView := preload("res://tools/audit/asset_view.gd")
const COMMON_SHARE := 0.25
const ARCHETYPES: Array[String] = ["office", "brick", "glass", "stone"]
const GLASS := 2
const SIGN_SHARE := 300  # of 1000: BuildingLayout.SIGN_CHANCE 0.3
const SIGN_MIN_FLOORS := 3
## Config sections that land with in-flight work (claude/tripo-buildings, city explosives): read
## when present, so their assets count the day they merge.
const POOL_KEY := "building_pool"
const HAZARDS_KEY := "hazards"
## Assets placed only by a fill rule, never by chance: why they can be missing from a seed.
const FILL_ONLY := {
	"prop:traffic_island":
	"TrafficIsland plants one only where the diagonal crosses an avenue, in a free wedge",
	"prop:bollard": "only on a traffic island (TrafficIsland)",
}


## Every asset id the stage's config can spawn: {id: {kind, hero, allowed}}.
static func inventory(cfg: Dictionary) -> Dictionary:
	var out := {}
	for a: String in ARCHETYPES:
		out["building:" + a] = {"kind": "building", "hero": false, "allowed": true}
	for i: int in Look.styles().size():
		out["facade:%d" % i] = {"kind": "facade", "hero": false, "allowed": true}
	var listed: Array[String] = []
	for spec: Dictionary in cfg.get("landmarks", []):
		listed.append(str(spec["id"]))
	var shapes: Dictionary = cfg.get("landmark_shapes", {})
	var past := _past_edge(cfg)
	for id: String in shapes:
		var allowed := id in listed and not id in past
		out["landmark:" + id] = {"kind": "landmark", "hero": true, "allowed": allowed}
	var book: Dictionary = cfg.get(POOL_KEY, {})
	var pool: Dictionary = book.get("pool", {})
	for id: String in pool:
		var pool_row: Dictionary = pool[id]
		var hero := str(pool_row.get("role", "")) == "hero"
		out["pool:" + id] = {"kind": "pool", "hero": hero, "allowed": true}
	var hazards: Dictionary = cfg.get(HAZARDS_KEY, {})
	for kind: Variant in hazards.get("kinds", []):
		out["hazard:" + str(kind)] = {"kind": "hazard", "hero": false, "allowed": true}
	for sport: Dictionary in Content.sports()["sports"]:
		out["sport:" + str(sport["id"])] = {"kind": "sport", "hero": true, "allowed": true}
	var paints: Array = cfg["car_colors"]
	for i: int in paints.size():
		out["car:car%d" % i] = {"kind": "car", "hero": false, "allowed": true}
	for kind: String in AssetView.PROP_KINDS:
		out["prop:" + kind] = {"kind": "prop", "hero": false, "allowed": true}
	for i: int in VoxelPerson.COP:
		out["civilian:%d" % i] = {"kind": "civilian", "hero": false, "allowed": true}
	out["sign:neon"] = {"kind": "sign", "hero": false, "allowed": true}
	return out


## The landmarks whose site this stage's plan places past its edge (D-380: the baby's city shows
## the east spot only): not due at this stage. A landmark with no site at all stays due, so a
## footprint that stops fitting still fails the bar.
static func _past_edge(cfg: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var plan := CityGen.map(cfg)
	var sites: Array = plan.get("sites", [])
	for block: Dictionary in plan["blocks"]:
		if block.has("site") and str(block["use"]) == "outer":
			var site: Dictionary = sites[Num.i(block["site"])]
			out.append(str(site["id"]))
	return out


## What one city's layout places (no view): {id: count}.
static func count_layout(layout: Array) -> Dictionary:
	var out := {}
	var styles := Look.styles().size()
	for e: Dictionary in layout:
		if e.has("landmark"):
			_add(out, "landmark:" + str(e["landmark"]))
			continue
		if e.has("model"):
			_add(out, "pool:" + str(e["model"]))
		else:
			var style := Num.i(e["style"])
			_add(out, "building:" + ARCHETYPES[style % 4])
			var x := Num.f(e["x"])
			var z := Num.f(e["z"])
			_add(out, "facade:%d" % posmod(style + roundi(x * 3.0 + z), styles))
			if _has_sign(e):
				_add(out, "sign:neon")
		if e.has("hazard"):
			_add(out, "hazard:" + str(e["hazard"]))
	return out


static func _has_sign(e: Dictionary) -> bool:
	if Num.i(e["h"]) < SIGN_MIN_FLOORS or Num.i(e["style"]) % 4 == GLASS:
		return false
	var key := roundi(Num.f(e["x"]) * 13.0 + Num.f(e["z"]))
	return absi(hash(Vector4i(7, 7, 7, key))) % 1000 < SIGN_SHARE


static func _add(out: Dictionary, id: String, n: int = 1) -> void:
	out[id] = Num.i(out.get(id, 0)) + n


## One stage of tuning `base`: per asset the seeds it appeared in and its total count.
## opts: {count (seeds), view (also build each city's decor and street life: props, cars,
## civilians, sport)}.
static func stage(root: Node, base: Dictionary, tier: int, opts: Dictionary) -> Dictionary:
	var count := Num.i(opts["count"])
	var with_view: bool = opts.get("view", false)
	var seen := {}
	var totals := {}
	var cfg := {}
	var largest := Vector2i.ZERO
	for i: int in count:
		cfg = Roads.city(base, tier, Roads.seeds(i + 1)[i])
		var layout := CityGen.generate(Seeds.make(CitySeed.STREAM, i), cfg)
		var got := count_layout(layout)
		if with_view:
			got.merge(await AssetView.count(root, base, tier, [layout, i]))
		for id: String in got:
			_add(seen, id)
			_add(totals, id, Num.i(got[id]))
		for e: Dictionary in layout:
			largest = Vector2i(maxi(largest.x, Num.i(e["w"])), maxi(largest.y, Num.i(e["d"])))
	var book: Dictionary = cfg.get(POOL_KEY, {})
	var pool: Dictionary = book.get("pool", {})
	return {
		"seen": seen,
		"totals": totals,
		"inventory": inventory(cfg),
		"largest": largest,
		"pool": pool
	}


## The bar on one stage's result: [{id, seeds, share, why}] for every asset short of it.
static func short_of_bar(result: Dictionary, count: int, with_view: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var inv: Dictionary = result["inventory"]
	for id: String in inv:
		var row: Dictionary = inv[id]
		if not row["allowed"] or (not with_view and AssetView.needs_view(str(row["kind"]))):
			continue
		var seen: Dictionary = result["seen"]
		var seeds := Num.i(seen.get(id, 0))
		var need := 1 if row["hero"] else ceili(COMMON_SHARE * count)
		if seeds < need:
			out.append({"id": id, "seeds": seeds, "need": need, "why": _why(id, result)})
	return out


## Why an asset falls short, from what can be told without a designer: its weight, its fit.
static func _why(id: String, result: Dictionary) -> String:
	var kind := id.get_slice(":", 0)
	if FILL_ONLY.has(id):
		return "fill rule, not chance: " + str(FILL_ONLY[id])
	if kind == "pool":
		var pool: Dictionary = result["pool"]
		var row: Dictionary = pool.get(id.get_slice(":", 1), {})
		var largest: Vector2i = result["largest"]
		var w := Num.i(row.get("w", 0))
		var d := Num.i(row.get("d", 0))
		if mini(w, d) > maxi(largest.x, largest.y):
			return "footprint %dx%d never fits (largest lot %dx%d)" % [w, d, largest.x, largest.y]
		return "placement rule or weight (CityPool): fits some lot, never drawn"
	if kind == "landmark":
		return "no site fits its footprint in this stage's plan (CitySites)"
	return "drawn by rule or chance too rarely (see its builder)"


## The audit on every stage: {data, markdown, summary}.
static func run_all(root: Node, count: int) -> Dictionary:
	var data := {}
	var lines: Array[String] = []
	var short_total := 0
	for tier: int in [1, 2, 3]:
		var opts := {"count": count, "view": true}
		var result: Dictionary = await stage(root, Content.tuning(), tier, opts)
		var short := short_of_bar(result, count, true)
		short_total += short.size()
		data["stage%d" % tier] = {
			"seen": result["seen"], "totals": result["totals"], "short": short
		}
		lines.append("### Stage %d (%d seeds)" % [tier, count])
		lines.append("")
		lines.append("| asset | hero | allowed | seeds | placed |")
		lines.append("|---|---|---|---|---|")
		var inv: Dictionary = result["inventory"]
		var ids := inv.keys()
		var seen_ids: Dictionary = result["seen"]
		var totals: Dictionary = result["totals"]
		for id: String in seen_ids:
			if not id in ids:
				ids.append(id)  # placed but not in the inventory: a new kind
		ids.sort()
		for id: String in ids:
			var row: Dictionary = inv.get(id, {"hero": false, "allowed": "NOT LISTED"})
			var seen := Num.i(seen_ids.get(id, 0))
			var placed := Num.i(totals.get(id, 0))
			lines.append(
				"| %s | %s | %s | %d | %d |" % [id, row["hero"], row["allowed"], seen, placed]
			)
		lines.append("")
		for s: Dictionary in short:
			lines.append(
				(
					"- SHORT: %s in %d of %d seeds (bar %d): %s"
					% [s["id"], s["seeds"], count, s["need"], s["why"]]
				)
			)
		lines.append("")
	var summary := "assets: %d asset-stage pairs short of the bar" % short_total
	return {"data": data, "markdown": "\n".join(lines) + "\n", "summary": summary}
