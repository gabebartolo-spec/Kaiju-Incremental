extends SceneTree
## People crushed per minute in autoplayed scene rampages (the flow suite's set-up: city seed N,
## CityGen.generate, autoplay), one line per seed: street kills, all civilians killed, sim
## seconds, kills per minute, kaiju path length. Used to tell a real turn-weight regression
## (the arcing walk dodges crowds) from a seed that flipped (lead 10, 2026-10-21).
##
##   godot --headless --path . --script tools/capture/probe_crush.gd -- --seeds=0-11
##     [--species=cephalopod] [--frames=4500]

var _from := 0
var _to := 11
var _species := "cephalopod"
var _frames := 60 * 75
var _trace := false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			var parts := arg.substr(8).split("-")
			_from = parts[0].to_int()
			_to = parts[parts.size() - 1].to_int()
		elif arg.begins_with("--species="):
			_species = arg.substr(10)
		elif arg == "--trace":
			_trace = true
		elif arg.begins_with("--frames="):
			_frames = arg.substr(9).to_int()
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var street_sum := 0
	var all_sum := 0
	var secs_sum := 0.0
	for seed: int in range(_from, _to + 1):
		var row := await _one(seed)
		street_sum += row[0]
		all_sum += row[1]
		secs_sum += row[2]
	print(
		(
			"TOTAL %s seeds %d-%d: street %d, all %d, %.0f s, street/min %.1f, all/min %.1f"
			% [
				_species,
				_from,
				_to,
				street_sum,
				all_sum,
				secs_sum,
				street_sum * 60.0 / maxf(1.0, secs_sum),
				all_sum * 60.0 / maxf(1.0, secs_sum)
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
	var feet := [0]
	var model: KaijuModel = rampage.get("_kaiju")
	if model != null:
		model.foot_planted.connect(func(_s: String, _f: float, _a: Vector3) -> void: feet[0] += 1)
	var frames := 0
	var rings := 0
	var dead := 0
	var path := 0.0
	var last := rampage.sim.kaiju_pos
	while not rampage.sim.over and frames < _frames:
		await physics_frame
		frames += 1
		var types: Array[String] = []
		for e: Dictionary in rampage.sim.events:
			types.append(str(e["type"]))

		if _trace and frames % 120 == 0 and frames >= 1800:
			var row: Array[String] = []
			for tank: RampageSim.Tank in rampage.sim.tanks:
				row.append("%d@%v" % [tank.id, tank.pos.snapped(Vector2(1, 1))])
			print("  t %.0f k %v %s" % [frames / 60.0, rampage.sim.kaiju_pos.snapped(Vector2(1, 1)), " ".join(row)])
		if false and frames % 300 == 0:
			var near_t := INF
			for tank: RampageSim.Tank in rampage.sim.tanks:
				near_t = minf(near_t, tank.pos.distance_to(rampage.sim.kaiju_pos))
			print(
				(
					"  t %.0f tanks %d nearest tank %.1f destruction %.3f killed %d"
					% [frames / 60.0, rampage.sim.tanks.size(), near_t, Num.f(rampage.sim.result()["destruction"]), street.killed]
				)
			)
		if false and (frames % 60 == 0 or street.killed > dead):
			var kp := rampage.sim.kaiju_pos
			var near := INF
			var cops := 0
			for person: StreetLife.Person in street.people:
				near = minf(near, person.pos.distance_to(kp))
				if person.cop and person.pos.distance_to(kp) < 10.0:
					cops += 1
			print(
				(
					"  t %.1f at %v heading %v nearest %.1f cops<10 %d killed %d %s"
					% [frames / 60.0, kp.snapped(Vector2(0.1, 0.1)), rampage.sim.body.heading.snapped(Vector2(0.01, 0.01)), near, cops, street.killed, types]
				)
			)
		if false and rampage.stomp_ring_at.size() > rings:
			rings = rampage.stomp_ring_at.size()
			var at: Vector3 = rampage.stomp_ring_at[rings - 1]
			var foot := Vector2(at.x, at.z)
			var near := INF
			for person: StreetLife.Person in street.people:
				near = minf(near, person.pos.distance_to(foot))
			print(
				(
					"  t %.1f stomp at %.1f from the body, nearest person %.1f, radius %.1f"
					% [
						frames / 60.0,
						foot.distance_to(rampage.sim.kaiju_pos),
						near,
						rampage.get("_stomp_radius")
					]
				)
			)
		dead = street.killed
		path += rampage.sim.kaiju_pos.distance_to(last)
		last = rampage.sim.kaiju_pos
	var secs := frames / 60.0
	var k := street.killed if street != null else -1
	var all := street.civilians_killed() if street != null else -1
	print(
		(
			(
				"seed %d: street %d, all %d, %.1f s, street/min %.1f, path %.0f, footfalls %d,"
				+ " stomps landed %d, blockades %d, tanks %d"
			)
			% [
				seed,
				k,
				all,
				secs,
				k * 60.0 / maxf(1.0, secs),
				path,
				feet[0],
				rampage.stomp_ring_at.size(),
				street.police.blockades_made,
				rampage.sim.tanks.size()
			]
		)
	)
	rampage.queue_free()
	await process_frame
	return [k, all, secs]


func _street_life(node: Node) -> StreetLife:
	if node is StreetLife:
		var found: StreetLife = node
		return found
	for child: Node in node.get_children():
		var hit := _street_life(child)
		if hit != null:
			return hit
	return null
