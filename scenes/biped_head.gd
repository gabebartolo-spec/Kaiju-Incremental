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
const JAW_OPEN := 0.55
## Idle tells: a snort or jaw click every few seconds.
const TELL_EVERY := Vector2(5.0, 10.0)

var g: BipedGait
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
var _jaw: Node3D
var _jaw_open := 0.0
var _mouth: Node3D


func _init(gait: BipedGait) -> void:
	g = gait
	_tell_in = g.rng.randf_range(TELL_EVERY.x, TELL_EVERY.y)
	_split_jaw()


func roar() -> void:
	_roar_t = 0.0


## A stomp jolts the head down.
func dip() -> void:
	_head_pitch.y -= 2.5


func update(dt: float, standing: bool) -> void:
	if not g.rig.has_bone("head1"):
		return
	# Where to look: ahead of a turn while moving, glances around while standing.
	_scan_in -= dt
	if _scan_in <= 0.0:
		_scan_in = g.rng.randf_range(SCAN_EVERY.x, SCAN_EVERY.y)
		_scan = Vector2(
			g.rng.randf_range(-SCAN_YAW, SCAN_YAW), g.rng.randf_range(-SCAN_PITCH, SCAN_PITCH * 0.5)
		)
	var glance := _scan if standing else Vector2.ZERO  # walking, it looks where it goes
	var target_yaw := g.model_yaw + clampf(g.yaw_rate * HEAD_LEAD, -0.6, 0.6) + glance.x
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
	# The neck carries the head steady: rest the neck, low-pass where the skull sits, aim at it.
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
	_pose_jaw(dt)


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


## The sculpt's skull is one bone; cut the lower jaw off it (the voxels below the mouth line, from
## the jaw hinge forward) and hang it on its own pivot so it can open.
func _split_jaw() -> void:
	var cells := g.rig.voxels_of("head1")
	if cells == null:
		return
	var v := g.rig.voxel_size()
	var head := g.rig.head_of("head1")
	var tip := head + g.rig.dir_of("head1")
	var length := (tip - head).length()
	# Mouth line: from the hinge (a third of the way along the skull) to just under the snout tip.
	var hinge := head.lerp(tip, 0.3) + Vector3(0, -0.06, 0) * length
	var snout := tip + Vector3(0, -0.18, 0) * length
	var axis := (snout - hinge).normalized()
	var below := Vector3.UP - axis * axis.y
	below = below.normalized()
	var upper := VoxelBuilder.new()
	var lower := VoxelBuilder.new()
	for cell: Vector3i in cells.cells:
		var p := (Vector3(cell) + Vector3(0.5, 0.5, 0.5)) * v
		var rel := p - hinge
		var color: Color = cells.colors[cell]
		if rel.dot(axis) > 0.0 and rel.dot(below) < 0.0:
			lower.put_color(cell, color)
		else:
			upper.put_color(cell, color)
	if lower.cells.size() < 20:
		return
	var skull := g.rig.bone("head1")
	for child: Node in skull.get_children():
		if child is MultiMeshInstance3D:
			skull.remove_child(child)
			child.queue_free()
	g.rig.attach_voxels("head1", upper)
	_jaw = Node3D.new()
	_jaw.name = "jaw"
	_jaw.position = hinge - head
	skull.add_child(_jaw)
	var holder := Node3D.new()
	holder.position = -(hinge - head)
	_jaw.add_child(holder)
	g.rig.attach_voxels("head1", lower, holder)
	# A dark mouth inside: fill the cut so an open jaw shows a throat, not a hollow shell.
	var mouth := VoxelBuilder.new()
	var dark := Color("2a0d0b")
	for cell: Vector3i in lower.cells:
		var above := cell + Vector3i(0, 1, 0)
		if not lower.cells.has(above) and upper.cells.has(above) == false:
			mouth.put_color(above, dark)
	if mouth.cells.size() > 0:
		_mouth = g.rig.attach_voxels("head1", mouth, holder)


func _pose_jaw(dt: float) -> void:
	if _jaw == null:
		return
	var target := JAW_OPEN * roar_open() + 0.07 * _tell
	_jaw_open = lerpf(_jaw_open, target, minf(1.0, dt * 18.0))
	_jaw.rotation = Vector3(-_jaw_open, 0, 0)
	if _mouth != null:
		_mouth.visible = _jaw_open > 0.03  # the throat shows only when the jaw is open
