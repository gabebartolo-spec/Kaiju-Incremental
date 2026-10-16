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


func _c(key: String) -> Color:
	return _colors.get(key, Color.MAGENTA)


func _fill(from: Vector3i, to: Vector3i, key: String) -> void:
	for x: int in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
		for y: int in range(mini(from.y, to.y), maxi(from.y, to.y) + 1):
			for z: int in range(mini(from.z, to.z), maxi(from.z, to.z) + 1):
				_cells[Vector3i(x, y, z)] = key


func _reptilian() -> void:
	_fill(Vector3i(-1, 0, -1), Vector3i(-3, 4, 1), "body")  # left leg
	_fill(Vector3i(1, 0, -1), Vector3i(3, 4, 1), "body")  # right leg
	_fill(Vector3i(-3, 0, -2), Vector3i(-1, 0, -2), "accent")  # toes
	_fill(Vector3i(1, 0, -2), Vector3i(3, 0, -2), "accent")
	_fill(Vector3i(-3, 4, -3), Vector3i(3, 9, 3), "body")  # torso
	_fill(Vector3i(-2, 4, -4), Vector3i(2, 8, -4), "belly")
	_fill(Vector3i(-2, 9, -3), Vector3i(2, 11, 0), "body")  # neck
	_fill(Vector3i(-2, 10, -8), Vector3i(2, 13, -3), "body")  # head
	_fill(Vector3i(-2, 9, -8), Vector3i(2, 9, -4), "belly")  # jaw
	_fill(Vector3i(-3, 12, -6), Vector3i(-3, 12, -6), "eye")
	_fill(Vector3i(3, 12, -6), Vector3i(3, 12, -6), "eye")
	_fill(Vector3i(-4, 7, -4), Vector3i(-4, 8, -5), "body")  # arms
	_fill(Vector3i(4, 7, -4), Vector3i(4, 8, -5), "body")
	for i: int in 7:  # tail
		var w := maxi(0, 2 - Num.i(i / 2.5))
		_fill(
			Vector3i(-w, 4 - Num.i(i / 2.0), 4 + i * 2),
			Vector3i(w, 6 - Num.i(i / 2.0), 5 + i * 2),
			"body"
		)
	for z: int in range(-2, 9, 2):  # back spikes
		_fill(Vector3i(0, 10, z), Vector3i(0, 11, z), "accent")
	_fill(Vector3i(0, 14, -5), Vector3i(0, 14, -3), "accent")


func _insectoid() -> void:
	_fill(Vector3i(-3, 3, 1), Vector3i(3, 7, 9), "body")  # abdomen
	_fill(Vector3i(-2, 8, 2), Vector3i(2, 8, 8), "accent")
	for z: int in [3, 5, 7]:
		_fill(Vector3i(-3, 7, z), Vector3i(3, 7, z), "belly")  # stripes
	_fill(Vector3i(-2, 3, -3), Vector3i(2, 7, 0), "body")  # thorax
	_fill(Vector3i(-2, 4, -7), Vector3i(2, 7, -4), "body")  # head
	_fill(Vector3i(-3, 6, -7), Vector3i(-3, 7, -6), "eye")
	_fill(Vector3i(3, 6, -7), Vector3i(3, 7, -6), "eye")
	_fill(Vector3i(-2, 4, -9), Vector3i(-2, 4, -8), "belly")  # mandibles
	_fill(Vector3i(2, 4, -9), Vector3i(2, 4, -8), "belly")
	_fill(Vector3i(-1, 8, -6), Vector3i(-2, 10, -7), "accent")  # antennae
	_fill(Vector3i(1, 8, -6), Vector3i(2, 10, -7), "accent")
	for z: int in [-3, -1, 1]:  # six legs
		for side: int in [-1, 1]:
			_fill(Vector3i(side * 3, 5, z), Vector3i(side * 6, 5, z), "accent")
			_fill(Vector3i(side * 6, 0, z), Vector3i(side * 6, 5, z), "accent")


func _cephalopod() -> void:
	_fill(Vector3i(-3, 4, -2), Vector3i(3, 10, 3), "body")  # mantle
	_fill(Vector3i(-2, 11, -1), Vector3i(2, 13, 3), "body")
	_fill(Vector3i(-1, 14, 0), Vector3i(1, 14, 3), "accent")
	_fill(Vector3i(-2, 4, -3), Vector3i(2, 5, -3), "belly")
	_fill(Vector3i(-3, 7, -3), Vector3i(-2, 8, -3), "eye")
	_fill(Vector3i(2, 7, -3), Vector3i(3, 8, -3), "eye")
	for i: int in 8:  # tentacles
		var angle := TAU * i / 8.0
		var dir := Vector2(sin(angle), -cos(angle))
		for step: int in range(4, 19):
			var p := dir * step * 0.5
			var y := maxi(0, 4 - Num.i(step / 3.0))
			var key := "belly" if step % 5 == 0 else "body"
			_cells[Vector3i(roundi(p.x), y, roundi(p.y))] = key
			if step < 12:
				_cells[Vector3i(roundi(p.x), y + 1, roundi(p.y))] = "body"


## One MultiMesh for the whole body: every cell a slightly inset cube with its colour.
func _build() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * VOXEL * 0.94
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.85
	mesh.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = _cells.size()
	var i := 0
	for cell: Vector3i in _cells:
		var key: String = _cells[cell]
		mm.set_instance_transform(
			i, Transform3D(Basis(), Vector3(cell) * VOXEL + Vector3(0, VOXEL * 0.5, 0))
		)
		mm.set_instance_color(i, _c(key))
		i += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	_body.add_child(mmi)
	# Eyes glow: a second, emissive pass over the eye cells.
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = _c("eye")
	eye_mat.emission_enabled = true
	eye_mat.emission = _c("eye")
	eye_mat.emission_energy_multiplier = 2.5
	for cell: Vector3i in _cells:
		if _cells[cell] == "eye":
			var eye := MeshInstance3D.new()
			var eye_mesh := BoxMesh.new()
			eye_mesh.size = Vector3.ONE * VOXEL * 0.98
			eye.mesh = eye_mesh
			eye.material_override = eye_mat
			eye.position = Vector3(cell) * VOXEL + Vector3(0, VOXEL * 0.5, 0)
			_body.add_child(eye)
