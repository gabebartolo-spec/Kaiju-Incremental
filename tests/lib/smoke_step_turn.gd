extends RefCounted
## The kaiju's turns, driven by the real sim the way the rampage scene drives it (60 Hz): the
## reptilian walks north and the stick swings west.
## The adult (the heavy Komodo, D-201 "Yes, animations lead"): he moves only as fast as his clips
## show, so a 90 deg turn takes about the Cascadeur turn clip's 4.5 s, the body never swings more
## than MAX_YAW_DEG in any YAW_WINDOW_S, his feet plant only on the clip's planted bits (no catch
## steps or re-plants), left and right in turn and never in the same frame, a planted foot holds
## its spot, and the head shows the sim's aim with the neck inside its cap (D-200 "Head aims, body
## follows").
## The baby turns smoothly at its pre-stepped rates (D-131, "Baby turns smoothly").

const StageGait := preload("res://tests/lib/smoke_stage_gait.gd")
const DT := 1.0 / 60.0
const ADULT := {"evolve1": 1, "evolve2": 1}
const WALK_S := 3.0
## The stick swings at these places in a step (the step clock's fraction, within SWING_NEAR), so
## either foot may be down when the turn starts.
const SWINGS := [0.0, 0.5]
const SWING_NEAR := 0.1
const TURN_S := 7.0
## The adult's 90 deg turn (s): about the Cascadeur turn clip's 4.5 s (D-201).
const MIN_TURN_S := 4.0
const MAX_TURN_S := 5.0
## The most the adult's body may yaw in any window this long (deg in s; the director's snap
## complaint, D-200).
const MAX_YAW_DEG := 45.0
const YAW_WINDOW_S := 0.3
## A planted foot may drift at most this far (world units; the lead's bar for the heavy class).
const MAX_DRIFT := 0.1
## The head's aim may be off the sim's heading by the clip's own head sway on a straight walk plus
## this (deg); the neck turns at most the aim's neck_max_deg plus this (deg).
const AIM_SLACK_DEG := 3.0
const NECK_SLACK_DEG := 0.5
## The turn is made when the yaw still to turn is under this (rad, about 1 deg).
const LANDED := 0.02
## The baby's smooth 90 deg turn (D-131), measured 2026-10-21 at its pre-stepped rates (turn-weight
## d24fe80e), and the share it may move.
const BABY_TURN_S := 0.60
const BABY_SHARE := 0.1


static func check(check: Callable, root: Node) -> void:
	var adult := _adult(root)
	check.call(
		adult["took"] >= MIN_TURN_S and adult["slowest"] <= MAX_TURN_S,
		(
			"the adult's 90 deg turn takes %.2f-%.2f s (%.1f-%.1f s, his turn clip's pace, D-201)"
			% [adult["took"], adult["slowest"], MIN_TURN_S, MAX_TURN_S]
		)
	)
	check.call(
		adult["yaw"] <= MAX_YAW_DEG,
		(
			"his body yaws at most %.1f deg in any %.1f s (<= %.0f)"
			% [adult["yaw"], YAW_WINDOW_S, MAX_YAW_DEG]
		)
	)
	check.call(
		adult["off_clip"] == 0,
		(
			"his feet are down exactly when the clip's are (%d foot-frames off == 0)"
			% adult["off_clip"]
		)
	)
	check.call(
		adult["same_side"] == 0 and adult["same_frame"] == 0 and adult["falls"] >= 4,
		(
			"left and right plant in turn (%d footfalls, %d after the same foot, %d in one frame)"
			% [adult["falls"], adult["same_side"], adult["same_frame"]]
		)
	)
	check.call(
		adult["drift"] < MAX_DRIFT,
		"a planted foot holds its spot (%.3f < %.2f units)" % [adult["drift"], MAX_DRIFT]
	)
	check.call(
		adult["neck"] <= adult["neck_max"] + NECK_SLACK_DEG,
		"the neck stays inside its cap (%.1f <= %.0f deg)" % [adult["neck"], adult["neck_max"]]
	)
	(
		check
		. call(
			adult["aim"] <= adult["sway"] + AIM_SLACK_DEG,
			(
				"the head shows the sim's aim through the turn (off by %.1f deg <= the walk's %.1f + %.0f)"
				% [adult["aim"], adult["sway"], AIM_SLACK_DEG]
			)
		)
	)
	StageGait.check(check, root)  # every growth step's stride, and the held curve (D-177)
	var baby := _baby(root)
	check.call(
		absf(baby - BABY_TURN_S) <= BABY_TURN_S * BABY_SHARE,
		(
			"the baby turns smoothly, 90 deg in %.2f s (%.2f s +- %.0f%%)"
			% [baby, BABY_TURN_S, BABY_SHARE * 100]
		)
	)


## The adult's turn from each of the SWINGS: the shortest and longest, and the worst of the rest.
static func _adult(root: Node) -> Dictionary:
	var out := {"took": INF, "slowest": 0.0}
	for swing: float in SWINGS:
		var one := _turn(ADULT, root, swing)
		out["took"] = minf(Num.f(out["took"]), Num.f(one["took"]))
		out["slowest"] = maxf(Num.f(out["slowest"]), Num.f(one["took"]))
		for key: String in one:
			if key != "took":
				out[key] = maxf(Num.f(out.get(key, 0.0)), Num.f(one[key]))
	return out


## The baby's 90 deg turn (s).
static func _baby(root: Node) -> float:
	var one := _turn({}, root)
	return Num.f(one["took"])


## One walk north then a 90 deg turn west at `levels`, the stick swinging at `at_step` of a step.
static func _turn(levels: Dictionary, root: Node, at_step: float = 0.0) -> Dictionary:
	var def := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), levels, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), def, tree)
	var layout: Array[Dictionary] = [
		{"x": 38.0, "z": 38.0, "w": 2, "d": 2, "h": 2, "tier": 1, "style": 0}
	]
	var tuning := CityGrowth.for_stats(stats)  # the stage's own tuning and speed, as played
	var sim := RampageSim.new(stats, tuning, layout, Seeds.make("army", 0))
	sim.body.use_species("reptilian")
	sim.kaiju_pos = Vector2(0, 30)
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, KaijuModel.stage_for(sim.size_tier()))
	kaiju.scale = Vector3.ONE * sim.body_scale()
	root.add_child(kaiju)
	var gait: KaijuGait = kaiju._rig.gait
	var clip_gait: ClipGait = gait as ClipGait
	var falls: Array[Vector2i] = []  # (frame, 0 left / 1 right)
	var frame: Array[int] = [0]
	kaiju.foot_planted.connect(
		func(side: String, _strength: float, _at: Vector3) -> void:
			if side != "tail":
				falls.append(Vector2i(frame[0], 0 if side == "left" else 1))
	)
	var walk := Walk.new()
	var turn_t := INF  # when the stick swung west
	var landed := INF
	for f: int in roundi((WALK_S + TURN_S) / DT):
		var t := f * DT
		frame[0] = f
		var into := fposmod(sim.body.phase, 1.0) - at_step
		if turn_t == INF and t >= WALK_S and into >= 0.0 and into < SWING_NEAR:
			turn_t = t
		var move := Vector2(0, -1) if t < turn_t else Vector2(-1, 0)
		sim.step(DT, move, false, 0)
		kaiju.position = Vector3(sim.kaiju_pos.x, 0.0, sim.kaiju_pos.y)
		kaiju.rotation.y = atan2(-sim.body.heading.x, -sim.body.heading.y)
		kaiju.follow_steps(sim.body.step_clock(), sim.body.step_ratio)
		kaiju.follow_body(sim.body)
		kaiju.animate(DT, 1.0, -sim.body.turn_left)
		if clip_gait != null:
			walk.sample(kaiju, clip_gait, t >= turn_t and t <= landed)
		if t >= turn_t and landed == INF and absf(sim.body.turn_left) < LANDED:
			landed = t
	kaiju.free()
	var out := {"took": landed - turn_t}
	if clip_gait != null:
		out.merge(walk.result(falls, roundi(turn_t / DT), roundi(landed / DT)))
	return out


## What the adult's feet, body and head do frame by frame.
class Walk:
	var yaws: Array[float] = []  # the body's yaw each frame
	var off_clip := 0
	var drift := 0.0
	var neck := 0.0
	var neck_max := 0.0
	var sway := 0.0  # the head's aim off the heading on the straight walk (deg)
	var aim := 0.0  # and through the turn
	var _lock: Array[Vector3] = [Vector3.INF, Vector3.INF]

	func sample(kaiju: KaijuModel, gait: ClipGait, turning: bool) -> void:
		var rig := kaiju._rig
		yaws.append(gait.body_yaw)
		var aim_cfg: Dictionary = BodyClass.of_kind(rig.kind).get("aim", {})
		neck_max = Num.f(aim_cfg.get("neck_max_deg", 180.0))
		neck = maxf(neck, absf(rad_to_deg(wrapf(gait.model_yaw - gait.body_yaw, -PI, PI))))
		for i: int in 2:
			var leg: BipedGait.Leg = gait.legs[i]
			off_clip += 1 if leg.planted != gait.clip_planted[i] else 0
			var toe := rig.tail_world(leg.names[2])
			if not leg.planted:
				_lock[i] = Vector3.INF
				continue
			if _lock[i] == Vector3.INF:
				_lock[i] = toe
			drift = maxf(drift, Vector2(toe.x - _lock[i].x, toe.z - _lock[i].z).length())
		if rig.has_bone("head1"):
			var skull := rig.tail_world("head1") - rig.bone("head1").global_position
			var off := absf(rad_to_deg(wrapf(atan2(-skull.x, -skull.z) - gait.model_yaw, -PI, PI)))
			if turning:
				aim = maxf(aim, off)
			elif yaws.size() > 60:  # the straight walk, once under way
				sway = maxf(sway, off)

	## The worst yaw in any window, and the footfalls from the turn's start to its end.
	func result(falls: Array[Vector2i], from: int, to: int) -> Dictionary:
		var window := roundi(YAW_WINDOW_S / DT)
		var most := 0.0
		for n: int in range(from, mini(to, yaws.size() - window)):
			most = maxf(most, absf(wrapf(yaws[n + window] - yaws[n], -PI, PI)))
		var count := 0
		var same_side := 0
		var same_frame := 0
		var last := Vector2i(-1, -1)
		for fall: Vector2i in falls:
			if fall.x < from or fall.x > to:
				continue
			count += 1
			same_side += 1 if last.x >= 0 and fall.y == last.y and fall.x != last.x else 0
			same_frame += 1 if fall.x == last.x else 0
			last = fall
		return {
			"yaw": rad_to_deg(most),
			"off_clip": off_clip,
			"falls": count,
			"same_side": same_side,
			"same_frame": same_frame,
			"drift": drift,
			"neck": neck,
			"neck_max": neck_max,
			"sway": sway,
			"aim": aim,
		}
