class_name KaijuGait
extends RefCounted
## How one body plan moves (KaijuRig drives one per kaiju): a biped stalks, a hexapod skitters,
## a radial body hauls itself along on its tentacles. The base class reads where the kaiju is
## going from its parent node every frame (position, speed, heading, turn rate), so every gait
## follows whatever the sim and the scene do to the kaiju and never decides anything itself.

## The body follows the heading (the sim turns it with weight, BodyContact.steer) at most this
## fast (rad/s at body scale 1; bigger bodies turn slower by sqrt(scale)) so the legs keep up. Above
## the quickest slice of a stepped turn (about 5.5 rad/s), or the body lags the sim's footfalls.
## No lag of its own: a body behind the way it walks would slide sideways (comments #16).
const BODY_TURN_MAX := 7.0
## How much the speed and the turn rate are smoothed (per second).
const VELOCITY_SMOOTHING := 8.0
const TURN_SMOOTHING := 10.0

var rig: KaijuRig
## World scale of the rig (the model's body scale).
var s := 1.0
## Smoothed horizontal velocity (world units/s), its length and its change.
var velocity := Vector3.ZERO
var speed := 0.0
## How far the node moved this frame over the ground (world units, not smoothed): a clip that leads
## (D-201) plays exactly as far as the body went.
var moved := 0.0
var accel := Vector3.ZERO
## Heading of the kaiju's node (radians, 0 = facing -Z) and how fast it turns.
var model_yaw := 0.0
var yaw_rate := 0.0
## Where the body actually faces: the heading, caught up at no more than the top turn rate.
var body_yaw := 0.0
## The yaw the body still has to turn (rad, set by the scene from the sim; INF: not told): the
## head looks ahead by it, a beat before the body turns (comments #16).
var turn_ahead := INF
## Steps the sim has walked (INF: not told; BodyContact.phase): an integer is a footfall, even the
## left foot, odd the right. A clip gait plants its feet on it, so the legs step where the sim
## turns the body.
var step_phase := INF
## How long this step is next to a full stride, 0..1 (BodyContact.step_ratio).
var step_ratio := 1.0
## The sim's own body yaw (rad; INF: not told) and tail bends (rad per tail bone; empty: not told)
## for a heavy body (BodyContact.body_dir, TailSim.bends, D-208): a gait that is told shows them.
var fed_yaw := INF
var fed_tail: Array[float] = []
var time := 0.0
## Top turn rate (rad/s at scale 1); a gait may change it (a skittering insect turns fast).
var turn_max := BODY_TURN_MAX
## Hip (or body) height at rest, rig units; worst planted-foot drift seen (world units).
var hip_height := 1.0
var max_drift := 0.0
## Seeded per gait so captures replay the same twitches and glances.
var rng := RandomNumberGenerator.new()
var _body_yaw_v := 0.0
var _last_pos := Vector3.ZERO
var _last_yaw := 0.0
var _started := false


func _init(p_rig: KaijuRig) -> void:
	rig = p_rig
	rng.seed = 7


## Called every frame by KaijuRig.animate.
func update(_delta: float) -> void:
	pass


func stomp() -> void:
	pass


func roar() -> void:
	pass


## Reads the parent's motion and turns the rig towards the body yaw. Every gait calls this first.
func track(delta: float) -> void:
	var dt := maxf(delta, 0.0001)
	time += delta
	var frame := rig.get_parent_node_3d().global_transform
	s = frame.basis.get_scale().x
	var fwd := -frame.basis.z
	model_yaw = atan2(-fwd.x, -fwd.z)
	var pos := frame.origin
	if not _started:
		_started = true
		_last_pos = pos
		_last_yaw = model_yaw
		body_yaw = model_yaw
	var raw := (pos - _last_pos) / dt
	raw.y = 0.0
	moved = raw.length() * dt
	var before := velocity
	velocity = velocity.lerp(raw, minf(1.0, dt * VELOCITY_SMOOTHING))
	accel = accel.lerp((velocity - before) / dt, minf(1.0, dt * VELOCITY_SMOOTHING))
	speed = velocity.length()
	var turn := wrapf(model_yaw - _last_yaw, -PI, PI) / dt
	yaw_rate = lerpf(yaw_rate, turn, minf(1.0, dt * TURN_SMOOTHING))
	_last_pos = pos
	_last_yaw = model_yaw
	var err := wrapf(model_yaw - body_yaw, -PI, PI)
	var top := _top_turn(err)
	_body_yaw_v = clampf(err / dt, -top, top)
	body_yaw = wrapf(body_yaw + _body_yaw_v * dt, -PI, PI)
	rig.rotation.y = wrapf(body_yaw - model_yaw, -PI, PI)


## The fastest the body may yaw toward the heading now (rad/s), `err` (rad) still to turn; a gait
## may slow it (a heavy body whose head aims first, ClipGait).
func _top_turn(_err: float) -> float:
	return turn_max / sqrt(maxf(s, 0.01))


## A damped spring step: returns the new [value, velocity]. zeta < 1 overshoots.
static func spring(
	value: float, vel: float, target: float, omega: float, zeta: float, dt: float
) -> Vector2:
	var a := (target - value) * omega * omega - 2.0 * zeta * omega * vel
	var v := vel + a * dt
	return Vector2(value + v * dt, v)


## The same spring for a vector; vel is updated in place through the returned pair.
static func spring3(
	value: Vector3, vel: Vector3, target: Vector3, omega: float, zeta: float, dt: float
) -> PackedVector3Array:
	var a := (target - value) * omega * omega - vel * (2.0 * zeta * omega)
	var v := vel + a * dt
	return PackedVector3Array([value + v * dt, v])


## Two-bone IK: where the middle joint goes so bones a (length l1) and b (l2) reach from root to
## end, bending towards pole. An end out of reach leaves the chain straight towards it.
static func solve_knee(root: Vector3, end: Vector3, l1: float, l2: float, pole: Vector3) -> Vector3:
	var d := end - root
	var dist := clampf(d.length(), absf(l1 - l2) + 0.0001, l1 + l2 - 0.0001)
	var dir := d.normalized() if d.length() > 0.0001 else Vector3.DOWN
	var cos_a := clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0)
	var p := pole - dir * pole.dot(dir)
	p = p.normalized() if p.length() > 0.0001 else dir.cross(Vector3.RIGHT).normalized()
	return root + dir * (cos_a * l1) + p * (sqrt(maxf(0.0, 1.0 - cos_a * cos_a)) * l1)


## A vector flattened onto the ground plane.
static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
