class_name CarveDebris
extends Node3D
## One building's loose pieces: carved cells thrown out and island bricks broken off. Each live
## piece is a bare Jolt body (PhysicsServer3D, no node) drawn by ONE MultiMesh for the building;
## a piece that comes to rest is frozen in place into a second, static rubble MultiMesh and its
## body turns static (no simulation cost) until the city's static cap, past which the oldest
## rubble keeps its look but loses its collider. Pieces retired to make room, rubble past
## rubble_cap and pieces left indoors (inside the footprint under cells that still stand, seen
## through the glass: hovering on slabs the view does not draw) shrink away over fade_seconds,
## never vanishing in one frame. Cosmetic: nothing here reaches the sim.

const SHRINK_MIN := 0.01  # a fading piece's last scale

var raised := 0  # live pieces lifted out of the road so far (captures)
var max_raise := 0.0  # the deepest of them

var skid_max := 0.0  # how far a settled piece slid along the road from first touch, in its widths
var culled := 0  # pieces faded out because they lay indoors (captures)
## The building and its grid (the sim's, after the last carve): what counts as indoors.
var site: CarveSite
var grid := PackedByteArray()
var skid_sum := 0.0
var skid_over := 0  # settled pieces that slid more than 5 of their widths
var skid_n := 0

var _cfg: Dictionary
var _space: RID
var _shapes: Dictionary = {}  # snapped size -> BoxShape3D (kept alive for its RID)
var _live_mm: MultiMesh
var _rubble: CarveRubble
# Live pieces, parallel arrays.
var _rids: Array[RID] = []
var _sizes := PackedVector3Array()
var _colors := PackedColorArray()
var _still := PackedFloat32Array()
var _age := PackedFloat32Array()
var _fade := PackedFloat32Array()  # < 0: not fading; else seconds since it began to fade
var _touch := PackedVector3Array()  # where it first met the road (y = NAN until it does)
var _fading := 0  # live pieces fading out


func _init() -> void:
	_cfg = Content.section("carve_physics")


func _ready() -> void:
	_space = get_world_3d().space
	_live_mm = CarveRubble.multimesh(self)
	_rubble = CarveRubble.new(CarveRubble.multimesh(self), _cfg)


func _exit_tree() -> void:
	for rid: RID in _rids:
		PhysicsServer3D.free_rid(rid)
	_rids.clear()
	_rubble.free_bodies()


## Live pieces still counted against the cap (fading ones excluded: they are on their way out).
func live() -> int:
	return _rids.size() - _fading


func bodies() -> int:
	return _rids.size()


func rubble() -> int:
	return _rubble.count()


## Rubble pieces dropped past rubble_cap so far.
func dropped() -> int:
	return _rubble.dropped


## Pieces that left the screen at over half size in one frame (captures; 0).
func vanished() -> int:
	return _rubble.vanished


func static_bodies() -> int:
	return _rubble.statics


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
	PhysicsServer3D.body_set_param(rid, PhysicsServer3D.BODY_PARAM_LINEAR_DAMP_MODE, 1)  # replace
	PhysicsServer3D.body_set_param(rid, PhysicsServer3D.BODY_PARAM_ANGULAR_DAMP_MODE, 1)
	PhysicsServer3D.body_set_param(
		rid, PhysicsServer3D.BODY_PARAM_LINEAR_DAMP, Num.f(_cfg["piece_linear_damp"])
	)
	PhysicsServer3D.body_set_param(
		rid, PhysicsServer3D.BODY_PARAM_ANGULAR_DAMP, Num.f(_cfg["piece_angular_damp"])
	)
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
	_touch.append(Vector3(0, NAN, 0))


## The lowest point of any piece, live or rubble (the capture's through-the-ground check).
func lowest_point() -> float:
	var low := INF
	for k: int in _rids.size():
		low = minf(low, _low(k))
	return minf(low, _rubble.lowest())


## How many live pieces reach below `y` (a capture's sunk-into-the-road count).
func sunk(y: float) -> int:
	var n := 0
	for k: int in _rids.size():
		if _low(k) < y:
			n += 1
	return n


## Live and rubble pieces whose centre lies inside `box` (captures: debris inside a building).
func inside(box: AABB) -> int:
	var n := 0
	for k: int in _rids.size():
		var xf: Transform3D = PhysicsServer3D.body_get_state(
			_rids[k], PhysicsServer3D.BODY_STATE_TRANSFORM
		)
		n += 1 if box.has_point(xf.origin) else 0
	return n + _rubble.inside(box)


## The fastest live piece's speed (captures).
func fastest() -> float:
	var top := 0.0
	for k: int in _rids.size():
		var v: Vector3 = PhysicsServer3D.body_get_state(
			_rids[k], PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY
		)
		top = maxf(top, v.length())
	return top


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
## Rubble inside `box` and off the ground loses its rest (what held it up was carved or fell):
## a piece with a collider turns live again where it lies; one without shrinks away. Rubble on
## the street never needs waking. Returns how many woke.
func wake(box: AABB) -> int:
	var woke := 0
	var floor_y := Num.f(_cfg["ground_y"]) + Num.f(_cfg["ground_slop"]) * 2.0
	var r := _rubble
	var k := r.count() - 1
	while k >= 0:
		var o := k * CarveRubble.FLOATS
		var at := Vector3(r.buf[o + 3], r.buf[o + 7], r.buf[o + 11])
		var reach := absf(r.buf[o + 4]) + absf(r.buf[o + 5]) + absf(r.buf[o + 6])
		if r.fade[k] < 0.0 and box.has_point(at) and at.y - 0.5 * reach > floor_y:
			var rid := r.rids[k]
			var xf := CarveRubble.unpack(r.buf, o)
			var color := Color(r.buf[o + 12], r.buf[o + 13], r.buf[o + 14])
			var size := Vector3(xf.basis.x.length(), xf.basis.y.length(), xf.basis.z.length())
			if rid.is_valid():
				PhysicsServer3D.body_set_mode(rid, PhysicsServer3D.BODY_MODE_RIGID)
				r.statics -= 1
				_adopt(rid, size, color)
			else:
				xf.basis = xf.basis.orthonormalized()
				var motion := [Vector3.ZERO, Vector3.ZERO, Num.f(_cfg["piece_gravity"]), 1.0]
				spawn(xf, size, color, motion)
				_fade[_fade.size() - 1] = 0.0
				_fading += 1
			r.remove(k)
			woke += 1
		k -= 1
	return woke


## Drops colliders from the oldest rubble until at most `keep` static bodies remain here.
func trim_static(keep: int) -> void:
	_rubble.trim_static(keep)


func _physics_process(delta: float) -> void:
	var rest_v := Num.f(_cfg["settle_speed"])
	var rest_w := Num.f(_cfg["settle_spin"])
	var rest_t := Num.f(_cfg["settle_seconds"])
	var fade_t := Num.f(_cfg["fade_seconds"])
	var ground := Num.f(_cfg["ground_y"])
	var floor_y := ground - Num.f(_cfg["ground_slop"])
	var indoor_t := Num.f(_cfg["indoor_seconds"])
	var k := _rids.size() - 1
	while k >= 0:
		var rid := _rids[k]
		_age[k] += delta
		var aged := _age[k] >= indoor_t and _age[k] - delta < indoor_t
		if _fade[k] < 0.0 and aged and _indoors(k):
			_cull(k)
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
			_note_touch(k, low)
			if low <= ground + Num.f(_cfg["ground_slop"]) * 3.0:
				_drag(rid, v, w, delta)
			_still[k] = _still[k] + delta if v.length() < rest_v and w.length() < rest_w else 0.0
			if _still[k] >= rest_t:
				if _indoors(k):
					_cull(k)
				else:
					_freeze(k)
		k -= 1


func _process(delta: float) -> void:
	_draw_live()
	_rubble.update(delta)


## True when live piece k lies indoors (see CarveSite.indoors).
func _indoors(k: int) -> bool:
	if site == null or grid.is_empty():
		return false
	var xf: Transform3D = PhysicsServer3D.body_get_state(
		_rids[k], PhysicsServer3D.BODY_STATE_TRANSFORM
	)
	return site.indoors(grid, xf.origin, Num.f(_cfg["indoor_margin"]))


## Live piece k begins to shrink away because it lies indoors.
func _cull(k: int) -> void:
	_fade[k] = 0.0
	_fading += 1
	culled += 1


func _draw_live() -> void:
	var n := _rids.size()
	CarveRubble.fit(_live_mm, n)
	var buf := PackedFloat32Array()
	buf.resize(_live_mm.instance_count * CarveRubble.FLOATS)
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
		CarveRubble.pack(
			buf,
			k * CarveRubble.FLOATS,
			Transform3D(xf.basis.scaled_local(scale), xf.origin),
			_colors[k]
		)
	_live_mm.buffer = buf
	_live_mm.visible_instance_count = n


## A piece on the road loses ground_drag of its sideways speed and spin a second: a cube that
## lands rolls and skids a little, not across the street (the road's friction alone leaves it
## tumbling for seconds).
func _drag(rid: RID, v: Vector3, w: Vector3, delta: float) -> void:
	var keep := maxf(0.0, 1.0 - Num.f(_cfg["ground_drag"]) * delta)
	PhysicsServer3D.body_set_state(
		rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3(v.x * keep, v.y, v.z * keep)
	)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, w * keep)


## Remembers where piece k first met the road, for the skid figure.
func _note_touch(k: int, low: float) -> void:
	if is_nan(_touch[k].y) and low <= Num.f(_cfg["ground_y"]) + Num.f(_cfg["ground_slop"]) * 2.0:
		var xf: Transform3D = PhysicsServer3D.body_get_state(
			_rids[k], PhysicsServer3D.BODY_STATE_TRANSFORM
		)
		_touch[k] = Vector3(xf.origin.x, 0.0, xf.origin.z)


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
	if not is_nan(_touch[k].y):
		var slid := Vector2(xf.origin.x - _touch[k].x, xf.origin.z - _touch[k].z).length()
		var width := maxf(_sizes[k].x, maxf(_sizes[k].y, _sizes[k].z))
		skid_max = maxf(skid_max, slid / width)
		skid_sum += slid / width
		skid_n += 1
		skid_over += 1 if slid > 5.0 * width else 0
	_rubble.add(rid, Transform3D(xf.basis.scaled_local(_sizes[k]), xf.origin), _colors[k])
	_drop(k)


## A faded piece is gone.
func _forget(k: int) -> void:
	_rubble.gone(maxf(SHRINK_MIN, 1.0 - _fade[k] / Num.f(_cfg["fade_seconds"])))
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
	_touch.remove_at(k)


func _shape(size: Vector3) -> BoxShape3D:
	var key := size.snapped(Vector3.ONE * 0.01)
	if not _shapes.has(key):
		var box := BoxShape3D.new()
		box.size = key
		_shapes[key] = box
	var out: BoxShape3D = _shapes[key]
	return out
