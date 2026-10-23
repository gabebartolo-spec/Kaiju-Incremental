extends "res://tests/lib/runner.gd"
## Claw rake suite (D-177 motion, D-185 anatomy): at every growth step (young croc, Behemoth,
## Colossus) the real sim swipes with both arms and the raking arm is a heavy rake, not a dart: no
## bone stretches, the chest and hips twist into it and the feet stay put, the hand loads back,
## strikes low and wide in under 0.1 s on the sim's hit and carries on past the midline, the speed
## never ticks, and the shoulder, elbow and wrist stay inside a crocodilian forelimb's range (Otero
## et al. 2017 PeerJ 5:e3976 Table 2; Baier & Gatesy 2013 J Anat 223:462 + a 10 degree margin).
## Measured by tests/lib/rake_probe.gd in the rig's frame; "claw_fx" holds the numbers. Fixed 60 Hz
## steps. godot --headless --path . --script tests/run_claw_rake_tests.gd

const Probe := preload("res://tests/lib/rake_probe.gd")
const STAGES: Array[String] = ["young", "Behemoth", "Colossus"]
## The bars, in the director's words (brief_claw_rake.md, D-185).
const CHEST_LOAD := -15.0
const CHEST_SWING := 25.0
const STRIKE_ARC := 120.0
const OVERSHOOT := 30.0
const LOAD_RATIO := 3.0
const FIRST_TENTH := 0.30
const STRIKE_S := 0.1
const SPEED_STEP := 0.35
const HAND_CAP := 15.0
const LOAD_CAP := 25.0
const SLIDE := 0.001
## The arm shows outside the chest's silhouette from the game camera (rake_probe) in this many of
## the wind-up's frames (a young croc's clip rests its arms across the chest).
const SHOWN_LOAD := 7
## The share of its recover time the hand takes to settle to within 5% of its swing, at least.
const SETTLE_LO := 0.7
## Joint limits (degrees): croc range plus 10 (claw_fx rom).
const ROM_ELEV := 15.0
const ROM_CONE := 80.0
const ROM_ROLL := 30.0
const ROM_ELBOW := 120.0
const ROM_WRIST := 70.0

var _swipes: Dictionary = {}  # stage -> Array[Dictionary]


func suite_name() -> String:
	return "Claw rake"


func run_checks() -> void:
	for stage: String in STAGES:
		_swipes[stage] = Probe.run(root, stage)
		await process_frame
	await _t("_check_swipes")
	await _t("_check_body_and_feet")
	await _t("_check_strike")
	await _t("_check_speed")
	await _t("_check_path")
	await _t("_check_hand_cap")
	await _t("_check_joint_limits")
	await _t("_check_heavier_with_size")


func _each(stage: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var all: Array = _swipes[stage]
	for m: Dictionary in all:
		out.append(m)
	return out


func _tag(m: Dictionary) -> String:
	return "%s side %+d" % [m["stage"], m["side"]]


func _check_swipes() -> void:
	for stage: String in STAGES:
		var sides: Dictionary = {}
		for m: Dictionary in _each(stage):
			sides[Num.f(m["side"])] = true
			print(Probe.row(m))
			if OS.get_environment("RAKE_DEBUG") != "":
				print("trace speed/phi/chest: ", m["trace"])
				print("bends elbow/wrist: ", m["bends"])
		check(
			sides.size() == 2,
			"%s: the sim swipes with both arms (%d sides)" % [stage, sides.size()]
		)


## No bone stretches; the chest twists away to load and through the strike; planted feet stay put.
func _check_body_and_feet() -> void:
	for stage: String in STAGES:
		for m: Dictionary in _each(stage):
			var tag := _tag(m)
			check(
				Num.f(m["scale_dev"]) < 0.0001, "%s: no bone scales (%.4f)" % [tag, m["scale_dev"]]
			)
			check(
				Num.f(m["chest_load"]) <= CHEST_LOAD,
				(
					"%s: the chest turns >= %.0f deg away to load (%.1f)"
					% [tag, -CHEST_LOAD, m["chest_load"]]
				)
			)
			check(
				Num.f(m["chest_swing"]) >= CHEST_SWING,
				(
					"%s: the chest swings >= %.0f deg through the strike (%.1f)"
					% [tag, CHEST_SWING, m["chest_swing"]]
				)
			)
			check(
				Num.f(m["slide"]) < SLIDE,
				"%s: planted feet do not slide (%.4f hip)" % [tag, m["slide"]]
			)


## The strike lands on the snout line as the sim hits (the director: "keep it straight ahead"), in
## 0.1 s, low (the hand never above the shoulder), after a wind-up the game camera behind the
## kaiju sees: the claw is outside the chest's silhouette for most of it.
func _check_strike() -> void:
	for stage: String in STAGES:
		for m: Dictionary in _each(stage):
			var tag := _tag(m)
			check(
				absi(Num.i(m["cross_off"])) <= 1,
				(
					"%s: the hand crosses the snout line within 1 frame of the sim's hit (%d)"
					% [tag, m["cross_off"]]
				)
			)
			check(
				Num.i(m["vis_load"]) >= SHOWN_LOAD,
				(
					"%s: the arm shows from behind in >= %d of the %d wind-up frames (%d)"
					% [tag, SHOWN_LOAD, m["load_n"], m["vis_load"]]
				)
			)
			check(
				Num.f(m["win_s"]) <= STRIKE_S + 0.0001,
				(
					"%s: the frames at >= 50%% of peak speed total <= %.1f s (%.3f)"
					% [tag, STRIKE_S, m["win_s"]]
				)
			)
			check(
				Num.f(m["strike_h"]) <= 0.005,
				(
					"%s: the hand stays at or below the shoulder through the strike (%+.3f hip)"
					% [tag, m["strike_h"]]
				)
			)


## Slow load, fast strike; no ticks (only the impact frame jumps).
func _check_speed() -> void:
	for stage: String in STAGES:
		for m: Dictionary in _each(stage):
			var tag := _tag(m)
			check(
				Num.f(m["load_ratio"]) >= LOAD_RATIO,
				(
					"%s: strike peak speed >= %.0fx the load's mean (%.1f)"
					% [tag, LOAD_RATIO, m["load_ratio"]]
				)
			)
			check(
				Num.f(m["first01"]) <= FIRST_TENTH,
				(
					"%s: the first 0.1 s eases in, <= %.0f%% of peak (%.0f%%)"
					% [tag, FIRST_TENTH * 100.0, m["first01"] * 100.0]
				)
			)
			check(
				Num.f(m["dv_rest"]) <= SPEED_STEP,
				(
					"%s: speed changes <= %.0f%% of peak a frame outside the impact (%.0f%%)"
					% [tag, SPEED_STEP * 100.0, m["dv_rest"] * 100.0]
				)
			)


## A wide arc, and the follow-through carries well past the midline.
func _check_path() -> void:
	for stage: String in STAGES:
		for m: Dictionary in _each(stage):
			var tag := _tag(m)
			check(
				Num.f(m["arc_deg"]) >= STRIKE_ARC,
				(
					"%s: the arc about the shoulder is >= %.0f deg (%.0f)"
					% [tag, STRIKE_ARC, m["arc_deg"]]
				)
			)
			check(
				Num.f(m["over_deg"]) >= OVERSHOOT,
				(
					"%s: the hand passes the midline by >= %.0f deg (%.0f)"
					% [tag, OVERSHOOT, m["over_deg"]]
				)
			)


## D-185 "darts out upward diagonally": the hand never rises over the chest horizontal (the load
## behind the shoulder apart).
func _check_hand_cap() -> void:
	for stage: String in STAGES:
		for m: Dictionary in _each(stage):
			var tag := _tag(m)
			check(
				Num.f(m["elev_strike"]) <= HAND_CAP and Num.f(m["elev_follow"]) <= HAND_CAP,
				(
					"%s: strike and follow-through stay <= %.0f deg above the chest horizontal (%.0f, %.0f)"
					% [tag, HAND_CAP, m["elev_strike"], m["elev_follow"]]
				)
			)
			check(
				Num.f(m["elev_load"]) <= LOAD_CAP,
				(
					"%s: the load behind the shoulder rises <= %.0f deg (%.0f)"
					% [tag, LOAD_CAP, m["elev_load"]]
				)
			)


## D-185 anatomy: shoulder, elbow and wrist inside a crocodilian forelimb's range (chest frame).
func _check_joint_limits() -> void:
	for stage: String in STAGES:
		for m: Dictionary in _each(stage):
			var tag := _tag(m)
			check(
				Num.f(m["hum_elev"]) <= ROM_ELEV,
				(
					"%s: the upper arm rises <= %.0f deg over the chest horizontal (%.0f)"
					% [tag, ROM_ELEV, m["hum_elev"]]
				)
			)
			check(
				Num.f(m["cone"]) <= ROM_CONE,
				(
					"%s: the upper arm stays <= %.0f deg from its rest (%.0f)"
					% [tag, ROM_CONE, m["cone"]]
				)
			)
			check(
				Num.f(m["roll"]) <= ROM_ROLL,
				"%s: the upper arm rolls <= %.0f deg (%.0f)" % [tag, ROM_ROLL, m["roll"]]
			)
			check(
				Num.f(m["elbow"]) <= ROM_ELBOW,
				"%s: the elbow bends <= %.0f deg (%.0f)" % [tag, ROM_ELBOW, m["elbow"]]
			)
			check(
				Num.f(m["wrist"]) <= ROM_WRIST,
				"%s: the wrist bends <= %.0f deg (%.0f)" % [tag, ROM_WRIST, m["wrist"]]
			)


## Bigger is heavier: the hand settles over the recover_s of the growth step (to within 5% of its
## swing it takes 70-100% of it, the clip's idle sway only ever delaying it, so the quicker of a
## step's two swipes counts), so slower the bigger the step.
func _check_heavier_with_size() -> void:
	var last := 0.0
	for stage: String in STAGES:
		var best := 99.0
		var recover := 0.0
		for m: Dictionary in _each(stage):
			best = minf(best, Num.f(m["settle_s"]))
			recover = Num.f(m["recover_cfg"])
		check(
			best >= SETTLE_LO * recover and best <= recover,
			"%s: settles in %.2f s of its %.2f s recover" % [stage, best, recover]
		)
		check(
			best > last,
			"%s: settles slower than the step before (%.2f > %.2f)" % [stage, best, last]
		)
		last = best
