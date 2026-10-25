extends RefCounted
## Measures the young croc's walk (WalkLife, director 2026-10-25): how far each short arm swings
## fore and aft from the shoulder, whether it swings with the opposite foot, and how far the snout
## bobs per step, at 60 Hz, headless. Bars: data/motion_gate.json "walk_life". Used by the croc
## standing suite and printed by tools/walk_life_probe.gd.

const DT := 1.0 / 60.0
const WARM := 60  # walk frames before measuring (the swing has eased in)
const FRAMES := 180


## What one walk measured.
class Result:
	var hip := 0.0  # hip height (world units)
	var swing: Array[float] = [0.0, 0.0]  # each arm's swing, half its fore-aft range (deg): l, r
	var with_foot: Array[float] = [0.0, 0.0]  # correlation of each arm with the other foot, -1..1
	var bob := 0.0  # the snout's rise and fall against the hips, largest per step (world units)
	var nod := 0.0  # WalkLife's own dip of the snout, largest per step (world units)
	var bob_world := 0.0  # the snout's rise and fall in the world, largest per step
	var hips_world := 0.0  # the hips' rise and fall in the world, largest per step
	var steps := 0.0  # steps walked while measured


func measure(root: Node, stage: String, body_scale: float) -> Result:
	var out := Result.new()
	var kaiju := _model(root, stage, body_scale)
	var rig: KaijuRig = kaiju.find_children("*", "KaijuRig", true, false)[0]
	var step := Vector3.FORWARD * Num.f(Content.section("kaiju")["speed"]) * DT  # the sim's pace
	for i: int in WARM:
		kaiju.position += step
		kaiju.animate(DT, 1.0)
	out.hip = kaiju.hip_height()
	var pitch: Array[Array] = [[], []]
	var foot: Array[Array] = [[], []]
	var snout: Array[float] = []
	var snout_world: Array[float] = []
	var hips_world: Array[float] = []
	var dips: Array[float] = []
	var life: WalkLife = (rig.gait as ClipGait).life if rig.gait is ClipGait else null
	for f: int in FRAMES:
		kaiju.position += step
		kaiju.animate(DT, 1.0)
		var body := rig.global_transform.basis.orthonormalized().inverse()
		for k: int in 2:
			var side := "lr"[k]
			var arm := "arm_%s0" % side
			var up := body * (rig.tail_world(arm) - rig.bone(arm).global_position)
			pitch[k].append(rad_to_deg(atan2(-up.z, -up.y)))
			var toe := body * (rig.tail_world("leg_%s2" % side) - rig.global_position)
			foot[k].append(-toe.z)
		var tip := rig.tail_world("head1") - rig.bone("spine0").global_position
		snout.append(tip.y)
		snout_world.append(rig.tail_world("head1").y)
		hips_world.append(rig.bone("spine0").global_position.y)
		dips.append(life.dip if life != null else 0.0)
	for k: int in 2:
		out.swing[k] = (_max(pitch[k]) - _min(pitch[k])) * 0.5
		out.with_foot[k] = _corr(pitch[k], foot[1 - k])
	out.bob = _per_step_range(snout, foot[0])
	out.nod = _max(dips) - _min(dips)
	out.bob_world = _per_step_range(snout_world, foot[0])
	out.hips_world = _per_step_range(hips_world, foot[0])
	out.steps = _crossings(foot[0], foot[1])
	kaiju.queue_free()
	return out


## The croc standing suite's checks (data/motion_gate.json "walk_life").
func run(suite: SceneTree, check: Callable, stage: String, body_scale: float) -> void:
	var bars: Dictionary = Content.load_json("res://data/motion_gate.json")["walk_life"]
	var m := measure(suite.root, stage, body_scale)
	await suite.process_frame
	var swing: Array = bars["swing_deg"]
	for k: int in 2:
		var side := "left" if k == 0 else "right"
		check.call(
			m.swing[k] >= Num.f(swing[0]) and m.swing[k] <= Num.f(swing[1]),
			"young croc walk: the %s arm swings %.1f deg each way" % [side, m.swing[k]]
		)
		check.call(
			m.with_foot[k] >= Num.f(bars["with_foot_min"]),
			"young croc walk: the %s arm swings with the other foot (%.2f)" % [side, m.with_foot[k]]
		)
	var bob: Array = bars["bob_m"]
	check.call(
		m.nod >= Num.f(bob[0]) and m.nod <= Num.f(bob[1]),
		"young croc walk: the head dips %.3f at each step" % m.nod
	)


func _model(root: Node, stage: String, body_scale: float) -> KaijuModel:
	var colors: Dictionary = Content.species_def("reptilian")["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, stage)
	kaiju.scale = Vector3.ONE * body_scale
	root.add_child(kaiju)
	return kaiju


## The largest rise-and-fall of `v` within one step (between the moments the left foot passes the
## right foot's place and back, i.e. half a cycle of `lead`).
func _per_step_range(v: Array[float], lead: Array) -> float:
	var mid := (_max(lead) + _min(lead)) * 0.5
	var best := 0.0
	var start := 0
	for i: int in range(1, v.size()):
		var crossed := (Num.f(lead[i - 1]) - mid) * (Num.f(lead[i]) - mid) <= 0.0
		if crossed or i == v.size() - 1:
			if i - start > 3:
				var part: Array[float] = []
				part.assign(v.slice(start, i + 1))
				best = maxf(best, _max(part) - _min(part))
			start = i
	return best


func _crossings(a: Array, b: Array) -> float:
	var n := 0.0
	for i: int in range(1, a.size()):
		if (Num.f(a[i - 1]) - Num.f(b[i - 1])) * (Num.f(a[i]) - Num.f(b[i])) < 0.0:
			n += 1.0
	return n


func _corr(a: Array, b: Array) -> float:
	var ma := 0.0
	var mb := 0.0
	for i: int in a.size():
		ma += Num.f(a[i]) / a.size()
		mb += Num.f(b[i]) / b.size()
	var sab := 0.0
	var saa := 0.0
	var sbb := 0.0
	for i: int in a.size():
		var da := Num.f(a[i]) - ma
		var db := Num.f(b[i]) - mb
		sab += da * db
		saa += da * da
		sbb += db * db
	return sab / maxf(sqrt(saa * sbb), 0.000001)


func _max(v: Array) -> float:
	var m := -INF
	for x: Variant in v:
		m = maxf(m, Num.f(x))
	return m


func _min(v: Array) -> float:
	var m := INF
	for x: Variant in v:
		m = minf(m, Num.f(x))
	return m
