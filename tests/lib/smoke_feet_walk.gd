extends RefCounted
## The smoke suite's planted-feet drives (run_smoke_tests._check_feet_of), split out to keep the
## runner small: a light body eased after the stick as before D-201, and a heavy body driven by the
## real sim (D-201, lead's ruling 2026-10-24: forward and turning, never crabwise or backing up).


## A light body driven as the rampage drove it before D-201: a walk, a hard reversal, a sideways
## run, then standing, the node eased after the stick, a stomp on the beat.
static func light(kaiju: KaijuModel, stats: Dictionary) -> void:
	var dt := 1.0 / 60.0
	var pos := Vector2.ZERO
	var facing := Vector2(0, -1)
	var stomp_in := 0.0
	for frame: int in 600:
		var t := frame * dt
		var move := Vector2.ZERO
		if t > 0.5 and t < 3.0:
			move = Vector2(0, -1)
		elif t >= 3.0 and t < 5.0:
			move = Vector2(0.4, 1).normalized()  # a hard reversal
		elif t >= 5.0 and t < 7.0:
			move = Vector2(-1, 0)
		if move != Vector2.ZERO:
			pos += move * Num.f(stats["speed"]) * dt
			facing = move
		kaiju.position = kaiju.position.lerp(Vector3(pos.x, 0, pos.y), minf(1.0, dt * 12.0))
		var heading := atan2(-facing.x, -facing.y)
		kaiju.rotation.y = lerp_angle(kaiju.rotation.y, heading, minf(1.0, dt * 10.0))
		stomp_in -= dt
		if stomp_in <= 0.0:
			stomp_in += Num.f(stats["stomp_interval"])
			kaiju.stomp()
		kaiju.animate(dt, move.length())


## A heavy adult driven by the real sim (seeded, no city in the way): stand, walk forward, a 90 deg
## turn to the left on the move, walk on, a turn back to the right, then stand; the model fed as
## Rampage._update_kaiju feeds it (the sim's stomps too). Returns the model, in the tree.
static func heavy(root: Node, species_id: String) -> KaijuModel:
	var def := Content.species_def(species_id)
	var tree := UpgradeTree.new(Content.upgrades(), {"evolve1": 1, "evolve2": 1}, species_id)
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), def, tree)
	var layout: Array[Dictionary] = [
		{"x": 38.0, "z": 38.0, "w": 2, "d": 2, "h": 2, "tier": 1, "style": 0}
	]
	var sim := RampageSim.new(stats, CityGrowth.for_stats(stats), layout, Seeds.make("army", 0))
	sim.body.use_species(species_id)
	sim.kaiju_pos = Vector2(0, 30)
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new(species_id, colors, KaijuModel.stage_for(sim.size_tier()))
	kaiju.scale = Vector3.ONE * sim.body_scale()
	root.add_child(kaiju)
	var dt := 1.0 / 60.0
	for frame: int in 720:
		var t := frame * dt
		var move := Vector2.ZERO
		if t > 0.5 and t < 9.0:
			move = Vector2(0, -1) if t < 3.0 or t >= 7.0 else Vector2(-1, 0)
		for event: Dictionary in sim.step(dt, move, false, 0):
			if str(event["type"]) == "stomp":
				kaiju.stomp()
		kaiju.position = Vector3(sim.kaiju_pos.x, 0.0, sim.kaiju_pos.y)
		kaiju.rotation.y = atan2(-sim.body.heading.x, -sim.body.heading.y)
		kaiju.follow_steps(sim.body.step_clock(), sim.body.step_ratio)
		kaiju.follow_body(sim.body)
		kaiju.animate(dt, move.length(), -sim.body.turn_left)
	return kaiju
