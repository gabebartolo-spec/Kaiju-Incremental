extends "res://tests/lib/runner.gd"
## City suite: the seeded layout reads as a real city, not a grid of isolated towers
## (director, 2026-10-16), the street plan presentation builds on is fixed by the config, and a
## landmark stands and pays in its own shape.
## Headless and seeded.
##   godot --headless --path . --script tests/run_city_tests.gd


func suite_name() -> String:
	return "City"


func run_checks() -> void:
	_check_city_layout(CityGen.generate(Seeds.make("city", 0), Content.section("city")))
	_check_calm_streets()
	_check_landmark()


## The city reads as a real city, not a grid of isolated towers (director, 2026-10-16): lots
## line the blocks and share party walls, nothing stands in a street, the plan is fixed by
## the config alone, and the kaiju starts in the street.
func _check_city_layout(layout: Array[Dictionary]) -> void:
	var cfg := Content.section("city")
	var rects: Array[Rect2] = []
	for e: Dictionary in layout:
		var w := Num.f(e["w"])
		var d := Num.f(e["d"])
		rects.append(Rect2(Num.f(e["x"]) - w * 0.5, Num.f(e["z"]) - d * 0.5, w, d))
	var overlaps := 0
	var touching := 0
	for i: int in rects.size():
		for j: int in range(i + 1, rects.size()):
			if rects[i].intersection(rects[j]).get_area() > 0.001:
				overlaps += 1
			elif rects[i].grow(0.01).intersection(rects[j]).size.length() > 0.5:
				touching += 1  # a shared wall at least half a unit long
	check(overlaps == 0, "no two buildings overlap (%d do)" % overlaps)
	check(
		touching > layout.size() * 0.5,
		(
			"buildings share party walls: %d touching pairs for %d buildings"
			% [touching, layout.size()]
		)
	)
	var plan := CityGen.map(cfg)
	var nodes: Array[Vector2] = plan["nodes"]
	var in_street := 0
	for street: Dictionary in plan["streets"]:
		var half_w := Num.f(street["width"]) * 0.5
		# The street between its crossings (a block corner may meet the crossing square).
		var a := nodes[Num.i(street["from"])]
		var b := nodes[Num.i(street["to"])]
		var trim := (b - a).normalized() * (Num.f(cfg["avenue_width"]) * 0.5 + 0.5)
		if a.distance_to(b) <= trim.length() * 2.0 and str(street["kind"]) != CityGen.DIAGONAL:
			continue  # all of it lies inside its two crossings
		a += trim
		b -= trim
		for r: Rect2 in rects:
			var closest := Geometry2D.get_closest_point_to_segment(r.get_center(), a, b)
			var inside := Rect2(r.position, r.size).grow(half_w - 0.01)
			if str(street["kind"]) != CityGen.DIAGONAL and inside.has_point(closest):
				in_street += 1
		if str(street["kind"]) == CityGen.DIAGONAL:
			for r: Rect2 in rects:
				var corners: Array[Vector2] = [
					r.position,
					r.end,
					Vector2(r.position.x, r.end.y),
					Vector2(r.end.x, r.position.y)
				]
				for corner: Vector2 in corners:
					if CityGen.diagonal_distance(plan, corner) < half_w - 0.01:
						in_street += 1
	check(in_street == 0, "no building stands in a street (%d do)" % in_street)
	check(CityGen.map(cfg) == plan, "the street plan is the same every time from the city config")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	var spawn := RampageSim.new(stats, Content.tuning(), layout, Seeds.make("army", 0)).kaiju_pos
	var on_lot := false
	for r: Rect2 in rects:
		on_lot = on_lot or r.has_point(spawn)
	check(not on_lot, "the kaiju starts in the street, not inside a building: %s" % spawn)


## Calm streets (director, 2026-10-18: "remove the level crossing hellscape"): zebra crossings
## only at the city.zebra_junctions junctions where two avenues cross, nearest the centre.
func _check_calm_streets() -> void:
	var cfg := Content.section("city")
	var ground := CityGround.new(cfg)
	var zebras := ground.zebra_junctions()
	var nodes: Array[Vector2] = ground.plan["nodes"]
	var far := 0.0
	for n: int in zebras:
		far = maxf(far, nodes[n].length())
	check(
		zebras.size() == Num.i(cfg["zebra_junctions"]) and far <= Num.f(cfg["half"]),
		(
			"zebras at %d junctions (tuning %d), furthest %.0f from the centre"
			% [zebras.size(), Num.i(cfg["zebra_junctions"]), far]
		)
	)
	ground.free()


## A landmark is a Structure with only its model's chunks: it stands as built, and (player-effect
## fixture) its chunks pay rubble_bonus times what the same chunks of an ordinary building pay.
func _check_landmark() -> void:
	var shape: Dictionary = Content.landmarks().get("stadium", {})
	var layers: Array = shape.get("chunks", [])
	var w := Num.i(shape.get("w", 0))
	var d := Num.i(shape.get("d", 0))
	var h := Num.i(shape.get("h", 0))
	var marked := 0
	var rows_ok := layers.size() == h and h > 0
	for row: Variant in layers:
		rows_ok = rows_ok and str(row).length() == w * d
		marked += str(row).count("1")
	check(rows_ok, "the stadium's chunk mask has one %d-long row per floor (%d)" % [w * d, h])
	var frame := Structure.new(w, d, h, 10.0)
	frame.keep(layers)
	check(
		frame.alive_count == marked and marked > 0 and marked < w * d * h,
		"a landmark keeps exactly its model's chunks: %d of %d" % [frame.alive_count, w * d * h]
	)
	check(frame.settle().is_empty(), "a landmark stands as built: nothing loose at the start")
	var plain := {"x": -40.0, "z": 0.0, "w": w, "d": d, "h": h, "tier": 2, "style": 0}
	var mark := plain.duplicate()
	mark["x"] = 40.0
	mark["landmark"] = "stadium"
	mark["rubble_bonus"] = 3.0
	mark["chunks"] = layers
	var layout: Array[Dictionary] = [plain, mark]
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	var sim := RampageSim.new(stats, Content.tuning(), layout, Seeds.make("army", 0))
	check(
		sim.chunks_total == w * d * h + marked,
		"destruction counts only a landmark's real chunks: %d" % sim.chunks_total
	)
	# The same top chunks of each: a chunk with nothing above it, so nothing falls.
	var tops: Array[Vector3i] = []
	for z: int in d:
		for x: int in w:
			var y := sim.buildings[1].frame.top_below(x, z, h)
			if y >= 0 and tops.size() < 6:
				tops.append(Vector3i(x, y, z))
	var before := sim.rubble
	var plain_broken := sim.damage_chunks(0, tops, 1.0e6)
	var plain_pay := sim.rubble - before
	before = sim.rubble
	var mark_broken := sim.damage_chunks(1, tops, 1.0e6)
	var mark_pay := sim.rubble - before
	check(
		plain_broken == 6 and mark_broken == 6 and is_equal_approx(mark_pay, plain_pay * 3.0),
		"a landmark's chunks pay 3x an ordinary building's: %.2f vs %.2f" % [mark_pay, plain_pay]
	)
