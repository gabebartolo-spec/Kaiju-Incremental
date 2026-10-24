extends "res://tests/lib/runner.gd"
## Motion suite, the gate on how the croc titan moves (director D-177: "motion, alongside the
## destruction mechanics, is the most important element of our design"; "Motion first"; DESIGN
## Motion: "the head leads, the legs step the turn, never a sliding pivot or 'swivelling on the
## spot like a plastic toy'"; 2026-10-23 "his legs so twitchy, and he swivels rather than turns").
## Every change to his body, speed, steps or animation must pass it. At each growth step (young,
## Behemoth, Colossus) the real sim drives his ClipGait at 60 Hz (tests/lib/motion_drive.gd) on
## five routes: a straight walk, 90 and 180 deg turns while walking, a turn from standing and a
## held curve. Bars:
##   - a planted foot holds its spot (under SLIDE_MAX units/s);
##   - no catch-step shuffle (at most CATCH_MAX a second; CATCH_SMOOTH_TURN in the young croc's
##     smooth turns, D-131);
##   - the legs step no faster than CADENCE_MAX times the walk clip's authored pace, and a stepping
##     body's sim step is half its clip's stride (within STEP_TOL), so feet are passed at the pace
##     the body walks;
##   - no knee pops (shin jerk p99 at most JERK_WALK, JERK_TURN in turns) and no leg locked straight
##     (planted reach at most STRETCH_MAX);
##   - a body that steps its turns (Behemoth, Colossus; D-131) never yaws with no foot down, the
##     sim's pivot is the drawn planted foot (PIVOT_MAX) and the body turns about it (CENTRE_MAX);
##   - the swing foot lifts no higher than its stage's share of hip height (LIFT_MAX).
## Deterministic: seeded sim, fixed step, no clock.
##   godot --headless --path . --script tests/run_motion_tests.gd

const Drive := preload("res://tests/lib/motion_drive.gd")
const SLIDE_MAX := 0.05
const CATCH_MAX := 0.5
const CATCH_SMOOTH_TURN := 1.0
const CADENCE_MAX := 2.3
const STEP_TOL := 0.02
const JERK_WALK := 5.0
const JERK_TURN := 8.0
const STRETCH_MAX := 0.97
const PIVOT_MAX := 0.1
const CENTRE_MAX := 0.6
## Toe-tip rise over the walk as a share of hip height: the Colossus lifts 2% (lead 2026-10-23: the
## young croc may bounce a little, at most 5%).
const LIFT_MAX := {"young": 0.05, "Behemoth": 0.03, "Colossus": 0.03}
const CLIP_STAGE := {"young": "baby", "Behemoth": "adolescent", "Colossus": "adult"}

var _runs: Dictionary = {}  # "stage/route" -> Drive.drive()


func suite_name() -> String:
	return "Motion"


func run_checks() -> void:
	await _t("_check_feet_hold")
	await _t("_check_no_shuffle")
	await _t("_check_cadence")
	await _t("_check_step_len")
	await _t("_check_knees")
	await _t("_check_turn_steps")
	await _t("_check_turn_pivot")
	await _t("_check_lift")


func _run(stage: String, route: String) -> Dictionary:
	var key := "%s/%s" % [stage, route]
	if not _runs.has(key):
		_runs[key] = Drive.drive(root, stage, route)
	var out: Dictionary = _runs[key]
	return out


## The worst value of `field` over the routes, and a "route value" list for the message.
func _worst(stage: String, routes: Array, field: String) -> Array:
	var worst := 0.0
	var text := ""
	for route: String in routes:
		var v := Num.f(_run(stage, route)[field])
		worst = maxf(worst, v)
		text += " %s %.2f" % [route, v]
	return [worst, text]


func _check_feet_hold() -> void:
	for stage: String in Drive.STAGES:
		var w := _worst(stage, Drive.ROUTES, "slide")
		check(
			Num.f(w[0]) < SLIDE_MAX,
			"%s: a planted foot holds its spot (%s units/s < %.2f)" % [stage, w[1], SLIDE_MAX]
		)


## A body that turns smoothly (the young croc, D-131 "Baby turns smoothly") turns over its planted
## feet, and catch steps are how they keep up: in its turns it may take up to CATCH_SMOOTH_TURN a
## second (lead 2026-10-23); walking straight, and for every body that steps its turns, CATCH_MAX.
## Each catch step still answers to the slide, lift and jerk bars, and the motion critic judges
## the young croc's turn clip.
func _check_no_shuffle() -> void:
	for stage: String in Drive.STAGES:
		var smooth: bool = not _run(stage, "straight")["stepping"]
		var routes: Array = Drive.ROUTES if not smooth else ["straight"]
		var w := _worst(stage, routes, "catch")
		check(
			Num.f(w[0]) <= CATCH_MAX,
			"%s: no catch-step shuffle (%s a second <= %.1f)" % [stage, w[1], CATCH_MAX]
		)
		if smooth:
			var turns := _worst(stage, ["turn90", "turn180", "stand_turn", "curve"], "catch")
			check(
				Num.f(turns[0]) <= CATCH_SMOOTH_TURN,
				(
					"%s: its smooth turns keep up with few catch steps (%s a second <= %.1f, D-131)"
					% [stage, turns[1], CATCH_SMOOTH_TURN]
				)
			)


func _check_cadence() -> void:
	for stage: String in Drive.STAGES:
		var run := _run(stage, "straight")
		var steps := Num.f(run["steps"])
		var ratio := steps / maxf(Num.f(run["authored_steps"]), 0.001)
		check(
			ratio <= CADENCE_MAX,
			(
				"%s: walking, the legs step %.2f a second, %.2fx the clip's authored %.2f (<= %.1fx)"
				% [stage, steps, ratio, run["authored_steps"], CADENCE_MAX]
			)
		)


func _check_step_len() -> void:
	for stage: String in Drive.STAGES:
		var run := _run(stage, "straight")
		if not run["stepping"]:
			print("SKIP: %s walks by distance, not the sim's step clock (D-131)" % stage)
			continue
		var step := Num.f(run["step"])
		var half := Num.f(run["half_stride"])
		check(
			absf(step / half - 1.0) <= STEP_TOL,
			(
				"%s: the sim's step is half the clip's stride (%.3f vs %.3f, within %.0f%%)"
				% [stage, step, half, STEP_TOL * 100]
			)
		)


func _check_knees() -> void:
	for stage: String in Drive.STAGES:
		var walk := Num.f(_run(stage, "straight")["jerk"])
		check(
			walk <= JERK_WALK,
			(
				"%s: walking, no knee pops (shin jerk p99 %.1f deg/frame^2 <= %.0f)"
				% [stage, walk, JERK_WALK]
			)
		)
		var turns := _worst(stage, ["turn90", "turn180", "stand_turn", "curve"], "jerk")
		check(
			Num.f(turns[0]) <= JERK_TURN,
			"%s: turning, no knee pops (shin jerk p99%s <= %.0f)" % [stage, turns[1], JERK_TURN]
		)
		var reach := _worst(stage, Drive.ROUTES, "stretch")
		check(
			Num.f(reach[0]) <= STRETCH_MAX,
			"%s: no planted leg locked straight (reach%s <= %.2f)" % [stage, reach[1], STRETCH_MAX]
		)


func _check_turn_steps() -> void:
	for stage: String in Drive.STAGES:
		if not _run(stage, "straight")["stepping"]:
			print("SKIP: %s turns smoothly by decision (D-131)" % stage)
			continue
		var w := _worst(stage, ["turn90", "turn180", "stand_turn", "curve"], "aloft_yaw")
		check(
			Num.f(w[0]) <= 0.0,
			"%s: the body never yaws with no foot down (%s deg == 0)" % [stage, w[1]]
		)


func _check_turn_pivot() -> void:
	for stage: String in Drive.STAGES:
		if not _run(stage, "straight")["stepping"]:
			print("SKIP: %s turns smoothly by decision (D-131)" % stage)
			continue
		var turns := ["turn90", "turn180", "stand_turn"]
		var pivot := _worst(stage, turns, "pivot")
		check(
			Num.f(pivot[0]) <= PIVOT_MAX,
			(
				"%s: the sim turns him about the drawn planted foot (%s hip heights <= %.1f)"
				% [stage, pivot[1], PIVOT_MAX]
			)
		)
		var centre := _worst(stage, turns, "centre")
		check(
			Num.f(centre[0]) <= CENTRE_MAX,
			(
				"%s: the body turns about a planted foot, not its middle (%s hip heights <= %.1f)"
				% [stage, centre[1], CENTRE_MAX]
			)
		)


## The walk clip's toe-tip rise as a share of hip height (its rest hip), at each growth step.
func _check_lift() -> void:
	for stage: String in Drive.STAGES:
		var clips := KaijuClips.read("res://assets/kaiju/reptilian_%s.kclip" % CLIP_STAGE[stage])
		var lo := INF
		var hi := -INF
		for f: int in clips.frames_of("walk"):
			var y := clips.pose_at("walk", float(f)).feet[0].y
			lo = minf(lo, y)
			hi = maxf(hi, y)
		var hip: Vector3 = clips._rest_heads[clips.bones.find("leg_l0")]
		var share := (hi - lo) / hip.y
		var most: float = LIFT_MAX[stage]
		check(
			share <= most,
			(
				"%s: the swing foot lifts %.1f%% of hip height (<= %.0f%%)"
				% [stage, share * 100.0, most * 100.0]
			)
		)
