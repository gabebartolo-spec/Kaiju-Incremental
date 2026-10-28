extends "res://tests/lib/powers_base.gd"
## The insectoid branch checks of the powers suite (run_powers_tests runs them): scuttle, glide,
## climb, brood and the streets.


func _check_scuttle() -> void:
	var dist: Array[float] = []
	for levels: Dictionary in [{}, {"i_scuttle": 2}]:
		var sim := _sim("insectoid", levels, [], Vector2(0, 20))
		_run(sim, 2.0, NORTH)
		dist.append(20.0 - sim.kaiju_pos.y)
	check(
		dist[1] > dist[0] * 1.15, "Scuttle covers more ground (%.1f vs %.1f)" % [dist[1], dist[0]]
	)


## Wing Buzz: tap leaps; holding the button glides on, steering, then lands with a crush.
func _check_glide() -> void:
	var out: Array[Dictionary] = []
	for levels: Dictionary in [{}, {"i_glide": 1}]:
		var sim := _sim("insectoid", levels, [_b(0, -14, Vector3i(3, 3, 3))], Vector2(0, 0))
		sim.facing = NORTH
		var seen := _run(sim, 1.5, NORTH, PRESS | HOLD)
		out.append({"y": sim.kaiju_pos.y, "seen": seen})
	var with: Dictionary = out[1]["seen"]
	var without: Dictionary = out[0]["seen"]
	check(
		with.has("glide_start") and with.has("glide_land") and not without.has("glide_start"),
		"holding the leap button glides and lands again only with Wing Buzz"
	)
	check(
		Num.f(out[1]["y"]) < Num.f(out[0]["y"]) - 2.0,
		(
			"the glide carries it further than the leap alone (%.1f vs %.1f)"
			% [-Num.f(out[1]["y"]), -Num.f(out[0]["y"])]
		)
	)


## Climber: on a tall tower, the insectoid climbs to the roof and breaks the top floors,
## far above what it can reach from the street.
func _check_climb() -> void:
	var top_hit: Array[int] = []
	var stood: Array[float] = []
	for levels: Dictionary in [{}, {"i_climb": 1}]:
		var sim := _sim("insectoid", levels, [_b(0, 0, Vector3i(3, 3, 16))], Vector2(0, 3.0))
		var highest := -1
		for i: int in 30 * 6:
			for event: Dictionary in sim.step(DT, NORTH if i < 13 else Vector2.ZERO, false):
				if str(event["type"]) == "chunks_broken":
					for c: Vector3i in event["cells"]:
						highest = maxi(highest, c.y)
		top_hit.append(highest)
		stood.append(sim.stand_y)
	var reach := _sim("insectoid", {}, [], Vector2.ZERO).reach_height()
	check(
		top_hit[0] < reach and top_hit[1] > reach + 4,
		(
			"climbing breaks floors far above street reach (floor %d vs %d, reach %.1f)"
			% [top_hit[1], top_hit[0], reach]
		)
	)
	check(stood[0] == 0.0, "without Climber the insectoid stays on the street")


## Brood: E lays eggs that hatch into young who bite the city and draw the tanks' fire.
func _check_brood() -> void:
	var ring: Array[Dictionary] = [
		_b(6, 0, Vector3i(3, 3, 3)), _b(-6, 0, Vector3i(3, 3, 3)), _b(0, 6, Vector3i(3, 3, 3))
	]
	var out: Array[RampageSim] = []
	for levels: Dictionary in [{}, {"i_brood": 1}]:
		var sim := _sim("insectoid", levels, ring, Vector2(0, -8))
		_run(sim, 0.1, Vector2.ZERO, ULT)
		_run(sim, 10.0, Vector2.ZERO)
		out.append(sim)
	check(
		out[0].brood.hatched == 0 and out[1].brood.hatched == 3,
		"E lays three eggs that hatch only with Brood (%d)" % out[1].brood.hatched
	)
	check(
		out[1].brood.bites > 5 and out[1].chunks_destroyed > out[0].chunks_destroyed,
		(
			"the young bite the city on their own (%d bites, %d vs %d chunks)"
			% [out[1].brood.bites, out[1].chunks_destroyed, out[0].chunks_destroyed]
		)
	)
	var sim := out[1]
	var tank := RampageSim.Tank.new()
	tank.id = 900
	tank.hp = 999.0
	tank.cooldown = 0.0
	tank.pos = (
		sim.brood.young[0].pos + Vector2(3, 0)
		if not sim.brood.young.is_empty()
		else Vector2(40, 40)
	)
	sim.tanks.append(tank)
	var shot_young := false
	for i: int in 30 * 3:
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			if str(event["type"]) == "tank_fired" and event.has("at"):
				shot_young = true
	check(shot_young, "a tank near the young fires on them instead of the kaiju")


## The building slow does not grow with the kaiju (lead review): a grown kaiju with no branch
## node strides down a 4-wide street lined with blocks at full speed, past every block.
func _check_streets() -> void:
	var street: Array[Dictionary] = []
	for n: int in 6:
		for side: float in [-3.5, 3.5]:
			street.append(_b(side, 34.0 - n * 8.0, Vector3i(3, 6, 4), 3))
	var grown := {"claws": 5, "hide": 5, "rage": 1, "evolve1": 1, "evolve2": 1}
	var slow: Array[String] = []
	for species_id: String in ["reptilian", "insectoid", "cephalopod"]:
		for levels: Dictionary in [{}, grown]:
			var sim := _sim(species_id, levels, street, Vector2(0, 40))
			_run(sim, 2.0, NORTH)
			var free := sim.stat("speed") * 2.0
			if 40.0 - sim.kaiju_pos.y < free * 0.95:
				slow.append(
					(
						"%s tier %d: %.1f of %.1f"
						% [species_id, sim.size_tier(), 40.0 - sim.kaiju_pos.y, free]
					)
				)
	check(slow.is_empty(), "young and grown kaiju walk a city street at full speed: %s" % [slow])
	# The street runs z 37 .. -9 (inside the arena's +-44.5); the kaiju starts at z 40.
	var far := _sim("reptilian", grown, street, Vector2(0, 40))
	_run(far, 11.0, NORTH)
	check(
		far.kaiju_pos.y < -10.0,
		(
			"a tier-3 kaiju with no branch passes all six blocks in 11 s (at z %.0f, past -10)"
			% far.kaiju_pos.y
		)
	)
