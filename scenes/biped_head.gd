class_name BipedHead
extends RefCounted
## The reptilian's head and neck (BipedGait drives it): held level and steady however the body
## rolls, it scans while standing, leads every turn with a little lag and overshoot, snorts and
## clicks its jaw now and then, and roars by throwing the head back, then lunging jaw-open.

## Head: how fast it turns (spring), how far it leads a turn (s), how far it may turn off the body.
const HEAD_OMEGA := 11.0
const HEAD_ZETA := 0.5
const HEAD_LEAD := 0.18
const HEAD_MAX_YAW := 0.95
const HEAD_STEADY := 4.0
## Head carriage: forward and a little low (hip heights), nose slightly down (rad).
const CARRY := Vector3(0, -0.06, -0.12)
const NOSE_DOWN := -0.08
## Idle scanning: a new glance every few seconds.
const SCAN_EVERY := Vector2(2.5, 6.0)
const SCAN_YAW := 0.65
const SCAN_PITCH := 0.12
## Roar: head thrown back, then a lunge with the jaw open (seconds).
const ROAR_BACK := 0.32
const ROAR_LUNGE := 0.14
const ROAR_HOLD := 0.9
const ROAR_RECOVER := 0.45
const JAW_OPEN := 1.0
## Mouth inside: how red a cell must be (red over green and blue), how dark it reads shut, and
## how far open (rad) the jaw must be to show the pink.
const MOUTH_RED := 1.35
const SEAM_DARK := 0.22
const MOUTH_SHOWS := 0.12
## Idle tells: a snort or jaw click every few seconds.
const TELL_EVERY := Vector2(5.0, 10.0)

var g: BipedGait
## The maw held open (KaijuModel.jaw_open: the beam).
var held_open := false
var _head_yaw := 0.0
var _head_yaw_v := 0.0
var _head_pitch := Vector2.ZERO
var _head_pos := Vector3.ZERO
var _head_pos_v := Vector3.ZERO
var _head_started := false
var _scan_in := 2.0
var _scan := Vector2.ZERO  # yaw, pitch
var _tell_in := 4.0
var _tell := 0.0
var _roar_t := -1.0
var _jaw_open := 0.0
var _mouth_open: Array[Node3D] = []  # the mouth's pink inside, shown once the jaw drops
var _mouth_shut: Array[Node3D] = []  # the same cells as a dark lip seam, shown while shut


func _init(gait: BipedGait) -> void:
	g = gait
	_tell_in = g.rng.randf_range(TELL_EVERY.x, TELL_EVERY.y)
	if not g.rig.bone_snarl.get("jaw", false):  # a resting snarl keeps its true colours
		for bone_name: String in ["head1", "jaw"]:
			_split_mouth(bone_name)


func roar() -> void:
	_roar_t = 0.0


## A stomp jolts the head down.
func dip() -> void:
	_head_pitch.y -= 2.5


## How far ahead of the body the head looks (rad): the yaw still to turn when the sim gives it
## (turn_ahead), else ahead of the body's own turn.
func _lead() -> float:
	return g.yaw_rate * HEAD_LEAD if g.turn_ahead == INF else g.turn_ahead


func update(dt: float, standing: bool) -> void:
	if not g.rig.has_bone("head1"):
		return
	var glance := _glance(dt, standing)
	var off := _turn_head(dt, glance.x)
	# Tells: a snort (head flick) and a jaw click now and then.
	_tell_in -= dt
	if _tell_in <= 0.0 and standing:  # a snort or jaw click only while it stands
		_tell_in = g.rng.randf_range(TELL_EVERY.x, TELL_EVERY.y)
		_tell = 1.0
		_head_pitch.y += 1.6
	_tell = maxf(0.0, _tell - dt * 4.0)
	var roar_pitch := _roar_pitch(dt)
	var hp := KaijuGait.spring(
		_head_pitch.x, _head_pitch.y, glance.y + roar_pitch + NOSE_DOWN, 9.0, 0.7, dt
	)
	_head_pitch = hp
	_carry_head(dt, off)
	_pose_jaw(dt)


## Where to look: ahead of a turn while moving, glances around while standing.
func _glance(dt: float, standing: bool) -> Vector2:
	_scan_in -= dt
	if _scan_in <= 0.0:
		_scan_in = g.rng.randf_range(SCAN_EVERY.x, SCAN_EVERY.y)
		_scan = Vector2(
			g.rng.randf_range(-SCAN_YAW, SCAN_YAW), g.rng.randf_range(-SCAN_PITCH, SCAN_PITCH * 0.5)
		)
	return _scan if standing else Vector2.ZERO  # walking, it looks where it goes


## Turns the head toward the look (`glance_yaw` added), held within the neck's limit; returns
## its yaw off the body.
func _turn_head(dt: float, glance_yaw: float) -> float:
	var target_yaw := g.model_yaw + clampf(_lead(), -0.6, 0.6) + glance_yaw
	var err := wrapf(target_yaw - _head_yaw, -PI, PI)
	if not _head_started:
		_head_yaw = target_yaw
		err = 0.0
	var y := KaijuGait.spring(0.0, _head_yaw_v, err, HEAD_OMEGA, HEAD_ZETA, dt)
	_head_yaw = wrapf(_head_yaw + y.x, -PI, PI)
	_head_yaw_v = y.y
	var off := wrapf(_head_yaw - g.body_yaw, -PI, PI)
	if absf(off) > HEAD_MAX_YAW:  # past the neck's limit: drawn back in, not snapped
		var limit := signf(off) * HEAD_MAX_YAW
		_head_yaw = wrapf(g.body_yaw + lerpf(off, limit, minf(1.0, dt * 12.0)), -PI, PI)
		off = wrapf(_head_yaw - g.body_yaw, -PI, PI)
	return off


## The neck carries the head steady: rest the neck, low-pass where the skull sits, aim at it
## (turned `off` toward the look).
func _carry_head(dt: float, off: float) -> void:
	g.rig.pose("head0", Vector3.ZERO)
	var neck := g.rig.bone("head0")
	var skull := g.rig.bone("head1")
	var to_local := g.rig.global_transform.affine_inverse()
	var natural := to_local * skull.global_position
	if not _head_started:
		_head_started = true
		_head_pos = natural
	var lunge := (CARRY + Vector3(0, 0, -_roar_reach() * 0.35)) * g.hip_height
	var sp := KaijuGait.spring3(_head_pos, _head_pos_v, natural + lunge, HEAD_STEADY, 0.8, dt)
	_head_pos = sp[0]
	_head_pos_v = sp[1]
	var base := neck.global_position
	var want := g.rig.global_transform * _head_pos
	want = base + (want - base).rotated(Vector3.UP, off * 0.4)
	g.rig.aim("head0", base, want)
	var world := Basis(Vector3.UP, _head_yaw) * Basis(Vector3.RIGHT, _head_pitch.x)
	g.rig.set_world_basis("head1", world)


# --- roar ----------------------------------------------------------------------------------------


func _roar_pitch(dt: float) -> float:
	if _roar_t < 0.0:
		return 0.0
	_roar_t += dt
	var t := _roar_t
	var total := ROAR_BACK + ROAR_LUNGE + ROAR_HOLD + ROAR_RECOVER
	if t >= total:
		_roar_t = -1.0
		return 0.0
	if t < ROAR_BACK:
		return 0.5 * _ease_out(t / ROAR_BACK)
	t -= ROAR_BACK
	if t < ROAR_LUNGE:
		return lerpf(0.5, -0.28, _ease_out(t / ROAR_LUNGE))
	t -= ROAR_LUNGE
	if t < ROAR_HOLD:
		return -0.28 + sin(g.time * 55.0) * 0.015
	t -= ROAR_HOLD
	return lerpf(-0.28, 0.0, _ease_out(t / ROAR_RECOVER))


## 0..1 how far forward the roar thrusts the head.
func _roar_reach() -> float:
	if _roar_t < 0.0:
		return 0.0
	var t := _roar_t
	if t < ROAR_BACK:
		return -0.4 * _ease_out(t / ROAR_BACK)
	t -= ROAR_BACK
	if t < ROAR_LUNGE:
		return lerpf(-0.4, 1.0, _ease_out(t / ROAR_LUNGE))
	t -= ROAR_LUNGE
	if t < ROAR_HOLD:
		return 1.0
	t -= ROAR_HOLD
	return lerpf(1.0, 0.0, _ease_out(t / ROAR_RECOVER))


## 0..1 how open the jaw is for the roar.
func roar_open() -> float:
	if _roar_t < ROAR_BACK:
		return 0.0
	var t := _roar_t - ROAR_BACK
	if t < ROAR_LUNGE:
		return _ease_out(t / ROAR_LUNGE)
	t -= ROAR_LUNGE
	if t < ROAR_HOLD:
		return 1.0
	t -= ROAR_HOLD
	return clampf(1.0 - t / ROAR_RECOVER, 0.0, 1.0)


func roar_lean() -> float:
	return -0.1 * maxf(0.0, -_roar_reach()) + 0.12 * maxf(0.0, _roar_reach())


static func _ease_out(t: float) -> float:
	var c := clampf(t, 0.0, 1.0)
	return 1.0 - (1.0 - c) * (1.0 - c) * (1.0 - c)


# --- jaw -----------------------------------------------------------------------------------------


func _pose_jaw(dt: float) -> void:
	if not g.rig.has_bone("jaw"):
		return
	var target := maxf(JAW_OPEN * roar_open(), JAW_OPEN if held_open else 0.0) + 0.07 * _tell
	_jaw_open = lerpf(_jaw_open, target, minf(1.0, dt * 18.0))
	# Shut at rest (the sculpt's snarl closed by the rig's "close" angle), dropped open to roar.
	g.rig.pose("jaw", Vector3(Num.f(g.rig.bone_close.get("jaw", 0.0)) - _jaw_open, 0, 0))
	show_mouth(_jaw_open)


## Shows the pink inside once the jaw has dropped `open` radians, the dark lip seam below that.
func show_mouth(open: float) -> void:
	var showing := open > MOUTH_SHOWS
	for node: Node3D in _mouth_open:
		node.visible = showing
	for node: Node3D in _mouth_shut:
		node.visible = not showing


## The sculpt's open snarl leaves its pink inside on the skull and jaw. Shut, those cells read as a
## dark lip seam; the pink shows only when the jaw drops (a roar, the beam).
func _split_mouth(bone_name: String) -> void:
	var cells := g.rig.voxels_of(bone_name)
	var skin: Node3D = g.rig.skins.get(bone_name, null)
	if cells == null or skin == null:
		return
	var rest := VoxelBuilder.new()
	var inside := VoxelBuilder.new()
	var seam := VoxelBuilder.new()
	for cell: Vector3i in cells.cells:
		var c: Color = cells.colors[cell]
		if c.r > c.g * MOUTH_RED and c.r > c.b * MOUTH_RED:
			inside.put_color(cell, c)
			seam.put_color(cell, Color(c.r * SEAM_DARK, c.g * SEAM_DARK, c.b * SEAM_DARK))
		else:
			rest.put_color(cell, c)
	if inside.cells.is_empty():
		return
	skin.queue_free()
	g.rig.attach_voxels(bone_name, rest)
	_mouth_open.append(g.rig.attach_voxels(bone_name, inside))
	_mouth_shut.append(g.rig.attach_voxels(bone_name, seam))
