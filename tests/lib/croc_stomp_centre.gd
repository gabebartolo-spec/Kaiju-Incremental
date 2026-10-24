extends RefCounted
## The croc standing suite's stomp-centre check (D-166): the sim's stomp is centred on the foot that
## delivers it, so the damage lands where the ring does. At each growth step (young, Behemoth,
## Colossus) and two headings, the sim stomps while the kaiju stands; the model, placed where the sim
## puts it, lifts the foot the sim names (KaijuModel.prefer_foot) and plants it; the sim's stomp point
## ("at" in its event) is within CENTRE_TOL of that planted foot. Then the damage itself: a tank on
## the foot's spot takes the full blow, and one where the old centre (kaiju_pos) was takes less.

const DT := 1.0 / 60.0
const BEAT_FRAMES := 42
const STAGES: Array[String] = ["baby", "adolescent", "adult"]
## The most the sim's stomp point may sit from the drawn foot (world units).
const CENTRE_TOL := 0.5
const STOMPS := 4
const TANK_HP := 100000.0

var _suite: SceneTree
var _check: Callable


func _init(suite: SceneTree, check: Callable) -> void:
	_suite = suite
	_check = check


func run() -> void:
	for size: int in 3:
		for turned: bool in [false, true]:
			await _stage(size, turned)


func _sim(size: int) -> RampageSim:
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), {})
	)
	stats["size"] = float(size + 1)
	var layout := CityGen.generate(Seeds.make("city", 0), Content.section("city"))
	var sim := RampageSim.new(stats, Content.tuning(), layout, Seeds.make("army", 0))
	sim.body.use_species("reptilian")
	return sim


func _stage(size: int, turned: bool) -> void:
	var sim := _sim(size)
	var heading := Vector2(1.0, 1.0).normalized() if turned else Vector2(0.0, -1.0)
	sim.facing = heading
	sim.body.heading = heading
	var colors: Dictionary = Content.species_def("reptilian")["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, STAGES[size])
	_suite.root.add_child(kaiju)
	kaiju.scale = Vector3.ONE * sim.body_scale()
	kaiju.position = Vector3(sim.kaiju_pos.x, 0.0, sim.kaiju_pos.y)
	kaiju.rotation.y = atan2(-heading.x, -heading.y)
	var rig: KaijuRig = kaiju.find_children("*", "KaijuRig", true, false)[0]
	var planted: Array[Vector2] = []
	rig.foot_planted.connect(
		func(side: String, _strength: float, at: Vector3) -> void:
			if side != "tail":
				planted.append(Vector2(at.x, at.z))
	)
	for i: int in 60:
		kaiju.animate(DT, 0.0)
	var worst := 0.0
	var spots: Array[Vector2] = []
	var steps := 0
	while spots.size() < STOMPS and steps < 600:
		steps += 1
		var before := planted.size()
		var old_centre := sim.kaiju_pos
		var tank := _tank(sim, spots, old_centre)
		var was := tank.hp
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			if str(event["type"]) != "stomp":
				continue
			kaiju.prefer_foot(str(event["side"]))
			kaiju.stomp()
			for f: int in BEAT_FRAMES:
				kaiju.animate(DT, 0.0)
			var foot := planted[-1] if planted.size() > before else Vector2(INF, INF)
			var at: Vector2 = event["at"]
			worst = maxf(worst, foot.distance_to(at))
			if spots.size() >= 2:  # the tank stood on this foot's spot from the stomp before last
				_damage(size, turned, sim, was - tank.hp, spots[-2], old_centre)
			spots.append(foot)
	print("DBG steps %d over %s reason %s" % [steps, sim.over, sim.end_reason])
	_check.call(
		spots.size() == STOMPS and worst <= CENTRE_TOL,
		(
			"%s stomp centre (%s): the sim's point is within %.1f of the planted foot (worst %.2f, %d stomps)"
			% [STAGES[size], "turned" if turned else "straight", CENTRE_TOL, worst, spots.size()]
		)
	)
	kaiju.queue_free()
	await _suite.process_frame


## A tank (very tough) on the spot this foot planted two stomps ago (stomps alternate feet, so it is
## the same foot's spot), or at the old centre until there is one.
func _tank(sim: RampageSim, spots: Array[Vector2], old_centre: Vector2) -> RampageSim.Tank:
	sim.tanks.clear()
	var tank := RampageSim.Tank.new()
	tank.id = 0
	tank.hp = TANK_HP
	tank.pos = spots[-2] if spots.size() >= 2 else old_centre
	sim.tanks.append(tank)
	return tank


## The tank on the foot's spot lost the whole stomp_damage; one where the old centre was would have
## lost only a part of it (or none).
func _damage(
	size: int, turned: bool, sim: RampageSim, lost: float, spot: Vector2, old_centre: Vector2
) -> void:
	var full := sim.stat("stomp_damage") * sim.powers.hit_mult()
	var old_k := RampageSim.falloff(
		old_centre.distance_to(spot) - RampageSim.TANK_RADIUS, sim.stomp_radius()
	)
	_check.call(
		absf(lost - full) < 0.01 and old_k < 1.0,
		(
			"%s stomp (%s): a tank on the foot's spot takes the whole blow (%.1f of %.1f; at the old centre %.0f%%)"
			% [STAGES[size], "turned" if turned else "straight", lost, full, old_k * 100.0]
		)
	)
