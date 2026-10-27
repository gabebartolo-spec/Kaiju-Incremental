class_name VoxelBuilder
extends RefCounted
## Collects voxel cells (integer grid -> palette key) with shape helpers, then builds one
## MultiMesh, cells ordered bottom-up so a smaller visible_instance_count removes the top.
## Buried cells (all six neighbours filled) are skipped: they can never be seen and would
## show through the gaps between voxels.

const DIRECT := "#"
## Floats per instance in pack()'s MultiMesh buffer: a 3x4 transform, then the colour.
const STRIDE := 16
## pack()'s stride with `detail` on: the colour is followed by the cell's grid index (custom data).
const DETAIL_STRIDE := 20
const NEIGHBOURS: Array[Vector3i] = [
	Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK
]

var cells: Dictionary = {}
## Per-cell colours for cells keyed DIRECT (models voxelized from a texture).
var colors: Dictionary = {}
## Per-cell flags from a .kvox (e.g. the bone a voxel belongs to).
var flags: Dictionary = {}
## Model height in cells when loaded from a .kvox (0 otherwise).
var height_hint := 0
## Seeds the per-cell colour jitter so neighbouring models do not repeat.
var salt := 0
## Each built instance's cell y, ascending (filled by build()).
var sorted_y: PackedInt32Array = PackedInt32Array()
## The cell behind each built instance, in instance order (filled by build()).
var built_cells: Array[Vector3i] = []
## Drawn size of each cube as a share of a cell (build()).
var inset := 1.0
## Whether build() adds the look's per-cell colour noise (off for a smooth painted surface).
var noise := true
## Whether build() draws the cells in the city's surface family (Look.voxel_detail_mesh), each
## instance carrying its cell's grid index in its custom data so the detail rides with the model.
var detail := false


func put(cell: Vector3i, key: String) -> void:
	cells[cell] = key


func put_color(cell: Vector3i, color: Color) -> void:
	cells[cell] = DIRECT
	colors[cell] = color


func has(cell: Vector3i) -> bool:
	return cells.has(cell)


func key_at(cell: Vector3i) -> String:
	return str(cells.get(cell, ""))


func box(a: Vector3i, b: Vector3i, key: String) -> void:
	for x: int in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
		for y: int in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
			for z: int in range(mini(a.z, b.z), maxi(a.z, b.z) + 1):
				cells[Vector3i(x, y, z)] = key


## Every cell inside the ellipsoid at `centre` with half-axes `radii`.
func blob(centre: Vector3, radii: Vector3, key: String) -> void:
	var lo := Vector3i((centre - radii).floor())
	var hi := Vector3i((centre + radii).ceil())
	for x: int in range(lo.x, hi.x + 1):
		for y: int in range(lo.y, hi.y + 1):
			for z: int in range(lo.z, hi.z + 1):
				if ((Vector3(x, y, z) - centre) / radii).length_squared() <= 1.0:
					cells[Vector3i(x, y, z)] = key


## A tapered tube from `a` (radius ra) to `b` (radius rb): spheres swept along the line.
## Radius under 0.6 draws a face-connected one-cell line.
## radii: (radius at a, radius at b).
func tube(a: Vector3, b: Vector3, radii: Vector2, key: String) -> void:
	var steps := maxi(1, ceili(a.distance_to(b) * 2.0))
	var last := Vector3i(a.round())
	for i: int in steps + 1:
		var t := float(i) / steps
		var p := a.lerp(b, t)
		var r := lerpf(radii.x, radii.y, t)
		if r < 0.6:
			var cell := Vector3i(p.round())
			var walk := last
			for axis: int in 3:
				if walk[axis] != cell[axis]:
					walk[axis] = cell[axis]
					cells[walk] = key
			cells[cell] = key
			last = cell
		else:
			blob(p, Vector3.ONE * r, key)
			last = Vector3i(p.round())


## A tube through several points with radii given per point.
func chain(points: Array[Vector3], radii: Array[float], key: String) -> void:
	for i: int in points.size() - 1:
		tube(points[i], points[i + 1], Vector2(radii[i], radii[i + 1]), key)


func buried(cell: Vector3i) -> bool:
	for d: Vector3i in NEIGHBOURS:
		if not cells.has(cell + d):
			return false
	return true


## Highest cell in column (x, z) whose key is not in `skip`, or -1000.
func top(x: int, z: int, skip: Array[String] = []) -> int:
	var best := -1000
	for cell: Vector3i in cells:
		if cell.x == x and cell.z == z and not skip.has(str(cells[cell])):
			best = maxi(best, cell.y)
	return best


## Re-keys cells: fn(cell, key) returns the new key (or the same).
func repaint(fn: Callable) -> void:
	for cell: Vector3i in cells.keys():
		var key: String = cells[cell]
		var next: String = fn.call(cell, key)
		cells[cell] = next


## One MultiMesh for every visible cell. palette: key -> Color (alpha 0 = glows at `glow`).
## A cell's centre sits at origin + cell * voxel, lifted half a voxel so y = 0 rests on the ground.
## Cubes are drawn at `inset` of their size (below 1: a filler layer that hides inside a skin).
## Main thread only: a worker calls pack() and hands the buffer to instance() on the main thread.
func build(palette: Dictionary, voxel: float, glow: float, origin: Vector3) -> MultiMeshInstance3D:
	return instance(pack(palette, voxel, origin), voxel, glow, detail)


## build()'s instances as plain data: the MultiMesh buffer (STRIDE floats each: the 3x4
## transform row by row, then the colour; DETAIL_STRIDE with `detail`, then the cell index),
## cells bottom-up; fills sorted_y and built_cells.
## Makes no resource, so it is safe on a worker thread.
func pack(palette: Dictionary, voxel: float, origin: Vector3) -> PackedFloat32Array:
	var shown: Array[Vector3i] = []
	for cell: Vector3i in cells:
		if not buried(cell):
			shown.append(cell)
	shown.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return a.y < b.y)
	sorted_y = PackedInt32Array()
	sorted_y.resize(shown.size())
	built_cells = shown
	var stride := DETAIL_STRIDE if detail else STRIDE
	var buf := PackedFloat32Array()
	buf.resize(shown.size() * stride)  # zeroed: the transform's off-diagonal stays 0
	var lift := Vector3(0, voxel * 0.5, 0)
	for i: int in shown.size():
		var cell := shown[i]
		sorted_y[i] = cell.y
		var key: String = cells[cell]
		var base: Color = colors[cell] if key == DIRECT else palette.get(key, Color.MAGENTA)
		var at := origin + Vector3(cell) * voxel + lift
		var c: Color = Look.jitter(base, cell, salt) if noise else base
		var k := i * stride
		buf[k] = inset
		buf[k + 3] = at.x
		buf[k + 5] = inset
		buf[k + 7] = at.y
		buf[k + 10] = inset
		buf[k + 11] = at.z
		buf[k + 12] = c.r
		buf[k + 13] = c.g
		buf[k + 14] = c.b
		buf[k + 15] = c.a
		if detail:
			buf[k + 16] = cell.x
			buf[k + 17] = cell.y
			buf[k + 18] = cell.z
	return buf


## The drawn cubes (`voxel` wide, glowing at `glow`) of a pack()ed buffer. Main thread only.
## detail: the buffer was packed with `detail` on (DETAIL_STRIDE); the cells draw in the
## city's surface family.
static func instance(
	buf: PackedFloat32Array, voxel: float, glow: float, detail := false
) -> MultiMeshInstance3D:
	ThreadCheck.main_only("VoxelBuilder.instance")
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = detail
	mm.mesh = Look.voxel_detail_mesh(voxel, glow) if detail else Look.voxel_mesh(voxel, glow)
	mm.instance_count = floori(buf.size() / float(DETAIL_STRIDE if detail else STRIDE))
	if mm.instance_count > 0:
		mm.buffer = buf
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	return mmi


## One merged mesh (vertex colours, hidden faces culled) for a small model that moves as a
## whole: people and moving cars. palette as build(); `origin` offsets every cell. Main thread
## only: a worker calls bake_arrays() and hands them to baked() on the main thread.
func bake(palette: Dictionary, voxel: float, origin: Vector3, glow: float) -> ArrayMesh:
	return baked(bake_arrays(palette, voxel, origin), glow)


## bake()'s surface arrays ([] when there are no cells). Makes no resource: safe on a worker.
func bake_arrays(palette: Dictionary, voxel: float, origin: Vector3) -> Array:
	if cells.is_empty():
		return []
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lift := Vector3(0, voxel * 0.5, 0)
	for cell: Vector3i in cells:
		var key: String = cells[cell]
		var base: Color = colors[cell] if key == DIRECT else palette.get(key, Color.MAGENTA)
		st.set_color(Look.jitter(base, cell, salt))
		var centre := origin + Vector3(cell) * voxel + lift
		for d: Vector3i in NEIGHBOURS:
			if not cells.has(cell + d):
				_face(st, centre, Vector3(d), voxel * 0.5)
	return st.commit_to_arrays()


## The mesh of bake_arrays() output, in the voxel material glowing at `glow`. Main thread only.
static func baked(arrays: Array, glow: float) -> ArrayMesh:
	ThreadCheck.main_only("VoxelBuilder.baked")
	var mesh := ArrayMesh.new()
	if arrays.is_empty():
		return mesh
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, Look.voxel_material(glow))
	return mesh


## One cube face, wound clockwise as seen from outside (Godot's front face).
static func _face(st: SurfaceTool, centre: Vector3, n: Vector3, half: float) -> void:
	var a := Vector3.UP if absf(n.y) < 0.5 else Vector3.RIGHT
	var u := a.cross(n) * half
	var v := n.cross(u.normalized()) * half
	var c := centre + n * half
	var quad: Array[Vector3] = [c - u - v, c + u - v, c + u + v, c - u + v]
	st.set_normal(n)
	for i: int in [0, 2, 1, 0, 3, 2]:
		st.add_vertex(quad[i])
