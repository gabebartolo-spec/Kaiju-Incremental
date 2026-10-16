class_name KaijuModel
extends Node3D
## A species' kaiju built from voxels (data colours, code shapes). Faces -Z. About 7 units
## tall at body scale 1. Animation is presentation only: bob while walking, squash on stomp.

const VOXEL := 0.6

var species_id: String
var _colors: Dictionary = {}
var _cells: Dictionary = {}
var _body: Node3D
var _walk_phase := 0.0
var _squash := 0.0


func _init(p_species_id: String, colors: Dictionary) -> void:
	species_id = p_species_id
	for key: String in colors:
		_colors[key] = Color(str(colors[key]))
	_body = Node3D.new()
	add_child(_body)
	match species_id:
		"insectoid":
			_insectoid()
		"cephalopod":
			_cephalopod()
		_:
			_reptilian()
	_build()


## moving: 0..1 how hard the kaiju is walking this frame.
func animate(delta: float, moving: float) -> void:
	_walk_phase += delta * (2.0 + 8.0 * moving)
	_squash = maxf(0.0, _squash - delta * 5.0)
	var bob := absf(sin(_walk_phase)) * 0.25 * moving
	_body.position.y = bob
	_body.rotation.z = sin(_walk_phase) * 0.06 * moving
	_body.scale = Vector3(1.0 + _squash * 0.12, 1.0 - _squash * 0.15, 1.0 + _squash * 0.12)


func stomp() -> void:
	_squash = 1.0


## Species colour, lifted by the look so the kaiju reads against its city (night).
func _c(key: String) -> Color:
	var base: Color = _colors.get(key, Color.MAGENTA)
	var lift := Look.value("kaiju_lift")
	if lift <= 0.0 or key == "accent" or key == "eye":
		return base
	return base.lightened(lift)


func _fill(from: Vector3i, to: Vector3i, key: String) -> void:
	for x: int in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
		for y: int in range(mini(from.y, to.y), maxi(from.y, to.y) + 1):
			for z: int in range(mini(from.z, to.z), maxi(from.z, to.z) + 1):
				_cells[Vector3i(x, y, z)] = key


## A one-voxel-thick line from `a` to `b` (cells), sampled finely so it stays face-connected.
func _line(a: Vector3, b: Vector3, key: String) -> void:
	var steps := ceili(a.distance_to(b) * 6.0) + 1
	var last := Vector3i(roundi(a.x), roundi(a.y), roundi(a.z))
	for i: int in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		var cell := Vector3i(roundi(p.x), roundi(p.y), roundi(p.z))
		# Step one axis at a time so neighbours share a face, never just an edge or corner.
		var walk := last
		for axis: int in 3:
			if walk[axis] != cell[axis]:
				walk[axis] = cell[axis]
				_cells[walk] = key
		_cells[cell] = key
		last = cell


## Fills every cell inside the ellipsoid at `centre` with half-axes `radii` (cells).
func _blob(centre: Vector3, radii: Vector3, key: String) -> void:
	var lo := Vector3i((centre - radii).floor())
	var hi := Vector3i((centre + radii).ceil())
	for x: int in range(lo.x, hi.x + 1):
		for y: int in range(lo.y, hi.y + 1):
			for z: int in range(lo.z, hi.z + 1):
				var d := (Vector3(x, y, z) - centre) / radii
				if d.length_squared() <= 1.0:
					_cells[Vector3i(x, y, z)] = key


func _reptilian() -> void:
	for side: int in [-1, 1]:
		_blob(Vector3(side * 2.8, 3.0, 0.0), Vector3(1.7, 3.2, 1.9), "body")  # thighs
		_fill(Vector3i(side * 3, 0, -2), Vector3i(side * 1, 0, -2), "accent")  # toes
		_line(Vector3(side * 3, 11, -1), Vector3(side * 4, 9, -3), "body")  # upper arm
		_line(Vector3(side * 4, 9, -3), Vector3(side * 4, 8, -5), "body")  # forearm
		_cells[Vector3i(side * 4, 7, -5)] = "accent"  # claws
		_cells[Vector3i(side * 4, 8, -6)] = "accent"
	_blob(Vector3(0, 8.5, 0.5), Vector3(3.4, 5.0, 3.2), "body")  # torso
	_blob(Vector3(0, 8.0, -2.2), Vector3(2.3, 3.8, 1.0), "belly")
	_blob(Vector3(0, 14.0, -1.5), Vector3(1.8, 2.0, 1.8), "body")  # neck
	_blob(Vector3(0, 15.5, -4.5), Vector3(2.0, 1.8, 3.0), "body")  # head
	_fill(Vector3i(-1, 13, -7), Vector3i(1, 14, -3), "belly")  # jaw
	_fill(Vector3i(-2, 16, -6), Vector3i(-2, 16, -6), "eye")
	_fill(Vector3i(2, 16, -6), Vector3i(2, 16, -6), "eye")
	for i: int in 7:  # tail, sweeping down to the ground
		var r := 2.4 - i * 0.22
		_blob(Vector3(0, maxf(r, 5.0 - i * 0.6), 4.0 + i * 1.6), Vector3(r, r, 1.2), "body")
	for z: int in range(0, 15, 2):  # dorsal plates, rooted on the top of the spine
		var top := _top(0, z)
		if top < 0:
			continue
		var tall := 2 if z < 2 else (3 if z < 6 else (2 if z < 10 else 1))
		_fill(Vector3i(0, top + 1, z), Vector3i(0, top + tall, z), "accent")


## A cell with all six neighbours filled can never be seen; drawing it shows through the gaps.
func _buried(cell: Vector3i) -> bool:
	for d: Vector3i in [
		Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK
	]:
		if not _cells.has(cell + d):
			return false
	return true


## Highest filled cell in the column (x, z), or -1.
func _top(x: int, z: int) -> int:
	var best := -1
	for cell: Vector3i in _cells:
		if cell.x == x and cell.z == z and _cells[cell] != "accent":
			best = maxi(best, cell.y)
	return best


func _insectoid() -> void:
	_blob(Vector3(0, 4.5, 6.0), Vector3(2.8, 2.4, 3.8), "body")  # abdomen
	for z: int in [4, 6, 8]:
		_fill(Vector3i(-2, 6, z), Vector3i(2, 6, z), "belly")  # stripes
	_blob(Vector3(0, 5.0, 0.5), Vector3(1.5, 1.6, 2.0), "body")  # thorax
	_blob(Vector3(0, 5.5, -1.5), Vector3(1.0, 1.0, 1.0), "body")  # neck
	_blob(Vector3(0, 6.0, -4.2), Vector3(2.3, 2.0, 2.0), "belly")  # head: its own colour, ahead
	for side: int in [-1, 1]:
		_fill(Vector3i(side * 2, 6, -5), Vector3i(side * 2, 7, -5), "eye")  # eyes at the front
		_line(Vector3(side * 2, 5, -6), Vector3(side, 5, -8), "accent")  # mandibles, held forward
		_line(Vector3(side, 8, -5), Vector3(side * 3, 12, -8), "accent")  # antennae
		for leg: int in 3:  # six legs: up to a high knee, splayed out and down to the ground
			var hip := Vector3(side, 5, -0.5 + leg)
			var knee := Vector3(side * 5, 8, -2.0 + leg * 2.5)
			var foot := Vector3(side * 8, 0, -4.0 + leg * 4.0)
			_line(hip, knee, "accent")
			_line(knee, foot, "accent")


func _cephalopod() -> void:
	_blob(Vector3(0, 10.0, 1.0), Vector3(3.6, 5.5, 3.6), "body")  # mantle
	_blob(Vector3(0, 5.5, 0.0), Vector3(2.8, 1.8, 2.8), "body")  # head under the mantle
	for side: int in [-1, 1]:  # eyes set into the sides of the head
		_fill(Vector3i(side * 3, 6, -1), Vector3i(side * 3, 6, 0), "eye")
	for i: int in 8:  # tentacles: thick at the head, tapering over the ground
		var angle := TAU * i / 8.0 + 0.2
		var dir := Vector3(sin(angle), 0, -cos(angle))
		var root := dir * 2.0 + Vector3(0, 4, 0)
		var bend := dir * 6.0 + Vector3(0, 1, 0)
		var tip := dir * 10.0 + dir.cross(Vector3.UP) * 1.5
		_line(root, bend, "body")
		_line(root + Vector3(0, 1, 0), bend + Vector3(0, 1, 0), "body")
		_line(bend, tip, "body")
		_cells[Vector3i(roundi(tip.x), 0, roundi(tip.z))] = "accent"


## One MultiMesh for the whole body: every cell a cube with its colour. Eyes always glow; the
## accent (spines, stripes) glows when the look says so.
func _build() -> void:
	var accent_glow := Look.value("accent_glow")
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = Look.voxel_mesh(VOXEL, maxf(1.5, accent_glow))
	var shell: Array[Vector3i] = []
	for cell: Vector3i in _cells:
		if not _buried(cell):
			shell.append(cell)
	mm.instance_count = shell.size()
	var i := 0
	for cell: Vector3i in shell:
		var key: String = _cells[cell]
		var color := Look.jitter(_c(key), cell, 7)
		if key == "eye" or (key == "accent" and accent_glow > 0.0):
			color.a = 0.0
		var pos := Vector3(cell) * VOXEL + Vector3(0, VOXEL * 0.5, 0)
		mm.set_instance_transform(i, Transform3D(Basis(), pos))
		mm.set_instance_color(i, color)
		i += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	_body.add_child(mmi)
