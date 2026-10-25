extends RefCounted
## Measures the claw swipe's raking arm (D-095, docs/claw_swipe_plan.md) on the in-game croc rig at
## 60 Hz, headless, at one growth stage and body scale: a windup cue, the swipe as the sim lands it
## (powers.swipe_windup later), and the arm against a calm twin. Used by the croc standing suite
## (bars: data/motion_gate.json "claw_arm") and printed by tools/claw_probe.gd.

const DT := 1.0 / 60.0
const FRAMES := 120
## Away from the held pose: the claw tip more than this share of a hip height from the calm twin's.
const AWAY := 0.01
## The snout-line crossing is looked for this many frames either side of the hit.
const CROSS_WINDOW := 10
## A frame is part of the chop while the claw tip moves at this share of its peak speed or more.
const CHOP_SHARE := 0.25

const STAGES: Array[String] = ["baby", "adolescent", "adult"]


## What one stage's rake measured.
class Result:
	var stage := ""
	var hip := 0.0  # hip height (world units)
	var stretch := 0.0  # the largest bone length change, a share of its rest length
	var elbow := Vector2(INF, -INF)  # bend range (deg)
	var wrist := Vector2(INF, -INF)
	var across := INF  # the upper arm's least outward lean (heading frame, outward +)
	var held := 0.0  # its lean in the clip's held pose
	var peak: Array[float] = [0.0, 0.0, 0.0]  # deg/s: upper, fore, hand
	var tip := 0.0  # claw tip peak speed (hip heights/s)
	var hit := 0  # the frame the sim's hit lands
	var fastest_at := -1  # the frame the claw tip moves fastest near the hit: the chop's contact
	var chop_frames := 0  # frames round fastest_at the tip moves at CHOP_SHARE of its peak or more
	var speeds: Array[float] = []  # the claw tip's speed per frame (hip heights/s)
	var short := INF  # nearest the claw comes to the snout line in the strike (hip heights)
	var away := 0.0  # s the arm is off its held pose
	var home := -1  # the frame it is back
	var rows: Array[String] = []

	func fastest() -> float:
		return maxf(peak[0], maxf(peak[1], peak[2]))


func measure(root: Node, stage: String, body_scale: float) -> Result:
	var kaiju := _model(root, stage, body_scale)
	var calm := _model(root, stage, body_scale)
	var rig: KaijuRig = kaiju.find_children("*", "KaijuRig", true, false)[0]
	var rig_calm: KaijuRig = calm.find_children("*", "KaijuRig", true, false)[0]
	for i: int in 40:
		kaiju.animate(DT, 0.0)
		calm.animate(DT, 0.0)
	var names: Array[String] = ["arm_r0", "arm_r1", "arm_r2"]
	var side := signf(rig.dir_of(names[0]).x)
	var hip := kaiju.hip_height()
	var out := Result.new()
	out.stage = stage
	out.hip = hip
	out.hit = roundi(Num.f(Content.section("powers")["swipe_windup"]) / DT)
	var rest_len: Array[float] = []
	for n: String in names:
		rest_len.append(_len(rig, n))
	var away_from := -1
	var before: Array[Vector3] = []
	var tip_before := Vector3.ZERO
	kaiju.tail_sweep(side, "claw_windup")
	for f: int in FRAMES:
		if f == out.hit:
			kaiju.tail_sweep(side, "claw")
		kaiju.animate(DT, 0.0)
		calm.animate(DT, 0.0)
		var body := rig.global_transform.basis.orthonormalized().inverse()
		var dirs: Array[Vector3] = []
		for i: int in 3:
			var d := body * (rig.tail_world(names[i]) - rig.bone(names[i]).global_position)
			dirs.append(d.normalized() * Vector3(side, 1, 1))
			var change := absf(_len(rig, names[i]) / rest_len[i] - 1.0)
			out.stretch = maxf(out.stretch, change)
		var e := rad_to_deg(dirs[0].angle_to(dirs[1]))
		var w := rad_to_deg(dirs[1].angle_to(dirs[2]))
		out.elbow = Vector2(minf(out.elbow.x, e), maxf(out.elbow.y, e))
		out.wrist = Vector2(minf(out.wrist.x, w), maxf(out.wrist.y, w))
		out.across = minf(out.across, dirs[0].x)
		if f == 0:
			out.held = dirs[0].x
		var tip := body * (rig.tail_world(names[2]) - rig.global_position)
		var speed: Array[float] = [0.0, 0.0, 0.0]
		if not before.is_empty():
			for i: int in 3:
				speed[i] = rad_to_deg(before[i].angle_to(dirs[i])) / DT
				out.peak[i] = maxf(out.peak[i], speed[i])
			var tip_speed := (tip - tip_before).length() / DT / hip
			out.speeds.append(tip_speed)
			var near_hit := absi(f - out.hit) <= CROSS_WINDOW
			if near_hit and tip_speed > out.tip:
				out.fastest_at = f
			out.tip = maxf(out.tip, tip_speed)
		if absi(f - out.hit) <= CROSS_WINDOW:
			out.short = minf(out.short, tip.x * side / hip)
		if before.is_empty():
			out.speeds.append(0.0)
		before = dirs
		tip_before = tip
		var calm_tip := rig_calm.tail_world(names[2]) - rig_calm.global_position
		var gap := (rig.tail_world(names[2]) - rig.global_position - calm_tip).length() / hip
		if gap > AWAY:
			away_from = f if away_from < 0 else away_from
			out.home = f + 1
		out.rows.append(
			(
				"  f%02d up(%+.2f %+.2f %+.2f) elbow %5.1f wrist %5.1f deg/s %4.0f %4.0f %4.0f"
				% [f, dirs[0].x, dirs[0].y, dirs[0].z, e, w, speed[0], speed[1], speed[2]]
			)
		)
	out.chop_frames = _chop_frames(out.speeds, out.fastest_at)
	out.away = (out.home - away_from) * DT if away_from >= 0 else 0.0
	kaiju.queue_free()
	calm.queue_free()
	return out


## The croc standing suite's checks (bars: data/motion_gate.json "claw_arm"): at every growth step
## no arm bone changes length, the elbow and wrist stay in a plausible range, the upper arm never
## swings far across the chest, no bone turns faster than the size's bar (bigger is slower), the
## chop is fastest as the sim's hit lands, its claw comes as near the snout line as the stage's arm
## reaches (D-190), and the arm is home before the next swipe.
func run(suite: SceneTree, check: Callable) -> void:
	var bars: Dictionary = Content.load_json("res://data/motion_gate.json")["claw_arm"]
	var scales: Array = bars["body_scales"]
	for i: int in STAGES.size():
		var m := measure(suite.root, STAGES[i], Num.f(scales[i]))
		await suite.process_frame
		var tag := "%s claw arm" % STAGES[i]
		check.call(
			m.stretch <= Num.f(bars["stretch_max"]),
			"%s: bones keep their length (%.2f%%)" % [tag, m.stretch * 100.0]
		)
		check.call(
			(
				m.elbow.x >= Num.f(bars["elbow_min"])
				and m.elbow.y <= Num.f(bars["elbow_max"])
				and m.wrist.y <= Num.f(bars["wrist_max"][i])
			),
			"%s: elbow %.0f-%.0f deg, wrist up to %.0f" % [tag, m.elbow.x, m.elbow.y, m.wrist.y]
		)
		check.call(
			m.across >= Num.f(bars["across_min"]),
			"%s: the upper arm crosses the chest at most to %+.2f" % [tag, m.across]
		)
		var bar := Num.f(bars["peak_baby"]) / sqrt(Num.f(scales[i]) / Num.f(scales[0]))
		check.call(
			m.fastest() <= bar, "%s: fastest bone %.0f deg/s (bar %.0f)" % [tag, m.fastest(), bar]
		)
		check.call(
			absi(m.fastest_at - m.hit) <= Num.i(bars["contact_frames"]),
			"%s: the chop is fastest at f%d, the hit lands at f%d" % [tag, m.fastest_at, m.hit]
		)
		var chop: Array = bars["chop_frames"]
		check.call(
			m.chop_frames >= Num.i(chop[0]) and m.chop_frames <= Num.i(chop[1]),
			"%s: the chop takes %d frames" % [tag, m.chop_frames]
		)
		check.call(
			m.short <= Num.f(bars["short_max"][i]),
			(
				"%s: the claw comes within %.2f hip heights of the snout line"
				% [tag, maxf(m.short, 0.0)]
			)
		)
		check.call(
			m.home >= 0 and m.home * DT < Num.f(bars["home_s"]),
			"%s: the arm is home at %.2f s" % [tag, m.home * DT]
		)


func _model(root: Node, stage: String, body_scale: float) -> KaijuModel:
	var colors: Dictionary = Content.species_def("reptilian")["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, stage)
	kaiju.scale = Vector3.ONE * body_scale
	root.add_child(kaiju)
	return kaiju


func _len(rig: KaijuRig, n: String) -> float:
	return (rig.tail_world(n) - rig.bone(n).global_position).length()


## How many frames round `peak` the speed stays at CHOP_SHARE of speeds[peak] or more.
static func _chop_frames(speeds: Array[float], peak: int) -> int:
	if peak < 0:
		return 0
	var floor_speed := speeds[peak] * CHOP_SHARE
	var first := peak
	var last := peak
	while first > 0 and speeds[first - 1] >= floor_speed:
		first -= 1
	while last < speeds.size() - 1 and speeds[last + 1] >= floor_speed:
		last += 1
	return last - first + 1
