extends RefCounted
## The city's positional lights are pooled (R 12.1, R 12.2): at night the city holds more street
## lamps than gl_compatibility lights a frame (32, rendering/limits/opengl/max_renderable_lights),
## and with fires and beacons burning, still no more than lights.pool_size are drawn at any
## moment, hand-over included; the lamp nearest the camera always holds a real light, and
## the pool follows the camera when it moves. Every lamp, fire and beacon also fades with camera
## distance, and small lights cast no shadow.

const GL_CAP := 32  # positional lights a frame in gl_compatibility
const STAGE := 2  # growth stage of the fixture city
const FADE_STEP := 0.1  # seconds the lights fade between two checks
const SETTLE := 8  # steps for a hand-over to finish (fade_seconds is well under SETTLE * STEP)


static func check(root: Node, check_fn: Callable) -> void:
	Content.set_time(Content.time_for_run(1))  # night: the lamps are lit
	var pool_size := Num.i(Content.section("lights")["pool_size"])
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	# The Behemoth's city: since the road geometry fix (D-265) the first stage's bigger blocks
	# carry fewer lamps than the cap, and the pool must be shown handling more than the cap.
	var tuning := CityGrowth.tuning_for(Content.tuning(), STAGE)
	var city: Dictionary = tuning["city"]
	var sim := RampageSim.new(
		stats, tuning, CityGen.generate(Seeds.make("city", 0), city), Seeds.make("army", 0)
	)
	var holder := Node3D.new()
	root.add_child(holder)
	var pool := LightPool.new()
	holder.add_child(pool)
	holder.add_child(CityDecor.new(sim, Seeds.make("decor", 0)))
	var cam := Camera3D.new()
	holder.add_child(cam)
	cam.current = true
	var lamps := _lights(holder)
	var spots: Array[Vector3] = [
		lamps[0].global_position,
		lamps[lamps.size() / 2].global_position,
		lamps[lamps.size() - 1].global_position,
	]
	# A fire and a beacon beside the first spot, so fires and beacons share the pool.
	for k: int in 4:
		var fire := Fire.new(1.0, float(k))
		fire.position = spots[0] + Vector3(k, 0, 1)
		holder.add_child(fire)
	var beacon := PooledLight.new("beacon")
	beacon.set_energy(1.6)
	beacon.position = spots[0] + Vector3(2, 1, 2)
	holder.add_child(beacon)
	var all := _lights(holder)
	var worst := 0
	var lit_near := true
	var nothing_far := true
	for at: Vector3 in spots:
		var eye := at + Vector3(0, 20, 12)
		for step: int in SETTLE:
			pool.repick(eye)
			worst = maxi(worst, _visible(all).size())
			_fade(all, FADE_STEP)
			worst = maxi(worst, _visible(all).size())
		var near := _nearest(all, eye)
		lit_near = lit_near and near.visible and near.wanted and near.light_energy > 0.0
		nothing_far = nothing_far and _visible(all).size() <= pool_size
	check_fn.call(
		all.size() > GL_CAP and pool_size < GL_CAP,
		(
			"night city holds %d positional lights, over gl_compatibility's cap %d; pool_size %d"
			% [all.size(), GL_CAP, pool_size]
		)
	)
	check_fn.call(
		worst <= pool_size and nothing_far,
		(
			"at most %d lights drawn (pool_size %d), hand-over included; worst %d of %d lights"
			% [pool_size, pool_size, worst, all.size()]
		)
	)
	check_fn.call(lit_near, "the light nearest the camera is lit, at three places in the city")
	_check_follow(pool, cam, all, spots, check_fn)
	_check_fades(all, check_fn)
	holder.free()
	Content.set_time(Content.time_for_run(0))


## The camera moves: the pool re-picks from its own process (distance moved), not only on a
## call, and the nearest light there is lit once the hand-over is done.
static func _check_follow(
	pool: LightPool,
	cam: Camera3D,
	all: Array[PooledLight],
	spots: Array[Vector3],
	check_fn: Callable
) -> void:
	cam.global_position = spots[0] + Vector3(0, 20, 12)
	pool._process(0.0)
	cam.global_position = spots[2] + Vector3(0, 20, 12)
	for step: int in SETTLE:
		pool._process(Num.f(Content.section("lights")["repick_seconds"]))
		_fade(all, FADE_STEP)
	var near := _nearest(all, cam.global_position)
	check_fn.call(
		near.visible and near.light_energy > 0.0 and _visible(all).size() <= _size(),
		"a camera that moves away is followed: the lamp nearest it is lit, the pool still full"
	)


## Every light fades with camera distance from data and none casts a shadow.
static func _check_fades(all: Array[PooledLight], check_fn: Callable) -> void:
	var ok := not all.is_empty()
	for light: PooledLight in all:
		ok = ok and light.distance_fade_enabled and light.distance_fade_length > 0.0
		ok = ok and light.distance_fade_begin > 0.0 and not light.shadow_enabled
	check_fn.call(ok, "every lamp, fire and beacon light fades with distance and is unshadowed")


static func _size() -> int:
	return Num.i(Content.section("lights")["pool_size"])


static func _lights(holder: Node) -> Array[PooledLight]:
	var out: Array[PooledLight] = []
	for node: Node in holder.find_children("*", "PooledLight", true, false):
		out.append(node as PooledLight)
	return out


static func _visible(all: Array[PooledLight]) -> Array[PooledLight]:
	return all.filter(func(l: PooledLight) -> bool: return l.is_inside_tree() and l.visible)


static func _fade(all: Array[PooledLight], delta: float) -> void:
	for light: PooledLight in all:
		if light.is_inside_tree():
			light._process(delta)


static func _nearest(all: Array[PooledLight], eye: Vector3) -> PooledLight:
	var best: PooledLight = null
	for light: PooledLight in all:
		if light.is_inside_tree() and light.energy > 0.0:
			if (
				best == null
				or light.global_position.distance_to(eye) < best.global_position.distance_to(eye)
			):
				best = light
	return best
