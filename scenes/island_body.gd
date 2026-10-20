class_name IslandBody
extends RigidBody3D
## A part of a building that lost its support, as one Jolt body: its own cells in their own
## materials, a mesh and a box per brick (one sim unit). A topple first follows the sim's turn
## about its pivot (kinematic, FallMotion's curve) for about a second, then is let go with the
## speed it had, so the hand-over has no jump. On each hard impact only the bricks near its
## lowest point break off (destruction spike clip r2: the whole island shattering on its first
## hit read as fake); the rest stays one body and breaks again on its next hard hit. A small
## remainder breaks up whole. Once few enough bricks are left (a slab, a stump), a hard hit splits
## it along its own bricks into seeded chunks that fly apart as islands of their own and break
## again on their own hits, so a slab never lands whole and stays. The bricks a break takes are
## chosen against a noise seeded per building (break_ragged), so the fracture front is ragged, not
## a flat cut that reads as a regular staircase on a tilted slab. Cosmetic: nothing here reaches
## the sim.

## Pieces broken off: each {"xf": Transform3D, "size": Vector3, "color": Color, "v": Vector3};
## `at` is the lowest point of the impact.
signal broke(pieces: Array[Dictionary], at: Vector3)
## The island split into chunks: each {"cells", "mats" (parallel), "xf" (the chunk body's
## transform), "v", "w"}; the owner makes each an IslandBody. This body is gone after it.
signal split(parts: Array[Dictionary])
signal settled
signal released

var site: CarveSite
## The look of this island's bricks (the building's own material); null keeps the vertex-coloured
## default. Also applied to bricks meshed later, and inherited by the chunks of a split.
var cell_material: Material:
	set(m):
		cell_material = m
		for mi: MeshInstance3D in _meshes.values():
			mi.material_override = m
var cells: PackedInt32Array
var mats: PackedByteArray
var settled_now := false
var last_break_us := 0  # how long the last break took (meshing and colliders), for benches
## Per staged break, the spread (standard deviation, world units) of the heights of the bricks
## left bordering the break: near 0 the fracture front is a plane, which reads as a staircase on
## a tilted slab (captures).
var front_spreads: Array[float] = []
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
var _contact_hit := Vector3.ZERO  # the speed before a first touch of the ground, taken next step
var _seed := 0  # the building's seed: its fracture noise and its splits
var _noise := FastNoiseLite.new()


func _init(
	p_site: CarveSite, p_cells: PackedInt32Array, p_mats: PackedByteArray, p_seed: int
) -> void:
	site = p_site
	cells = p_cells
	mats = p_mats
	_seed = p_seed
	_cfg = Content.section("carve_physics")
	_noise.seed = p_seed
	_noise.frequency = Num.f(_cfg["break_ragged_freq"])
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
	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_touched)


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


## A first touch of something solid: a hard one breaks the island on the next step (the contact
## frame), without waiting for the body to lose its speed.
func _touched(other: Node) -> void:
	if other is StaticBody3D and _follow.is_empty() and _v_prev.length() > Num.f(_cfg["break_speed"]):
		_contact_hit = _v_prev


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
	if hit == Vector3.ZERO and _contact_hit.length() > speed:
		hit = _contact_hit  # the contact step itself, not once the speed has bled off
	_contact_hit = Vector3.ZERO
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
	if not whole and _bricks.size() <= Num.i(_cfg["split_bricks"]):
		_split(v)
		return
	var ragged := Num.f(_cfg["break_ragged"])
	var keys: Array[Vector3i] = []
	for key: Vector3i in _bricks:
		var jag := ragged * _noise.get_noise_3dv(Vector3(key))
		if whole or Num.f(centre[key]) + jag < low + Num.f(_cfg["break_depth"]):
			keys.append(key)
	keys.sort_custom(
		func(a: Vector3i, b: Vector3i) -> bool: return Num.f(centre[a]) < Num.f(centre[b])
	)
	if not whole:
		_note_front(keys, centre)
	_stage = {"keys": keys, "v": v, "done": 0, "t": 0.0}
	_step_stage(0.0)


## Splits the island along its bricks into chunks of about split_chunk bricks (each brick joins
## the nearest of seeded seed bricks); a lone brick breaks into half-brick pieces. The chunks keep
## piece_keep of the speed before the hit, spread from the centre at up to split_spread and spin
## by up to split_spin: they tumble apart where the slab hit, then settle or break on their own.
func _split(v: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_seed, cells.size(), _bricks.size()])
	var groups := IslandFracture.group_bricks(_bricks.keys(), rng, Num.f(_cfg["split_chunk"]))
	var xf := global_transform
	var keep := v * Num.f(_cfg["piece_keep"])
	var spread := Num.f(_cfg["split_spread"])
	var spin := Num.f(_cfg["split_spin"])
	var parts: Array[Dictionary] = []
	var pieces: Array[Dictionary] = []
	for group: Array in groups:
		if group.size() == 1:
			var lone: Vector3i = group[0]
			_pieces_of(lone, xf, v, pieces)
			continue
		var own := PackedInt32Array()
		var own_mats := PackedByteArray()
		var com := Vector3.ZERO
		for key: Vector3i in group:
			var ks: PackedInt32Array = _bricks[key]
			for k: int in ks:
				own.append(cells[k])
				own_mats.append(mats[k])
				com += site.world(site.cell(cells[k]))
		com /= own.size()
		var at := xf * (com - _com)
		var out := at - global_position
		out.y = 0.0
		out = out.normalized() * spread * rng.randf_range(0.5, 1.0)
		var w := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		(
			parts
			. append(
				{
					"cells": own,
					"mats": own_mats,
					"xf": Transform3D(xf.basis, at),
					"v": keep + out + angular_velocity.cross(at - global_position),
					"w": angular_velocity + w * spin,
				}
			)
		)
	_settle_out()
	split.emit(parts)
	if not pieces.is_empty():
		broke.emit(pieces, global_position)
	queue_free()


## Takes this body out of the world at once (its chunks take its place this step).
func _settle_out() -> void:
	settled_now = true
	visible = false
	collision_layer = 0
	collision_mask = 0
	freeze = true


## Records the height spread of the bricks that will border this break (see front_spreads).
func _note_front(keys: Array[Vector3i], centre: Dictionary) -> void:
	var spread := IslandFracture.front_spread(keys, _bricks, centre)
	if spread >= 0.0:
		front_spreads.append(spread)


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


## Half-brick pieces round this brick's cells, each in its first material.
func _pieces_of(key: Vector3i, xf: Transform3D, v: Vector3, out: Array[Dictionary]) -> void:
	var own: PackedInt32Array = _bricks[key]
	IslandFracture.pieces_of(site, cells, mats, own, [xf, _com, v], out)


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
	mi.material_override = cell_material


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
