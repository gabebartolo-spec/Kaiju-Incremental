extends SceneTree
## People crushed per minute in autoplayed scene rampages (the flow suite's set-up: city seed N,
## CityGen.generate, autoplay), one line per seed: people the kaiju crushed (stomps, falls,
## claws), people tanks ran over, sim seconds, kaiju kills per minute. --trace prints, for each
## crush the kaiju makes, its radius and the nearest person (how close it came).
##
##   godot --headless --fixed-fps 60 --path . --script tools/capture/probe_crush.gd --
##     --seeds=0-11 [--species=cephalopod] [--frames=4500] [--trace]

var _from := 0
var _to := 11
var _species := "cephalopod"
var _frames := 60 * 75
var _trace := false


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			var parts := arg.substr(8).split("-")
			_from = parts[0].to_int()
			_to = parts[parts.size() - 1].to_int()
		elif arg.begins_with("--species="):
			_species = arg.substr(10)
		elif arg.begins_with("--frames="):
			_frames = arg.substr(9).to_int()
		elif arg == "--trace":
			_trace = true
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var kaiju_sum := 0
	var tank_sum := 0
	var secs_sum := 0.0
	var zero := 0
	for seed: int in range(_from, _to + 1):
		var row := await _one(seed)
		kaiju_sum += row[0]
		tank_sum += row[1]
		secs_sum += row[2]
		zero += 1 if row[0] == 0 else 0
	print(
		(
			"TOTAL %s seeds %d-%d: kaiju %d (%.1f/min), tanks %d (%.1f/min), seeds with none %d"
			% [
				_species,
				_from,
				_to,
				kaiju_sum,
				kaiju_sum * 60.0 / maxf(1.0, secs_sum),
				tank_sum,
				tank_sum * 60.0 / maxf(1.0, secs_sum),
				zero
			]
		)
	)
	quit(0)


func _one(seed: int) -> Array:
	var rampage := Rampage.new()
	var species := Content.species_def(_species)
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", seed), Content.section("city")), 0
	)
	rampage.set_autoplay(true)
	root.add_child(rampage)
	await process_frame
	var street := _street_life(rampage)
	var frames := 0
	var rings := 0
	var by_kaiju := 0
	var by_tanks := 0
	while not rampage.sim.over and frames < _frames:
		await physics_frame
		frames += 1
		if is_instance_valid(street):  # the street goes with the rampage's end beat
			if _trace and street.kaiju_killed() > by_kaiju:
				var more := street.kaiju_killed() - by_kaiju
				print("  t %.2f the kaiju crushes %d" % [frames / 60.0, more])
			by_kaiju = street.kaiju_killed()
			by_tanks = street.run_over
		if _trace and is_instance_valid(street) and rampage.stomp_ring_at.size() > rings:
			rings = rampage.stomp_ring_at.size()
			_near("stomp", street, rampage.stomp_ring_at[rings - 1], frames)
		if _trace and is_instance_valid(street):
			for e: Dictionary in rampage.sim.events:
				if str(e["type"]) == "fall_land":
					_landed(e, rampage.sim, street, frames)
	var secs := frames / 60.0
	print(
		(
			"seed %d: kaiju %d, tanks %d, %.1f s, kaiju/min %.1f"
			% [seed, by_kaiju, by_tanks, secs, by_kaiju * 60.0 / maxf(1.0, secs)]
		)
	)
	rampage.queue_free()
	await process_frame
	return [by_kaiju, by_tanks, secs]


func _near(what: String, street: StreetLife, at: Vector3, frames: int) -> void:
	var c := Vector2(at.x, at.z)
	var near := INF
	var within := [0, 0, 0, 0]  # people within 3, 4, 6 and 8 m
	for spot: Vector2 in street.pos:
		var d := spot.distance_to(c)
		near = minf(near, d)
		for k: int in 4:
			within[k] += 1 if d <= [3.0, 4.0, 6.0, 8.0][k] else 0
	var line := "  t %.1f %s: nearest person %.1f, within 3/4/6/8 m %s"
	print(line % [frames / 60.0, what, near, within])


## How close the people were to a landing fall: a topple's strip (from..to, half its width) or
## a dropped section's footprint.
func _landed(e: Dictionary, sim: RampageSim, street: StreetLife, frames: int) -> void:
	var near := INF
	var reach := 0.0
	if str(e["kind"]) == "topple":
		var from: Vector2 = e["from"]
		var to: Vector2 = e["to"]
		reach = Num.f(e["width"]) * 0.6
		for at: Vector2 in street.pos:
			var q := Geometry2D.get_closest_point_to_segment(at, from, to)
			near = minf(near, at.distance_to(q))
	else:
		var b := sim.buildings[Num.i(e["building"])]
		reach = maxf(b.w, b.d) * 0.5 + 0.8
		for at: Vector2 in street.pos:
			near = minf(near, at.distance_to(Vector2(b.x, b.z)))
	print(
		(
			"  t %.1f %s lands: crushes within %.1f, nearest person %.1f"
			% [frames / 60.0, e["kind"], reach, near]
		)
	)


func _street_life(node: Node) -> StreetLife:
	if node is StreetLife:
		var found: StreetLife = node
		return found
	for child: Node in node.get_children():
		var hit := _street_life(child)
		if hit != null:
			return hit
	return null
