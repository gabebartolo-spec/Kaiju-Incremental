class_name VoxelBuilder
extends RefCounted
## Collects voxel cells (integer grid -> palette key) with shape helpers, then builds one
## MultiMesh, cells ordered bottom-up so a smaller visible_instance_count removes the top.
## Buried cells (all six neighbours filled) are skipped: they can never be seen and would
## show through the gaps between voxels.

const DIRECT := "#"
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


## Instances needed to show every cell with y below `y` (cells are drawn bottom-up).
func count_below(y: int) -> int:
	return sorted_y.bsearch(y, true)


## One MultiMesh for every visible cell. palette: key -> Color (alpha 0 = glows at `glow`).
## A cell's centre sits at origin + cell * voxel, lifted half a voxel so y = 0 rests on the ground.
func build(palette: Dictionary, voxel: float, glow: float, origin: Vector3) -> MultiMeshInstance3D:
	var shown: Array[Vector3i] = []
	for cell: Vector3i in cells:
		if not buried(cell):
			shown.append(cell)
	shown.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return a.y < b.y)
	sorted_y = PackedInt32Array()
	sorted_y.resize(shown.size())
	built_cells = shown
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = Look.voxel_mesh(voxel, glow)
	mm.instance_count = shown.size()
	var lift := Vector3(0, voxel * 0.5, 0)
	for i: int in shown.size():
		var cell := shown[i]
		sorted_y[i] = cell.y
		var key: String = cells[cell]
		var base: Color = colors[cell] if key == DIRECT else palette.get(key, Color.MAGENTA)
		mm.set_instance_transform(i, Transform3D(Basis(), origin + Vector3(cell) * voxel + lift))
		mm.set_instance_color(i, Look.jitter(base, cell, salt))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	return mmi


## One merged mesh (vertex colours, hidden faces culled) for a small model that moves as a
## whole: people and moving cars. palette as build(); `origin` offsets every cell.
func bake(palette: Dictionary, voxel: float, origin: Vector3, glow: float) -> ArrayMesh:
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
	var mesh := st.commit()
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
