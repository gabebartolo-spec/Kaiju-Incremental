class_name CarveDebris
extends Node3D
## One building's loose pieces: carved cells thrown out and island bricks broken off. Each live
## piece is a bare Jolt body (PhysicsServer3D, no node) drawn by ONE MultiMesh for the building;
## a piece that comes to rest is frozen in place into a second, static rubble MultiMesh and its
## body turns static (no simulation cost) until the city's static cap, past which the oldest
## rubble keeps its look but loses its collider. Pieces retired to make room shrink away over
## fade_seconds, never vanishing in one frame. Cosmetic: nothing here reaches the sim.

const FLOATS := 16  # per MultiMesh instance: a 3x4 transform, then a colour
const SHRINK_MIN := 0.01  # a fading piece's last scale

var raised := 0  # live pieces lifted out of the road so far (captures)
var max_raise := 0.0  # the deepest of them

var _cfg: Dictionary
var _space: RID
var _shapes: Dictionary = {}  # snapped size -> BoxShape3D (kept alive for its RID)
var _live_mm: MultiMesh
var _rubble_mm: MultiMesh
# Live pieces, parallel arrays.
var _rids: Array[RID] = []
var _sizes := PackedVector3Array()
var _colors := PackedColorArray()
var _still := PackedFloat32Array()
var _age := PackedFloat32Array()
var _fade := PackedFloat32Array()  # < 0: not fading; else seconds since it began to fade
# Rubble, parallel arrays; an invalid RID is rubble with no collider left.
var _rubble_rids: Array[RID] = []
var _rubble := PackedFloat32Array()  # FLOATS per piece
var _rubble_dirty := false
var _fading := 0  # live pieces fading out
var _statics := 0  # rubble pieces that still have a (static) body


func _init() -> void:
	_cfg = Content.section("carve_physics")


func _ready() -> void:
	_space = get_world_3d().space
	_live_mm = _multimesh()
	_rubble_mm = _multimesh()


func _exit_tree() -> void:
	for rid: RID in _rids + _rubble_rids:
		if rid.is_valid():
			PhysicsServer3D.free_rid(rid)
	_rids.clear()
	_rubble_rids.clear()


## Live pieces still counted against the cap (fading ones excluded: they are on their way out).
func live() -> int:
	return _rids.size() - _fading


func bodies() -> int:
	return _rids.size()


func rubble() -> int:
	return _rubble_rids.size()


func static_bodies() -> int:
	return _statics


## A new live piece at `xf`, `size` (world); motion is [velocity, spin, gravity scale, mass].
func spawn(xf: Transform3D, size: Vector3, color: Color, motion: Array) -> void:
	var v: Vector3 = motion[0]
	var spin: Vector3 = motion[1]
	var gravity: float = motion[2]
	var m: float = motion[3]
	var rid := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(rid, PhysicsServer3D.BODY_MODE_RIGID)
	PhysicsServer3D.body_add_shape(rid, _shape(size).get_rid())
	PhysicsServer3D.body_set_space(rid, _space)
	PhysicsServer3D.body_set_param(rid, PhysicsServer3D.BODY_PARAM_MASS, m)
	PhysicsServer3D.body_set_param(rid, PhysicsServer3D.BODY_PARAM_GRAVITY_SCALE, gravity)
	PhysicsServer3D.body_set_enable_continuous_collision_detection(rid, true)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, v)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, spin)
	_adopt(rid, size, color)


func _adopt(rid: RID, size: Vector3, color: Color) -> void:
	_rids.append(rid)
	_sizes.append(size)
	_colors.append(color)
	_still.append(0.0)
	_age.append(0.0)
	_fade.append(-1.0)


## The lowest point of any piece, live or rubble (the capture's through-the-ground check).
func lowest_point() -> float:
	var low := INF
	for k: int in _rids.size():
		low = minf(low, _low(k))
	for o: int in range(0, _rubble.size(), FLOATS):
		var reach := absf(_rubble[o + 4]) + absf(_rubble[o + 5]) + absf(_rubble[o + 6])
		low = minf(low, _rubble[o + 7] - 0.5 * reach)
	return low


## How many live pieces reach below `y` (a capture's sunk-into-the-road count).
func sunk(y: float) -> int:
	var n := 0
	for k: int in _rids.size():
		if _low(k) < y:
			n += 1
	return n


## Live piece k's lowest point.
func _low(k: int) -> float:
	var xf: Transform3D = PhysicsServer3D.body_get_state(
		_rids[k], PhysicsServer3D.BODY_STATE_TRANSFORM
	)
	var b := xf.basis.scaled_local(_sizes[k])
	return xf.origin.y - 0.5 * (absf(b.x.y) + absf(b.y.y) + absf(b.z.y))


## Starts the oldest `n` live pieces fading (the cap is full): they shrink away, then go.
func retire(n: int) -> void:
	for k: int in _rids.size():
		if n <= 0:
			return
		if _fade[k] < 0.0:
			_fade[k] = 0.0
			_fading += 1
			n -= 1


## Rubble inside `box` and off the ground loses its rest (what held it up was carved or fell):
## a piece with a collider turns live again where it lies; one without shrinks away. Rubble on
## the street never needs waking. Returns how many woke.
func wake(box: AABB) -> int:
	var woke := 0
	var floor_y := Num.f(_cfg["ground_y"]) + Num.f(_cfg["ground_slop"]) * 2.0
	var k := _rubble_rids.size() - 1
	while k >= 0:
		var o := k * FLOATS
		var at := Vector3(_rubble[o + 3], _rubble[o + 7], _rubble[o + 11])
		var reach := absf(_rubble[o + 4]) + absf(_rubble[o + 5]) + absf(_rubble[o + 6])
		if box.has_point(at) and at.y - 0.5 * reach > floor_y:
			var rid := _rubble_rids[k]
			var xf := _unpack(_rubble, o)
			var color := Color(_rubble[o + 12], _rubble[o + 13], _rubble[o + 14])
			var size := Vector3(xf.basis.x.length(), xf.basis.y.length(), xf.basis.z.length())
			if rid.is_valid():
				PhysicsServer3D.body_set_mode(rid, PhysicsServer3D.BODY_MODE_RIGID)
				_statics -= 1
				_adopt(rid, size, color)
			else:
				xf.basis = xf.basis.orthonormalized()
				var motion := [Vector3.ZERO, Vector3.ZERO, Num.f(_cfg["piece_gravity"]), 1.0]
				spawn(xf, size, color, motion)
				_fade[_fade.size() - 1] = 0.0
				_fading += 1
			_rubble_rids.remove_at(k)
			_remove_floats(k)
			woke += 1
		k -= 1
	return woke


## Drops colliders from the oldest rubble until at most `keep` static bodies remain here.
func trim_static(keep: int) -> void:
	for k: int in _rubble_rids.size():
		if _statics <= keep:
			return
		if _rubble_rids[k].is_valid():
			PhysicsServer3D.free_rid(_rubble_rids[k])
			_rubble_rids[k] = RID()
			_statics -= 1


func _physics_process(delta: float) -> void:
	var rest_v := Num.f(_cfg["settle_speed"])
	var rest_w := Num.f(_cfg["settle_spin"])
	var rest_t := Num.f(_cfg["settle_seconds"])
	var fade_t := Num.f(_cfg["fade_seconds"])
	var ground := Num.f(_cfg["ground_y"])
	var floor_y := ground - Num.f(_cfg["ground_slop"])
	var k := _rids.size() - 1
	while k >= 0:
		var rid := _rids[k]
		_age[k] += delta
		if _fade[k] >= 0.0:
			_fade[k] += delta
			if _fade[k] >= fade_t:
				_forget(k)
		else:
			var v: Vector3 = PhysicsServer3D.body_get_state(
				rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY
			)
			var w: Vector3 = PhysicsServer3D.body_get_state(
				rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY
			)
			var low := _low(k)
			if low < floor_y:
				_raise(rid, ground - low, v)
				low = ground
			_still[k] = _still[k] + delta if v.length() < rest_v and w.length() < rest_w else 0.0
			if _still[k] >= rest_t:
				_freeze(k)
		k -= 1


func _process(_delta: float) -> void:
	_draw_live()
	if _rubble_dirty:
		_rubble_dirty = false
		var n := _rubble_rids.size()
		_fit(_rubble_mm, n)
		var buf := _rubble.duplicate()
		buf.resize(_rubble_mm.instance_count * FLOATS)
		_rubble_mm.buffer = buf
		_rubble_mm.visible_instance_count = n


func _draw_live() -> void:
	var n := _rids.size()
	_fit(_live_mm, n)
	var buf := PackedFloat32Array()
	buf.resize(_live_mm.instance_count * FLOATS)
	var fade_t := Num.f(_cfg["fade_seconds"])
	var ground := Num.f(_cfg["ground_y"])
	var floor_y := ground - Num.f(_cfg["ground_slop"])
	for k: int in n:
		var xf: Transform3D = PhysicsServer3D.body_get_state(
			_rids[k], PhysicsServer3D.BODY_STATE_TRANSFORM
		)
		var low := _low(k)
		if low < floor_y:
			# The physics steps since the last fix can press a piece in again: never draw it so.
			var v: Vector3 = PhysicsServer3D.body_get_state(
				_rids[k], PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY
			)
			_raise(_rids[k], ground - low, v)
			xf.origin.y += ground - low
		var scale := _sizes[k]
		if _fade[k] >= 0.0:
			scale *= maxf(SHRINK_MIN, 1.0 - _fade[k] / fade_t)
		_pack(buf, k * FLOATS, Transform3D(xf.basis.scaled_local(scale), xf.origin), _colors[k])
	_live_mm.buffer = buf
	_live_mm.visible_instance_count = n


## A live piece pressed into the road (a small box under a pile: Jolt's position correction is
## soft, so it can sit up to a box deep in the ground) is lifted `by` onto it and stops sinking.
## The view is cosmetic, so a positional fix-up is honest; `raised` counts them for captures.
func _raise(rid: RID, by: float, v: Vector3) -> void:
	var xf: Transform3D = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM)
	xf.origin.y += by
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
	if v.y < 0.0:
		v.y = 0.0
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, v)
	raised += 1
	max_raise = maxf(max_raise, by)


## A resting piece becomes rubble where it lies: its body turns static, its look moves to the
## rubble MultiMesh.
func _freeze(k: int) -> void:
	var rid := _rids[k]
	var xf: Transform3D = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM)
	PhysicsServer3D.body_set_mode(rid, PhysicsServer3D.BODY_MODE_STATIC)
	var o := _rubble.size()
	_rubble.resize(o + FLOATS)
	_pack(_rubble, o, Transform3D(xf.basis.scaled_local(_sizes[k]), xf.origin), _colors[k])
	_rubble_rids.append(rid)
	_statics += 1
	_rubble_dirty = true
	_drop(k)


## A faded piece is gone.
func _forget(k: int) -> void:
	PhysicsServer3D.free_rid(_rids[k])
	_fading -= 1
	_drop(k)


func _drop(k: int) -> void:
	_rids.remove_at(k)
	_sizes.remove_at(k)
	_colors.remove_at(k)
	_still.remove_at(k)
	_age.remove_at(k)
	_fade.remove_at(k)


func _remove_floats(k: int) -> void:
	var o := k * FLOATS
	var tail := _rubble.slice(o + FLOATS)
	_rubble.resize(o)
	_rubble.append_array(tail)
	_rubble_dirty = true


func _shape(size: Vector3) -> BoxShape3D:
	var key := size.snapped(Vector3.ONE * 0.01)
	if not _shapes.has(key):
		var box := BoxShape3D.new()
		box.size = key
		_shapes[key] = box
	var out: BoxShape3D = _shapes[key]
	return out


func _multimesh() -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var cube := BoxMesh.new()  # unit cube, scaled per instance to the piece's size
	cube.material = CarveMesh.material()
	mm.mesh = cube
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.top_level = true
	add_child(mmi)
	return mm


## Grows the MultiMesh's capacity (doubling) so `n` pieces fit; it never shrinks.
static func _fit(mm: MultiMesh, n: int) -> void:
	if mm.instance_count >= n:
		return
	mm.instance_count = maxi(64, nearest_po2(n))


static func _pack(buf: PackedFloat32Array, o: int, xf: Transform3D, c: Color) -> void:
	var b := xf.basis
	buf[o] = b.x.x
	buf[o + 1] = b.y.x
	buf[o + 2] = b.z.x
	buf[o + 3] = xf.origin.x
	buf[o + 4] = b.x.y
	buf[o + 5] = b.y.y
	buf[o + 6] = b.z.y
	buf[o + 7] = xf.origin.y
	buf[o + 8] = b.x.z
	buf[o + 9] = b.y.z
	buf[o + 10] = b.z.z
	buf[o + 11] = xf.origin.z
	buf[o + 12] = c.r
	buf[o + 13] = c.g
	buf[o + 14] = c.b
	buf[o + 15] = 1.0


static func _unpack(buf: PackedFloat32Array, o: int) -> Transform3D:
	var bx := Vector3(buf[o], buf[o + 4], buf[o + 8])
	var by := Vector3(buf[o + 1], buf[o + 5], buf[o + 9])
	var bz := Vector3(buf[o + 2], buf[o + 6], buf[o + 10])
	return Transform3D(Basis(bx, by, bz), Vector3(buf[o + 3], buf[o + 7], buf[o + 11]))
