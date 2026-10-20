class_name IslandBody
extends RigidBody3D
## A part of a building that lost its support, as one Jolt body: its own cells in their own
## materials, a mesh and a box per brick (one sim unit). A topple first follows the sim's turn
## about its pivot (kinematic, FallMotion's curve) for about a second, then is let go with the
## speed it had, so the hand-over has no jump. On each hard impact only the bricks near its
## lowest point break off (destruction spike clip r2: the whole island shattering on its first
## hit read as fake); the rest stays one body and breaks again on its next hard hit. A small
## remainder breaks up whole. Cosmetic: nothing here reaches the sim.

## Pieces broken off: each {"xf": Transform3D, "size": Vector3, "color": Color, "v": Vector3};
## `at` is the lowest point of the impact.
signal broke(pieces: Array[Dictionary], at: Vector3)
signal settled
signal released

var site: CarveSite
var cells: PackedInt32Array
var mats: PackedByteArray
var settled_now := false
var last_break_us := 0  # how long the last break took (meshing and colliders), for benches
var _cfg: Dictionary
var _solid := PackedByteArray()  # site-sized, 1 where this island still owns a cell
var _bricks: Dictionary = {}  # brick -> PackedInt32Array of positions in `cells`
var _meshes: Dictionary = {}  # brick -> MeshInstance3D
var _shapes: Dictionary = {}  # brick -> CollisionShape3D
var _spans: Dictionary = {}  # brick -> world AABB of its cells at spawn (a brick never shrinks)
var _com := Vector3.ZERO  # world centre of mass at spawn = the body's origin at spawn
var _follow := {}  # pivot, dir, duration, until, t (empty: not following)
var _v_prev := Vector3.ZERO
var _recent: Array[Vector4] = []  # (velocity, clock) over the last break_window seconds
var _clock := 0.0
var _stage := {}  # a break in progress: keys (bottom first), v, done, t
var _still := 0.0
var _cooldown := 0.0


func _init(p_site: CarveSite, p_cells: PackedInt32Array, p_mats: PackedByteArray) -> void:
	site = p_site
	cells = p_cells
	mats = p_mats
	_cfg = Content.section("carve_physics")
	_solid.resize(site.count())
	for i: int in cells:
		_solid[i] = 1
		_com += site.world(site.cell(i))
	_com /= maxi(1, cells.size())
	position = _com
	_bricks = CarveMesh.bricks(site, cells)
	for key: Vector3i in _bricks:
		_mesh_brick(key)
		_shape_brick(key)
	_mass()
	continuous_cd = true
	can_sleep = true


## Follows the sim's topple: turns about `pivot` (world) toward `dir` over `duration` (the
## sim's fall time) for `seconds`, then is let go.
func follow(pivot: Vector3, dir: Vector2, duration: float, seconds: float) -> void:
	_follow = {"pivot": pivot, "dir": dir, "duration": maxf(0.05, duration), "until": seconds}
	_follow["t"] = 0.0
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true


func brick_count() -> int:
	return _bricks.size()


func cell_count() -> int:
	var n := 0
	for key: Vector3i in _bricks:
		var ks: PackedInt32Array = _bricks[key]
		n += ks.size()
	return n


func following() -> bool:
	return not _follow.is_empty()


func _physics_process(delta: float) -> void:
	if settled_now:
		return
	if not _follow.is_empty():
		_step_follow(delta)
		return
	_clock += delta
	if not _stage.is_empty():
		_step_stage(delta)
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	var v := linear_velocity
	var speed := Num.f(_cfg["break_speed"])
	var hit := _hit(v, speed)
	if _cooldown == 0.0 and hit.length() > 0.0:
		_start_break(hit)
		_cooldown = 0.1
	_v_prev = linear_velocity
	var spin := angular_velocity.length()
	if v.length() < Num.f(_cfg["settle_speed"]) and spin < Num.f(_cfg["settle_spin"]):
		_still += delta
		if _still >= Num.f(_cfg["settle_seconds"]):
			_settle()
	else:
		_still = 0.0


## The velocity the body had just before a hard hit, or ZERO: the fastest recent velocity above
## `speed` that the body has since lost more than break_jolt of. Looking back break_window
## seconds, not one step, catches a slab that lands on a pile and slows over several steps.
func _hit(v: Vector3, speed: float) -> Vector3:
	var window := Num.f(_cfg["break_window"])
	_recent.append(Vector4(v.x, v.y, v.z, _clock))
	while _recent[0].w < _clock - window:
		_recent.pop_front()
	var out := Vector3.ZERO
	var worst := speed * Num.f(_cfg["break_jolt"])
	for r: Vector4 in _recent:
		var old := Vector3(r.x, r.y, r.z)
		var lost := (old - v).length()
		if old.length() > speed and lost > worst:
			worst = lost
			out = old
	return out


## The kinematic turn: the angle grows with the square of time, as FallMotion and the sim's
## Collapse have it; at `until` the body is let go with that turn's angular speed.
func _step_follow(delta: float) -> void:
	var t := Num.f(_follow["t"]) + delta
	_follow["t"] = t
	var duration := Num.f(_follow["duration"])
	var dir: Vector2 = _follow["dir"]
	var pivot: Vector3 = _follow["pivot"]
	var k := minf(1.0, t / duration)
	var turn := FallMotion.topple_basis(dir, k)
	global_transform = Transform3D(turn, pivot + turn * (_com - pivot))
	if t < Num.f(_follow["until"]) and k < 1.0:
		return
	var axis := Vector3(dir.y, 0, -dir.x)
	axis = FallMotion.STILL_AXIS if axis.is_zero_approx() else axis.normalized()
	var spin := axis * PI * k / duration
	_follow = {}
	freeze = false
	angular_velocity = spin
	linear_velocity = spin.cross(global_position - pivot)
	_v_prev = linear_velocity
	released.emit()


func _settle() -> void:
	settled_now = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	settled.emit()


## The bricks whose centres are within break_depth of the lowest one (all of a small remainder)
## are lined up bottom first and let go over break_stage seconds, each in half-brick pieces in
## its own material, so a slab crumbles from the foot up rather than bursting at once.
func _start_break(v: Vector3) -> void:
	var xf := global_transform
	var centre := {}
	var low := INF
	for key: Vector3i in _bricks:
		var y := (xf * (_brick_span(key).get_center() - _com)).y
		centre[key] = y
		low = minf(low, y)
	var whole := _bricks.size() < Num.i(_cfg["break_whole_bricks"])
	var keys: Array[Vector3i] = []
	for key: Vector3i in _bricks:
		if whole or Num.f(centre[key]) < low + Num.f(_cfg["break_depth"]):
			keys.append(key)
	keys.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return Num.f(centre[a]) < Num.f(centre[b]))
	_stage = {"keys": keys, "v": v, "done": 0, "t": 0.0}
	_step_stage(0.0)


## Lets go the next share of the staged bricks; the last share frees an emptied island.
func _step_stage(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	var t := Num.f(_stage["t"]) + delta
	_stage["t"] = t
	var keys: Array[Vector3i] = _stage["keys"]
	var done := Num.i(_stage["done"])
	var share := minf(1.0, t / maxf(0.01, Num.f(_cfg["break_stage"])))
	var upto := keys.size() if share >= 1.0 else ceili(share * keys.size())
	if upto <= done:
		return
	var xf := global_transform
	var v: Vector3 = _stage["v"]
	var pieces: Array[Dictionary] = []
	var at := Vector3.ZERO
	var low := INF
	for k: int in range(done, upto):
		var key := keys[k]
		_pieces_of(key, xf, v, pieces)
		var here := xf * (_brick_span(key).get_center() - _com)
		at += here
		low = minf(low, here.y)
		_drop_brick(key)
	at /= upto - done
	at.y = low
	var touched := {}
	for k: int in range(done, upto):
		for step: Vector3i in CarveMesh.STEPS:
			if _bricks.has(keys[k] + step):
				touched[keys[k] + step] = true
	for key: Vector3i in touched:
		_mesh_brick(key)
	_stage["done"] = upto
	if upto >= keys.size():
		_stage = {}
	last_break_us = Time.get_ticks_usec() - t0
	broke.emit(pieces, at)
	if _bricks.is_empty():
		queue_free()
		return
	_mass()


## Half-brick pieces (res/2 cells a side) round this brick's cells, each in its first material.
func _pieces_of(key: Vector3i, xf: Transform3D, v: Vector3, out: Array[Dictionary]) -> void:
	var half := maxi(1, site.res >> 1)
	var groups := {}
	var own: PackedInt32Array = _bricks[key]
	for k: int in own:
		var sub := site.cell(cells[k]) / half
		if not groups.has(sub):
			groups[sub] = PackedInt32Array()
		var list: PackedInt32Array = groups[sub]
		list.append(k)
		groups[sub] = list
	for sub: Vector3i in groups:
		var ks: PackedInt32Array = groups[sub]
		var box := CarveMesh.span(site, cells, ks)
		var at := xf * (box.get_center() - _com)
		(
			out
			. append(
				{
					"xf": Transform3D(xf.basis, at),
					"size": box.size,
					"color": site.color(mats[ks[0]]),
					"v": v,
				}
			)
		)


func _drop_brick(key: Vector3i) -> void:
	var own: PackedInt32Array = _bricks[key]
	for k: int in own:
		_solid[cells[k]] = 0
	_bricks.erase(key)
	_spans.erase(key)
	for table: Dictionary in [_meshes, _shapes]:
		if table.has(key):
			var node: Node = table[key]
			node.queue_free()
			table.erase(key)


func _brick_span(key: Vector3i) -> AABB:
	if not _spans.has(key):
		var ks: PackedInt32Array = _bricks[key]
		_spans[key] = CarveMesh.span(site, cells, ks)
	var out: AABB = _spans[key]
	return out


func _mesh_brick(key: Vector3i) -> void:
	var ks: PackedInt32Array = _bricks[key]
	var own := PackedInt32Array()
	var own_mats := PackedByteArray()
	for k: int in ks:
		own.append(cells[k])
		own_mats.append(mats[k])
	var mesh := CarveMesh.build_at(site, own, [own_mats, _solid], _com)
	var mi: MeshInstance3D = _meshes.get(key)
	if mi == null:
		mi = MeshInstance3D.new()
		add_child(mi)
		_meshes[key] = mi
	mi.mesh = mesh


func _shape_brick(key: Vector3i) -> void:
	var box := _brick_span(key)
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = box.size
	shape.shape = b
	shape.position = box.get_center() - _com
	add_child(shape)
	_shapes[key] = shape


func _mass() -> void:
	mass = maxf(1.0, cell_count() * Num.f(_cfg["cell_mass"]))
