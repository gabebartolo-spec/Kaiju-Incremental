extends "res://tests/lib/runner.gd"
## The croc turns over its planted foot only as far as the stick turned it (D-177, the sim review of
## the gait fix): the hand-over from the river, where the body still lies along the water about 90
## deg off the way it faces, catches its heading up about the middle and does not swing the body
## about the feet; and a leap (the dash button), which holds its own axis, is not slid sideways
## by a stick a little off it.
## Seeded by design: every sim is Seeds.make("army", 0) on the seeded city 0.

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


func suite_name() -> String:
	return "Gait"


func run_checks() -> void:
	await _t("_check_hand_over")
	await _t("_check_dash")
	await _t("_check_straight")


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
			sim.step(DT, Vector2.ZERO, false, RampageSim.STOMP)
		var off := rad_to_deg(absf(sim.body.heading.angle_to(sim.facing)))
		var from := sim.kaiju_pos
		for _n: int in HAND_OVER_FRAMES:
			sim.step(DT, sim.facing, false, RampageSim.STOMP)  # the stick held from the first live tick
		var moved := sim.kaiju_pos.distance_to(from)
		check(
			rose and not sim.emerge.active and off > 30.0,
			"%s: the rise hands over with the body %.0f deg off the way it faces" % [stage, off]
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
			sim.step(DT, sim.facing, false, RampageSim.STOMP)  # walking north
		var axis := sim.facing
		var from := sim.kaiju_pos
		var stick := axis.rotated(OFF_AXIS)
		sim.step(DT, stick, false, DASH_BUTTON | RampageSim.STOMP)
		var dashed := sim.body.dash.on()
		for _n: int in roundi(6.0 / DT):
			if not sim.body.dash.on():
				break
			# the stick held a little off the axis for the whole leap
			sim.step(DT, stick, false, RampageSim.STOMP)
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
			sim.step(DT, sim.facing, false, RampageSim.STOMP)
		var from := sim.kaiju_pos
		for _n: int in 60:
			sim.step(DT, sim.facing, false, RampageSim.STOMP)
		var speed := sim.kaiju_pos.distance_to(from)  # in the last second
		var top := sim.stat("speed")
		check(
			absf(speed / top - 1.0) < 0.01,
			(
				"%s: straight on, the croc walks %.2f units a second (the stage's speed %.2f)"
				% [stage, speed, top]
			)
		)
