extends "res://tests/lib/runner.gd"
## Walk suite: the croc titan's walk carries weight (ClipWeight on its baked clips; director
## 2026-10-21 #4 "kaiju needs more motion in the shoulders and head while it walks"; research 11
## R 11.2-11.4 and 14 R 14.1-14.3). Each move is measured on and off (ClipWeight.off, the bare
## clips) on the same fixed 60 Hz walk (tests/lib/clips_weight.gd).
##   godot --headless --path . --script tests/run_walk_tests.gd
## Seeded by design: nothing here draws random numbers (the gaits seed their own twitches).

const DT := 1.0 / 60.0
const Weight := preload("res://tests/lib/clips_weight.gd")


func suite_name() -> String:
	return "Walk"


func run_checks() -> void:
	await _t("_check_weight_stride")
	await _t("_check_weight_upper_body")
	await _t("_check_weight_footfall")
	await _t("_check_weight_chest_lead")
	await _t("_check_weight_replay")


## Stride from speed (R 11.2): at base speed the stride stretches (ClipWeight.warp) so the legs
## cycle at least 1.25x slower than the bare clips, with no catch step and feet still planted.
func _check_weight_stride() -> void:
	for stage: String in ["baby", "adult"]:
		var on := Weight.measure(root, stage, false)
		var off := Weight.measure(root, stage, true)
		var slower := off.cycles_s / maxf(0.001, on.cycles_s)
		check(
			slower >= 1.25 and on.catches == 0 and on.drift <= 0.05,
			(
				(
					"%s: a longer stride, not faster legs (cycles/s %.2f off -> %.2f on, x%.2f"
					% [stage, off.cycles_s, on.cycles_s, slower]
				)
				+ " >= 1.25; %d catch steps, drift %.3f hips)" % [on.catches, on.drift]
			)
		)
		await process_frame


## Shoulders and head (director 2026-10-21 #4): walking, the chest rolls and twists against the
## pelvis (negative correlation) at least 1.5x as much as on the bare clip, and the head's pitch
## swings at least 1.5x as much (its lagging bob).
func _check_weight_upper_body() -> void:
	var on := Weight.measure(root, "adult", false)
	var off := Weight.measure(root, "adult", true)
	var roll := Weight.spread(on.chest_roll) / maxf(0.0001, Weight.spread(off.chest_roll))
	var twist := Weight.spread(on.chest_twist) / maxf(0.0001, Weight.spread(off.chest_twist))
	var head := Weight.spread(on.head_pitch) / maxf(0.0001, Weight.spread(off.head_pitch))
	var against := Weight.correlation(on.chest_roll, on.pelvis_roll)
	var twist_against := Weight.correlation(on.chest_twist, on.pelvis_twist)
	check(
		roll >= 1.5 and twist >= 1.5 and against < 0.0 and twist_against < 0.0,
		(
			(
				"the shoulders counter the hips (roll %.1f deg, x%.2f the clip's; twist %.1f deg, x%.2f;"
				% [
					Weight.spread(on.chest_roll) * 57.2958,
					roll,
					Weight.spread(on.chest_twist) * 57.2958,
					twist
				]
			)
			+ (
				" >= 1.5; against the pelvis: roll r %.2f, twist r %.2f < 0)"
				% [against, twist_against]
			)
		)
	)
	var deg := Vector2(Weight.spread(on.head_pitch), Weight.spread(off.head_pitch)) * 57.2958
	check(
		head >= 1.5,
		(
			"the head bobs on its lag (pitch range %.1f deg vs %.1f bare, x%.2f >= 1.5)"
			% [deg.x, deg.y, head]
		)
	)


## Footfall weight (R 11.3, 11.4): an adult's step drops the pelvis (at least half the data's
## drop for that step's strength); a cub's steps land lighter than on the bare clips and shake the
## camera (strength x body scale, as the scene dips it) under 0.6x an adult's; a start eases in
## longer for an adult.
func _check_weight_footfall() -> void:
	var adult := Weight.footfall_and_start(root, "adult")
	var baby := Weight.footfall_and_start(root, "baby")
	var drops: Array = Content.section("walk")["drop"]
	var mean_a := _mean(Weight.measure(root, "adult", false).strength)
	var mean_b := _mean(Weight.measure(root, "baby", false).strength)
	var bare_b := _mean(Weight.measure(root, "baby", true).strength)
	var want := Num.f(drops[1]) * mean_a * 0.5
	var dip := Vector2(
		mean_b * Num.f(Weight.SCALES["baby"]), mean_a * Num.f(Weight.SCALES["adult"])
	)
	check(
		adult.x >= want and mean_b < bare_b and dip.x < 0.6 * dip.y,
		(
			(
				"each footfall lands (adult pelvis drops %.3f >= %.3f hips; cub step %.2f < bare %.2f,"
				% [adult.x, want, mean_b, bare_b]
			)
			+ " cub dip %.2f < 0.6 x adult %.2f)" % [dip.x, dip.y]
		)
	)
	check(
		adult.y >= baby.y + 0.2,
		"an adult eases into its walk (%.2f s) longer than a cub (%.2f s)" % [adult.y, baby.y]
	)


## Lead order (R 14.3): the head leads a turn and the chest takes part of it (the bare gait turns
## only the neck and skull).
func _check_weight_chest_lead() -> void:
	var leads: Array[float] = []
	for off: bool in [false, true]:
		ClipWeight.off = off
		var kaiju := Weight.model(root, "adult")
		var rig: KaijuRig = kaiju._rig
		for f: int in 30:
			kaiju.animate(DT, 0.0)
		var ref := rig.bone("spine2").global_transform.basis.orthonormalized()
		for f: int in 60:
			kaiju.animate(DT, 0.0, 0.5)  # the sim says: half a radian still to turn left
		leads.append(Weight.turn_of(rig, "spine2", ref).y)
		kaiju.free()
	ClipWeight.off = false
	check(
		leads[0] >= 0.15 and absf(leads[1]) < 0.05,
		"the chest takes part of the head's lead (%.2f rad; bare gait %.2f)" % [leads[0], leads[1]]
	)


## Two identical walks pose every bone the same (no clock, no unseeded randomness).
func _check_weight_replay() -> void:
	var a := Weight.pose_after(root, 200)
	var b := Weight.pose_after(root, 200)
	var same := a.size() == b.size()
	for i: int in mini(a.size(), b.size()):
		same = same and a[i].is_equal_approx(b[i])
	check(same, "two identical walks pose all %d bones the same" % a.size())


func _mean(xs: Array[float]) -> float:
	var t := 0.0
	for x: float in xs:
		t += x
	return t / maxf(1.0, xs.size())
