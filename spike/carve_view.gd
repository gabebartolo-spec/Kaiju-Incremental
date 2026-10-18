class_name CarveView
extends Node3D
@warning_ignore_start("unsafe_method_access", "unsafe_property_access", "unsafe_call_argument", "unsafe_cast", "untyped_declaration", "integer_division", "narrowing_conversion")
## SPIKE (throwaway). Option A's presentation for one CarveGrid: the grid meshed in regions
## (only regions a carve touched are remeshed), a static collider per RES brick, physics debris
## for carved cells and a Jolt rigid body per island that, on its first hard impact, breaks into
## one body per brick. Reads the grid; never writes it.

const REGION := 16
static var debris_per_carve := 40
const MAX_DEBRIS := 2500  # pieces per building; all drawn by one MultiMesh
const BREAK_SPEED := 3.0  # an island hitting something faster than this breaks where it hit
const BREAK_DEPTH := 2.5  # units above its lowest point that break off on an impact
const COLORS := {
	CarveGrid.WALL: Color("b9ad98"),
	CarveGrid.SLAB: Color("5d5a55"),
	CarveGrid.GLASS: Color("3d6d7a"),
	CarveGrid.COLUMN: Color("8a8378"),
}

var grid: CarveGrid
var mesh_us := 0  # last remesh
var bodies := 0
var _regions: Dictionary = {}  # region key -> MeshInstance3D
var _bricks: Dictionary = {}  # brick key -> CollisionShape3D
var _static: StaticBody3D
var _mat: StandardMaterial3D
var _box: BoxMesh
var _debris: Array[RigidBody3D] = []
var _islands: Array[RigidBody3D] = []
var _box_mats: Dictionary = {}
var _sizes: Array[Vector3] = []
var _mm: MultiMesh
var _rng := RandomNumberGenerator.new()


func _init(p_grid: CarveGrid, seed_value: int) -> void:
	grid = p_grid
	_rng.seed = seed_value
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.roughness = 0.9
	_box = BoxMesh.new()
	_box.size = Vector3.ONE / grid.res * 0.95


func _ready() -> void:
	_static = StaticBody3D.new()
	add_child(_static)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	var cube := BoxMesh.new()
	var cmat := StandardMaterial3D.new()
	cmat.vertex_color_use_as_albedo = true
	cmat.roughness = 0.95
	cube.material = cmat
	_mm.mesh = cube
	_mm.instance_count = MAX_DEBRIS
	_mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.top_level = true
	add_child(mmi)
	var rx := ceili(float(grid.w) / REGION)
	var ry := ceili(float(grid.h) / REGION)
	var rz := ceili(float(grid.d) / REGION)
	for y: int in ry:
		for z: int in rz:
			for x: int in rx:
				_remesh(Vector3i(x, y, z))
	var bw := grid.w / grid.res
	var bd := grid.d / grid.res
	for y: int in grid.h / grid.res:
		for z: int in bd:
			for x: int in bw:
				_rebrick(Vector3i(x, y, z))


## A carve happened: remesh what it touched, throw debris, drop each island as a body.
func carved(removed: PackedInt32Array, islands: Array[PackedInt32Array], push: Vector3) -> void:
	var t0 := Time.get_ticks_usec()
	var dirty_regions := {}
	var dirty_bricks := {}
	for part: PackedInt32Array in [removed] + islands:
		for i: int in part:
			var c := _cell(i)
			dirty_regions[c / REGION] = true
			dirty_bricks[c / grid.res] = true
	for key: Vector3i in dirty_regions:
		_remesh(key)
	for key: Vector3i in dirty_bricks:
		_rebrick(key)
	mesh_us = Time.get_ticks_usec() - t0
	for n: int in mini(debris_per_carve, removed.size()):
		var i := removed[_rng.randi_range(0, removed.size() - 1)]
		_debris_at(grid.world(i), COLORS[grid_color_of(i)], push)
	for k: int in islands.size():
		_island(islands[k], grid.island_mats[k], push)


## Removed cells are already EMPTY; debris takes the material their brick mostly had.
func grid_color_of(i: int) -> int:
	var c := _cell(i)
	return CarveGrid.GLASS if c.y % grid.res >= 2 and _rng.randf() < 0.3 else CarveGrid.WALL


func _process(_delta: float) -> void:
	for body: RigidBody3D in _islands.duplicate():
		if body.get_meta("fallen", false):
			continue
		var v: Vector3 = body.get_meta("v", Vector3.ZERO)
		var now := body.linear_velocity
		body.set_meta("v", now)
		if v.length() > BREAK_SPEED and (v - now).length() > BREAK_SPEED * 0.6:
			_break_low(body, v)
	while _debris.size() > MAX_DEBRIS:
		var old: RigidBody3D = _debris.pop_front()
		_sizes.pop_front()
		old.queue_free()
	for k: int in _debris.size():
		var t := _debris[k].global_transform
		_mm.set_instance_transform(k, Transform3D(t.basis.scaled_local(_sizes[k]), t.origin))
		_mm.set_instance_color(k, _debris[k].get_meta("color"))
	_mm.visible_instance_count = _debris.size()
	bodies = _debris.size() + _islands.size()


func _track(body: RigidBody3D, size: Vector3, color: Color) -> void:
	body.set_meta("color", color)
	_debris.append(body)
	_sizes.append(size)


func _cell(i: int) -> Vector3i:
	var plan := grid.w * grid.d
	return Vector3i(i % grid.w, i / plan, (i / grid.w) % grid.d)


func _remesh(key: Vector3i) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := 0
	var lo := key * REGION
	for y: int in range(lo.y, mini(grid.h, lo.y + REGION)):
		for z: int in range(lo.z, mini(grid.d, lo.z + REGION)):
			for x: int in range(lo.x, mini(grid.w, lo.x + REGION)):
				var m := grid.cells[grid.index(x, y, z)]
				if m != CarveGrid.EMPTY:
					faces += _cube(st, Vector3i(x, y, z), m, grid.cells)
	var mi: MeshInstance3D = _regions.get(key)
	if faces == 0:
		if mi != null:
			mi.queue_free()
			_regions.erase(key)
		return
	if mi == null:
		mi = MeshInstance3D.new()
		mi.material_override = _mat
		add_child(mi)
		_regions[key] = mi
	mi.mesh = st.commit()


## Emits the cube's faces that border an empty cell; returns how many.
func _cube(st: SurfaceTool, c: Vector3i, m: int, src: PackedByteArray) -> int:
	var col: Color = COLORS[m]
	var shade := 0.9 + 0.1 * float(posmod(c.x * 7 + c.y * 13 + c.z * 3, 5)) / 4.0
	col = Color(col.r * shade, col.g * shade, col.b * shade)
	var faces := 0
	var s := 1.0 / grid.res
	var p := grid.origin + Vector3(c) * s
	for f: int in 6:
		var n: Vector3i = [
			Vector3i(-1, 0, 0), Vector3i(1, 0, 0), Vector3i(0, -1, 0),
			Vector3i(0, 1, 0), Vector3i(0, 0, -1), Vector3i(0, 0, 1)
		][f]
		var q := c + n
		if (
			q.x >= 0 and q.y >= 0 and q.z >= 0 and q.x < grid.w and q.y < grid.h and q.z < grid.d
			and src[grid.index(q.x, q.y, q.z)] != CarveGrid.EMPTY
		):
			continue
		faces += 1
		_quad(st, p, s, f, col)
	return faces


static func _quad(st: SurfaceTool, p: Vector3, s: float, f: int, col: Color) -> void:
	var corners: Array[Vector3] = []
	match f:
		0: corners = [Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0)]
		1: corners = [Vector3(1, 0, 1), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1)]
		2: corners = [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]
		3: corners = [Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0)]
		4: corners = [Vector3(1, 0, 0), Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0)]
		_: corners = [Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)]
	var normal := (corners[1] - corners[0]).cross(corners[2] - corners[0]).normalized()
	st.set_color(col)
	st.set_normal(normal)
	for k: int in [0, 2, 1, 0, 3, 2]:
		st.add_vertex(p + corners[k] * s)


## The brick's collider: the box round its remaining cells (none if empty).
func _rebrick(key: Vector3i) -> void:
	var lo := Vector3i(grid.w, grid.h, grid.d)
	var hi := Vector3i(-1, -1, -1)
	var b := key * grid.res
	for y: int in range(b.y, b.y + grid.res):
		for z: int in range(b.z, b.z + grid.res):
			for x: int in range(b.x, b.x + grid.res):
				if grid.cells[grid.index(x, y, z)] != CarveGrid.EMPTY:
					lo = lo.min(Vector3i(x, y, z))
					hi = hi.max(Vector3i(x, y, z))
	var shape: CollisionShape3D = _bricks.get(key)
	if hi.x < 0:
		if shape != null:
			shape.queue_free()
			_bricks.erase(key)
		return
	if shape == null:
		shape = CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		_static.add_child(shape)
		_bricks[key] = shape
	var s := 1.0 / grid.res
	var box: BoxShape3D = shape.shape
	box.size = Vector3(hi - lo + Vector3i.ONE) * s
	shape.position = grid.origin + (Vector3(lo) + Vector3(hi + Vector3i.ONE)) * 0.5 * s


func _debris_at(pos: Vector3, color: Color, push: Vector3) -> void:
	var body := RigidBody3D.new()
	body.gravity_scale = 2.2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = _box.size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	add_child(body)
	var spread := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.2, 1), _rng.randf_range(-1, 1))
	body.linear_velocity = push * 4.0 + spread * 3.0
	body.angular_velocity = Vector3(_rng.randf(), _rng.randf(), _rng.randf()) * 8.0
	_track(body, _box.size, color)


func _box_mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html(false)
	if not _box_mats.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.95
		_box_mats[key] = mat
	var out: StandardMaterial3D = _box_mats[key]
	return out


## An island as a Jolt body: its cells keep their materials; it is meshed and boxed per brick.
func _island(part: PackedInt32Array, mats: PackedByteArray, push: Vector3) -> void:
	var t0 := Time.get_ticks_usec()
	var com := Vector3.ZERO
	for i: int in part:
		com += grid.world(i)
	com /= part.size()
	var body := RigidBody3D.new()
	body.position = com
	body.set_meta("com", com)
	body.set_meta("part", part)
	body.set_meta("mats", mats)
	var all := PackedInt32Array()
	all.resize(part.size())
	for k: int in part.size():
		all[k] = k
	_build(body, all)
	add_child(body)
	body.angular_velocity = Vector3(push.z, 0, -push.x) * 0.5
	body.linear_velocity = push * 1.5
	_islands.append(body)
	mesh_us += Time.get_ticks_usec() - t0


## (Re)builds an island body's mesh and brick boxes from `keep` (indices into its part).
func _build(body: RigidBody3D, keep: PackedInt32Array) -> void:
	for child: Node in body.get_children():
		body.remove_child(child)
		child.queue_free()
	var part: PackedInt32Array = body.get_meta("part")
	var mats: PackedByteArray = body.get_meta("mats")
	var com: Vector3 = body.get_meta("com")
	var own := {}
	for k: int in keep:
		own[part[k]] = true
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bricks := {}  # brick -> PackedInt32Array of part indices
	for k: int in keep:
		var c := _cell(part[k])
		var key := c / grid.res
		if not bricks.has(key):
			bricks[key] = PackedInt32Array()
		var list: PackedInt32Array = bricks[key]
		list.append(k)
		bricks[key] = list
		_cube_own(st, c, own, com, mats[k])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat
	body.add_child(mi)
	for key: Vector3i in bricks:
		var span := _span(part, bricks[key])
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = span.size
		shape.shape = box
		shape.position = span.get_center() - com
		body.add_child(shape)
	body.mass = maxf(1.0, keep.size() * 0.05)
	body.set_meta("bricks", bricks)
	body.set_meta("keep", keep)


## World-space (at spawn) box round the given cells of a part.
func _span(part: PackedInt32Array, ks: PackedInt32Array) -> AABB:
	var lo := Vector3i(grid.w, grid.h, grid.d)
	var hi := Vector3i(-1, -1, -1)
	for k: int in ks:
		var c := _cell(part[k])
		lo = lo.min(c)
		hi = hi.max(c)
	var s := 1.0 / grid.res
	return AABB(grid.origin + Vector3(lo) * s, Vector3(hi - lo + Vector3i.ONE) * s)


func _cube_own(st: SurfaceTool, c: Vector3i, own: Dictionary, com: Vector3, m: int) -> void:
	var s := 1.0 / grid.res
	var p := grid.origin + Vector3(c) * s - com
	var col: Color = COLORS[m]
	var shade := 0.9 + 0.1 * float(posmod(c.x * 7 + c.y * 13 + c.z * 3, 5)) / 4.0
	col = Color(col.r * shade, col.g * shade, col.b * shade)
	for f: int in 6:
		var n: Vector3i = [
			Vector3i(-1, 0, 0), Vector3i(1, 0, 0), Vector3i(0, -1, 0),
			Vector3i(0, 1, 0), Vector3i(0, 0, -1), Vector3i(0, 0, 1)
		][f]
		var q := c + n
		if own.has(grid.index(q.x, q.y, q.z)) and q.x >= 0 and q.x < grid.w and q.z >= 0 and q.z < grid.d:
			continue
		_quad(st, p, s, f, col)


## The island hit hard: the bricks within BREAK_DEPTH of its lowest point break off as rubble
## (half-brick pieces round their own cells, in their own material); the rest stays one body,
## keeps falling and breaks again on its next hard hit. Small remainders break up whole.
func _break_low(body: RigidBody3D, v: Vector3) -> void:
	var part: PackedInt32Array = body.get_meta("part")
	var mats: PackedByteArray = body.get_meta("mats")
	var com: Vector3 = body.get_meta("com")
	var bricks: Dictionary = body.get_meta("bricks")
	var xf := body.global_transform
	var low := INF
	var mid_y := {}
	for key: Vector3i in bricks:
		var y := (xf * (_span(part, bricks[key]).get_center() - com)).y
		mid_y[key] = y
		low = minf(low, y)
	var keep := PackedInt32Array()
	var broken: Array[Vector3i] = []
	for key: Vector3i in bricks:
		if mid_y[key] < low + BREAK_DEPTH or bricks.size() < 12:
			broken.append(key)
		else:
			keep.append_array(bricks[key])
	var half := maxi(1, grid.res / 2)
	for key: Vector3i in broken:
		var pieces := {}
		for k: int in (bricks[key] as PackedInt32Array):
			var sub := _cell(part[k]) / half
			if not pieces.has(sub):
				pieces[sub] = PackedInt32Array()
			var list: PackedInt32Array = pieces[sub]
			list.append(k)
			pieces[sub] = list
		for sub: Vector3i in pieces:
			var ks: PackedInt32Array = pieces[sub]
			var span := _span(part, ks)
			_rubble(xf * (span.get_center() - com), xf.basis, span.size, COLORS[mats[ks[0]]], v)
	if keep.is_empty():
		_islands.erase(body)
		body.queue_free()
		return
	_build(body, keep)
	body.set_meta("v", Vector3.ZERO)


func _rubble(at: Vector3, basis: Basis, size: Vector3, color: Color, v: Vector3) -> void:
	var piece := RigidBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size.max(Vector3.ONE * 0.1) * 0.95
	shape.shape = box
	piece.add_child(shape)
	piece.transform = Transform3D(basis, at)
	piece.gravity_scale = 1.5
	piece.mass = maxf(0.1, box.size.x * box.size.y * box.size.z)
	add_child(piece)
	var spread := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0, 1), _rng.randf_range(-1, 1))
	piece.linear_velocity = v * 0.4 + spread * 2.5
	piece.angular_velocity = spread * 3.0
	_track(piece, box.size, color)
