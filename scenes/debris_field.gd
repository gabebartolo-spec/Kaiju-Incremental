class_name DebrisField
extends Node3D
## Physics debris: real rigid fragments thrown from breaking floors and landing towers, mostly
## small, in the building's own colours; they fall heavily, settle on the street, then crumble.
## Meshes and materials are shared by size and colour. Oldest pieces go first past the cap.

var _rng: RandomNumberGenerator
var _cap: int
var _bodies: Array[RigidBody3D] = []
var _meshes: Dictionary = {}
var _materials: Dictionary = {}


func _init(rng: RandomNumberGenerator, cap: int) -> void:
	_rng = rng
	_cap = cap


func _process(_delta: float) -> void:
	while _bodies.size() > _cap:
		var old: RigidBody3D = _bodies.pop_front()
		old.queue_free()


## A real physics fragment: mostly small, in the building's own colours, thrown out and
## falling heavily to settle on the street, then crumbling away.
func spawn(pos: Vector3, color: Color, away: Vector3) -> void:
	var size := BuildingVoxels.VOXEL * (_rng.randf_range(0.35, 0.8) if _rng.randf() < 0.8 else 1.0)
	var body := RigidBody3D.new()
	body.gravity_scale = 1.6
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3.ONE * size
	shape.shape = box_shape
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(size)
	mi.material_override = _material(Color(color, 1.0).lightened(Look.value("debris_lift")))
	body.add_child(mi)
	body.position = pos
	add_child(body)
	var spread := Vector3(
		_rng.randf_range(-1, 1), _rng.randf_range(0.1, 0.7), _rng.randf_range(-1, 1)
	)
	body.apply_central_impulse((away * 2.5 + spread * 2.5) * body.mass)
	body.angular_velocity = Vector3(
		_rng.randf_range(-6, 6), _rng.randf_range(-6, 6), _rng.randf_range(-6, 6)
	)
	_bodies.append(body)
	var tween := mi.create_tween()
	tween.tween_interval(_rng.randf_range(5.0, 8.0))
	tween.tween_property(mi, "scale", Vector3.ONE * 0.01, 0.8)
	tween.tween_callback(func() -> void: _forget(body))


func _mesh(size: float) -> BoxMesh:
	var key := snappedf(size, 0.02)
	if not _meshes.has(key):
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * key * 0.95
		_meshes[key] = mesh
	var out: BoxMesh = _meshes[key]
	return out


func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html(false)
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.95
		_materials[key] = mat
	var out: StandardMaterial3D = _materials[key]
	return out


func _forget(body: RigidBody3D) -> void:
	_bodies.erase(body)
	body.queue_free()
