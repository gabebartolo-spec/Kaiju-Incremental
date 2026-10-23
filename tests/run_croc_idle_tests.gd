extends "res://tests/lib/runner.gd"
## Croc idle suite (D-165, the living predator): the croc titan standing breathes at its stage's own
## pace (slower as it grows), shifts weight, glances, blinks and cracks its jaw (ClipIdle,
## ClipAlive), every number from "croc_idle" tuning and every choice a hash of (run, stage, event):
## the same run stands the same way, the pose stays finite and bounded, the feet stay locked, the
## jaw never shows the pink inside, and the layer has NO effect while he walks (the pose is
## exactly the plain clips'), fading out in a quarter second on a walk, a turn, a roar or the
## beam. Fixed 60 Hz steps, no clock, no randomness.
##   godot --headless --path . --script tests/run_croc_idle_tests.gd

const STAGES: Array[String] = ["baby", "adolescent", "adult"]
const DT := 1.0 / 60.0
## Seconds stood to measure the breath over, and the seconds of the longer stand.
const BREATH_RUN := 90.0
const LONG_RUN := 120.0
## Most the layer may turn any bone (rad): the glance's yaw and the neck/skull share, the jaw's 6.9.
const MAX_TURN_DEG := 16.0
const JAW_MAX_DEG := 6.9


func suite_name() -> String:
	return "Croc idle"


func run_checks() -> void:
	await _t("_check_breath_by_size")
	await _t("_check_same_run_same_motion")
	await _t("_check_bounded_and_locked")
	await _t("_check_jaw_blink_shift")
	await _t("_check_none_while_walking")
	await _t("_check_fades_out")


func _model(stage: String, life: bool = true, run: int = 0) -> KaijuModel:
	var colors: Dictionary = Content.species_def("reptilian")["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, stage)
	root.add_child(kaiju)
	kaiju.set_life_seed(run)
	_gait_of(kaiju).life_on = life
	return kaiju


func _rig_of(kaiju: KaijuModel) -> KaijuRig:
	return kaiju.find_children("*", "KaijuRig", true, false)[0]


func _gait_of(kaiju: KaijuModel) -> ClipAlive:
	var rig := _rig_of(kaiju)
	return rig.gait


func _skin_of(kaiju: KaijuModel) -> VoxelSkin:
	return kaiju.find_children("VoxelSkin", "VoxelSkin", true, false)[0]


## Seconds between the breath's upward zero crossings while standing, averaged over BREATH_RUN.
func _breath_period(kaiju: KaijuModel) -> float:
	var gait := _gait_of(kaiju)
	var last := 0.0
	var crossings: Array[float] = []
	for f: int in int(BREATH_RUN / DT):
		kaiju.animate(DT, 0.0)
		var now := gait.life.breath
		if last <= 0.0 and now > 0.0 and gait.life.weight >= 1.0:
			crossings.append(float(f) * DT)
		last = now
	if crossings.size() < 3:
		return 0.0
	return (crossings[-1] - crossings[0]) / float(crossings.size() - 1)


## The breath's period rises with the stage: the young croc breathes quickest, the Colossus slowest,
## each near its tuned length (a sigh makes one breath longer, so a little above); the plain baked
## idle is 3 s whatever the size.
func _check_breath_by_size() -> void:
	var cfg := Content.section("croc_idle")
	var base: Array = cfg["breath_s"]
	var periods: Array[float] = []
	for i: int in STAGES.size():
		var kaiju := _model(STAGES[i])
		var period := _breath_period(kaiju)
		periods.append(period)
		var want := Num.f(base[i])
		check(
			period > 0.95 * want and period < 1.12 * want,
			"%s breathes once per %.2f s (tuned %.2f s)" % [STAGES[i], period, want]
		)
		kaiju.queue_free()
	check(
		periods[0] < periods[1] and periods[1] < periods[2],
		"the breath slows as he grows (%.2f < %.2f < %.2f s)" % [periods[0], periods[1], periods[2]]
	)
	var plain := _model("adult", false)
	for f: int in int(3.0 / DT):
		plain.animate(DT, 0.0)
	var played := _gait_of(plain).clip_time
	check(
		absf(played - 72.0) < 2.0,
		"with the life layer off the baked idle still takes 3 s (%.1f of 72 frames)" % played
	)
	plain.queue_free()
	await process_frame


## The same run, stage and time give the same pose to the last bit; another run gives another
## schedule (some bone differs).
func _check_same_run_same_motion() -> void:
	var a := _model("adult", true, 3)
	var b := _model("adult", true, 3)
	var c := _model("adult", true, 4)
	var same := true
	var other := false
	for f: int in int(60.0 / DT):
		a.animate(DT, 0.0)
		b.animate(DT, 0.0)
		c.animate(DT, 0.0)
		same = same and _gap(a, b) == 0.0
		other = other or _gap(a, c) > 0.0005
	check(same, "the same run stands the same way, frame for frame")
	check(other, "another run has another schedule of glances and shifts")
	for kaiju: KaijuModel in [a, b, c]:
		kaiju.queue_free()
	await process_frame


## Standing two minutes: every bone stays finite; no bone is turned more than the life layer's
## bounds off the plain clip; the feet do not slide (they stay where the plain clip's stand).
func _check_bounded_and_locked() -> void:
	for stage: String in STAGES:
		var kaiju := _model(stage)
		var plain := _model(stage, false)
		var rig := _rig_of(kaiju)
		var rig_plain := _rig_of(plain)
		var hip := kaiju.hip_height()
		var finite := true
		var worst := 0.0
		var slide := 0.0
		var pelvis := 0.0
		for f: int in int(LONG_RUN / DT):
			kaiju.animate(DT, 0.0)
			plain.animate(DT, 0.0)
			if f % 6 == 0:
				finite = finite and _finite(rig)
			worst = maxf(worst, _worst_turn(rig, rig_plain))
			for leg: String in ["leg_l2", "leg_r2"]:
				slide = maxf(slide, rig.tail_world(leg).distance_to(rig_plain.tail_world(leg)))
			pelvis = maxf(pelvis, absf(_gait_of(kaiju).life.pelvis_x))
		check(finite, "%s: no bone turns NaN or infinite standing %d s" % [stage, int(LONG_RUN)])
		check(
			worst < deg_to_rad(MAX_TURN_DEG),
			(
				"%s: no bone strays more than %.0f deg from the clip (%.1f deg)"
				% [stage, MAX_TURN_DEG, rad_to_deg(worst)]
			)
		)
		check(
			slide < 0.004 * hip and kaiju.foot_drift() <= 0.01 * hip,
			(
				"%s: the feet stay locked (%.4f hip off the plain stand, drift %.4f hip)"
				% [stage, slide / hip, kaiju.foot_drift() / hip]
			)
		)
		check(pelvis > 0.01, "%s: the weight shifts (pelvis %.3f hip)" % [stage, pelvis])
		kaiju.queue_free()
		plain.queue_free()
	await process_frame


## The jaw crack stays under the 6.9 deg that shows the pink inside; the blink closes the lids and
## opens them again; both happen in two minutes; the skin gets the breath.
func _check_jaw_blink_shift() -> void:
	var kaiju := _model("baby")
	var plain := _model("baby", false)
	var skin := _skin_of(kaiju)
	var jaw := 0.0
	var peak_blink := 0.0
	var blinks := 0
	var shut := false
	var pink := false
	var pushed := 0.0
	for f: int in int(LONG_RUN / DT):
		kaiju.animate(DT, 0.0)
		plain.animate(DT, 0.0)
		var open := _jaw_angle(_rig_of(kaiju)) - _jaw_angle(_rig_of(plain))
		jaw = maxf(jaw, absf(open))
		pink = pink or skin.mouth_open
		peak_blink = maxf(peak_blink, skin.blink)
		if not shut and skin.blink > 0.9:
			shut = true
			blinks += 1
		if skin.blink < 0.1:
			shut = false
		pushed = maxf(pushed, absf(skin.breath))
	check(
		jaw > deg_to_rad(1.0) and jaw < deg_to_rad(JAW_MAX_DEG) and not pink,
		(
			"the jaw cracks %.1f deg, under %.1f, and the pink inside never shows"
			% [rad_to_deg(jaw), JAW_MAX_DEG]
		)
	)
	check(
		peak_blink > 0.95 and blinks >= 10 and blinks < 60,
		(
			"he blinks now and then (%d blinks in %d s, lids to %.2f)"
			% [blinks, int(LONG_RUN), peak_blink]
		)
	)
	check(pushed > 0.05, "the skin is pushed out by the breath (%.3f rig units)" % pushed)
	kaiju.queue_free()
	plain.queue_free()
	await process_frame


## While he walks the life layer does nothing: after the quarter second it fades, every bone is
## where the plain clips put it and the skin gets no breath or blink.
func _check_none_while_walking() -> void:
	for stage: String in STAGES:
		var kaiju := _model(stage)
		var plain := _model(stage, false)
		var skin := _skin_of(kaiju)
		for f: int in int(20.0 / DT):  # stand a while first: the layer is fully in
			kaiju.animate(DT, 0.0)
			plain.animate(DT, 0.0)
		check(_gait_of(kaiju).life.weight >= 1.0, "%s: standing, the layer is fully in" % stage)
		var gap := 0.0
		var pushed := 0.0
		var lids := 0.0
		for f: int in int(6.0 / DT):
			for m: KaijuModel in [kaiju, plain]:
				m.position += Vector3(0, 0, -4.0 * DT)
				m.animate(DT, 1.0)
			if f > int(2.0 / DT):  # past the cross-fade into the walk
				gap = maxf(gap, _gap(kaiju, plain))
				pushed = maxf(pushed, absf(skin.breath))
				lids = maxf(lids, skin.blink)
		check(
			_gait_of(kaiju).state == "walk" and gap < 0.00001 and pushed == 0.0 and lids == 0.0,
			(
				"%s walking: no effect at all (pose gap %.7f, breath %.4f, blink %.2f)"
				% [stage, gap, pushed, lids]
			)
		)
		kaiju.queue_free()
		plain.queue_free()
	await process_frame


## A turn, a roar and the beam each fade the layer out in a quarter second.
func _check_fades_out() -> void:
	var kaiju := _model("adult")
	var gait := _gait_of(kaiju)
	var skin := _skin_of(kaiju)
	var fade := ceili(Num.f(Content.section("croc_idle")["fade_out_s"]) / DT) + 3
	for f: int in int(10.0 / DT):
		kaiju.animate(DT, 0.0)
	var results: Array[String] = []
	kaiju.roar()
	for f: int in fade:
		kaiju.animate(DT, 0.0)
	results.append("roar %.2f" % gait.life.weight)
	var roar_out := gait.life.weight == 0.0 and skin.breath == 0.0
	for f: int in int(10.0 / DT):  # the roar ends, he stands again
		kaiju.animate(DT, 0.0)
	var back := gait.life.weight > 0.9
	kaiju.jaw_open(true)
	for f: int in fade:
		kaiju.animate(DT, 0.0)
	results.append("beam %.2f" % gait.life.weight)
	var beam_out := gait.life.weight == 0.0
	kaiju.jaw_open(false)
	for f: int in int(6.0 / DT):
		kaiju.animate(DT, 0.0)
	kaiju.rotation.y = PI * 0.5  # a standing turn
	for f: int in fade:
		kaiju.animate(DT, 0.0)
	results.append("turn %.2f" % gait.life.weight)
	var turn_out := gait.state.begins_with("turn") and gait.life.weight == 0.0
	check(
		roar_out and back and beam_out and turn_out,
		(
			"the roar, the beam and a turn each fade the layer out in %.2f s (%s)"
			% [float(fade) * DT, ", ".join(results)]
		)
	)
	kaiju.queue_free()
	await process_frame


## The widest any bone's world position differs between two kaiju.
func _gap(a: KaijuModel, b: KaijuModel) -> float:
	var rig_a := _rig_of(a)
	var rig_b := _rig_of(b)
	var worst := 0.0
	for bone_name: String in rig_a.bone_names():
		var ta := rig_a.bone(bone_name).global_transform
		var tb := rig_b.bone(bone_name).global_transform
		worst = maxf(worst, ta.origin.distance_to(tb.origin))
		for axis: int in 3:
			worst = maxf(worst, (ta.basis[axis] - tb.basis[axis]).length())
	return worst


## The most any bone is turned off the other rig's (rad), by their local transforms.
func _worst_turn(a: KaijuRig, b: KaijuRig) -> float:
	var worst := 0.0
	for bone_name: String in a.bone_names():
		if bone_name.begins_with("leg") or bone_name.begins_with("arm"):
			continue  # the legs re-solve to the locked feet; the arms ride the chest
		var qa := a.bone(bone_name).transform.basis.get_rotation_quaternion()
		var qb := b.bone(bone_name).transform.basis.get_rotation_quaternion()
		worst = maxf(worst, _angle(qa, qb))
	return worst


## The angle between two turns (rad), exact for tiny ones (acos is not).
func _angle(a: Quaternion, b: Quaternion) -> float:
	var d := a.inverse() * b
	return 2.0 * asin(minf(1.0, Vector3(d.x, d.y, d.z).length()))


func _jaw_angle(rig: KaijuRig) -> float:
	return rig.bone("jaw").transform.basis.get_euler().x


func _finite(rig: KaijuRig) -> bool:
	for bone_name: String in rig.bone_names():
		var t := rig.bone(bone_name).global_transform
		if not (
			t.origin.is_finite()
			and t.basis.x.is_finite()
			and t.basis.y.is_finite()
			and t.basis.z.is_finite()
		):
			return false
	return true
