extends "res://tests/lib/runner.gd"
## Croc standing suite (D-047): the clip-driven croc titan, at every stage, does what the sim asks
## of a body that stands. Each sim stomp lifts one foot, alternating, and plants it inside the
## scene's wait for it (Rampage.STOMP_WAIT) at a stomp's weight, so the ring and cracks land under
## a foot, and no foot slides; the claw rake swings the raking arm over the clip's pose, only it,
## and it comes back to rest; with no rake called the arms match a calm kaiju's. Fixed 60 Hz
## steps, no clock, no randomness.
##   godot --headless --path . --script tests/run_croc_standing_tests.gd

const CrocStompCentre := preload("res://tests/lib/croc_stomp_centre.gd")
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
	await _t("_check_stomp_shape")
	await _t("_check_stomp_landing")
	await _t("_check_claw_rake")
	await _t("_check_claw_trail")
	await _h("CrocStompCentre", func() -> void: await CrocStompCentre.new(self, check).run())


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
			wrong == 0 and alternate and rose > 0.4 * hip and finite,
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


## One standing stomp's shape, the adult's: the foot eases up (the first frames barely move it),
## rises most of a leg's half, hangs a beat near its top, and its toe is on the street in the very
## frame its footfall goes out (not a frame on); the body sinks as it lands, back up within 0.3 s;
## and the six stomps differ in height and time (a hash of the stomp's number).
func _check_stomp_shape() -> void:
	var kaiju := _model("adult")
	var calm := _model("adult")
	var rig := _rig_of(kaiju)
	var hip := kaiju.hip_height()
	var landed: Array[int] = []
	var clock: Array[int] = [0]
	rig.foot_planted.connect(
		func(side: String, _strength: float, _at: Vector3) -> void:
			if side != "tail":
				landed.append(clock[0])
	)
	for i: int in 60:
		kaiju.animate(DT, 0.0)
		calm.animate(DT, 0.0)
	var rest := _toe_height(rig)
	var series: Array[float] = []  # the toe's height over the street, frame by frame
	var sunk := 0.0
	var peaks: Array[float] = []
	var times: Array[int] = []
	var beat_peak := 0.0
	var beat_start := 0
	for f: int in BEATS * BEAT_FRAMES + 18:
		if f % BEAT_FRAMES == 0 and f < BEATS * BEAT_FRAMES:
			kaiju.stomp()
			beat_start = f
			beat_peak = 0.0
		clock[0] = f + 1
		kaiju.animate(DT, 0.0)
		calm.animate(DT, 0.0)
		series.append(_toe_height(rig) - rest)
		beat_peak = maxf(beat_peak, series[-1])
		if f % BEAT_FRAMES == BEAT_FRAMES - 1:
			peaks.append(beat_peak)
			times.append(landed[-1] - beat_start if not landed.is_empty() else -1)
		var gap := _pelvis_y(_rig_of(calm)) - _pelvis_y(rig)
		sunk = maxf(sunk, gap)
		if f == BEATS * BEAT_FRAMES + 17:
			check(
				absf(gap) < 0.002 * hip,
				"stomp: the body is back up 0.3 s on (%.4f hip)" % (gap / hip)
			)
	check(sunk > 0.02 * hip, "stomp: the body sinks as it lands (%.3f hip)" % (sunk / hip))
	var first := landed[0] - 1  # the first stomp, called on frame 0: its landing frame (index)
	check(
		series[0] < 0.03 * hip and series[2] < 0.15 * hip,
		(
			"stomp: the foot eases up (%.3f, %.3f hip after 1 and 3 frames)"
			% [series[0] / hip, series[2] / hip]
		)
	)
	var peak := peaks[0]
	var hung := 0
	for f: int in BEAT_FRAMES:
		if series[f] >= 0.9 * peak:
			hung += 1
	check(
		peak > 0.3 * hip and hung >= 5,
		"stomp: the foot rises %.2f hip and hangs %d frames near the top" % [peak / hip, hung]
	)
	check(
		series[first] <= 0.02 * hip and series[first - 1] > 0.03 * hip,
		(
			"stomp: the toe is on the street as the footfall goes out (%.3f hip), moving before (%.3f)"
			% [series[first] / hip, series[first - 1] / hip]
		)
	)
	var spread: float = Num.f(peaks.max()) - Num.f(peaks.min())
	var differ: bool = times.min() != times.max()
	check(
		spread > 0.005 * hip or differ,
		"stomp: the six differ in height (%.3f hip) or time" % (spread / hip)
	)
	kaiju.queue_free()
	calm.queue_free()
	await process_frame


## The pelvis's height (the first bone), world units.
func _pelvis_y(rig: KaijuRig) -> float:
	return rig.bone(rig.bone_names()[0]).global_position.y


## The scene's side of a standing stomp (StompLanding): the stomp names the foot it lifts, left then
## right; that foot's landing kicks the camera, and as the same foot lifts again the crack it left
## fades out in a moment while the other foot's crack stays; no stomp, no kick.
func _check_stomp_landing() -> void:
	var kaiju := _model("adult")
	var rig := _rig_of(kaiju)
	var shake := CameraShake.new()
	var landing := StompLanding.new(shake)
	var cracks: Array[Decal] = []
	var sides: Array[String] = []
	var kicks: Array[bool] = []
	for f: int in 60:
		kaiju.animate(DT, 0.0)
	for beat: int in 3:
		landing.lift(kaiju)
		sides.append(kaiju.stomped_side())
		for f: int in BEAT_FRAMES:
			kaiju.animate(DT, 0.0)
			shake.update(DT)  # the last kick fades between beats
		var crack := Decal.new()
		root.add_child(crack)
		cracks.append(crack)
		landing.landed(sides[-1], crack)
		var nod := shake.turn(1.0, 1.0)
		kicks.append(nod.y < 0.0 and nod.x == 0.0)  # straight down: no sideways, no up
	for f: int in 30:  # the third stomp's foot lifted over the first crack: it fades and is freed
		await process_frame
	check(
		sides == ["left", "right", "left"] and not kicks.has(false),
		(
			"landing: stomps lift left, right, left and each landing kicks the camera straight down (%s)"
			% ",".join(sides)
		)
	)
	check(
		not is_instance_valid(cracks[0]) and is_instance_valid(cracks[1]),
		"landing: the crack under a foot fades out as that foot lifts again, the other stays"
	)
	shake.update(1.0)  # the last kick is over
	landing.landed("left", null)  # a footfall of the clip's own, not a stomp's
	check(shake.kick_now() == 0.0, "landing: a footfall that is not the stomp's kicks nothing")
	kaiju.queue_free()
	await process_frame


## Highest toe above the street (world units).
func _toe_height(rig: KaijuRig) -> float:
	var top := 0.0
	for side: String in ["l", "r"]:
		var tip := "leg_%s3" % side if rig.has_bone("leg_%s3" % side) else "leg_%s2" % side
		top = maxf(top, rig.tail_world(tip).y - rig.global_position.y)
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


## The raking claw's streak is laid by the arm (ClawTrail): marks appear only on the swing frames
## (not in the windup, not after), none lives past a few frames, and claw_arc says the arm draws it.
func _check_claw_trail() -> void:
	var kaiju := _model("adult")
	var rig := _rig_of(kaiju)
	var strike := Num.f(Content.section("claw_fx")["strike_s"])
	var lift := Num.f(Content.section("powers")["swipe_windup"]) - strike * 0.5  # BipedSwing's lift_s
	var life := Num.f(Content.section("claw_fx")["trail_s"])
	for i: int in 40:
		_step(kaiju, rig)
	var gait: ClipGait = rig.gait
	var arc := gait.swing.claw_arc(1.0)
	var trailed: bool = arc.get("trailed", false)
	check(trailed, "trail: the arm draws its own streak")
	kaiju.tail_sweep(1.0, "claw_windup")
	var first := -1
	var last := -1
	var peak := 0
	for f: int in 60:
		if f == 18:
			kaiju.tail_sweep(1.0, "claw")
		_step(kaiju, rig)
		await process_frame  # a freed mark leaves the tree
		var marks := 0
		for n: Node in root.get_children():
			marks += 1 if n is MeshInstance3D else 0
		peak = maxi(peak, marks)
		if marks > 0:
			first = f if first < 0 else first
			last = f
	var swing_start := floori(lift / DT)
	var swing_end := ceili((lift + strike * 1.3 + life) / DT) + 2
	check(
		first >= swing_start and last <= swing_end and peak > 0,
		(
			"trail: marks run from frame %d to %d (the swing is %d to %d), up to %d at once"
			% [first, last, swing_start, swing_end, peak]
		)
	)
	kaiju.queue_free()
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
