class_name StreamStandIns
extends RefCounted
## One facade box per building (the skyline's stand-in look), shown while the building is not
## meshed (BuildingStream). Presentation only.

var _multi: MultiMesh
var _buildings: Array[RampageSim.Building]


func _init(buildings: Array[RampageSim.Building]) -> void:
	_buildings = buildings


## The boxes, as a node to add to the stream; every building shows its box.
func build(colors: Array[Color]) -> MultiMeshInstance3D:
	_multi = MultiMesh.new()
	_multi.transform_format = MultiMesh.TRANSFORM_3D
	_multi.use_colors = true
	_multi.use_custom_data = true
	var mesh := BoxMesh.new()
	mesh.material = CitySkyline.facade_material(0.0)
	_multi.mesh = mesh
	_multi.instance_count = _buildings.size()
	for n: int in _buildings.size():
		var b := _buildings[n]
		_multi.set_instance_transform(n, _box(n))
		_multi.set_instance_color(n, colors[n])
		var tall := 1.0 if b.height > 18 else 0.0
		var custom := Color(b.style % 4, 0.35, tall, fposmod(b.x * 0.37 + b.z * 0.11, 1.0))
		_multi.set_instance_custom_data(n, custom)
	var node := MultiMeshInstance3D.new()
	node.multimesh = _multi
	return node


## Building n is meshed: its box goes.
func hide(n: int) -> void:
	if _multi != null:
		_multi.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))


## Building n is a box again.
func show(n: int) -> void:
	_multi.set_instance_transform(n, _box(n))


func _box(n: int) -> Transform3D:
	var b := _buildings[n]
	if b.is_rail():  # a viaduct is no box: it stays meshed (BuildingStream holds it)
		return Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	return Transform3D(
		Basis.from_scale(Vector3(b.w, b.height, b.d)), Vector3(b.x, b.height * 0.5, b.z)
	)
