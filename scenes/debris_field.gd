class_name DebrisField
extends Node3D
## Physics debris: real rigid fragments thrown from breaking floors and landing towers, mostly
## small, in the building's own colours; they fall heavily, settle on the street, then crumble.
## Pieces are drawn by one MultiMesh per size (the colour rides on each instance), so a big
## collapse costs a few draw calls, not one per piece. Oldest pieces go first past the cap.

const SPAWN_PER_FRAME := 30
const SHRINK_SECONDS := 0.8  # a piece shrinks away over this long once its time is up
const SHRINK_MIN := 0.01  # a shrinking piece's last scale

var size_scale := 1.0  # pieces are this many times the building's size (trees: bigger, to read)
var lift := -1.0  # toward white before shading; below 0, the look's debris_lift
var shadows := true  # whether the pieces cast shadows

var _rng: RandomNumberGenerator
var _queue: Array[Array] = []
var _head := 0  # _queue[_head:] are pending; the oldest are dropped past _cap
var _cap: int
var _bodies: Array[RigidBody3D] = []
var _views := PackedInt32Array()  # which MultiMesh (in _meshes) draws each piece
var _colors := PackedColorArray()  # each piece's sRGB colour
var _ends := PackedFloat32Array()  # when each piece starts to shrink (seconds on _clock)
var _clock := 0.0
var _sizes: Dictionary = {}  # snapped size -> its index in _meshes
var _meshes: Array[MultiMesh] = []  # one per piece size
## Each mesh's instance data as last drawn (CarveRubble.pack layout; a test reads it).
var _bufs: Array[PackedFloat32Array] = []
var _material: ShaderMaterial


func _init(rng: RandomNumberGenerator, cap: int) -> void:
	_rng = rng
	_cap = cap


func _process(delta: float) -> void:
	_clock += delta
	for _n: int in mini(SPAWN_PER_FRAME, pending()):
		var item: Array = _queue[_head]
		_head += 1
		var pos: Vector3 = item[0]
		var color: Color = item[1]
		var away: Vector3 = item[2]
		_spawn_now(pos, color, away)
	if pending() > _cap:  # what is left over the cap is dropped, oldest first
		_head = _queue.size() - _cap
	_compact()
	while _bodies.size() > _cap:
		_forget(0)
	_age_out()
	_draw()


## A real physics fragment: mostly small, in the building's own colours, thrown out and
## falling heavily to settle on the street, then crumbling away.
## Queues a fragment; at most SPAWN_PER_FRAME are created each frame so a big collapse never
## stalls a frame.
## Past the cap and one frame's worth the oldest queued fragment is dropped as a new one comes
## (b2-3: a heavy swipe queued 4000+ in one frame); the same count is thrown each frame as when
## the queue was trimmed only after throwing, so the shared fx random stream is unchanged.
func spawn(pos: Vector3, color: Color, away: Vector3) -> void:
	_queue.append([pos, color, away])
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


func _spawn_now(pos: Vector3, color: Color, away: Vector3) -> void:
	var size := BuildingVoxels.VOXEL * (_rng.randf_range(0.35, 0.8) if _rng.randf() < 0.8 else 1.0)
	size *= size_scale
	var body := RigidBody3D.new()
	body.gravity_scale = 2.2
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3.ONE * size
	shape.shape = box_shape
	body.add_child(shape)
	var whiten := lift if lift >= 0.0 else Look.value("debris_lift")
	var view := _view(snappedf(size, 0.02))
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
	_views.append(view)
	_colors.append(Color(color, 1.0).lightened(whiten))
	_ends.append(_clock + _rng.randf_range(5.0, 8.0))


## Pieces whose time is up and fully shrunk are gone.
func _age_out() -> void:
	var k := _bodies.size() - 1
	while k >= 0:
		if _clock >= _ends[k] + SHRINK_SECONDS:
			_forget(k)
		k -= 1


## Every live piece into its size's MultiMesh, shrinking over SHRINK_SECONDS once its time is up.
func _draw() -> void:
	var counts := PackedInt32Array()
	counts.resize(_meshes.size())
	for view: int in _views:
		counts[view] += 1
	for view: int in _meshes.size():  # capacity grows by doubling; the tail stays zeros
		var mm := _meshes[view]
		if mm.instance_count < counts[view]:
			mm.instance_count = nearest_po2(counts[view])
			_bufs[view].resize(mm.instance_count * CarveRubble.FLOATS)
		mm.visible_instance_count = counts[view]
		counts[view] = 0
	for k: int in _bodies.size():
		var view := _views[k]
		var t := clampf((_clock - _ends[k]) / SHRINK_SECONDS, 0.0, 1.0)
		var xf := _bodies[k].global_transform
		xf.basis = xf.basis.scaled_local(Vector3.ONE * lerpf(1.0, SHRINK_MIN, t))
		CarveRubble.pack(_bufs[view], counts[view] * CarveRubble.FLOATS, xf, _colors[k])
		counts[view] += 1
	for view: int in _meshes.size():
		if counts[view] > 0:
			_meshes[view].buffer = _bufs[view]


## The index of the MultiMesh drawing pieces of snapped size `key` (made on first use).
func _view(key: float) -> int:
	ThreadCheck.main_only("DebrisField._view")
	if not _sizes.has(key):
		if _material == null:
			_material = Look.plain_detail_material(Color.WHITE, 0.0)  # colour per instance
		var box := BoxMesh.new()
		box.size = Vector3.ONE * key * 0.95
		box.material = _material
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = box
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.top_level = true
		if not shadows:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_sizes[key] = _meshes.size()
		_meshes.append(mm)
		_bufs.append(PackedFloat32Array())
	var out: int = _sizes[key]
	return out


func _forget(k: int) -> void:
	_bodies[k].queue_free()
	_bodies.remove_at(k)
	_views.remove_at(k)
	_colors.remove_at(k)
	_ends.remove_at(k)
