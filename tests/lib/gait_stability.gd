extends RefCounted
## The gaits' springs stay finite at any frame rate (debt row 1, the engine's non-finite vector
## errors): the hexapod's snap spring (omega 46) was stable at 60 fps and exploded at 30, so the
## far insectoid's head, scythes and mandibles spun off to infinity, then NaN, in a 30 fps capture
## (and on any machine under about 45 fps).
## Seeded by design: the model's own twitches draw from the gait's seeded stream.

## The springs the gaits use: [omega, zeta] (hexapod snap, biped arm, head, pelvis, body lean).
const SPRINGS: Array[Vector2] = [
	Vector2(46.0, 0.75),
	Vector2(18.0, 0.7),
	Vector2(11.0, 0.8),
	Vector2(9.0, 0.7),
	Vector2(4.0, 0.9)
]
const FPS: Array[float] = [144.0, 60.0, 30.0, 20.0]
## Seconds a spring is run toward its target, and how close it must settle (a share of the step).
const SECONDS := 10.0
const SETTLED := 0.01
## The abdomen snaps to at most 0.35 rad (HexapodUpper.ABDOMEN_JERK); a wild one is a blown spring.
const MAX_ABDOMEN := 1.0
## Frames the model walks at 30 fps (15 s, past the frame the blown spring went to NaN).
const WALK_FRAMES := 450


static func check(check: Callable, root: Node) -> void:
	for omega_zeta: Vector2 in SPRINGS:
		for fps: float in FPS:
			_spring(check, omega_zeta.x, omega_zeta.y, fps)
	_unchanged_at_60(check)
	await _hexapod(check, root)


## Every spring settles on its target at every frame rate, scalar and vector alike.
static func _spring(check: Callable, omega: float, zeta: float, fps: float) -> void:
	var dt := 1.0 / fps
	var x := Vector2(0.0, 0.0)
	var v := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
	var peak := 0.0
	for _i: int in roundi(SECONDS * fps):
		x = KaijuGait.spring(x.x, x.y, 1.0, omega, zeta, dt)
		v = KaijuGait.spring3(v[0], v[1], Vector3.ONE, omega, zeta, dt)
		peak = maxf(peak, absf(x.x))
	var label := "omega %d zeta %.2f at %d fps" % [roundi(omega), zeta, roundi(fps)]
	check.call(
		is_finite(x.x) and absf(x.x - 1.0) < SETTLED and peak < 2.0,
		"the spring settles on its target (%s; ends %f, peak %f)" % [label, x.x, peak]
	)
	check.call(
		v[0].is_finite() and (v[0] - Vector3.ONE).length() < SETTLED * 2.0,
		"the vector spring settles on its target (%s; ends %s)" % [label, str(v[0])]
	)


## A frame at 60 fps or faster is one step, the integration the gaits were tuned on (no new look).
static func _unchanged_at_60(check: Callable) -> void:
	var dt := 1.0 / 60.0
	var value := 0.31
	var vel := -1.7
	var target := 0.5
	var a := (target - value) * 46.0 * 46.0 - 2.0 * 0.75 * 46.0 * vel
	var v := vel + a * dt
	var old := Vector2(value + v * dt, v)
	var now := KaijuGait.spring(value, vel, target, 46.0, 0.75, dt)
	check.call(
		KaijuGait.spring_steps(46.0, 0.75, dt) == 1 and now == old,
		(
			"the hexapod's snap spring is the same single step at 60 fps (%s vs %s)"
			% [str(now), str(old)]
		)
	)
	check.call(
		KaijuGait.spring_steps(46.0, 0.75, 1.0 / 30.0) > 1,
		"... and is split into sub-steps at 30 fps"
	)


## The insectoid walks 15 s at 30 fps: no blown spring, no non-finite bone.
static func _hexapod(check: Callable, root: Node) -> void:
	var def: Dictionary = Content.species_def("insectoid")
	var colors: Dictionary = def["colors"]
	var model := KaijuModel.new("insectoid", colors, "adult")
	root.add_child(model)
	await root.get_tree().process_frame
	var dt := 1.0 / 30.0
	model.animate(dt, 1.0)
	var rig := model.find_children("*", "KaijuRig", true, false)[0] as KaijuRig
	var upper := (rig.gait as HexapodGait).upper
	var wild := 0.0
	for _f: int in WALK_FRAMES:
		model.position.x += 0.9 * dt
		model.animate(dt, 1.0)
		wild = maxf(wild, absf(upper.abdomen_jerk))
	var head: Basis = rig.bone("head0").global_transform.basis
	check.call(
		head.x.is_finite() and head.y.is_finite() and head.z.is_finite(),
		"the insectoid's head is a real rotation after %d frames at 30 fps" % WALK_FRAMES
	)
	check.call(
		wild < MAX_ABDOMEN,
		"the insectoid's abdomen stays within its snap at 30 fps (peak %f rad)" % wild
	)
	model.free()
