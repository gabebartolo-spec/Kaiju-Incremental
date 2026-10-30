extends "res://tests/lib/runner.gd"
## Croc takes suite: the adult croc titan's Cascadeur takes (r13f) play at their game moments. The
## leap plays its clip on the sim's Dash phases: the crouch sinks the body, the feet leave the
## street through the flight and the settle, the clip's own rise is left to the sim, and the kaiju
## is back to idle after it; without the hook the body keeps its standing pose (on vs off). A
## standing stomp plays the keyed stomp of the foot the sim chose: that foot rises high and lands
## as the stomp's footfall inside the scene's wait; the adolescent, with no keyed stomp, lifts its
## foot in code and stays idle (on vs off). Fixed 60 Hz steps, no clock, no randomness.
##   godot --headless --path . --script tests/run_croc_takes_tests.gd

const DT := 1.0 / 60.0
## The adult croc's leap seconds (tuning contact.leap.stages.reptilian, the adult's stage).
const LEAP_SECONDS := {"crouch": 0.8, "flight": 0.867, "settle": 0.867, "recover": 1.067}


func suite_name() -> String:
	return "Croc takes"


func run_checks() -> void:
	await _t("_check_leap")
	await _t("_check_stomp")


## The leap clip on the Dash phases (on) against no hook (off): how far the pelvis dips in the
## crouch and how high it climbs over the leap (the rise stays the sim's), whether both feet leave
## the street in flight, and the state after.
func _check_leap() -> void:
	var on: Leap = await _leap(true)
	var off: Leap = await _leap(false)
	check(
		on.states == ["leap"] and off.states == ["idle"],
		"the leap hook plays the leap clip, none without it (%s vs %s)" % [on.states, off.states]
	)
	check(
		on.dip > 0.08 * on.hip and off.dip < 0.02 * on.hip,
		(
			"the crouch sinks the pelvis %.2f hip heights before lift-off (%.2f without the hook)"
			% [on.dip / on.hip, off.dip / on.hip]
		)
	)
	check(
		on.climb < 0.1 * on.hip and on.clip_rise > 0.5 * on.hip,
		(
			"the clip's own rise (%.2f hip heights) is the sim's: the pelvis climbs %.2f"
			% [on.clip_rise / on.hip, on.climb / on.hip]
		)
	)
	check(on.flew, "both feet leave the street through the flight")
	check(
		on.after == "idle" and on.finite and off.finite,
		"the kaiju is back to idle after the leap (%s), no bone NaN" % on.after
	)


## Each foot's keyed stomp on the adult (on) and the adolescent's code stomp (off): the clip
## played, the foot's top height (hip heights), and the footfall it lands.
func _check_stomp() -> void:
	for side: String in ["left", "right"]:
		var on: Stomp = await _stomp("adult", side)
		check(
			on.states.has("stomp_" + side[0]) and on.landed == side and on.after == "idle",
			(
				"the adult's %s stomp plays its keyed clip and lands that foot (%s, landed %s)"
				% [side, on.states, on.landed]
			)
		)
		check(
			on.landed_at < Rampage.STOMP_WAIT and is_equal_approx(on.strength, on.weight),
			(
				"it lands as a stomp's footfall inside the scene's wait (%.2f s, strength %.2f of %.2f)"
				% [on.landed_at, on.strength, on.weight]
			)
		)
		check(on.top > 0.2, "the stomping foot rises %.2f hip heights" % on.top)
	var off: Stomp = await _stomp("adolescent", "left")
	check(
		off.states == ["idle"] and off.landed == "left",
		"without keyed stomps the foot is lifted in code (%s, landed %s)" % [off.states, off.landed]
	)


## One standing stomp of the `side` foot at `stage`, and what it did.
func _stomp(stage: String, side: String) -> Stomp:
	var kaiju := _model(stage)
	var rig: KaijuRig = kaiju.find_children("*", "KaijuRig", true, false)[0]
	var gait: ClipGait = rig.gait
	var out := Stomp.new()
	for frame: int in 30:
		_step(kaiju, rig)
	var i := 0 if side == "left" else 1
	var base := rig.global_position.y
	var hip := gait.hip_height * gait.s
	out.weight = clampf(sqrt(gait.s / BipedGait.ADULT_SCALE), ClipStomp.WEIGHT_MIN, 1.0)
	var heard := func(foot: String, strength: float, _at: Vector3) -> void:
		if out.landed.is_empty():
			out.landed = foot
			out.strength = strength
			out.landed_at = out.t
	rig.foot_planted.connect(heard)
	kaiju.prefer_foot(side)
	kaiju.stomp()
	for frame: int in 90:
		_step(kaiju, rig)
		out.t += DT
		out.top = maxf(out.top, (rig.tail_world(gait.legs[i].tip).y - base) / hip)
		if not out.states.has(gait.state):
			out.states.append(gait.state)
	out.after = gait.state
	kaiju.queue_free()
	await process_frame
	return out


func _model(stage: String) -> KaijuModel:
	var def: Dictionary = Content.species_def("reptilian")
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, stage)
	root.add_child(kaiju)
	return kaiju


## Runs one leap at the adult's seconds, through the pose hook (hooked) or not.
func _leap(hooked: bool) -> Leap:
	var kaiju := _model("adult")
	var rig: KaijuRig = kaiju.find_children("*", "KaijuRig", true, false)[0]
	var gait: ClipGait = rig.gait
	var pelvis := rig.bone(rig.bone_names()[0])
	var out := Leap.new()
	for frame: int in 30:
		out.finite = out.finite and _step(kaiju, rig)
	var rest := pelvis.global_position.y
	out.hip = gait.hip_height * gait.s
	var clips := gait.clips
	for f: int in clips.frames_of("leap"):
		var up := clips.pose_at("leap", f).offset.y - clips.pose_at("leap", 0).offset.y
		out.clip_rise = maxf(out.clip_rise, up * clips.rig_scale * gait.s)
	var settle: float = LEAP_SECONDS["settle"]
	var recover: float = LEAP_SECONDS["recover"]
	var share := settle / (settle + recover)
	for phase: String in LEAP_SECONDS:
		var seconds: float = LEAP_SECONDS[phase]
		var frames := roundi(seconds / DT)
		for n: int in frames:
			if hooked:
				kaiju.leap(phase, float(n + 1) / frames, share)
			out.finite = out.finite and _step(kaiju, rig)
			if not out.states.has(gait.state):
				out.states.append(gait.state)
			var y := pelvis.global_position.y - rest
			if phase == "crouch":
				out.dip = maxf(out.dip, -y)
			out.climb = maxf(out.climb, y)
			if phase == "flight" and n == frames / 2:
				out.flew = not gait.legs[0].planted and not gait.legs[1].planted
	for frame: int in 60:
		out.finite = out.finite and _step(kaiju, rig)
	out.after = gait.state
	kaiju.queue_free()
	await process_frame
	return out


func _step(kaiju: KaijuModel, rig: KaijuRig) -> bool:
	kaiju.animate(DT, 0.0)
	for bone_name: String in rig.bone_names():
		if not rig.bone(bone_name).global_transform.origin.is_finite():
			return false
	return true


## One leap's measures (world units).
class Leap:
	var hip := 0.0
	var dip := 0.0
	var climb := 0.0
	var clip_rise := 0.0
	var flew := false
	var finite := true
	var states: Array[String] = []
	var after := ""


## One stomp's measures.
class Stomp:
	var t := 0.0
	var top := 0.0
	var landed := ""
	var landed_at := INF
	var strength := 0.0
	var weight := 0.0  # a stomp's footfall at this body (ClipStomp.landing)
	var states: Array[String] = []
	var after := ""
