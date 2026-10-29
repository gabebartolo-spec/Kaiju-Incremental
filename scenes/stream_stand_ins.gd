class_name StreamStandIns
extends RefCounted
## One facade box per building (the skyline's stand-in look), shown while the building is not
## meshed (BuildingStream). Presentation only.

## How far a dissolving box stands inside the building's walls (m).
const INSET := 0.1

var _multi: MultiMesh
var _buildings: Array[RampageSim.Building]
var _colors: Array[Color]
var _alpha := PackedFloat32Array()  # per building: how much of its box is drawn (0 hidden)


func _init(buildings: Array[RampageSim.Building]) -> void:
	_buildings = buildings


## The boxes, as a node to add to the stream; every building shows its box.
func build(colors: Array[Color]) -> MultiMeshInstance3D:
	_colors = colors
	_multi = MultiMesh.new()
	_multi.transform_format = MultiMesh.TRANSFORM_3D
	_multi.use_colors = true
	_multi.use_custom_data = true
	var mesh := BoxMesh.new()
	mesh.material = SkylineMeshes.facade_material(0.0)
	_multi.mesh = mesh
	_multi.instance_count = _buildings.size()
	_alpha.resize(_buildings.size())
	for n: int in _buildings.size():
		var b := _buildings[n]
		_multi.set_instance_transform(n, _box(n))
		_alpha[n] = 0.0 if b.is_span() else 1.0
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
		_alpha[n] = 0.0
		_multi.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))


## Building n is a box again.
func show(n: int) -> void:
	_alpha[n] = 0.0 if _buildings[n].is_span() else 1.0
	_multi.set_instance_transform(n, _box(n))


## How much of building n's box is drawn: 0 when it is hidden (or a viaduct), else its opacity
## (kept here: a headless MultiMesh does not read back).
func alpha(n: int) -> float:
	return _alpha[n] if n < _alpha.size() else 0.0


## Building n's box drawn at `opacity` (a dither, see facade.gdshaderinc), a hair smaller
## than the building so the meshed walls in front of it stay solid while it dissolves.
func fade(n: int, opacity: float) -> void:
	var b := _buildings[n]
	if _multi == null or b.is_span():
		return
	_alpha[n] = opacity
	var color := _colors[n]
	color.a = opacity
	_multi.set_instance_color(n, color)
	var size := Vector3(b.w - 2.0 * INSET, b.height - INSET, b.d - 2.0 * INSET)
	_multi.set_instance_transform(
		n, Transform3D(Basis.from_scale(size), Vector3(b.x, size.y * 0.5, b.z))
	)


func _box(n: int) -> Transform3D:
	var b := _buildings[n]
	if b.is_span():  # a viaduct or bridge is no box: it stays meshed (BuildingStream holds it)
		return Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	return Transform3D(
		Basis.from_scale(Vector3(b.w, b.height, b.d)), Vector3(b.x, b.height * 0.5, b.z)
	)
