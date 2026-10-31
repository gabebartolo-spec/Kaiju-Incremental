extends RefCounted
## Director 2026-11-01 ("his feet teleport between 6-8 seconds"): the Colossus sets off from a stand
## with the stick 90 deg off his heading, the sim driving the drawn body as Rampage does
## (RampageAbility.place: position, heading, the sim's step clock). No toe jumps more than JUMP
## hip in a frame (a swing moves well under it; the bug jumped a lifted foot about half a hip as
## the walk start handed over to the walk) and planted feet hold. Seeded sim, fixed 60 Hz steps.

const DT := 1.0 / 60.0
const STAND := 60  # frames standing first
const FRAMES := 240  # then 4 s walking
const JUMP := 0.2  # hip a frame
const SIDES: Array[String] = ["l", "r"]


## `sim`: the Colossus on its own tuning; `kaiju`: his drawn body, scaled as Rampage scales it.
static func check(check: Callable, sim: RampageSim, kaiju: KaijuModel) -> void:
	var rig: KaijuRig = kaiju.find_children("*", "KaijuRig", true, false)[0]
	kaiju.scale = Vector3.ONE * sim.body_scale()
	for frame: int in STAND:
		sim.step(DT, Vector2.ZERO, false, 0)
		_place(sim, kaiju, 0.0)
	var hip := kaiju.hip_height()
	var was: Array[Vector3] = [_toe(rig, SIDES[0]), _toe(rig, SIDES[1])]
	var stick := sim.body.heading.rotated(PI * 0.5)
	var worst := 0.0
	for frame: int in FRAMES:
		sim.step(DT, stick, false, 0)
		_place(sim, kaiju, 1.0)
		for i: int in 2:
			var toe := _toe(rig, SIDES[i])
			worst = maxf(worst, toe.distance_to(was[i]))
			was[i] = toe
	check.call(
		worst <= JUMP * hip,
		"set-off: no toe jumps (worst %.3f hip a frame, bar %.2f)" % [worst / hip, JUMP]
	)
	check.call(
		kaiju.foot_drift() <= 0.05 * hip,
		"set-off: planted feet hold (drift %.3f <= %.3f)" % [kaiju.foot_drift(), 0.05 * hip]
	)
	kaiju.queue_free()
	await kaiju.get_tree().process_frame


## RampageAbility.place on the ground: no glide, no leap.
static func _place(sim: RampageSim, kaiju: KaijuModel, moving: float) -> void:
	kaiju.position = Vector3(sim.kaiju_pos.x, sim.stand_y, sim.kaiju_pos.y)
	kaiju.rotation.y = atan2(-sim.body.heading.x, -sim.body.heading.y)
	kaiju.follow_steps(sim.body.step_clock(), sim.body.step_ratio)
	kaiju.animate(DT, moving, -sim.body.turn_left)


static func _toe(rig: KaijuRig, side: String) -> Vector3:
	var tip := "leg_%s3" % side if rig.has_bone("leg_%s3" % side) else "leg_%s2" % side
	return rig.tail_world(tip)
