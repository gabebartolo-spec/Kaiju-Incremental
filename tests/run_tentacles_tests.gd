extends "res://tests/lib/powers_base.gd"
## Tentacles suite: the cephalopod's branch (hydra limbs, squeeze, grab and throw, corrosive
## ink), the helicopters (D-037), and a full-branch replay for every species. Player-effect
## fixtures as in run_powers_tests.gd. Headless, no autoloads.
##   godot --headless --path . --script tests/run_tentacles_tests.gd


func suite_name() -> String:
	return "Tentacles"


func run_checks() -> void:
	_check_hydra()
	_check_squeeze()
	_check_grab()
	_check_ink()
	_check_helicopters()
	_check_caps()
	_check_replay()


## Hydra Limbs: standing out of stomp reach, freed tentacles still strike the buildings and
## tanks all around, each on its own timer.
func _check_hydra() -> void:
	var ring: Array[Dictionary] = [
		_b(4.5, 0, Vector3i(3, 3, 3)), _b(-4.5, 0, Vector3i(3, 3, 3)), _b(0, 4.5, Vector3i(3, 3, 3))
	]
	var out: Array[RampageSim] = []
	var strikes: Array[int] = []
	for levels: Dictionary in [{}, {"c_hydra": 3}, {"c_hydra": 1}]:
		var sim := _sim("cephalopod", levels, ring, Vector2(0, 0))
		_run(sim, 2.0, Vector2.ZERO)
		strikes.append(sim.powers.tentacles.limb_strikes)
		_run(sim, 3.0, Vector2.ZERO)
		out.append(sim)
	check(
		strikes[0] == 0 and strikes[1] >= 6 and strikes[1] > strikes[2] * 2,
		(
			"each freed limb strikes on its own (0 / 1 / 3 limbs: %d / %d / %d strikes in 2 s)"
			% [strikes[0], strikes[2], strikes[1]]
		)
	)
	var hit := 0
	for i: int in 3:
		if _alive(out[1], i) < _alive(out[0], i):
			hit += 1
	check(hit >= 2, "the limbs hit buildings on several sides (%d of 3)" % hit)


## Squeeze: through a narrow alley between two strong towers, the cephalopod slips through
## instead of shoving.
func _check_squeeze() -> void:
	var alley: Array[Dictionary] = [
		_b(-2.5, 0, Vector3i(3, 6, 6), 3), _b(2.5, 0, Vector3i(3, 6, 6), 3)
	]
	var z: Array[float] = []
	for levels: Dictionary in [{}, {"c_squeeze": 2}]:
		var sim := _sim("cephalopod", levels, alley, Vector2(0, 5))
		_run(sim, 3.0, NORTH)
		z.append(sim.kaiju_pos.y)
	check(
		z[1] < z[0] - 1.5, "Squeeze gets through the alley faster (z %.1f vs %.1f)" % [z[1], z[0]]
	)


## Grab and Throw: a tank in reach is seized and hurled where the kaiju faces; it lands like a
## grenade on the building there.
func _check_grab() -> void:
	var out: Array[Dictionary] = []
	for levels: Dictionary in [{}, {"c_grab": 1}]:
		var sim := _sim("cephalopod", levels, [_b(0, -7, Vector3i(3, 3, 3))], Vector2(0, 0))
		sim.facing = NORTH
		var tank := RampageSim.Tank.new()
		tank.id = 900
		tank.hp = 200.0
		tank.cooldown = 99.0
		tank.pos = Vector2(3.5, 0)
		sim.tanks.append(tank)
		var seen := _run(sim, 2.0, Vector2.ZERO)
		out.append({"seen": seen, "alive": _alive(sim, 0), "tanks": sim.tanks_destroyed})
	var with: Dictionary = out[1]["seen"]
	check(
		with.has("grab") and with.has("throw_land") and Num.i(out[1]["tanks"]) == 1,
		"a limb grabs the tank and throws it only with Grab and Throw: %s" % [with.keys()]
	)
	check(
		Num.i(out[1]["alive"]) < Num.i(out[0]["alive"]),
		(
			"the thrown tank blasts the building it lands on (%d vs %d standing)"
			% [Num.i(out[1]["alive"]), Num.i(out[0]["alive"])]
		)
	)


## Corrosive Ink: E coats everything around; coated chunks dissolve over seconds and coated
## tanks die.
func _check_ink() -> void:
	var ring: Array[Dictionary] = [_b(4, 0, Vector3i(3, 3, 4), 2), _b(-4, 0, Vector3i(3, 3, 4), 2)]
	var out: Array[Dictionary] = []
	for levels: Dictionary in [{}, {"c_ink": 1}]:
		var sim := _sim("cephalopod", levels, ring, Vector2(0, 0))
		var tank := RampageSim.Tank.new()
		tank.id = 900
		tank.hp = 60.0
		tank.cooldown = 99.0
		tank.pos = Vector2(0, 3.5)
		sim.tanks.append(tank)
		_run(sim, 0.5, Vector2.ZERO, ULT)
		var early := sim.chunks_destroyed
		_run(sim, 3.5, Vector2.ZERO)
		out.append({"early": early, "late": sim.chunks_destroyed, "tanks": sim.tanks_destroyed})
	check(
		Num.i(out[1]["late"]) > Num.i(out[1]["early"]) + 5,
		(
			"ink keeps dissolving coated chunks (%d to %d)"
			% [Num.i(out[1]["early"]), Num.i(out[1]["late"])]
		)
	)
	check(
		Num.i(out[1]["late"]) > Num.i(out[0]["late"]) and Num.i(out[1]["tanks"]) == 1,
		(
			"ink beats no ink (%d vs %d chunks) and kills the coated tank"
			% [Num.i(out[1]["late"]), Num.i(out[0]["late"])]
		)
	)


## Helicopters (D-037): they come once the city is burning, circle and strafe; a young kaiju
## cannot reach them, a grown one swats them on their strafing dives, and a cephalopod
## plucks them out of the air.
func _check_helicopters() -> void:
	var calm := _sim("reptilian", {}, [], Vector2(0, 0))
	_run(calm, 15.0, Vector2.ZERO)
	check(calm.air.helis.is_empty(), "no helicopters before the city has been hurt")
	var young := _sim("reptilian", {}, [], Vector2(0, 0))
	var heli := young.air.spawn()
	var start := heli.pos
	var seen := _run(young, 8.0, Vector2.ZERO)
	check(
		heli.pos.distance_to(start) > 1.0 and seen.has("heli_fired") and young.hp < young.max_hp,
		"a helicopter circles and strafes the kaiju (%d bursts)" % Num.i(seen.get("heli_fired", 0))
	)
	check(heli.hp > 0.0, "a young kaiju's stomps cannot reach a helicopter")
	_check_heli_keeps_clear()
	var grown := _sim("reptilian", {"evolve1": 1, "claws": 5, "hide": 5}, [], Vector2(0, 0))
	grown.air.spawn()
	var swatted := _run(grown, 12.0, Vector2.ZERO)
	check(
		swatted.has("heli_destroyed"),
		"a grown kaiju (reach %.1f) swats a diving helicopter" % grown.reach_top()
	)
	var octo := _sim("cephalopod", {"c_grab": 1}, [_b(0, -7, Vector3i(3, 3, 3))], Vector2(0, 0))
	octo.air.spawn()
	var grabbed := false
	for i: int in 30 * 8:
		for event: Dictionary in octo.step(DT, Vector2.ZERO, false):
			if str(event["type"]) == "grab" and str(event["kind"]) == "heli":
				grabbed = true
	check(grabbed, "a cephalopod plucks a helicopter out of the sky")


## Helicopters keep off the camera's side of the kaiju (never between the player and it) and
## cruise a helicopter-and-a-half beyond its body, for 20 s of sweeping and diving.
func _check_heli_keeps_clear() -> void:
	var sim := _sim("reptilian", {}, [], Vector2(0, 0))
	var air: Dictionary = Content.section("air")
	var bearing := deg_to_rad(Num.f(air["camera_bearing"]))
	var body := Num.f(Content.section("powers")["body_radius"]) * sim.body_scale()
	for _n: int in 3:
		sim.air.spawn()
	var closest := PI
	var cruise := INF
	for i: int in roundi(20.0 / DT):
		sim.step(DT, Vector2.ZERO, false)
		for heli: AirWing.Heli in sim.air.helis:
			var side := absf(wrapf((heli.pos - sim.kaiju_pos).angle() - bearing, -PI, PI))
			closest = minf(closest, side)
			cruise = minf(cruise, heli.cruise - body)
	check(
		(
			closest >= deg_to_rad(Num.f(air["clear_arc"])) - 0.01
			and cruise >= Num.f(air["clear_margin"])
		),
		(
			"helicopters stay %.0f deg off the camera side and cruise %.1f beyond the body"
			% [rad_to_deg(closest), cruise]
		)
	)


## A full autoplayed rampage with every branch bought replays identically for each species.
func _check_replay() -> void:
	var full := {
		"reptilian": {"r_tail": 2, "r_momentum": 2, "r_shear": 1, "r_beam": 1},
		"insectoid": {"i_scuttle": 2, "i_glide": 1, "i_climb": 1, "i_brood": 1},
		"cephalopod": {"c_hydra": 2, "c_squeeze": 1, "c_grab": 1, "c_ink": 1},
	}
	var same := true
	for species_id: String in full:
		var runs: Array[Dictionary] = []
		for n: int in 2:
			var layout := CityGen.generate(Seeds.make("city", 0), Content.section("city"))
			var species := Content.species_def(species_id)
			var levels: Dictionary = full[species_id]
			var tree := UpgradeTree.new(Content.upgrades(), levels, species_id)
			var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
			var sim := RampageSim.new(stats, Content.tuning(), layout, Seeds.make("army", 3))
			var ability: Dictionary = species["ability"]
			sim.ability_type = str(ability["type"])
			var target := Vector2(INF, INF)
			for i: int in 30 * 30:
				if i % 15 == 0:
					target = sim.nearest_standing(sim.kaiju_pos)
				var move := Vector2.ZERO
				if target.x < INF:
					move = (target - sim.kaiju_pos).normalized()
				var held := RampageSim.HELD if i % 40 < 20 else 0
				sim.step(DT, move, sim.ability_ready_in <= 0.0, held | RampageSim.ULTIMATE)
			runs.append(sim.result())
		same = same and runs[0] == runs[1]
	check(same, "every species' full branch replays identically from the same seed")


## Caps (lead review): a downed helicopter is replaced only after the call-in interval, never on
## the next step; never more helicopters than the max; never more young than brood_max; and a
## second Brood level lays twice the eggs.
func _check_caps() -> void:
	var air: Dictionary = Content.section("air")
	var sim := _sim("reptilian", {}, [], Vector2(0, 0))
	sim.chunks_total = 1000000  # a big-city stand-in, so the run cannot end as "fallen"
	sim.chunks_destroyed = Num.i(air["after_chunks"])
	sim.army_units.rouse()
	var first := _run(sim, 0.2, Vector2.ZERO)
	var called := first.has("heli_spawned") and sim.air.helis.size() == 1
	_run(sim, Num.f(air["interval"]) * 1.5, Vector2.ZERO)  # a long spell at the cap first
	called = called and sim.air.helis.size() == 1
	sim.air.helis[0].hp = 0.0 if called else 1.0
	sim.air.clear_dead()
	var soon := _run(sim, Num.f(air["interval"]) * 0.9, Vector2.ZERO)
	var later := _run(sim, Num.f(air["interval"]) * 0.2, Vector2.ZERO)
	check(
		called and not soon.has("heli_spawned") and later.has("heli_spawned"),
		(
			"a downed helicopter is replaced only after the %.0f s call-in interval"
			% Num.f(air["interval"])
		)
	)
	var swarm := _sim("reptilian", {"hide": 5, "titan_hide": 5}, [], Vector2(0, 0))
	swarm.chunks_total = 1000000
	swarm.chunks_destroyed = 99999
	swarm.army_units.rouse()
	var most := 0
	for i: int in 30 * 60:
		swarm.step(DT, Vector2.ZERO, false)
		most = maxi(most, swarm.air.helis.size())
	check(
		most == Num.i(air["max"]),
		"the sky never holds more than %d helicopters (most %d)" % [Num.i(air["max"]), most]
	)
	var one := _sim("insectoid", {"i_brood": 1}, [], Vector2(0, 0))
	var two := _sim("insectoid", {"i_brood": 2}, [], Vector2(0, 0))
	one.brood.lay(Num.i(one.stat("brood_count")))
	two.brood.lay(Num.i(two.stat("brood_count")))
	var full := _sim("insectoid", {"i_brood": 3}, [], Vector2(0, 0))
	var empty_event := false
	for n: int in 6:
		full.brood.lay(Num.i(full.stat("brood_count")))
	var cap := Num.i(Content.section("powers")["brood_max"])
	full.brood.lay(3)
	for event: Dictionary in full.events:
		var at: Array = event.get("at", [1])
		if str(event["type"]) == "eggs_laid" and at.is_empty():
			empty_event = true
	check(
		one.brood.young.size() == 3 and two.brood.young.size() == 6,
		(
			"each Brood level lays three more eggs (%d, %d)"
			% [one.brood.young.size(), two.brood.young.size()]
		)
	)
	check(
		full.brood.young.size() == cap and not empty_event,
		(
			"the brood never passes %d young, and a full brood lays nothing (%d)"
			% [cap, full.brood.young.size()]
		)
	)
