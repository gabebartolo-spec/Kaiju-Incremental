extends "res://tests/lib/runner.gd"
## Croc standing suite (D-047): the clip-driven croc titan, at every stage, does what the sim asks
## of a body that stands. Each sim stomp lifts one foot, alternating, and plants it inside the
## scene's wait for it (Rampage.STOMP_WAIT) at a stomp's weight, so the ring and cracks land under
## a foot, and no foot slides; the claw rake swings the raking arm over the clip's pose, only it,
## and it comes back to rest; with no rake called the arms match a calm kaiju's. Fixed 60 Hz
## steps, no clock, no randomness.
##   godot --headless --path . --script tests/run_croc_standing_tests.gd

const STAGES: Array[String] = ["baby", "adolescent", "adult"]
const DT := 1.0 / 60.0
## Stomps on the sim's 0.7 s beat, and the footfall weight below which a step is not a stomp.
const BEATS := 6
const BEAT_FRAMES := 42
const STOMP_WEIGHT := 0.35


func suite_name() -> String:
	return "Croc standing"


func run_checks() -> void:
	await _t("_check_standing_stomp")
	await _t("_check_claw_rake")


func _model(stage: String) -> KaijuModel:
	var colors: Dictionary = Content.species_def("reptilian")["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, stage)
	root.add_child(kaiju)
	return kaiju


func _rig_of(kaiju: KaijuModel) -> KaijuRig:
	return kaiju.find_children("*", "KaijuRig", true, false)[0]


## Standing, each sim stomp lifts one foot (alternating) and plants it inside the scene's wait, at
## a stomp's weight, so the ring and cracks have a foot to land under; no foot slides.
func _check_standing_stomp() -> void:
	var wait_frames := ceili(Rampage.STOMP_WAIT / DT)
	for stage: String in STAGES:
		var kaiju := _model(stage)
		var rig := _rig_of(kaiju)
		var feet: Array[Dictionary] = []
		var clock: Array[int] = [0]  # an array: a lambda copies plain ints
		rig.foot_planted.connect(
			func(side: String, strength: float, _at: Vector3) -> void:
				if side != "tail":
					feet.append({"side": side, "strength": strength, "frame": clock[0]})
		)
		for i: int in 60:
			kaiju.animate(DT, 0.0)
		var rest := _toe_height(rig)
		var rose := 0.0
		var wrong := 0
		var sides: Array[String] = []
		var finite := true
		for beat: int in BEATS:
			var called := clock[0]
			var before := feet.size()
			kaiju.stomp()
			for f: int in BEAT_FRAMES:
				clock[0] += 1
				finite = finite and _step(kaiju, rig)
				rose = maxf(rose, _toe_height(rig) - rest)
			var landed := feet.slice(before)
			if landed.size() != 1:
				wrong += 1  # no foot came down, or more than one
				continue
			sides.append(str(landed[0]["side"]))
			if Num.i(landed[0]["frame"]) - called > wait_frames:
				wrong += 1  # too late for the wait
			elif Num.f(landed[0]["strength"]) < STOMP_WEIGHT:
				wrong += 1  # a settling step's footfall, not a stomp
		var alternate := sides.size() == BEATS
		for i: int in range(1, sides.size()):
			alternate = alternate and sides[i] != sides[i - 1]
		var hip := kaiju.hip_height()
		check(
			wrong == 0 and alternate and rose > 0.15 * hip and finite,
			(
				(
					"%s standing: each stomp lifts a foot (%.2f hip) and plants it within STOMP_WAIT, "
					% [stage, rose / hip]
				)
				+ "alternating (wrong %d, sides %s)" % [wrong, ",".join(sides)]
			)
		)
		check(
			kaiju.foot_drift() <= 0.05 * hip,
			(
				"%s standing stomps: no foot slides (%.3f <= %.3f)"
				% [stage, kaiju.foot_drift(), 0.05 * hip]
			)
		)
		kaiju.queue_free()
		await process_frame


## Highest toe above the street (world units).
func _toe_height(rig: KaijuRig) -> float:
	var top := 0.0
	for leg_name: String in ["leg_l2", "leg_r2"]:
		top = maxf(top, rig.tail_world(leg_name).y - rig.global_position.y)
	return top


## The claw rake (a windup, then the swipe 0.3 s on) moves the raking arm and only that arm, and
## it comes back to rest; with no rake called, nothing about the arms differs from a calm kaiju's.
func _check_claw_rake() -> void:
	for stage: String in STAGES:
		await _rake_one(stage, -1.0)
		await _rake_one(stage, 1.0)


func _rake_one(stage: String, side: float) -> void:
	var rake := _model(stage)
	var calm := _model(stage)
	var rig := _rig_of(rake)
	var rig_calm := _rig_of(calm)
	var finite := true
	for i: int in 40:
		finite = finite and _step(rake, rig) and _step(calm, rig_calm)
	var before := _arm_gap(rig, rig_calm)
	rake.tail_sweep(side, "claw_windup")
	var gap: Array[float] = [0.0, 0.0]  # the widest the hands parted, by side of the body (-x, +x)
	var end: Array[float] = [0.0, 0.0]
	for f: int in 120:  # 2 s: the windup 0.3 s, then the rake; 0.7 s in all
		if f == 18:
			rake.tail_sweep(side, "claw")
		finite = finite and _step(rake, rig) and _step(calm, rig_calm)
		end = _arm_gap(rig, rig_calm)
		for i: int in 2:
			gap[i] = maxf(gap[i], end[i])
	var hip := rake.hip_height()
	var mine := 1 if side > 0.0 else 0
	var tag := "%s claw rake, side %+d" % [stage, side]
	check(
		before[0] + before[1] < 0.0001 * hip,
		"%s: before it, the arms match a calm kaiju's (%.5f)" % [tag, before[0]]
	)
	check(
		gap[mine] > 0.3 * hip and gap[1 - mine] < 0.001 * hip and end[0] + end[1] < 0.001 * hip,
		(
			"%s: the raking arm swings (%.2f hip), the other holds (%.4f), and it is back at rest (%.4f)"
			% [tag, gap[mine] / hip, gap[1 - mine] / hip, (end[0] + end[1]) / hip]
		)
	)
	check(finite, "%s: no bone turns NaN or infinite" % tag)
	rake.queue_free()
	calm.queue_free()
	await process_frame


## How far apart the two rigs' hands are, by side of the body: [-x hand, +x hand] (world units).
func _arm_gap(a: KaijuRig, b: KaijuRig) -> Array[float]:
	var out: Array[float] = [0.0, 0.0]
	for arm: String in ["l", "r"]:
		if a.has_bone("arm_%s2" % arm):
			var index := 1 if a.dir_of("arm_%s0" % arm).x > 0.0 else 0
			out[index] = a.tail_world("arm_%s2" % arm).distance_to(b.tail_world("arm_%s2" % arm))
	return out


func _step(kaiju: KaijuModel, rig: KaijuRig) -> bool:
	kaiju.animate(DT, 0.0)
	for bone_name: String in rig.bone_names():
		var t := rig.bone(bone_name).global_transform
		if not (
			t.basis.x.is_finite()
			and t.basis.y.is_finite()
			and t.basis.z.is_finite()
			and t.origin.is_finite()
		):
			return false
	return true
