extends "res://tests/lib/runner.gd"
## The croc turns over its planted foot only as far as the stick turned it (D-177, the sim review of
## the gait fix): the hand-over from the river, where the body still lies along the water about 90
## deg off the way it faces, catches its heading up about the middle and does not swing the body
## about the feet; and a leap (the dash button), which holds its own axis, is not slid sideways
## by a stick a little off it.
## The big forms' U-turns are heavy and slow, their yaw spread evenly over real alternating steps,
## and the young croc's smooth turns are as they were (D-187, tests/lib/gait_turn.gd).
## Seeded by design: every sim is Seeds.make("army", 0) on the seeded city 0.

const GaitTurn := preload("res://tests/lib/gait_turn.gd")
const Leaks := preload("res://tests/lib/gait_leaks.gd")
const Stability := preload("res://tests/lib/gait_stability.gd")
const DT := 1.0 / 60.0
## The growth steps that step their turns (the young croc turns smoothly, D-131).
const STAGES := {"Behemoth": {"evolve1": 1}, "Colossus": {"evolve1": 1, "evolve2": 1}}
const DASH_BUTTON := 4  # Dash.BUTTON
## 12 frames after the hand-over the body has walked about a unit: a lurch is several.
const HAND_OVER_FRAMES := 12
const MAX_HAND_OVER := 3.0
## A stick this far off a leap's axis (rad) may not slide the body sideways more than this.
const OFF_AXIS := 0.2
const MAX_SLIDE := 1.0
## The young croc's smooth turns (D-131, D-385: a rule, not a pinned route): each leg ends facing
## the stick within FACE_DEG, no frame turns more than SNAP_DEG (it turns about 3 deg a frame, a
## snap is many times that), and each leg walks at least WALK_SHARE of its speed x time.
const FACE_DEG := 1.0
const SNAP_DEG := 10.0
const WALK_SHARE := 0.5
## D-355: from a stand the grown croc reaches full stride in about WALK_OFF_S, evenly; the young
## croc still sets off at once (well inside YOUNG_OFF_S).
const WALK_OFF_S := 1.3
const YOUNG_OFF_S := 0.3


func suite_name() -> String:
	return "Gait"


func run_checks() -> void:
	await _t("_check_hand_over")
	await _t("_check_dash")
	await _t("_check_straight")
	await _t("_check_walk_start")
	await _t("_check_u_turn")
	await _t("_check_young_turn")
	await _h("Leaks", func() -> void: await Leaks.check(check, root))
	await _h("Stability", func() -> void: await Stability.check(check, root))


## The reptilian at `levels` on its stage's own tuning, as Rampage builds it, with a far building so
## the run goes on.
func _croc(levels: Dictionary) -> RampageSim:
	var def := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), levels, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), def, tree)
	var tuning := CityGrowth.for_stats(stats)
	var layout: Array[Dictionary] = [
		{"x": 38.0, "z": 38.0, "w": 2, "d": 2, "h": 2, "tier": 1, "style": 0}
	]
	var sim := RampageSim.new(stats, tuning, layout, Seeds.make("army", 0))
	sim.ability_type = "cone"
	sim.body.use_species("reptilian")
	sim.time_left = 1.0e9
	return sim


func _check_hand_over() -> void:
	for stage: String in STAGES:
		var levels: Dictionary = STAGES[stage]
		var sim := _croc(levels)
		sim.emerge.start(sim)
		var rose := sim.emerge.active
		for _n: int in roundi(10.0 / DT):
			if not sim.emerge.active:
				break
			sim.step(DT, Vector2.ZERO, false, 0)
		var off := rad_to_deg(absf(sim.body.heading.angle_to(sim.facing)))
		var from := sim.kaiju_pos
		for _n: int in HAND_OVER_FRAMES:
			sim.step(DT, sim.facing, false, 0)  # the stick held from the first live tick
		var moved := sim.kaiju_pos.distance_to(from)
		check(
			rose and not sim.emerge.active and off < 30.0,
			(
				"%s: the rise from the bay hands over with the body %.0f deg off the way it faces"
				% [stage, off]
			)
		)
		check(
			moved < MAX_HAND_OVER,
			(
				"%s: %d frames of a held stick after the hand-over move the body %.1f units (< %.0f)"
				% [stage, HAND_OVER_FRAMES, moved, MAX_HAND_OVER]
			)
		)


func _check_dash() -> void:
	for stage: String in STAGES:
		var levels: Dictionary = STAGES[stage]
		var sim := _croc(levels)
		sim.kaiju_pos = Vector2(0.0, 30.0)
		for _n: int in 60:
			sim.step(DT, sim.facing, false, 0)  # walking north
		var axis := sim.facing
		var from := sim.kaiju_pos
		var stick := axis.rotated(OFF_AXIS)
		sim.step(DT, stick, false, DASH_BUTTON)
		var dashed := sim.body.dash.on()
		for _n: int in roundi(6.0 / DT):
			if not sim.body.dash.on():
				break
			sim.step(DT, stick, false, 0)  # the stick held a little off the axis for the whole leap
		var along := (sim.kaiju_pos - from).dot(axis)
		var slide := absf((sim.kaiju_pos - from).dot(axis.orthogonal()))
		check(
			dashed and along > 5.0,
			"%s: the leap carried the body %.1f units along its axis" % [stage, along]
		)
		check(
			slide < MAX_SLIDE,
			(
				"%s: a stick %.1f rad off the axis slides the leap %.1f units sideways (< %.0f)"
				% [stage, OFF_AXIS, slide, MAX_SLIDE]
			)
		)


## Walking straight is not touched by any of it: the top speed is the stage's own.
func _check_straight() -> void:
	for stage: String in STAGES:
		var levels: Dictionary = STAGES[stage]
		var sim := _croc(levels)
		sim.kaiju_pos = Vector2(0.0, 30.0)
		for _n: int in 120:
			sim.step(DT, sim.facing, false, 0)
		var from := sim.kaiju_pos
		for _n: int in 60:
			sim.step(DT, sim.facing, false, 0)
		var speed := sim.kaiju_pos.distance_to(from)  # in the last second
		var top := sim.stat("speed")
		check(
			absf(speed / top - 1.0) < 0.01,
			(
				"%s: straight on, the croc walks %.2f units a second (the stage's speed %.2f)"
				% [stage, speed, top]
			)
		)


## D-355: the grown croc eases into his walk over about 1.3 s from a stand: under half his stride
## at 0.6 s, full by 1.35 s and never sooner than 1.25 s; the young croc sets off at once.
func _check_walk_start() -> void:
	var forms := {"young": {}}
	forms.merge(STAGES)
	for stage: String in forms:
		var levels: Dictionary = forms[stage]
		var sim := _croc(levels)
		sim.kaiju_pos = Vector2(0.0, 30.0)
		for _n: int in 30:
			sim.step(DT, Vector2.ZERO, false, 0)
		var full_at := -1.0
		var at_half := 0.0
		for n: int in 120:
			sim.step(DT, sim.facing, false, 0)
			if n + 1 == 36:  # 0.6 s
				at_half = sim.body.stride
			if full_at < 0.0 and sim.body.stride >= 0.999:
				full_at = float(n + 1) * DT
		if stage == "young":
			check(
				full_at > 0.0 and full_at <= YOUNG_OFF_S,
				(
					"young: sets off at once, full stride at %.2f s (bar <= %.2f)"
					% [full_at, YOUNG_OFF_S]
				)
			)
			continue
		check(
			absf(full_at - WALK_OFF_S) <= 0.05 and at_half < 0.5,
			(
				"%s: eases in, full stride at %.2f s (D-355 %.2f), %.2f of it at 0.6 s (bar < 0.5)"
				% [stage, full_at, WALK_OFF_S, at_half]
			)
		)


## A U-turn while walking at full stick: 1.94 s as the Behemoth, 3 s as the Colossus (D-187).
func _check_u_turn() -> void:
	for stage: String in STAGES:
		var levels: Dictionary = STAGES[stage]
		GaitTurn.check_big(check, _croc, stage, levels)


## The young croc turns smoothly (D-131) through GaitTurn.YOUNG_ROUTE, and two runs match.
func _check_young_turn() -> void:
	var legs := GaitTurn.young_legs(_croc({}))
	var speed := _croc({}).stat("speed")
	for n: int in legs.size():
		var leg: Dictionary = legs[n]
		var off := absf(
			angle_difference(deg_to_rad(Num.f(leg["heading"])), deg_to_rad(Num.f(leg["stick"])))
		)
		check(
			rad_to_deg(off) <= FACE_DEG,
			(
				"young croc leg %d ends facing %.2f deg, the stick %.2f (within %.0f)"
				% [n + 1, leg["heading"], leg["stick"], FACE_DEG]
			)
		)
		check(
			Num.f(leg["snap"]) <= SNAP_DEG,
			(
				"young croc leg %d turns smoothly (most in one frame %.2f deg <= %.0f)"
				% [n + 1, leg["snap"], SNAP_DEG]
			)
		)
		var least := WALK_SHARE * speed * Num.f(leg["seconds"])
		check(
			Num.f(leg["path"]) >= least,
			"young croc leg %d walks %.2f units (>= %.2f)" % [n + 1, leg["path"], least]
		)
	var again := GaitTurn.young_legs(_croc({}))
	check(again == legs, "young croc: two runs of the same seed walk the same route")
