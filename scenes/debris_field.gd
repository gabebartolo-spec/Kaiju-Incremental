class_name DebrisField
extends Node3D
## Physics debris: real rigid fragments thrown from breaking floors and landing towers, mostly
## small, in the building's own colours; they fall heavily, settle on the street, then crumble.
## Meshes and materials are shared by size and colour. Oldest pieces go first past the cap.

const SPAWN_PER_FRAME := 30

var size_scale := 1.0  # pieces are this many times the building's size (trees: bigger, to read)
var lift := -1.0  # toward white before shading; below 0, the look's debris_lift
var shadows := true  # whether the pieces cast shadows

var _rng: RandomNumberGenerator
var _queue: Array[Array] = []
var _head := 0  # _queue[_head:] are pending; the oldest are dropped past _cap
var _cap: int
var _bodies: Array[RigidBody3D] = []
var _meshes: Dictionary = {}
var _materials: Dictionary = {}


func _init(rng: RandomNumberGenerator, cap: int) -> void:
	_rng = rng
	_cap = cap


func _process(_delta: float) -> void:
	for _n: int in mini(SPAWN_PER_FRAME, pending()):
		var item: Array = _queue[_head]
		_head += 1
		var pos: Vector3 = item[0]
		var color: Color = item[1]
		var away: Vector3 = item[2]
		var big: float = item[3]
		_spawn_now(pos, color, away, big)
	if pending() > _cap:  # what is left over the cap is dropped, oldest first
		_head = _queue.size() - _cap
	_compact()
	while _bodies.size() > _cap:
		var old: RigidBody3D = _bodies.pop_front()
		old.queue_free()


## A real physics fragment: mostly small, in the building's own colours, thrown out and
## falling heavily to settle on the street, then crumbling away.
## Queues a fragment; at most SPAWN_PER_FRAME are created each frame so a big collapse never
## stalls a frame.
## Past the cap and one frame's worth the oldest queued fragment is dropped as a new one comes
## (b2-3: a heavy swipe queued 4000+ in one frame); the same count is thrown each frame as when
## the queue was trimmed only after throwing, so the shared fx random stream is unchanged.
func spawn(pos: Vector3, color: Color, away: Vector3, big := 1.0) -> void:
	_queue.append([pos, color, away, big])
	if pending() > _cap + SPAWN_PER_FRAME:
		_head += 1
	if _head >= _cap:
		_compact()


## Fragments queued and not yet thrown (never more than the cap and one frame's worth).
func pending() -> int:
	return _queue.size() - _head


func _compact() -> void:
	if _head > 0:
		_queue = _queue.slice(_head)
		_head = 0


## A fragment of exactly `size` now (a band bursting into its cubes), past the queue.
func cube(pos: Vector3, color: Color, away: Vector3, size: float) -> void:
	_spawn_now(pos, color, away, 1.0, size)
	while _bodies.size() > _cap:
		var old: RigidBody3D = _bodies.pop_front()
		old.queue_free()


func _spawn_now(pos: Vector3, color: Color, away: Vector3, big := 1.0, fixed := 0.0) -> void:
	var size := BuildingVoxels.VOXEL * (_rng.randf_range(0.35, 0.8) if _rng.randf() < 0.8 else 1.0)
	size *= size_scale * big
	if fixed > 0.0:
		size = fixed
	var body := RigidBody3D.new()
	body.gravity_scale = 2.2
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3.ONE * size
	shape.shape = box_shape
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(size)
	var whiten := lift if lift >= 0.0 else Look.value("debris_lift")
	mi.material_override = _material(Color(color, 1.0).lightened(whiten))
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
