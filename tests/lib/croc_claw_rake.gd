extends RefCounted
## The croc standing suite's claw rake checks (D-095 Claws, D-185, D-243): at every stage, on the
## sim's windup cue and its rake powers.swipe_windup later, the arm rakes and comes back to rest,
## and the raking claw lays its streak only while it sweeps. The young play the code rake
## (BipedSwing); the adult plays the rake keyed in Cascadeur (ClipRake), its hit frame on the sim's
## rake. Fixed 60 Hz steps, no clock, no randomness.

const DT := 1.0 / 60.0
const STAGES: Array[String] = ["baby", "adolescent", "adult"]

var _suite: SceneTree
var _check: Callable
var _model: Callable  # stage -> a KaijuModel in the tree
var _step: Callable  # (kaiju, rig) -> one DT step, true while every bone is finite


func _init(suite: SceneTree, check: Callable, model: Callable, step: Callable) -> void:
	_suite = suite
	_check = check
	_model = model
	_step = step


func run() -> void:
	await _check_claw_rake()
	await _check_claw_trail()


## The claw rake (a windup, then the swipe powers.swipe_windup on) swings the raking arm out and it
## comes back to rest; with no rake called, nothing about the arms differs from a calm kaiju's. The
## code rake (the young) moves only that arm; the keyed rake (the adult, ClipRake) twists the
## shoulders and body into it (D-185), so the other arm draws back too, less than the raking one;
## neither moves a foot.
func _check_claw_rake() -> void:
	for stage: String in STAGES:
		for side: float in [-1.0, 1.0]:
			var tag := "%s claw rake, side %+d" % [stage, side]
			var got := await _rake_run(stage, side)
			var hip: float = got["hip"]
			var gap: Array[float] = got["gap"]
			var end: float = got["end"]
			var keyed: bool = got["keyed"]
			var mine := 1 if side > 0.0 else 0
			var other_bar := gap[mine] if keyed else 0.001 * hip  # the keyed body twists into it
			_check.call(
				float(got["before"]) < 0.0001 * hip,
				"%s: before it, the arms match a calm kaiju's (%.5f)" % [tag, got["before"]]
			)
			_check.call(
				gap[mine] > 0.3 * hip and gap[1 - mine] < other_bar and end < 0.001 * hip,
				(
					"%s: the raking arm swings (%.2f hip), the other %s (%.4f), back at rest (%.4f)"
					% [
						tag,
						gap[mine] / hip,
						"less" if keyed else "holds",
						gap[1 - mine] / hip,
						end / hip
					]
				)
			)
			_check.call(gap[2] < 0.0001 * hip, "%s: the feet hold (%.5f hip)" % [tag, gap[2] / hip])
			_check.call(got["finite"], "%s: no bone turns NaN or infinite" % tag)


## One rake beside a calm twin: {"before": the hands' gap before it, "gap": the widest the hands
## (-x, +x) and the feet parted, "end": the hands' gap at the end, "hip", "keyed", "finite"}.
func _rake_run(stage: String, side: float) -> Dictionary:
	var rake: KaijuModel = _model.call(stage)
	var calm: KaijuModel = _model.call(stage)
	var rig := _rig_of(rake)
	var rig_calm := _rig_of(calm)
	var finite := true
	for i: int in 40:
		finite = finite and _steps(rake, rig) and _steps(calm, rig_calm)
	var before := _arm_gap(rig, rig_calm)
	var swipe := _swipe_frame()
	rake.tail_sweep(side, "claw_windup")
	var gap: Array[float] = [0.0, 0.0, 0.0]
	var end: Array[float] = [0.0, 0.0]
	for f: int in swipe + 120:  # the windup, then the rake and its follow-through
		if f == swipe:
			rake.tail_sweep(side, "claw")
		finite = finite and _steps(rake, rig) and _steps(calm, rig_calm)
		end = _arm_gap(rig, rig_calm)
		for i: int in 2:
			gap[i] = maxf(gap[i], end[i])
		gap[2] = maxf(gap[2], _feet_gap(rig, rig_calm))
	var got := {
		"before": before[0] + before[1],
		"gap": gap,
		"end": end[0] + end[1],
		"hip": rake.hip_height(),
		"keyed": (rig.gait as ClipGait).rake.on,
		"finite": finite,
	}
	rake.queue_free()
	calm.queue_free()
	await _suite.process_frame
	return got


## The frame (at DT steps) the sim's rake lands after its windup cue: powers.swipe_windup on.
func _swipe_frame() -> int:
	return roundi(Num.f(Content.section("powers")["swipe_windup"]) / DT)


## The raking claw's streak is laid by the arm (ClawTrail): marks appear only on the swing frames
## (not in the windup, not after), none lives past a few frames, and claw_arc says the arm draws
## it. The code rake (the young) swings strike_s about the sim's rake; the keyed one (the adult)
## over its clip's trail frames, its hit frame (the claws cross the snout line) on the sim's rake
## (D-166).
func _check_claw_trail() -> void:
	for stage: String in ["adolescent", "adult"]:
		var kaiju: KaijuModel = _model.call(stage)
		var rig := _rig_of(kaiju)
		for i: int in 40:
			_steps(kaiju, rig)
		var gait: ClipGait = rig.gait
		var arc := gait.swing.claw_arc(1.0)
		var trailed: bool = arc.get("trailed", false)
		_check.call(trailed, "%s trail: the arm draws its own streak" % stage)
		var swipe := _swipe_frame()
		kaiju.tail_sweep(1.0, "claw_windup")
		var marks := Vector3i(-1, -1, 0)  # the first and last frames with marks, the most at once
		for f: int in swipe + 60:
			if f == swipe:
				_check_hit(stage, gait.rake)  # where the windup alone brought it
				kaiju.tail_sweep(1.0, "claw")
			_steps(kaiju, rig)
			await _suite.process_frame  # a freed mark leaves the tree
			var n := _suite.root.get_children().filter(
				func(c: Node) -> bool: return c is MeshInstance3D
			)
			marks.z = maxi(marks.z, n.size())
			if n.size() > 0:
				marks.x = f if marks.x < 0 else marks.x
				marks.y = f
		var swing := _swing_frames(gait.rake, swipe)
		_check.call(
			marks.x >= swing.x and marks.y <= swing.y and marks.z > 0,
			(
				"%s trail: marks run from frame %d to %d (the swing is %d to %d), up to %d at once"
				% [stage, marks.x, marks.y, swing.x, swing.y, marks.z]
			)
		)
		kaiju.queue_free()
		await _suite.process_frame


## The first and last frames (at DT steps from the windup cue) the claw may lay its streak.
func _swing_frames(rake: ClipRake, swipe: int) -> Vector2i:
	var life := Num.f(Content.section("claw_fx")["trail_s"])
	if rake.on:
		var span := rake.clips.trail_span("rake_r") / rake.clips.fps / DT  # both rakes share them
		var hit := rake.clips.hit_frame("rake_r") / rake.clips.fps / DT
		return Vector2i(floori(swipe - hit + span.x), ceili(swipe - hit + span.y + life / DT) + 2)
	var strike := Num.f(Content.section("claw_fx")["strike_s"])
	var lift := swipe * DT - strike * 0.5  # BipedSwing's wait_s + lift_s
	return Vector2i(floori(lift / DT), ceili((lift + strike * 1.3 + life) / DT) + 2)


## On the sim's rake the keyed rake stands at its hit frame, within a frame (D-166).
func _check_hit(stage: String, rake: ClipRake) -> void:
	if not rake.on:
		return
	var off := absf(rake.clip_time - rake.clips.hit_frame(rake.clip))
	_check.call(
		off <= 1.0, "%s: the keyed rake is on its hit frame at the rake (%.2f off)" % [stage, off]
	)


## How far apart the two rigs' hands are, by side of the body: [-x hand, +x hand] (world units).
func _arm_gap(a: KaijuRig, b: KaijuRig) -> Array[float]:
	var out: Array[float] = [0.0, 0.0]
	for arm: String in ["l", "r"]:
		if a.has_bone("arm_%s2" % arm):
			var index := 1 if a.dir_of("arm_%s0" % arm).x > 0.0 else 0
			out[index] = a.tail_world("arm_%s2" % arm).distance_to(b.tail_world("arm_%s2" % arm))
	return out


## How far apart the two rigs' toe tips are (world units, the wider of the two feet).
func _feet_gap(a: KaijuRig, b: KaijuRig) -> float:
	var out := 0.0
	for side: String in ["l", "r"]:
		var tip := "leg_%s3" % side if a.has_bone("leg_%s3" % side) else "leg_%s2" % side
		out = maxf(out, a.tail_world(tip).distance_to(b.tail_world(tip)))
	return out


func _rig_of(kaiju: KaijuModel) -> KaijuRig:
	return kaiju.find_children("*", "KaijuRig", true, false)[0]


func _steps(kaiju: KaijuModel, rig: KaijuRig) -> bool:
	var finite: bool = _step.call(kaiju, rig)
	return finite
