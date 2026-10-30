class_name IslandBricks
extends RefCounted
## A breaking island's bricks (IslandBody): dropped, measured, meshed and given a collision shape.

static var _boxes: Dictionary = {}  # merged: Vector4i(box size in cells, res) -> BoxShape3D


static func drop_brick(body: IslandBody, key: Vector3i) -> void:
	var own: PackedInt32Array = body._bricks[key]
	for k: int in own:
		body._solid[body.cells[k]] = 0
	body._bricks.erase(key)
	body._spans.erase(key)
	var i := body._shape_keys.find(key)
	if i >= 0:
		PhysicsServer3D.body_remove_shape(body.get_rid(), i)
		body._shape_keys.remove_at(i)
	for table: Dictionary in [body._meshes, body._shapes]:
		if table.has(key):
			var node: Node = table[key]
			node.queue_free()
			table.erase(key)


static func brick_span(body: IslandBody, key: Vector3i) -> AABB:
	if not body._spans.has(key):
		var ks: PackedInt32Array = body._bricks[key]
		body._spans[key] = CarveMesh.span(body.site, body.cells, ks)
	var out: AABB = body._spans[key]
	return out


static func mesh_brick(body: IslandBody, key: Vector3i) -> void:
	var ks: PackedInt32Array = body._bricks[key]
	var own := PackedInt32Array()
	var own_mats := PackedByteArray()
	for k: int in ks:
		own.append(body.cells[k])
		own_mats.append(body.mats[k])
	var mesh := CarveMesh.build_at(body.site, own, [own_mats, body._solid], body._com)
	var mi: MeshInstance3D = body._meshes.get(key)
	if mi == null:
		mi = MeshInstance3D.new()
		body.add_child(mi)
		body._meshes[key] = mi
	mi.mesh = mesh
	mi.material_override = body.cell_material


static func shape_brick(body: IslandBody, key: Vector3i) -> void:
	var box := brick_span(body, key)
	if body.merged:
		var at := Transform3D(Basis(), box.get_center() - body._com)
		PhysicsServer3D.body_add_shape(body.get_rid(), box_shape(body, box.size).get_rid(), at)
		body._shape_keys.append(key)
		return
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = box.size
	shape.shape = b
	shape.position = box.get_center() - body._com
	body.add_child(shape)
	body._shapes[key] = shape


## The shared box shape `size` (world) a side on this site's grid.
static func box_shape(body: IslandBody, size: Vector3) -> BoxShape3D:
	var n := Vector3i((size * body.site.res).round())
	var tag := Vector4i(n.x, n.y, n.z, body.site.res)
	var shape: BoxShape3D = _boxes.get(tag)
	if shape == null:
		shape = BoxShape3D.new()
		shape.size = size
		_boxes[tag] = shape
	return shape
