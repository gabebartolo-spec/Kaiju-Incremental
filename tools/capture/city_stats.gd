extends SceneTree
## Prints the seeded city's numbers (buildings, chunks, rough voxel count, tiers, street plan),
## to compare layouts without rendering:
##   godot --headless --path . --script tools/capture/city_stats.gd


func _initialize() -> void:
	var cfg := Content.section("city")
	var layout := CityGen.generate(Seeds.make("city", 0), cfg)
	var chunks := 0
	var voxels := 0
	var tallest := 0
	var tiers := {}
	for e: Dictionary in layout:
		var w := Num.i(e["w"])
		var d := Num.i(e["d"])
		var h := Num.i(e["h"])
		var tier := Num.i(e["tier"])
		chunks += w * d * h
		voxels += (w * 4 - 2) * (d * 4 - 2) * h + (w + d) * 8 * h * 4
		tallest = maxi(tallest, h)
		tiers[tier] = Num.i(tiers.get(tier, 0)) + 1
	print(
		(
			"buildings %d chunks %d voxels ~%dk tallest %d tiers %s"
			% [layout.size(), chunks, voxels / 1000, tallest, tiers]
		)
	)
	var plan := CityGen.map(cfg)
	var uses := {}
	var blocks: Array[Dictionary] = plan["blocks"]
	for b: Dictionary in blocks:
		uses[str(b["use"])] = Num.i(uses.get(str(b["use"]), 0)) + 1
	var kinds := {}
	var streets: Array[Dictionary] = plan["streets"]
	for st: Dictionary in streets:
		kinds[str(st["kind"])] = Num.i(kinds.get(str(st["kind"]), 0)) + 1
	var nodes: Array[Vector2] = plan["nodes"]
	print("nodes %d streets %s blocks %s" % [nodes.size(), kinds, uses])
	print("street lines x %s" % [plan["xs"]])
	print("street lines z %s" % [plan["zs"]])
	quit()
