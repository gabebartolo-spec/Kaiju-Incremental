extends RefCounted
## The per-frame scan that was indexed (perf: the director picked faster scans): the lights nearest
## the camera (LightPool.nearest, the best few kept as it scans instead of a sort of every lamp).
## It runs a recorded camera path through a real city and must give the very same set in the very
## same order as the old scan (copied below as the reference), frame by frame; it prints its old
## and new cost per frame.

const Kit := preload("res://tools/capture/capture_kit.gd")
const LIGHT_STEP := 7  # every this-th lamp is a camera spot on the recorded light path


## The adult stage's city (seed 0) with its kaiju.
static func _adult() -> RampageSim:
	var tree := UpgradeTree.new(Content.upgrades(), Kit.STAGE_LEVELS[2], "reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), Content.species_def("reptilian"), tree
	)
	var layout := CityGrowth.layout(Content.tuning(), Num.i(stats["size"]), Seeds.make("city", 0))
	return RampageSim.new(stats, CityGrowth.for_stats(stats), layout, Seeds.make("army", 0))


## LightPool.nearest over the adult city's night lamps along a recorded path, and over a lattice of
## equidistant lights with some dark ones (ties go to the earlier light in the tree).
static func lights(root: Node, check: Callable) -> void:
	Content.set_time(Content.time_for_run(1))  # night: the lamps are lit
	var sim := _adult()
	var holder := Node3D.new()
	root.add_child(holder)
	var pool := LightPool.new()
	holder.add_child(pool)
	holder.add_child(CityDecor.new(sim, Seeds.make("decor", 0)))
	var lamps := root.get_tree().get_nodes_in_group(PooledLight.GROUP)
	var same := true
	var old_us := 0
	var new_us := 0
	var calls := 0
	var k := 0
	while k < lamps.size():
		var eye := (lamps[k] as PooledLight).global_position + Vector3(0, 20, 12)
		var t0 := Time.get_ticks_usec()
		var was := _nearest_reference(pool, eye)
		var t1 := Time.get_ticks_usec()
		var now := pool.nearest(eye)
		var t2 := Time.get_ticks_usec()
		old_us += t1 - t0
		new_us += t2 - t1
		calls += 1
		same = same and was == now
		k += LIGHT_STEP
	print(
		(
			"SCANS lights: %d lamps, %d camera spots; old nearest %.3f ms/call, packed %.3f ms/call"
			% [lamps.size(), calls, old_us / 1000.0 / calls, new_us / 1000.0 / calls]
		)
	)
	check.call(
		calls > 20 and lamps.size() > 100,
		"the recorded path visits %d spots among %d lamps" % [calls, lamps.size()]
	)
	(
		check
		. call(
			same,
			"LightPool.nearest names the same lights in the same order as sorting every lamp, at every spot"
		)
	)
	holder.free()
	# Ties: a lattice round the origin has many lights at one distance; the order falls to the
	# tree order.
	var grid := Node3D.new()
	root.add_child(grid)
	var pool2 := LightPool.new()
	grid.add_child(pool2)
	var made := 0
	for x: int in range(-4, 5):
		for z: int in range(-4, 5):
			var light := PooledLight.new("lamp")
			light.set_energy(0.0 if (x * 7 + z * 3) % 5 == 0 else 1.0)  # some are dark
			light.position = Vector3(x, 0, z)
			grid.add_child(light)
			made += 1
	var ties := true
	for at: Vector3 in [Vector3.ZERO, Vector3(0.5, 0, 0.5), Vector3(2, 0, 0), Vector3(-9, 3, 4)]:
		ties = ties and _nearest_reference(pool2, at) == pool2.nearest(at)
	check.call(
		ties,
		"equidistant, dark and distant lights come out as the old sort had them (%d lights)" % made
	)
	grid.free()
	Content.set_time(Content.time_for_run(0))


## The old LightPool.nearest: key every lit light by (distance, tree index), sort, take pool_size.
static func _nearest_reference(pool: LightPool, origin: Vector3) -> Array[PooledLight]:
	var all := pool.get_tree().get_nodes_in_group(PooledLight.GROUP)
	var keyed: Array[Vector2] = []
	for i: int in all.size():
		var light: PooledLight = all[i]
		if light.is_inside_tree() and light.energy > 0.0:
			keyed.append(Vector2(light.global_position.distance_to(origin), i))
	keyed.sort_custom(
		func(a: Vector2, b: Vector2) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y)
	)
	var out: Array[PooledLight] = []
	for key: Vector2 in keyed.slice(0, Num.i(Content.section("lights")["pool_size"])):
		out.append(all[int(key.y)])
	return out
