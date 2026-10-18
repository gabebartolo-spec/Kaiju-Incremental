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


## A sim whose jets are on (`max`), its city hurt enough to call them in when `hurt` (the
## call-in mark lowered to the chunks already down: the test city is too small to reach it).
func _jet_sim(hurt: bool, max_jets: int = 1) -> RampageSim:
	var sim := _sim("reptilian", {}, [], AT)
	sim.strike.cfg = sim.strike.cfg.duplicate(true)
	sim.strike.cfg["max"] = max_jets
	if hurt:
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
	var calm := _jet_sim(false)
	var none_calm := _until(calm, "jet_spawned", 20.0) == INF
	var off := _jet_sim(true, 0)
	var none_off := _until(off, "jet_spawned", 20.0) == INF
	var hurt := _jet_sim(true)
	var called := _until(hurt, "jet_spawned", Num.f(hurt.strike.cfg["first_delay"]) + 1.0)
	check(
		none_calm and none_off and called < INF,
		"jets stay away from a calm city and a stage without them, and come to a hurt one"
	)


## Across the camera's view (within yaw_jitter of square to camera_bearing), entering and
## leaving `approach` from the kaiju: off screen at both ends, never popping in or out in view.
func _check_pass_shape() -> void:
	var sim := _jet_sim(true)
	var jet := sim.strike.spawn()
	var cfg := sim.strike.cfg
	var toward := Vector2.from_angle(deg_to_rad(Num.f(cfg["camera_bearing"])))
	var off_square := absf(jet.dir.dot(toward))
	var start_far := jet.start.distance_to(AT) >= Num.f(cfg["approach"]) - 0.01
	var left := _until(sim, "jet_left", 10.0)
	var flown := 2.0 * Num.f(cfg["approach"]) / Num.f(cfg["speed"])
	check(
		off_square <= sin(deg_to_rad(Num.f(cfg["yaw_jitter"]))) + 0.001 and start_far,
		"a jet enters off screen and flies across the camera's view (%.2f off square)" % off_square
	)
	check(
		absf(left - flown) < 2.0 * DT and sim.strike.jets.is_empty(),
		"it flies straight on and leaves the arena after %.1f s" % left
	)


## The warning comes warn_seconds before the first round lands, and a standing kaiju is hit.
func _check_warning() -> void:
	var sim := _jet_sim(true)
	sim.strike.spawn()
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
		lead >= Num.f(sim.strike.cfg["warn_seconds"]) - DT,
		"the warning comes %.2f s before the first round lands" % lead
	)
	check(hits > 0, "a kaiju standing on the line is strafed (%d rounds hit)" % hits)


## Player-effect fixture: the same pass, the same seed; one kaiju stands, the other steps
## toward the camera (off the line) as soon as the warning comes.
func _check_dodge() -> void:
	var hits: Array[int] = []
	var hurt: Array[float] = []
	for dodge: bool in [false, true]:
		var sim := _jet_sim(true)
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
	var sim := _jet_sim(true)
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
	var sim := _jet_sim(true)
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
