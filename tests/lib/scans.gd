extends RefCounted
## The two per-frame scans that were indexed (perf: the director picked faster scans): the
## buildings a sight line crosses (BuildingFade, a grid of footprints instead of every building)
## and the lights nearest the camera (LightPool.nearest, the best few kept as it scans instead of
## a sort of every lamp). Each runs a recorded camera path through a real city and must give the
## very same sets in the very same order as the old scan (copied below as the reference), frame by
## frame, with the fade's opacities equal too; each prints its old and new cost per frame.

const Growth := preload("res://tools/capture/capture_growth.gd")
const DT := 1.0 / 60.0
const FRAMES := 600
## The kaiju walks the city's length at this speed; the breath swings the camera while it goes.
const WALK := 20.0
const SWING_DEG := 25.0
const LIGHT_STEP := 7  # every this-th lamp is a camera spot on the recorded light path


## BuildingFade on stage 4's 4,435 buildings along a recorded walk.
static func fade(check: Callable) -> void:
	var sim := _stage4()
	var cfg := Content.section("vehicles")
	var fader := BuildingFade.new(sim.buildings, func(_n: int) -> BuildingView: return null)
	var rest := CameraTuning.offset() * CameraTuning.zoom(sim.body_scale())
	var low := Num.f(cfg["fade_opacity"])
	var step := DT / Num.f(cfg["fade_seconds"])
	var ref_faded := {}
	var ref_first := true
	var same_sets := true
	var same_fade := true
	var busy := 0
	var old_us := 0
	var new_us := 0
	sim.facing = Vector2(0, -1)
	for f: int in FRAMES:
		sim.kaiju_pos = sim.clamp_to_arena(
			Vector2(sin(f * 0.01) * 20.0, sim.arena_half - WALK * DT * f)
		)
		var swing := rest.rotated(Vector3.UP, deg_to_rad(SWING_DEG * sin(f * 0.05)))
		var eye := Vector3(sim.kaiju_pos.x, 0, sim.kaiju_pos.y) + swing
		var sight := BuildingFade.sight_of(sim)
		var t0 := Time.get_ticks_usec()
		var was := _reference(sim.buildings, eye, sight)
		var t1 := Time.get_ticks_usec()
		var now := fader.blocking(eye, sight)
		var t2 := Time.get_ticks_usec()
		old_us += t1 - t0
		new_us += t2 - t1
		same_sets = same_sets and was == now
		busy += 1 if not now.is_empty() else 0
		# The whole update against the old update's easing, fed the old scan's set.
		fader.update(eye, sight, DT)
		var hit := {}
		for n: int in was:
			hit[n] = true
		for n: int in hit:
			if not ref_faded.has(n):
				ref_faded[n] = low if ref_first else 1.0
		ref_first = false
		for n: int in ref_faded.keys():
			var cur: float = ref_faded[n]
			var next := move_toward(cur, low if hit.has(n) else 1.0, step)
			if next >= 1.0:
				ref_faded.erase(n)
			else:
				ref_faded[n] = next
		for n: int in ref_faded:
			var want: float = ref_faded[n]
			same_fade = same_fade and is_equal_approx(fader.opacity(n), want)
	print(
		(
			(
				"SCANS fade: %d buildings, %d frames, a building in a sight line on %d; old scan %.3f"
				+ " ms/frame, indexed %.3f ms/frame"
			)
			% [
				sim.buildings.size(),
				FRAMES,
				busy,
				old_us / 1000.0 / FRAMES,
				new_us / 1000.0 / FRAMES
			]
		)
	)
	check.call(
		busy > FRAMES / 4, "the recorded walk crosses buildings on %d of %d frames" % [busy, FRAMES]
	)
	check.call(
		same_sets,
		"the indexed fade scan names the same buildings in the same order as scanning all of them"
	)
	check.call(same_fade, "every faded building's opacity matches the old scan's on every frame")


## Stage 4's city (seed 0) with its kaiju.
static func _stage4() -> RampageSim:
	var tree := UpgradeTree.new(Content.upgrades(), Growth.LEVELS[3], "reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), Content.species_def("reptilian"), tree
	)
	var layout := CityGrowth.layout(Content.tuning(), Num.i(stats["size"]), Seeds.make("city", 0))
	return RampageSim.new(stats, CityGrowth.for_stats(stats), layout, Seeds.make("army", 0))


## The old scan, as it was in BuildingFade.update: every building, the cheap rectangle, then
## blocks().
static func _reference(
	buildings: Array[RampageSim.Building], eye: Vector3, sight: PackedVector3Array
) -> PackedInt32Array:
	var lo := Vector2(eye.x, eye.z)
	var hi := lo
	for p: Vector3 in sight:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	var out := PackedInt32Array()
	for n: int in buildings.size():
		var b := buildings[n]
		if b.x + b.w * 0.5 < lo.x or b.x - b.w * 0.5 > hi.x:
			continue
		if b.z + b.d * 0.5 < lo.y or b.z - b.d * 0.5 > hi.y:
			continue
		if BuildingFade.blocks(eye, sight, b):
			out.append(n)
	return out


## LightPool.nearest over stage 4's night city lamps along a recorded path, and over a lattice of
## equidistant lights with some dark ones (ties go to the earlier light in the tree).
static func lights(root: Node, check: Callable) -> void:
	Content.set_time(Content.time_for_run(1))  # night: the lamps are lit
	var sim := _stage4()
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
