extends RefCounted
## D-083 (director 2026-10-19: "a city caught unaware - have our reptilian emerge from a river
## to start each run"): the city suite's river check, called from its D-062 loop for each stage
## and map_seed. The city has a river, the same at every stage, with no building in it; a run
## the game starts puts the kaiju in the river, under the water; the run's clock waits while it
## rises and wades out; then the sim says "kaiju_emerged" once, with the kaiju standing on land
## inside the arena, out of the river (at every stage: the grown city's arena takes the river in).

const DT := 1.0 / 30.0
## Parked cars keep this far off the channel's edge (CityDecor's water margin): their bodies
## clear the quay walls whichever way they face.
const CAR_CLEAR := 0.5


static func check(tier: int, map_seed: int, sim: RampageSim, check_fn: Callable) -> void:
	var plan := CityGen.map(sim.city)
	var spawn: Vector2 = plan.get("river_spawn", Vector2(INF, INF))
	var rivers: Array[Rect2] = []
	for block: Dictionary in plan["blocks"]:
		if str(block["use"]) == "river":
			var rect: Rect2 = block["rect"]
			rivers.append(rect)
	# The river's blocks and the bay it rises in (CityRiver.bay).
	var wet: Array[Rect2] = rivers.duplicate()
	wet.append_array(CityRiver.bay(plan, sim.city))
	var built := 0
	for b: RampageSim.Building in sim.buildings:
		var foot := Rect2(b.x - b.w * 0.5, b.z - b.d * 0.5, b.w, b.d)
		for rect: Rect2 in wet:
			if rect.intersects(foot):
				built += 1
	var in_river := false
	for rect: Rect2 in wet:
		in_river = in_river or rect.has_point(spawn)
	var stage_one: Dictionary = CityGrowth.tuning_for(_with_seed(map_seed), 1)["city"]
	var same: bool = CityGen.map(stage_one).get("river", Vector2.ZERO) == plan.get("river")
	var clock := sim.time_left
	sim.emerge.start(sim)
	var started := false  # under the water, in the river or its bay
	for rect: Rect2 in CityRiver.water(plan, sim.city):
		started = started or (rect.has_point(sim.kaiju_pos) and sim.stand_y < 0.0)
	var waited := 0.0
	var emerged := 0
	var clock_held := true
	var limit := Num.f(Content.tuning()["emerge"]["max_seconds"]) + 1.0  # past the stall cap
	while emerged == 0 and waited < limit:
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			if str(event["type"]) == "kaiju_emerged":
				emerged += 1
		waited += DT
		clock_held = clock_held and (emerged > 0 or sim.time_left == clock)
	var landed := sim.clamp_to_arena(sim.kaiju_pos) == sim.kaiju_pos and sim.stand_y == 0.0
	for rect: Rect2 in wet:
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


## The river's look, from the plan and the decor (lead FIX 2026-10-19 on #88): one sunk channel
## from the west end of the street grid to the east, bridges in every gap along it and none
## over solid ground, no building standing in the channel (a landmark's site in the river row
## included), no parked car within CAR_CLEAR of the water or its quay walls (its centre half a
## car length further), and a building within city "quay" "reach" of where the kaiju steps out
## (no empty space at the landing).
static func check_look(
	tier: int, map_seed: int, sim: RampageSim, decor: CityDecor, check_fn: Callable
) -> void:
	var plan := CityGen.map(sim.city)
	if not plan.has("river"):
		return
	var channels := CityRiver.channels(plan, sim.city)
	var bridges := CityRiver.bridges(plan, sim.city)
	var spans := 0
	var covered := true
	var west := INF
	var east := -INF
	for block: Dictionary in plan["blocks"]:
		if str(block["use"]) == "river":
			var rect: Rect2 = block["rect"]
			spans += 1
			west = minf(west, rect.position.x)
			east = maxf(east, rect.end.x)
			covered = covered and not channels.is_empty() and channels[0].encloses(rect)
	var whole := (
		channels.size() == 1 and channels[0].position.x <= west and channels[0].end.x >= east
	)
	var bridged := true
	for deck: Rect2 in bridges:
		bridged = bridged and not channels.is_empty() and channels[0].encloses(deck)
		for block: Dictionary in plan["blocks"]:
			if str(block["use"]) == "river":
				var rect: Rect2 = block["rect"]
				bridged = bridged and not rect.intersects(deck)
	var in_water := 0
	for car: Rect2 in decor.cars:
		for channel: Rect2 in channels:
			if channel.grow(CAR_CLEAR + CityDecor.CAR_HALF.y).has_point(car.get_center()):
				in_water += 1
	var bank: Vector2 = plan.get("river_bank", Vector2(INF, INF))
	var landing := sim.clamp_to_arena(bank)
	var reach := Num.f(sim.city["quay"]["reach"])
	var near := 0
	var wet := 0
	for b: RampageSim.Building in sim.buildings:
		var foot := Rect2(b.x - b.w * 0.5, b.z - b.d * 0.5, b.w, b.d)
		if landing.clamp(foot.position, foot.end).distance_to(landing) <= reach:
			near += 1
		if not channels.is_empty() and channels[0].intersects(foot):
			wet += 1
	check_fn.call(
		whole and covered and bridged and in_water == 0 and near > 0 and wet == 0,
		(
			(
				"stage %d, map_seed %d: river look (%d river blocks in %d channel(s) spanning them:"
				+ " %s, %d bridges, all over water: %s, %d buildings in the channel, %d cars on"
				+ " the water or its quays, %d buildings within %.0f m of the landing %s)"
			)
			% [
				tier,
				map_seed,
				spans,
				channels.size(),
				whole and covered,
				bridges.size(),
				bridged,
				wet,
				in_water,
				near,
				reach,
				landing
			]
		)
	)


## The start can never stall (sim review FIX 2026-10-20 on #88): with city "river_inset" 0 the
## bank point lies on the river's sidewalk, inside the sunk channel, and in the Behemoth city
## (stage 2) the arena does not clamp it back onto land, so the wade never climbs out.
## Without the cap (max_seconds pushed out of reach) the kaiju is still wading past tuning
## "emerge" "max_seconds"; with it, it stands on the bank and the sim says "kaiju_emerged" once,
## by that time. Seeded by design: the default map_seed, no randomness in the rise or the wade.
static func check_cap(check_fn: Callable) -> void:
	var shipped: Dictionary = Content.tuning().duplicate(true)
	shipped["city"]["river_inset"] = 0.0
	var base := CityGrowth.tuning_for(shipped, 2)  # its arena takes the river in: no clamp out
	var city: Dictionary = base["city"]
	var cap := Num.f(base["emerge"]["max_seconds"])
	var bank: Vector2 = CityGen.map(city).get("river_bank", Vector2(INF, INF))
	var wet := false
	for channel: Rect2 in CityRiver.channels(CityGen.map(city), city):
		wet = wet or channel.has_point(bank)
	(
		check_fn
		. call(
			cap > Num.f(base["emerge"]["rise_seconds"]),
			(
				"tuning emerge max_seconds (%.1f) is longer than rise_seconds (the cap cannot cut the rise)"
				% cap
			)
		)
	)
	var uncapped: Dictionary = base.duplicate(true)
	uncapped["emerge"]["max_seconds"] = INF
	var stalled := _emerge_for(uncapped, cap + 1.0)
	var capped := _emerge_for(base, cap + 1.0)
	check_fn.call(
		wet and stalled["emerged"] == 0 and capped["emerged"] == 1 and capped["landed"],
		(
			(
				"river start never stalls (bank %s in the channel: %s; no cap: emerged %d times"
				+ " in %.1f s; cap %.1f s: emerged %d time(s) after %.2f s, on its feet: %s)"
			)
			% [
				bank,
				wet,
				stalled["emerged"],
				cap + 1.0,
				cap,
				capped["emerged"],
				capped["at"],
				capped["landed"]
			]
		)
	)


## No landmark ever stands in the river (sim review FIX 2026-10-20 on #88): with a landmark's
## anchor moved onto the river's row, at points along it, its site never covers that row, so no
## landmark's ground meets the channel (CityRiver.channels runs on under every gap). Seeded by
## design: the default map_seed, the plan is pure.
static func check_sites(check_fn: Callable) -> void:
	var placed := 0
	var wet := 0
	var tried := 0
	for x: float in [-30.0, -15.0, 0.0, 15.0, 30.0]:
		var base: Dictionary = Content.tuning().duplicate(true)
		var city: Dictionary = base["city"]
		var plan := CityGen.map(city)
		var band: Vector2 = plan["river"]
		for spec: Dictionary in city["landmarks"]:
			spec["anchor"] = [x, (band.x + band.y) * 0.5]
		plan = CityGen.map(city)
		var channels := CityRiver.channels(plan, city)
		tried += 1
		for site: Dictionary in plan["sites"]:
			placed += 1
			var rect: Rect2 = site["rect"]
			if not channels.is_empty() and channels[0].intersects(rect):
				wet += 1
	check_fn.call(
		wet == 0,
		(
			(
				"no landmark in the river (landmark anchors moved onto its row at %d points: %d"
				+ " sites placed, %d of them in the channel)"
			)
			% [tried, placed, wet]
		)
	)


## Runs a start (Emergence) from `tuning` for up to `limit` seconds; how many times it emerged,
## when, and whether the kaiju then stood on the street.
static func _emerge_for(tuning: Dictionary, limit: float) -> Dictionary:
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	var none: Array[Dictionary] = []
	var sim := RampageSim.new(stats, tuning, none, Seeds.make("army", 0))
	sim.emerge.start(sim)
	var waited := 0.0
	var at := INF
	var emerged := 0
	while waited < limit:
		var before := sim.events.size()
		sim.emerge.step(sim, DT)
		for event: Dictionary in sim.events.slice(before):
			if str(event["type"]) == "kaiju_emerged":
				emerged += 1
				at = minf(at, waited + DT)
		waited += DT
	return {"emerged": emerged, "at": at, "landed": emerged > 0 and sim.stand_y == 0.0}


static func _with_seed(map_seed: int) -> Dictionary:
	var base: Dictionary = Content.tuning().duplicate(true)
	var city: Dictionary = base["city"]
	city["map_seed"] = map_seed
	return base
