extends RefCounted
## D-083 (director 2026-10-19: "a city caught unaware - have our reptilian emerge from a river
## to start each run"): the city suite's river check, called from its D-062 loop for each stage
## and map_seed. The city has a river, the same at every stage, with no building in it; a run
## the game starts puts the kaiju in the river, under the water; the run's clock waits while it
## rises and wades out; then the sim says "kaiju_emerged" once, with the kaiju standing on land
## inside the arena, out of the river (at every stage: the grown city's arena takes the river in).

const DT := 1.0 / 30.0
const LIMIT := 20.0  # seconds: the rise and the wade take a few


static func check(tier: int, map_seed: int, sim: RampageSim, check_fn: Callable) -> void:
	var plan := CityGen.map(sim.city)
	var spawn: Vector2 = plan.get("river_spawn", Vector2(INF, INF))
	var rivers: Array[Rect2] = []
	for block: Dictionary in plan["blocks"]:
		if str(block["use"]) == "river":
			var rect: Rect2 = block["rect"]
			rivers.append(rect)
	var built := 0
	for b: RampageSim.Building in sim.buildings:
		var foot := Rect2(b.x - b.w * 0.5, b.z - b.d * 0.5, b.w, b.d)
		for rect: Rect2 in rivers:
			if rect.intersects(foot):
				built += 1
	var in_river := false
	for rect: Rect2 in rivers:
		in_river = in_river or rect.has_point(spawn)
	var stage_one: Dictionary = CityGrowth.tuning_for(_with_seed(map_seed), 1)["city"]
	var same: bool = CityGen.map(stage_one).get("river", Vector2.ZERO) == plan.get("river")
	var clock := sim.time_left
	sim.emerge.start(sim)
	var started := sim.kaiju_pos == spawn and sim.stand_y < 0.0
	var waited := 0.0
	var emerged := 0
	var clock_held := true
	while emerged == 0 and waited < LIMIT:
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			if str(event["type"]) == "kaiju_emerged":
				emerged += 1
		waited += DT
		clock_held = clock_held and (emerged > 0 or sim.time_left == clock)
	var landed := sim.clamp_to_arena(sim.kaiju_pos) == sim.kaiju_pos and sim.stand_y == 0.0
	for rect: Rect2 in rivers:
		landed = landed and not rect.has_point(sim.kaiju_pos)
	check_fn.call(
		(
			not rivers.is_empty()
			and in_river
			and built == 0
			and same
			and started
			and emerged == 1
			and clock_held
			and landed
		),
		(
			(
				"stage %d, map_seed %d: river start (%d river blocks, spawn %s in one: %s, %d"
				+ " buildings in it, same river as stage 1: %s; rose from under the water: %s,"
				+ " emerged after %.1f s: %s, clock held: %s, out of the river, in the arena: %s)"
			)
			% [
				tier,
				map_seed,
				rivers.size(),
				spawn,
				in_river,
				built,
				same,
				started,
				waited,
				emerged == 1,
				clock_held,
				landed
			]
		)
	)


static func _with_seed(map_seed: int) -> Dictionary:
	var base: Dictionary = Content.tuning().duplicate(true)
	var city: Dictionary = base["city"]
	city["map_seed"] = map_seed
	return base
