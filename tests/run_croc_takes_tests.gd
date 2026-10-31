extends "res://tests/lib/runner.gd"
## Croc takes suite: the adult croc titan's Cascadeur takes (r13f) play at their game moments. The
## leap plays its clip on the sim's Dash phases: the crouch sinks the body, the feet leave the
## street through the flight and the settle, the clip's own rise is left to the sim, and the kaiju
## is back to idle after it; without the hook the body keeps its standing pose (on vs off). A
## standing stomp plays the keyed stomp of the foot the sim chose: that foot rises high and lands
## as the stomp's footfall inside the scene's wait; the adolescent, with no keyed stomp, lifts its
## foot in code and stays idle (on vs off). Walking (PR3): from standing the walk start plays about
## 1.3 s, then the walk (the adolescent walks at once); momentum blends the walk into the keyed run
## (blend 1 vs 0); a slam plays the slam stop to its end; a walking turn lays head_look (mirrored
## for a right turn) or the 90 deg walk turn over the upper body (vs no turn).
## Fixed 60 Hz steps, no clock, no randomness.
##   godot --headless --path . --script tests/run_croc_takes_tests.gd

const DT := 1.0 / 60.0
## The adult croc's leap seconds (tuning contact.leap.stages.reptilian, the adult's stage).
## When a walking turn starts (s): past the walk start, in the walk loop.
const TURN_AT := 2.0
const LEAP_SECONDS := {"crouch": 0.8, "flight": 0.867, "settle": 0.867, "recover": 1.067}


func suite_name() -> String:
	return "Croc takes"


func run_checks() -> void:
	await _t("_check_leap")
	await _t("_check_stomp")
	await _t("_check_walk_start")
	await _t("_check_run")
	await _t("_check_slam_stop")
	await _t("_check_walk_turns")


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


## From standing, the adult plays the walk start's first steps, then the walk; the adolescent
## (no take) walks at once.
func _check_walk_start() -> void:
	var on: Walk = await _walk("adult", 3.0)
	var off: Walk = await _walk("adolescent", 3.0)
	var start: float = on.seconds.get("walk_start", 0.0)
	check(
		on.states.slice(0, 3) == ["idle", "walk_start", "walk"],
		"standing to walking: %s (the adolescent: %s)" % [on.states, off.states]
	)
	check(
		absf(start - ClipTakes.WALK_START_SECONDS) < 0.1 and not off.states.has("walk_start"),
		"the walk start plays %.2f s before the walk loop" % start
	)


## Full momentum (blend 1) against none, on the same step clock: the walk becomes the run.
func _check_run() -> void:
	var on: Walk = await _walk("adult", 3.0, {"run": 1.0})
	var off: Walk = await _walk("adult", 3.0, {"run": 0.0})
	var most := 0.0
	for f: int in mini(on.arm.size(), off.arm.size()):
		most = maxf(most, on.arm[f].angle_to(off.arm[f]))
	check(on.finite and on.states.has("walk"), "he runs on the walk's state, no bone NaN")
	check(most > 0.25, "the run moves the arm %.2f rad from the walk's at the same step" % most)


## A slam while he walks plays the slam stop to its end; no slam, he walks on.
func _check_slam_stop() -> void:
	var on: Walk = await _walk("adult", 7.0, {"slam_at": 2.5})
	var off: Walk = await _walk("adult", 7.0)
	var played: float = on.seconds.get("slam_stop", 0.0)
	check(
		absf(played - on.slam_s) < 0.1 and on.after == "idle",
		"the slam stop plays %.2f s of its %.2f s, then idle (%s)" % [played, on.slam_s, on.states]
	)
	check(not off.states.has("slam_stop"), "no slam, no slam stop (%s)" % [off.states])


## A small walking turn lays head_look on (the right one mirrored), a big one the walk turn; the
## head turns with the take, not without a turn.
func _check_walk_turns() -> void:
	var none: Walk = await _walk("adult", 4.0)
	for ahead: float in [0.6, -0.6, 1.4, -1.4]:
		var on: Walk = await _walk("adult", 4.0, {"ahead": ahead})
		var big := absf(ahead) >= ClipTakes.BIG_TURN
		var want := ("walk_turn_left" if ahead > 0.0 else "walk_turn_right") if big else "head_look"
		var most := 0.0
		for f: int in mini(on.head.size(), none.head.size()):
			most = maxf(most, on.head[f].angle_to(none.head[f]))
		check(
			on.turn == want and on.mirrored == (not big and ahead < 0.0),
			"a %.1f rad walking turn plays %s (mirrored %s)" % [ahead, on.turn, on.mirrored]
		)
		check(
			on.weight > 0.9 and most > 0.1,
			"it lays on (%.2f), the head turns %.2f rad" % [on.weight, most]
		)
	check(none.turn.is_empty(), "no turn, no turn take (%s)" % none.turn)


## `stage` standing 0.5 s, then walking `seconds` on a step clock; `with`: "run" the run blend,
## "ahead" a turn (rad) from TURN_AT (in the walk loop), closing over 1.5 s, "slam_at" a slam (s)
## that stops him.
func _walk(stage: String, seconds: float, with := {}) -> Walk:
	var run: float = with.get("run", 0.0)
	var ahead: float = with.get("ahead", 0.0)
	var slam_at: float = with.get("slam_at", INF)
	var kaiju := _model(stage)
	var rig: KaijuRig = kaiju.find_children("*", "KaijuRig", true, false)[0]
	var gait: ClipGait = rig.gait
	var speed := gait.stride() * 0.5  # half a stride a second
	var out := Walk.new()
	if gait.clips.has_clip("slam_stop"):
		out.slam_s = gait.clips.frames_of("slam_stop") / gait.clips.fps
	var phase := 0.0
	for f: int in roundi((seconds + 0.5) / DT):
		var t := f * DT
		var moving := t >= 0.5 and t < slam_at
		if moving:
			kaiju.position.z -= speed * DT
			phase += 1.0 * DT  # one step a second
		var turn := ahead * clampf(1.0 - (t - TURN_AT) / 1.5, 0.0, 1.0) if moving else 0.0
		kaiju.follow_steps(phase if moving else INF, 1.0, run, 1 if t >= slam_at else 0)
		kaiju.animate(DT, 1.0 if moving else 0.0, turn)
		out.finite = out.finite and rig.bone("spine0").global_transform.origin.is_finite()
		if out.states.is_empty() or out.states[-1] != gait.state:
			out.states.append(gait.state)
		out.seconds[gait.state] = out.seconds.get(gait.state, 0.0) + DT
		out.arm.append(rig.bone("arm_l1").global_transform.basis.get_rotation_quaternion())
		out.head.append(rig.bone("head1").global_transform.basis.get_rotation_quaternion())
		if not gait.takes.turn.is_empty():
			out.turn = gait.takes.turn
			out.mirrored = gait.takes.mirrored
			out.weight = maxf(out.weight, gait.takes.turn_weight())
	out.after = gait.state
	kaiju.queue_free()
	await process_frame
	return out


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


## One walk's record.
class Walk:
	var finite := true
	var states: Array[String] = []
	var seconds: Dictionary = {}  # state -> seconds played
	var arm: Array[Quaternion] = []  # the left forearm's world turn per frame
	var head: Array[Quaternion] = []  # the skull's
	var turn := ""
	var mirrored := false
	var weight := 0.0
	var slam_s := 0.0  # the slam stop take's length (s)
	var after := ""
