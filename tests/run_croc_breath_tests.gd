extends "res://tests/lib/runner.gd"
## Croc breath suite (D-165, director 2026-10-23: "the breathing is way too much, too much movement
## and too fast, should be deep and slow like a behemoth"): the standing croc titan's breath at each
## stage against the director's bars, measured on the real model at 60 Hz. The breath is 4 s (young
## croc), 6 s (Behemoth), 8 s (Colossus) +-10%; it rises over about 40% of the breath, falls over
## about 50% and rests about 10%; its push on the back, shoulders and flanks is at most 0.8 / 0.6 /
## 0.5% of the body's height and at least 0.25%; no breath-driven point moves faster than 0.6% of
## the height a second, smoothly (no jerk spike); the belly barely moves; the tail rides the breath.
## While he stands (all of the life layer) the snout moves at most 1.5% of the height a second and
## the tail tip at most 3%. Fixed steps, no clock, no randomness.
##   godot --headless --path . --script tests/run_croc_breath_tests.gd

const STAGES: Array[String] = ["baby", "adolescent", "adult"]
const DT := 1.0 / 60.0
## The bars: the biggest push (share of the body's height, percent) by stage, and the least.
const PUSH_MAX: Array[float] = [0.8, 0.6, 0.5]
const PUSH_MIN := 0.25
const BREATH_SECONDS: Array[float] = [4.0, 6.0, 8.0]
const BREATH_TOLERANCE := 0.1
## Fastest a breath-driven point goes (%/s), how sharply its speed may change (%/s per s), the
## snout's and the tail tip's top speeds while he stands.
const BREATH_SPEED := 0.6
const BREATH_JERK := 1.3
const SNOUT_SPEED := 1.5
const TAIL_SPEED := 3.0
## Samples of speed are taken over this many frames (0.2 s), so frame noise does not count.
const SPAN := 12
## Seconds stood before measuring (the layer fades in) and measured.
const SETTLE := 6.0
const RUN := 100.0
## The body's height in world units at body scale 1 (KaijuModel.MODEL_HEIGHT).
const HEIGHT := 10.0


func suite_name() -> String:
	return "Croc breath"


func run_checks() -> void:
	await _t("_check_curve_shape")
	await _t("_check_breath_in_the_run")
	await _t("_check_push_bars")
	await _t("_check_breath_speed")
	await _t("_check_standing_speeds")


func _model(stage: String, breath_only: bool) -> KaijuModel:
	var colors: Dictionary = Content.species_def("reptilian")["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, stage)
	root.add_child(kaiju)
	_gait_of(kaiju).life.breath_only = breath_only
	return kaiju


func _rig_of(kaiju: KaijuModel) -> KaijuRig:
	return kaiju.find_children("*", "KaijuRig", true, false)[0]


func _gait_of(kaiju: KaijuModel) -> ClipAlive:
	var rig := _rig_of(kaiju)
	return rig.gait


func _skin_of(kaiju: KaijuModel) -> VoxelSkin:
	return kaiju.find_children("VoxelSkin", "VoxelSkin", true, false)[0]


## The breath's curve: still at the bottom, a smooth rise to the top at the inhale share, a smooth
## fall to the bottom before the pause, never outside 0..1; rising 40%, falling 50%, still 10%.
func _check_curve_shape() -> void:
	var idle := ClipIdle.new()
	var cfg := Content.section("croc_idle")
	var inhale := Num.f(cfg["inhale"])
	var pause := Num.f(cfg["pause"])
	var rising := true
	var falling := true
	var rest := true
	var inside := true
	var last := 0.0
	for i: int in 1001:
		var p := float(i) / 1000.0
		var v := idle.curve(p)
		inside = inside and v >= 0.0 and v <= 1.0
		if p <= inhale:
			rising = rising and v >= last - 0.000001
		elif p <= 1.0 - pause:
			falling = falling and v <= last + 0.000001
		else:
			rest = rest and v == 0.0
		last = v
	check(
		absf(inhale - 0.4) < 0.05 and absf(pause - 0.1) < 0.05,
		(
			"the breath rises over about 40%% (%.2f), rests about 10%% (%.2f), falls over the rest"
			% [inhale, pause]
		)
	)
	check(
		(
			rising
			and falling
			and rest
			and inside
			and idle.curve(0.0) == 0.0
			and absf(idle.curve(inhale) - 1.0) < 0.0001
		),
		"the breath's curve rises smoothly to the top, falls smoothly, then rests at the bottom"
	)
	await process_frame


## In a run: the breath's mean length is the stage's 4 / 6 / 8 s +-10%, and it spends about 40% of
## each breath rising, about 50% falling and about 10% at the bottom.
func _check_breath_in_the_run() -> void:
	for i: int in STAGES.size():
		var kaiju := _model(STAGES[i], true)
		var gait := _gait_of(kaiju)
		var starts: Array[float] = []
		var rise := 0.0
		var fall := 0.0
		var still := 0.0
		var last := 0.0
		for f: int in int((SETTLE + RUN) / DT):
			kaiju.animate(DT, 0.0)
			if float(f) * DT < SETTLE:
				last = gait.life.breath
				continue
			var now := gait.life.breath
			if last <= 0.0001 and now > 0.0001:
				starts.append(float(f) * DT)
			if now <= 0.0001:
				still += DT
			elif now > last:
				rise += DT
			else:
				fall += DT
			last = now
		var mean := (starts[-1] - starts[0]) / float(starts.size() - 1)
		var total := rise + fall + still
		var want := BREATH_SECONDS[i]
		check(
			absf(mean - want) <= BREATH_TOLERANCE * want,
			"%s breathes every %.2f s (bar %.1f s +-10%%)" % [STAGES[i], mean, want]
		)
		check(
			(
				absf(rise / total - 0.4) < 0.07
				and absf(fall / total - 0.5) < 0.07
				and absf(still / total - 0.1) < 0.05
			),
			(
				"%s: inhale %.0f%%, exhale %.0f%%, rest at the bottom %.0f%%"
				% [STAGES[i], 100.0 * rise / total, 100.0 * fall / total, 100.0 * still / total]
			)
		)
		kaiju.queue_free()
	await process_frame


## The push the skin shader makes (rig units, as a share of the height) at its biggest, over a
## long stand with a sigh in it: at most the stage's bar, and the flank (the push sideways, at the
## skin shader's lift) still at least 0.25%; the underside moves least.
func _check_push_bars() -> void:
	var cfg := Content.section("croc_idle")
	var lift := Num.f(cfg["skin_lift"])
	var belly := Num.f(cfg["skin_belly"])
	for i: int in STAGES.size():
		var kaiju := _model(STAGES[i], true)
		var skin := _skin_of(kaiju)
		var biggest := 0.0
		for f: int in int((SETTLE + RUN) / DT):
			kaiju.animate(DT, 0.0)
			if float(f) * DT >= SETTLE:
				biggest = maxf(biggest, skin.breath)
		var peak := biggest / HEIGHT * 100.0
		var flank := peak * sqrt(1.0 + lift * lift) / (1.0 + lift)
		check(
			peak <= PUSH_MAX[i] and peak >= PUSH_MIN and flank >= PUSH_MIN,
			(
				"%s: back %.2f%% (bar %.1f), flank %.2f%% (least %.2f), %% of height"
				% [STAGES[i], peak, PUSH_MAX[i], flank, PUSH_MIN]
			)
		)
		check(
			peak * belly < 0.1,
			"%s: the belly barely moves (%.3f%% of the height)" % [STAGES[i], peak * belly]
		)
		kaiju.queue_free()
	await process_frame


## Breath only: the skin's push and the bones' points on the back, shoulders, flank and hip each
## move at most 0.6% of the height a second, and the push's speed changes smoothly; the tail rides
## the breath (its tip's height follows it at some lag); bone travel stays a fraction of the push.
func _check_breath_speed() -> void:
	for i: int in STAGES.size():
		var kaiju := _model(STAGES[i], true)
		var rig := _rig_of(kaiju)
		var skin := _skin_of(kaiju)
		var push: Array[float] = []
		var points := {"spine1": [], "spine2": [], "arm_l0": [], "leg_l0": []}
		var tip: Array[float] = []
		var tail: Array[Vector3] = []
		for f: int in int((SETTLE + RUN) / DT):
			kaiju.animate(DT, 0.0)
			if float(f) * DT < SETTLE:
				continue
			push.append(skin.breath / HEIGHT * 100.0)
			for bone_name: String in points:
				var track: Array = points[bone_name]
				track.append(rig.bone(bone_name).global_position)
			tip.append(rig.tail_world("tail8").y)
			tail.append(rig.tail_world("tail8"))
		var top := _top_speed_1d(push)
		var jerk := _top_jerk_1d(push)
		var worst := 0.0
		for bone_name: String in points:
			var track: Array = points[bone_name]
			worst = maxf(worst, _top_speed_3d(track))
		check(
			top <= BREATH_SPEED and worst <= BREATH_SPEED,
			(
				"%s: breath-driven points under %.1f%%/s (push %.2f, bones %.2f)"
				% [STAGES[i], BREATH_SPEED, top, worst]
			)
		)
		check(
			jerk <= BREATH_JERK,
			(
				"%s: the push changes speed smoothly (%.2f%%/s per s, bar %.1f)"
				% [STAGES[i], jerk, BREATH_JERK]
			)
		)
		var follow := _best_follow(tip, push)
		check(
			follow > 0.5,
			(
				"%s: the tail rides the breath (its tip follows it, correlation %.2f)"
				% [STAGES[i], follow]
			)
		)
		kaiju.queue_free()
	await process_frame


## All of the life layer: standing for two minutes, the snout moves at most 1.5% of the height a
## second, the tail tip at most 3%, and the back and shoulders at most 0.6% (weight shifts, glances
## and drift included).
func _check_standing_speeds() -> void:
	for i: int in STAGES.size():
		var kaiju := _model(STAGES[i], false)
		var rig := _rig_of(kaiju)
		var snout: Array[Vector3] = []
		var tail: Array[Vector3] = []
		var back: Array[Vector3] = []
		for f: int in int((SETTLE + RUN + 20.0) / DT):
			kaiju.animate(DT, 0.0)
			if float(f) * DT < SETTLE:
				continue
			snout.append(rig.tail_world("head1"))
			tail.append(rig.tail_world("tail8"))
			back.append(rig.bone("spine2").global_position)
		var s := _top_speed_3d(snout)
		var t := _top_speed_3d(tail)
		var b := _top_speed_3d(back)
		check(
			s <= SNOUT_SPEED and t <= TAIL_SPEED and b <= BREATH_SPEED,
			(
				"%s standing: snout %.2f (%.1f), tail tip %.2f (%.1f), shoulders %.2f (%.1f) %%/s"
				% [STAGES[i], s, SNOUT_SPEED, t, TAIL_SPEED, b, BREATH_SPEED]
			)
		)
		kaiju.queue_free()
	await process_frame


## Top speed of a series of numbers (percent of height) per second, over SPAN frames.
func _top_speed_1d(series: Array[float]) -> float:
	var top := 0.0
	for i: int in range(SPAN, series.size()):
		top = maxf(top, absf(series[i] - series[i - SPAN]) / (float(SPAN) * DT))
	return top


## Top change of that speed per second (jerk-like: a spike would show), over SPAN frames.
func _top_jerk_1d(series: Array[float]) -> float:
	var speeds: Array[float] = []
	for i: int in range(SPAN, series.size()):
		speeds.append((series[i] - series[i - SPAN]) / (float(SPAN) * DT))
	var top := 0.0
	for i: int in range(SPAN, speeds.size()):
		top = maxf(top, absf(speeds[i] - speeds[i - SPAN]) / (float(SPAN) * DT))
	return top


## Top speed of a point (world units) as a share of the body's height a second, in percent.
func _top_speed_3d(track: Array) -> float:
	var top := 0.0
	for i: int in range(SPAN, track.size()):
		var a: Vector3 = track[i]
		var b: Vector3 = track[i - SPAN]
		top = maxf(top, a.distance_to(b) / (float(SPAN) * DT))
	return top / HEIGHT * 100.0


## The best correlation of a series with the other at any lag up to 8 s (steps of 0.1 s).
func _best_follow(a: Array[float], b: Array[float]) -> float:
	var best := 0.0
	var n := mini(a.size(), b.size()) - 480
	for lag: int in range(0, 480, 6):
		best = maxf(best, absf(_correlation(a, b, lag, n)))
	return best


func _correlation(a: Array[float], b: Array[float], lag: int, n: int) -> float:
	var mean_a := 0.0
	var mean_b := 0.0
	for i: int in n:
		mean_a += a[i + lag]
		mean_b += b[i]
	mean_a /= float(n)
	mean_b /= float(n)
	var cov := 0.0
	var var_a := 0.0
	var var_b := 0.0
	for i: int in n:
		var da := a[i + lag] - mean_a
		var db := b[i] - mean_b
		cov += da * db
		var_a += da * da
		var_b += db * db
	return cov / maxf(sqrt(var_a * var_b), 0.0000001)
