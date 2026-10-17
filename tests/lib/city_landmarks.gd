extends RefCounted
## The city suite's landmark checks, split out to keep the runner small: a landmark is a
## Structure with only its baked model's chunks (it stands as built, and pays rubble_bonus times
## an ordinary building's chunks: the player-effect fixture), and on the shipping map each
## landmark gets its own plaza of merged blocks (CitySites).

var _check: Callable


## check: the runner's check(condition, expectation).
func _init(p_check: Callable) -> void:
	_check = p_check


func run() -> void:
	_structure()
	_sites()


## A landmark is a Structure with only its model's chunks: it stands as built, and (player-effect
## fixture) its chunks pay rubble_bonus times what the same chunks of an ordinary building pay.
func _structure() -> void:
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
	_check.call(rows_ok, "the stadium's chunk mask has one %d-long row per floor (%d)" % [w * d, h])
	var frame := Structure.new(w, d, h, 10.0)
	frame.keep(layers)
	_check.call(
		frame.alive_count == marked and marked > 0 and marked < w * d * h,
		"a landmark keeps exactly its model's chunks: %d of %d" % [frame.alive_count, w * d * h]
	)
	_check.call(frame.settle().is_empty(), "a landmark stands as built: nothing loose at the start")
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
	_check.call(
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
	_check.call(
		plain_broken == 6 and mark_broken == 6 and is_equal_approx(mark_pay, plain_pay * 3.0),
		"a landmark's chunks pay 3x an ordinary building's: %.2f vs %.2f" % [mark_pay, plain_pay]
	)


## Landmark sites (city.landmarks): on the shipping map the stadium stands in the first city and
## the wheel joins it at the Behemoth, each centred on its own plaza of merged blocks: no street
## runs through a site, the landmark fits inside its kerbs, and no other building touches it.
func _sites() -> void:
	for tier: int in [1, 2]:
		var base := Content.tuning()
		var cfg: Dictionary = CityGrowth.tuning_for(base, tier)["city"]
		var plan := CityGen.map(cfg)
		var nodes: Array[Vector2] = plan["nodes"]
		var through := 0
		for site: Dictionary in plan["sites"]:
			var outer: Rect2 = site["outer"]
			for st: Dictionary in plan["streets"]:
				var mid := (nodes[Num.i(st["from"])] + nodes[Num.i(st["to"])]) * 0.5
				through += 1 if outer.grow(-0.01).has_point(mid) else 0
		var layout := CityGrowth.layout(base, tier, Seeds.make("city", 0))
		var ids: Array[String] = []
		var misfit := 0
		var touching := 0
		for e: Dictionary in layout:
			if not e.has("landmark"):
				continue
			ids.append(str(e["landmark"]))
			var foot := _footprint(e)
			var inside := false
			for site: Dictionary in plan["sites"]:
				var rect: Rect2 = site["rect"]
				inside = inside or rect.grow(0.01).encloses(foot)
			misfit += 0 if inside else 1
			for other: Dictionary in layout:
				if other != e and _footprint(other).intersects(foot):
					touching += 1
		ids.sort()
		var want: Array[String] = ["stadium"]
		if tier == 2:
			want.append("wheel")
		(
			_check
			. call(
				ids == want and through == 0 and misfit == 0 and touching == 0,
				(
					"stage %d: landmarks %s on their own plazas (%d streets through, %d misfit, %d touching)"
					% [tier, ids, through, misfit, touching]
				)
			)
		)


func _footprint(e: Dictionary) -> Rect2:
	var w := Num.f(e["w"])
	var d := Num.f(e["d"])
	return Rect2(Num.f(e["x"]) - w * 0.5, Num.f(e["z"]) - d * 0.5, w, d)
