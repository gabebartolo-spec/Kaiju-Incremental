extends "res://tests/lib/powers_base.gd"
## Tentacles suite: the cephalopod's branch (hydra limbs, squeeze, grab and throw, corrosive
## ink), the helicopters (D-037), and a full-branch replay for every species. Player-effect
## fixtures as in run_powers_tests.gd. Headless, no autoloads.
##   godot --headless --path . --script tests/run_tentacles_tests.gd

## Strafing passes a helicopter is sent on, and the seconds each is given (strafe_seconds).
const PASSES := 8
const PASS_SECONDS := 22.0


func suite_name() -> String:
	return "Tentacles"


func run_checks() -> void:
	await _t("_check_hydra")
	await _t("_check_squeeze")
	await _t("_check_grab")
	await _t("_check_ink")
	await _t("_check_helicopters")
	await _t("_check_caps")
	await _t("_check_chain_rate")
	await _t("_check_replay")


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


## Helicopters (D-037, D-183): they come once the city is burning, hold their stand-off ring and
## fire; a young kaiju cannot reach them, a grown one swats one on its strafing pass, and a
## cephalopod plucks one out of the air on its pass.
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
		(
			"a helicopter flies in and fires on the kaiju (%d bursts)"
			% Num.i(seen.get("heli_fired", 0))
		)
	)
	check(heli.hp > 0.0, "a young kaiju's stomps cannot reach a helicopter")
	await _t("_check_heli_keeps_clear")
	var grown := _sim("reptilian", {"evolve1": 1, "claws": 5, "hide": 5}, [], Vector2(0, 0))
	var diver := grown.air.spawn()
	_face_away_from_camera(grown)
	var swatted := {}
	for pass_n: int in PASSES:
		# A swipe lands every 2 s, so each pass starts a little later in that rhythm (a pass is
		# in the claw's band for about 1.6 s of it).
		_run(grown, 0.4 * pass_n, Vector2.ZERO)
		grown.air.flight.start_pass(diver)
		swatted = _run(grown, PASS_SECONDS, Vector2.ZERO)
		if swatted.has("heli_destroyed"):
			break
	check(
		swatted.has("heli_destroyed"),
		"a grown kaiju (reach %.1f) swats a helicopter on its strafing pass" % grown.reach_top()
	)
	var octo := _sim("cephalopod", {"c_grab": 1}, [_b(0, -7, Vector3i(3, 3, 3))], Vector2(0, 0))
	var flyer := octo.air.spawn()
	_face_away_from_camera(octo)
	octo.time_left = 1.0e9  # the passes run longer than a short rampage
	var reach := Num.f(octo.powers.tentacles.cfg["grab_reach"]) * octo.body_scale()
	var closest := INF
	for _pass: int in PASSES:
		octo.air.flight.start_pass(flyer)
		for _i: int in roundi(PASS_SECONDS / DT):
			octo.hp = octo.max_hp  # the passes run on; the helicopters' fire is not what is measured
			octo.step(DT, Vector2.ZERO, false, RampageSim.STOMP)
			closest = minf(closest, flyer.pos.distance_to(octo.kaiju_pos))
	check(
		closest <= reach,
		(
			"a strafing pass brings a helicopter within a tentacle's grab (%.1f of %.1f)"
			% [closest, reach]
		)
	)
	var grabbed := false  # and a tentacle plucks one that is in reach out of the sky
	var low := octo.air.spawn()
	for _i: int in roundi(PASS_SECONDS / DT):
		octo.hp = octo.max_hp
		low.pos = octo.kaiju_pos + octo.facing.orthogonal() * reach * 0.5
		for event: Dictionary in octo.step(DT, Vector2.ZERO, false, RampageSim.STOMP):
			if str(event["type"]) == "grab" and str(event["kind"]) == "heli":
				grabbed = true
	check(grabbed, "a cephalopod plucks a helicopter out of the sky")


## The kaiju faces away from the game camera, where the helicopters are allowed to be.
func _face_away_from_camera(sim: RampageSim) -> void:
	sim.facing = Vector2.from_angle(
		deg_to_rad(Num.f(Content.section("air")["camera_bearing"])) + PI
	)


## Helicopters keep off the camera's side of the kaiju (never between the player and it) and
## hold their stand-off ring (D-183) round a standing kaiju, for 20 s (before the first pass).
func _check_heli_keeps_clear() -> void:
	var sim := _sim("reptilian", {}, [], Vector2(0, 0))
	var air: Dictionary = Content.section("air")
	var bearing := deg_to_rad(Num.f(air["camera_bearing"]))
	var ring := Num.f(air["standoff"]) * (1.0 - Num.f(air["standoff_jitter"])) * sim.body_scale()
	for _n: int in 3:
		sim.air.spawn()
	var closest := PI
	var nearest := INF
	for i: int in roundi(20.0 / DT):
		sim.step(DT, Vector2.ZERO, false, RampageSim.STOMP)
		for heli: AirWing.Heli in sim.air.helis:
			var side := absf(wrapf((heli.pos - sim.kaiju_pos).angle() - bearing, -PI, PI))
			closest = minf(closest, side)
			nearest = minf(nearest, heli.pos.distance_to(sim.kaiju_pos))
	check(
		(
			closest >= deg_to_rad(Num.f(air["clear_arc"])) - 0.01
			and nearest >= ring - Num.f(air["arrive"])
		),
		(
			"helicopters stay %.0f deg off the camera side and hold %.1f out (ring %.1f)"
			% [rad_to_deg(closest), nearest, ring]
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
				sim.step(
					DT,
					move,
					sim.ability_ready_in <= 0.0,
					held | RampageSim.ULTIMATE | RampageSim.STOMP
				)
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
	var most := 0
	for i: int in 30 * 60:
		swarm.step(DT, Vector2.ZERO, false, RampageSim.STOMP)
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


## The rig's spring chains step at a fixed rate (tuning "chain"), so a whipped, driven tentacle
## ends a 2 s run in the same pose at 30, 60 and 144 fps (R 9.1: the old variable step felt
## different at every frame rate and no two captures matched).
func _check_chain_rate() -> void:
	var ends: Array[PackedVector3Array] = []
	var moved := 0.0
	for fps: int in [60, 30, 144]:
		var colors: Dictionary = Content.species_def("cephalopod")["colors"]
		var rig := CephalopodStandIn.build(colors, 10.0, 1.5)
		root.add_child(rig)
		rig.simulate_chains(0.0)  # lays the chains out at rest
		var chain: KaijuRig.SpringChain = rig.chains[0]
		var start := chain.pos.duplicate()
		chain.kick(Vector3(8.0, 4.0, 0.0), 1.0 / 60.0)
		chain.drive[2] = Basis(Vector3.BACK, 0.6)
		for _frame: int in roundi(2.0 * fps):
			rig.simulate_chains(1.0 / fps)
		ends.append(chain.pos.duplicate())
		moved = maxf(moved, start[start.size() - 1].distance_to(chain.pos[start.size() - 1]))
		rig.free()
	var worst := 0.0
	for run: int in range(1, ends.size()):
		for i: int in ends[0].size():
			worst = maxf(worst, ends[0][i].distance_to(ends[run][i]))
	check(moved > 0.5, "the driven tentacle really moves in 2 s (tip %.2f)" % moved)
	check(
		worst < 0.05,
		"a tentacle ends 2 s in the same pose at 30, 60, 144 fps (worst joint off %.3f)" % worst
	)
