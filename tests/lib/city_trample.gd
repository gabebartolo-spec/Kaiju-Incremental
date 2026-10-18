extends RefCounted
## The kaiju's body tramples what it covers (D-065; the motion critic on #55: trees under the
## tail stayed up): with the drawn kaiju beside the city, facing north and its tail over a park
## tree, one step on the ground brings that tree down. Headless, so the body box has to come from
## the kaiju's own sculpt, not from what a renderer reports.

const TAIL := 0.8  # the tree stands this share of the way from the middle to the tail's end


## holder: the node that holds `decor` (in the tree); the kaiju is added beside it and freed.
static func check_tail(
	tier: int, map_seed: int, sim: RampageSim, decor: CityDecor, check: Callable
) -> void:
	var holder := decor.get_parent()
	var colors: Dictionary = Content.species_def("reptilian")["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, KaijuModel.stage_for(sim.size_tier()))
	holder.add_child(kaiju)
	kaiju.scale = Vector3.ONE * sim.body_scale()
	var share := Num.f(sim.city["trample_share"])
	var foot := KaijuFootprint.of(kaiju, sim.size_tier(), share)
	var trees: Array[Vector2] = decor._park_trees
	var tree := trees[0] if not trees.is_empty() else Vector2.ZERO
	# Facing north (-z, the sculpt's own facing), so the tail reaches south (+z).
	var behind := foot.end.y * TAIL * sim.body_scale()
	sim.airborne = false
	for step: int in 2:
		var at := Vector2(tree.x, tree.y - behind - 0.1 * (1 - step))
		sim.kaiju_pos = at
		kaiju.position = Vector3(at.x, 0, at.y)
		decor._process(1.0 / 60.0)
	var down := false
	var felled := {}
	for group: Dictionary in decor._props._groups:
		var base: Vector3 = group["at"]
		if Vector2(base.x, base.z).distance_to(tree) < 0.01:
			down = group.get("crushed", false)
			felled = group
	check.call(
		down and not trees.is_empty(),
		(
			(
				"stage %d, map_seed %d: a park tree under the kaiju's tail goes down (tail %.1f m"
				% [tier, map_seed, foot.end.y * sim.body_scale()]
			)
			+ " behind its middle, tree %.1f m behind)" % behind
		)
	)
	if not felled.is_empty():
		_check_lies(decor, felled, kaiju, foot, check)
	kaiju.free()


## Once down (critic on #55, r9), the felled tree lies on the ground, never sunk into it (a
## half-buried crown reads as see-through); it lies east or west only, across the camera's view;
## its crown lands clear of the body, so it is seen; and its stump has the one stump colour.
static func _check_lies(
	decor: CityDecor, group: Dictionary, kaiju: Node3D, foot: Rect2, check: Callable
) -> void:
	var props: PropField = decor._props
	var heights: PackedInt32Array = group["heights"]
	var base: Vector3 = group["at"]
	var before: PackedVector3Array = group["origins"]
	for frame: int in 30:
		decor._process(1.0 / 30.0)
	var after: PackedVector3Array = group["origins"]
	var ground := INF
	for k: int in heights.size():
		if heights[k] == 0:
			ground = after[k].y
	var reach := absf(foot.position.x) * kaiju.scale.x
	var sunk := 0
	var along := 0
	var hidden := 0
	var stumps := 0
	var painted: Color = group.get("stump_color", Color.BLACK)
	for k: int in heights.size():
		var now := after[k]
		var was := before[k]
		if heights[k] < PropField.STUMP:
			stumps += 0 if painted == props.stump_color else 1
			continue
		sunk += 1 if now.y < ground - 0.01 else 0
		along += 1 if absf(now.z - was.z) > 0.01 else 0
		hidden += 1 if absf(now.x - kaiju.position.x) < reach else 0
	check.call(
		sunk + along + hidden + stumps == 0,
		(
			"felled tree at (%.1f, %.1f) lies on the ground east or west, clear of the body"
			% [base.x, base.z]
			+ " (%d cells sunk, %d moved north-south, %d under the body, %d stump cells not the stump colour)"
			% [sunk, along, hidden, stumps]
		)
	)
