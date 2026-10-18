extends "res://tests/lib/powers_base.gd"
## Jets suite (D-072): the strafing pass (StrikeWing). A jet comes once the city is hurt, flies
## straight across the game camera's view, warns before its rounds land, strafes a line through
## the kaiju's spot and flies on out of the arena. The player-effect fixture: a kaiju that
## steps off the line after the warning takes nothing, one that stands is hit. Seeded by design:
## the sim's own streams (Seeds.make("army", 0) in powers_base). Headless, no autoloads.
##   godot --headless --path . --script tests/run_jets_tests.gd

const AT := Vector2(0, 0)


func suite_name() -> String:
	return "Jets"


func run_checks() -> void:
	_check_call_in()
	_check_pass_shape()
	_check_warning()
	_check_dodge()
	_check_next_pass()
	_check_hit_back()
	_check_jet()
	_check_collateral()
	_check_grab()
	_check_height()
	_check_lead_scales()


## A sim whose jets are on (`max`), its city hurt enough to call them in (the call-in mark
## lowered to the chunks already down: the test city is too small to reach the real one).
func _jet_sim(
	max_jets: int = 1,
	layout: Array[Dictionary] = [],
	species: String = "reptilian",
	levels: Dictionary = {}
) -> RampageSim:
	var sim := _sim(species, levels, layout, AT)
	sim.strike.cfg = sim.strike.cfg.duplicate(true)
	sim.strike.cfg["max"] = max_jets
	sim.strike.cfg["after_chunks"] = sim.chunks_destroyed
	return sim


## Steps until `type` is seen or `seconds` run out; the time it took (INF if never).
func _until(sim: RampageSim, type: String, seconds: float, move := Vector2.ZERO) -> float:
	for i: int in roundi(seconds / DT):
		for event: Dictionary in sim.step(DT, move, false):
			if str(event["type"]) == type:
				return (i + 1) * DT
	return INF


func _check_call_in() -> void:
	var calm := _jet_sim()
	calm.strike.cfg["after_chunks"] = Num.i(Content.section("jets")["after_chunks"])
	var none_calm := _until(calm, "jet_spawned", 20.0) == INF
	var off := _jet_sim(0)
	var none_off := _until(off, "jet_spawned", 20.0) == INF
	var hurt := _jet_sim()
	var called := _until(hurt, "jet_spawned", Num.f(hurt.strike.cfg["first_delay"]) + 1.0)
	check(
		none_calm and none_off and called < INF,
		"jets stay away from a calm city and a stage without them, and come to a hurt one"
	)


## Across the camera's view (within yaw_jitter of square to camera_bearing), entering and
## leaving `approach` from the kaiju: off screen at both ends, never popping in or out in view.
func _check_pass_shape() -> void:
	var sim := _jet_sim()
	var jet := sim.strike.spawn()
	var cfg := sim.strike.cfg
	var toward := Vector2.from_angle(deg_to_rad(Num.f(cfg["camera_bearing"])))
	var off_square := absf(jet.dir.dot(toward))
	var start_far := jet.start.distance_to(AT) >= Num.f(cfg["approach"]) - 0.01
	var left := _until(sim, "jet_left", 10.0)
	var flown := 2.0 * jet.approach / Num.f(cfg["speed"])
	check(
		off_square <= sin(deg_to_rad(Num.f(cfg["yaw_jitter"]))) + 0.001 and start_far,
		"a jet enters off screen and flies across the camera's view (%.2f off square)" % off_square
	)
	check(
		absf(left - flown) < 2.0 * DT and sim.strike.jets.is_empty(),
		"it flies straight on and leaves the arena after %.1f s" % left
	)


## The warning comes the jet's lead (D-080) before the first round lands, and a standing kaiju
## is hit.
func _check_warning() -> void:
	var sim := _jet_sim()
	var jet := sim.strike.spawn()
	var warned := INF
	var first := INF
	var hits := 0
	for i: int in roundi(6.0 / DT):
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			var t := (i + 1) * DT
			match str(event["type"]):
				"jet_inbound":
					warned = minf(warned, t)
				"jet_strafe":
					first = minf(first, t)
					hits += 1 if event["hit"] else 0
	var lead := first - warned
	check(
		lead >= jet.lead - DT,
		"the warning comes %.2f s (lead %.2f) before the first round lands" % [lead, jet.lead]
	)
	check(hits > 0, "a kaiju standing on the line is strafed (%d rounds hit)" % hits)


## Player-effect fixture: the same pass, the same seed; one kaiju stands, the other steps
## toward the camera (off the line) as soon as the warning comes.
func _check_dodge() -> void:
	var hits: Array[int] = []
	var hurt: Array[float] = []
	for dodge: bool in [false, true]:
		var sim := _jet_sim()
		sim.strike.spawn()
		var move := Vector2.ZERO
		var n := 0
		var hp0 := sim.hp
		for i: int in roundi(6.0 / DT):
			for event: Dictionary in sim.step(DT, move, false):
				if str(event["type"]) == "jet_inbound" and dodge:
					move = Vector2(0, 1)
				if str(event["type"]) == "jet_strafe" and event["hit"]:
					n += 1
		hits.append(n)
		hurt.append(hp0 - sim.hp)
	check(
		hits[0] > 0 and hits[1] == 0 and hurt[1] < hurt[0],
		(
			"stepping off the line after the warning dodges the pass (%d vs %d rounds, %.0f vs %.0f hp)"
			% [hits[0], hits[1], hurt[0], hurt[1]]
		)
	)


## Another jet comes `interval` after the last was called in, from the other side.
func _check_next_pass() -> void:
	var sim := _jet_sim()
	var dirs: Array[Vector2] = []
	for i: int in roundi(30.0 / DT):
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			if str(event["type"]) == "jet_spawned":
				dirs.append(event["dir"])
	check(
		dirs.size() >= 2 and dirs[0].dot(dirs[1]) < 0.0 and sim.strike.jets.size() <= 1,
		"passes keep coming, one at a time, from alternate sides (%d in 30 s)" % dirs.size()
	)


## Only an attack that reaches the air hits a jet; a downed jet pays rubble and is gone.
func _check_hit_back() -> void:
	var sim := _jet_sim()
	sim.strike.spawn()
	var all := func(_p: Vector2, _r: float) -> float: return 1.0
	sim.strike.hit(all, 1000.0, false)
	var kept := sim.strike.jets.size() == 1
	var rubble := sim.rubble
	sim.strike.hit(all, 1000.0, true)
	check(
		kept and sim.strike.jets.is_empty() and sim.strike.destroyed == 1 and sim.rubble > rubble,
		"only attacks that reach the air down a jet, for rubble"
	)


## Collateral (director, D-072): rounds chew the roofs on their line, which fall like any other
## chunks but pay the player no biomass. The same rampage with and without the pass.
func _check_collateral() -> void:
	var standing: Array[int] = []
	var rubble: Array[float] = []
	for pass_on: bool in [false, true]:
		var sim := _jet_sim(1, [_b(4.5, 0, Vector3i(3, 3, 3))])
		sim.strike.cfg["yaw_jitter"] = 0.0  # the line along the street, through the building
		if pass_on:
			sim.strike.spawn()
		else:
			sim.strike.cfg["max"] = 0
		_run(sim, 6.0, Vector2.ZERO)
		standing.append(_alive(sim, 0))
		rubble.append(sim.rubble)
	check(
		standing[1] < standing[0] and is_equal_approx(rubble[1], rubble[0]),
		(
			"its rounds wreck roofs on the line (%d vs %d chunks), paying no biomass (%.2f vs %.2f)"
			% [standing[1], standing[0], rubble[1], rubble[0]]
		)
	)


## The cephalopod (Grab and Throw) seizes a jet passing over and hurls it.
func _check_grab() -> void:
	var sim := _jet_sim(1, [], "cephalopod", {"c_grab": 1})
	var jet := sim.strike.spawn()
	jet.s = jet.approach - 1.0  # overhead now, before any car is taken
	var grabbed := false
	for i: int in roundi(2.0 / DT):  # before the next jet is called in
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			if str(event["type"]) == "grab" and str(event["kind"]) == "jet":
				grabbed = true
	check(
		grabbed and sim.strike.jets.is_empty() and sim.strike.destroyed == 1,
		"a cephalopod plucks a jet out of the sky as it passes over"
	)


## A jet flies `clearance` over the kaiju's head, so it never flies through a grown body.
func _check_height() -> void:
	var young := _jet_sim()
	var colossus := _jet_sim(1, [], "reptilian", {"evolve1": 1, "evolve2": 1})
	var gaps: Array[float] = []
	for sim: RampageSim in [young, colossus]:
		gaps.append(sim.strike.altitude() - sim.reach_height())
	check(
		(
			gaps[0] > 0.0
			and is_equal_approx(gaps[0], gaps[1])
			and colossus.strike.altitude() > young.strike.altitude()
		),
		(
			"a jet flies over the kaiju's head (%.1f young, %.1f Colossus)"
			% [young.strike.altitude(), colossus.strike.altitude()]
		)
	)


## The interceptor (D-072) draws the Blender voxels it was built from (vox_jet.py), its nose
## (where its rounds leave) forward along -Z.
func _check_jet() -> void:
	var jet := JetModel.new("interceptor")
	root.add_child(jet)
	var mmi := jet.get_child(0) as MultiMeshInstance3D
	var cubes := mmi.multimesh.instance_count if mmi != null else 0
	var cells := Kvox.read("res://assets/vehicles/jet_interceptor_body.kvox").frames[0].cells.size()
	check(
		cubes > 0 and cubes <= cells and jet.nose().z < -2.0,
		"the interceptor draws its Blender voxels (%d of %d), nose forward" % [cubes, cells]
	)
	jet.free()


## D-080: the warning is as long as the kaiju needs to walk clear (body radius at its speed) plus
## the reaction time, so it grows with the body; a jet enters further out to give it room, and
## a grown kaiju can still dodge.
func _check_lead_scales() -> void:
	var young := _jet_sim()
	var apex := _jet_sim(1, [], "reptilian", {"evolve1": 1, "evolve2": 1, "evolve3": 1})
	var leads: Array[float] = []
	var jets: Array[StrikeWing.Jet] = []
	for sim: RampageSim in [young, apex]:
		var jet := sim.strike.spawn()
		jets.append(jet)
		var clear := Num.f(sim.powers_cfg["body_radius"]) * sim.body_scale() / sim.stat("speed")
		leads.append(clear + Num.f(sim.strike.cfg["react_seconds"]))
	var hits := 0
	var move := Vector2.ZERO
	for i: int in roundi(8.0 / DT):
		for event: Dictionary in apex.step(DT, move, false):
			if str(event["type"]) == "jet_inbound":
				move = Vector2(0, 1)
			if str(event["type"]) == "jet_strafe" and event["hit"]:
				hits += 1
	check(
		(
			is_equal_approx(jets[0].lead, leads[0])
			and is_equal_approx(jets[1].lead, leads[1])
			and jets[1].lead > jets[0].lead
			and jets[1].approach >= jets[0].approach
			and hits == 0
		),
		(
			"the warning grows with the body (young %.2f s, Apex %.2f s); an Apex dodges (%d hits)"
			% [jets[0].lead, jets[1].lead, hits]
		)
	)
