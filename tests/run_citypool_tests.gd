extends "res://tests/lib/runner.gd"
## City pool suite: the Tripo heroes and fillers (D-256, data/city_buildings.json) baked into the
## city (CityPool) and broken through the one carve path (D-253). Over 3 stages x 20 city seeds:
## every baked model appears, heroes in at least 10% of the cities and each filler in at least
## 25%; no filler above 5% of the buildings in any sampled game-camera view; no two touching
## copies alike; no overlap with buildings, roads or water. The port (CityPort) stands the same in
## every city of a stage, all of it by the last stage. Every model carves. The tallest is
## about 2x the adult croc (D-257). Player-effect fixture "city_pool": the pool on vs off.
## Seeded by design: city seeds 0..19 per stage, Seeds "army" 0.
##   godot --headless --path . --script tests/run_citypool_tests.gd

const Cities := preload("res://tests/lib/city_pool_cities.gd")
const Bars := preload("res://tests/lib/city_pool_bars.gd")
const DT := 1.0 / 15.0

var _cities: Cities


func suite_name() -> String:
	return "CityPool"


func run_checks() -> void:
	await _t("_check_schema")
	await _t("_check_variant_maps")
	var t0 := Time.get_ticks_msec()
	_cities = Cities.new()
	print("  %d cities built in %d ms" % [_cities.cities.size(), Time.get_ticks_msec() - t0])
	for test: String in [
		"_check_appears",
		"_check_overlaps",
		"_check_twins",
		"_check_port",
		"_check_view_share",
		"_check_effect",
		"_check_every_model_carves",
		"_check_tallest",
	]:
		t0 = Time.get_ticks_msec()
		await _t(test)
		print("  %s: %d ms" % [test, Time.get_ticks_msec() - t0])


func _pool() -> Dictionary:
	var pool: Dictionary = Content.city_buildings()["pool"]
	return pool


## Every row is well formed (the pool's schema): name, a known district, hero, filler or fixed,
## storeys;
## once baked, w, d, h, one chunk layer per floor of w x d, a kvox that exists, stretch_floor.
func _check_schema() -> void:
	var book := Content.city_buildings()
	var bad := Bars.schema_errors(book)
	check(bad.is_empty(), "every pool row and district is well formed: %s" % [bad])
	var broken := book.duplicate(true)
	var rows: Dictionary = broken["pool"]
	rows["X99"] = {"name": "x", "district": "nowhere", "role": "boss", "storeys": 2}
	check(Bars.schema_errors(broken).size() >= 2, "the schema check catches a planted bad row")
	var baked := 0
	for row: Dictionary in _pool().values():
		baked += int(row.has("w"))
	check(baked == _pool().size(), "every row is baked (%d of %d)" % [baked, _pool().size()])


## The port (D-381, CityPort): every city of a stage stands the same port models at the same spots
## and turns, and the last stage's band holds every one city "harbour" "port" lists.
func _check_port() -> void:
	var listed: Array = Content.tuning()["city"]["harbour"]["port"]["at"]
	var by_stage: Dictionary = {}
	var odd: Array[String] = []
	var last := 0
	for city: Dictionary in _cities.cities:
		var key: Array[String] = []
		for e: Dictionary in city["layout"]:
			if e.get("fixed", false):
				key.append("%s@%.1f,%.1f/%d" % [e["model"], e["x"], e["z"], Num.i(e["facing"])])
		var stage := Num.i(city["stage"])
		last = maxi(last, stage)
		var line := ";".join(key)  # the keys hold commas
		if by_stage.has(stage) and by_stage[stage] != line:
			odd.append("stage %d seed %d" % [stage, city["seed"]])
		by_stage[stage] = line
	check(odd.is_empty(), "every city of a stage has the same port (not: %s)" % [odd])
	var all := str(by_stage.get(last, "")).split(";", false).size()
	check(
		all == listed.size(), "the last stage stands all %d port models (%d)" % [listed.size(), all]
	)


## Four quarter turns bring a cell and its face bits home; a turn swaps the footprint; a stretch
## repeats the stretch floor; chunks follow the cells.
func _check_variant_maps() -> void:
	var row := {"w": 2, "d": 1, "h": 3, "chunks": ["11", "10", "10"], "stretch_floor": 1}
	var c := Vector3i(3, 5, 2)
	var p := c
	var m := 0b010011
	for _k: int in 4:
		p = ModelVariant.place(p, 16, 8, {"facing": 1, "mirror": false})
		m = ModelVariant.flags(m, {"facing": 1, "mirror": false})
	check(p == c and m == 0b010011, "four quarter turns return a cell and its faces (%s)" % p)
	var v := {"facing": 1, "mirror": true, "stretch": 2}
	check(ModelVariant.size(row, v) == Vector3i(1, 5, 2), "a turn swaps w and d; stretch adds 2")
	var layers := ModelVariant.chunks(row, v)
	check(
		layers.size() == 5 and str(layers[2]) == str(layers[1]),
		"the stretch floor repeats in the chunks"
	)
	var got := ModelVariant.cells(PackedInt32Array([0, 9, 0, 0, 17, 0]), row, v, 8)
	var src: PackedInt32Array = got["src"]
	check(src.size() == 4, "a stretch floor cell is copied per added floor (%d cells)" % src.size())
	var xyz: PackedInt32Array = got["xyz"]
	var top := xyz[xyz.size() - 2]
	check(top == 33, "a cell above the band rises by the stretch (y %d)" % top)


## D-256 bars: every model in at least one city, heroes in 10%, each filler in 20%.
func _check_appears() -> void:
	var report := Bars.appearances(_cities.cities, Content.city_buildings())
	print("  pool: ", report["line"])
	var missing: Array = report["missing"]
	var heroes: Array = report["rare_heroes"]
	var fillers: Array = report["rare_fillers"]
	check(missing.is_empty(), "every baked model appears: missing %s" % [missing])
	check(heroes.is_empty(), "heroes in >= 10%% of cities: under %s" % [heroes])
	check(fillers.is_empty(), "fillers in >= 20%% of cities: under %s" % [fillers])


## No pool building overlaps another building, a street's carriageway or the river.
func _check_overlaps() -> void:
	var counts := Bars.overlaps(_cities.cities)
	for key: String in ["buildings", "roads", "water"]:
		var n := Num.i(counts[key])
		check(n == 0, "0 pool overlaps with %s (%d)" % [key, n])


## No two touching pool buildings share model and variant (or even model).
func _check_twins() -> void:
	var twins := Bars.twins(_cities.cities)
	var look := Num.i(twins["look"])
	var model := Num.i(twins["model"])
	check(look == 0, "0 identical model+variant neighbours (%d)" % look)
	check(model == 0, "0 same-model neighbours (%d)" % model)


## No filler is more than 5% of the buildings in any sampled game-camera view.
func _check_view_share() -> void:
	var worst := Bars.view_share(_cities.cities, Content.tuning())
	print("  view share: ", worst["line"])
	var share := Num.f(worst["share"])
	check(
		share <= 0.05, "no filler above 5%% of a view (%.1f%%: %s)" % [share * 100.0, worst["line"]]
	)


## Player-effect fixture "city_pool": the same seeds with the pool on and off; on, the city holds
## pool buildings and the same run builds the same city; off, none.
func _check_effect() -> void:
	var off := Cities.new(false, 1)
	var on_n := 0
	var off_n := 0
	for k: int in off.cities.size():
		var on_city: Dictionary = _cities.cities[k * Cities.SEEDS]
		var off_city: Dictionary = off.cities[k]
		var on_layout: Array[Dictionary] = on_city["layout"]
		var off_layout: Array[Dictionary] = off_city["layout"]
		on_n += Cities.pooled(on_layout).size()
		off_n += Cities.pooled(off_layout).size()
	check(on_n > 0 and off_n == 0, "pool on: %d pool buildings; off: %d" % [on_n, off_n])
	var first: Dictionary = _cities.cities[0]
	var cfg: Dictionary = first["cfg"]
	var again := CityGen.generate(Seeds.make("city", Num.i(first["seed"])), cfg)
	check(str(again) == str(first["layout"]), "the same seed builds the same city")


## Every model breaks through the carve path: alone on a lot, stomped beside its face, it is
## promoted and cells are carved (D-253).
func _check_every_model_carves() -> void:
	var dead: Array[String] = []
	var pool := _pool()
	for id: String in pool:
		var row: Dictionary = pool[id]
		if Bars.carved(id, row, DT) <= 0:
			dead.append(id)
	check(dead.is_empty(), "every pool model carves (not: %s)" % [dead])


## The tallest model is about 2x the adult croc (D-257): 1.8-2.2x the adult's reach height.
func _check_tallest() -> void:
	var tallest := 0
	for row: Dictionary in _pool().values():
		tallest = maxi(tallest, Num.i(row.get("h", 0)))
	var adult := Bars.adult_height()
	var ratio := tallest / adult
	check(
		ratio >= 1.8 and ratio <= 2.2,
		"tallest %d floors = %.2fx the adult croc (%.1f)" % [tallest, ratio, adult]
	)
