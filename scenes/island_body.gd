class_name IslandBody
extends RigidBody3D
## A part of a building that lost its support, as one Jolt body: its own cells in their own
## materials, a box per brick (one sim unit) and a mesh per brick, or with render_opt.island_merged
## (render plan item 11, on) one merged mesh for them all (IslandMesh) and the boxes added straight
## to the body's RID. A topple first follows the sim's turn
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
## transform), "v", "w", "layers": [layer, mask]}; the owner makes each an IslandBody.
## This body is gone after it.
signal split(parts: Array[Dictionary])
signal settled
signal released

var site: CarveSite
## The look of the bricks (the building's material; null: vertex colours), kept on remeshes.
var cell_material: Material:
	set(m):
		cell_material = m
		for mi: MeshInstance3D in _meshes.values():
			mi.material_override = m
		if _view != null:
			_view.material = m
var cells: PackedInt32Array
var mats: PackedByteArray
var settled_now := false
var merged := true  # render_opt.island_merged: IslandMesh draws the cells, shapes on the RID
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
var _view: IslandMesh  # merged: the cells' one mesh and patch
var _shape_keys: Array[Vector3i] = []  # merged: the brick of each of the body's shapes, in order
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
	merged = Content.section("render_opt").get("island_merged", true) == true
	if merged:
		_view = IslandMesh.new(site, VoxelAO.strength())
		add_child(_view)
		_view.build_now([cells, mats, _solid], _bricks, _com)
	for key: Vector3i in _bricks:
		if not merged:
			IslandBricks.mesh_brick(self, key)
		IslandBricks.shape_brick(self, key)
	_mass()
	continuous_cd = true
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


## Blocks until a running remesh is drawn (a capture's settled frame; tests).
func finish_mesh() -> void:
	if _view != null:
		_view.finish()


func cell_count() -> int:
	var n := 0
	for key: Vector3i in _bricks:
		var ks: PackedInt32Array = _bricks[key]
		n += ks.size()
	return n


## A hard first touch of something solid breaks the island next step, not once its speed bleeds off.
func _touched(other: Node) -> void:
	if (
		other is StaticBody3D
		and _follow.is_empty()
		and _v_prev.length() > Num.f(_cfg["break_speed"])
	):
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
	var hit := IslandFracture.hard_hit(_recent, v, _clock, _cfg)
	hit = _contact_hit if hit == Vector3.ZERO else hit  # the contact step, not once speed bleeds
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
		var y := (xf * (IslandBricks.brick_span(self, key).get_center() - _com)).y
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
	if not whole:  # the height spread of the bricks left bordering the break (see front_spreads)
		var spread := IslandFracture.front_spread(keys, _bricks, centre)
		if spread >= 0.0:
			front_spreads.append(spread)
	_stage = {"keys": keys, "v": v, "done": 0, "t": 0.0}
	_step_stage(0.0)


## Splits the island along its bricks into seeded chunks that tumble apart where the slab hit
## (see IslandSplit); a lone brick breaks into half-brick pieces.
func _split(v: Vector3) -> void:
	var plan := IslandSplit.new(self, _bricks, _com)
	plan.run(hash([_seed, cells.size(), _bricks.size()]), v, _cfg)
	_settle_out()
	split.emit(plan.parts)
	if not plan.pieces.is_empty():
		broke.emit(plan.pieces, global_position)
	queue_free()


## Takes this body out of the world at once (its chunks take its place this step).
func _settle_out() -> void:
	settled_now = true
	visible = false
	collision_layer = 0
	collision_mask = 0
	freeze = true


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
	var pieces: Array[Dictionary] = []
	var at := _let_go(keys, done, upto, pieces)
	_stage["done"] = upto
	if upto >= keys.size():
		_stage = {}
		if merged and not _bricks.is_empty():  # the whole island meshed again, on a worker
			_view.remesh([cells, mats, _solid], _bricks, _com)
	last_break_us = Time.get_ticks_usec() - t0
	broke.emit(pieces, at)
	if _bricks.is_empty():
		queue_free()
		return
	_mass()


## Lets go the bricks `keys[done..upto)` as pieces (into `pieces`) and redraws what they leave;
## returns the impact point (their mean, at the lowest of them).
func _let_go(keys: Array[Vector3i], done: int, upto: int, pieces: Array[Dictionary]) -> Vector3:
	var xf := global_transform
	var v: Vector3 = _stage["v"]
	var at := Vector3.ZERO
	var low := INF
	var lists := {}
	for k: int in range(done, upto):
		var key := keys[k]
		_pieces_of(key, xf, v, pieces)
		var here := xf * (IslandBricks.brick_span(self, key).get_center() - _com)
		at += here
		low = minf(low, here.y)
		lists[key] = _bricks[key]
		IslandBricks.drop_brick(self, key)
	at /= upto - done
	at.y = low
	_redraw(lists)
	return at


## What dropping `lists` (brick -> positions in cells) left, drawn again: merged, the view hides
## them and patches the faces they laid bare; else every brick next to one is meshed again.
func _redraw(lists: Dictionary) -> void:
	if merged:
		_view.dropped(lists, [cells, mats, _solid], _bricks, _com)
		return
	var touched := {}
	for key: Vector3i in lists:
		for step: Vector3i in CarveMesh.STEPS:
			if _bricks.has(key + step):
				touched[key + step] = true
	for key: Vector3i in touched:
		IslandBricks.mesh_brick(self, key)


## Half-brick pieces round this brick's cells, each in its first material.
func _pieces_of(key: Vector3i, xf: Transform3D, v: Vector3, out: Array[Dictionary]) -> void:
	var own: PackedInt32Array = _bricks[key]
	IslandFracture.pieces_of(site, cells, mats, own, [xf, _com, v], out)


func _mass() -> void:
	mass = maxf(1.0, cell_count() * Num.f(_cfg["cell_mass"]))
