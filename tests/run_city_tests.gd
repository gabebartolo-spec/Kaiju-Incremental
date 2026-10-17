extends "res://tests/lib/runner.gd"
## City suite: the seeded layout reads as a real city, not a grid of isolated towers
## (director, 2026-10-16), and the street plan presentation builds on is fixed by the config.
## Headless and seeded.
##   godot --headless --path . --script tests/run_city_tests.gd


func suite_name() -> String:
	return "City"


func run_checks() -> void:
	_check_city_layout(CityGen.generate(Seeds.make("city", 0), Content.section("city")))
	_check_calm_streets()


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
