class_name PropField
extends RefCounted
## Many small static props (cars, trees, streetlights) in one MultiMesh, each prop a group of
## instances that can be crushed (flattened) when the kaiju stomps on it. Presentation only:
## the sim never knows props exist.

var vox := VoxelBuilder.new()
var voxel: float
var _groups: Array[Dictionary] = []
var _mmi: MultiMeshInstance3D


func _init(p_voxel: float) -> void:
	voxel = p_voxel


## Adds a prop: `shape` fills a VoxelBuilder in prop-local cells; `at` is its world base.
## Each prop is built into the shared builder offset by its own cell origin.
func add(at: Vector3, shape: Callable) -> void:
	var local := VoxelBuilder.new()
	shape.call(local)
	var offset := Vector3i((at / voxel).round())
	offset.y = 0
	var before := vox.cells.size()
	for cell: Vector3i in local.cells:
		vox.put(cell + offset, local.key_at(cell))
	_groups.append({"at": at, "cells": vox.cells.size() - before, "offset": offset, "local": local})


## glow: strength for palette colours with alpha 0 (lamps).
func build(palette: Dictionary, salt: int, glow: float) -> MultiMeshInstance3D:
	vox.salt = salt
	_mmi = vox.build(palette, voxel, glow, Vector3.ZERO)
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return _mmi


## Flattens every prop whose base is within `radius` of `at` (ground plane).
func crush(at: Vector3, radius: float) -> void:
	if _mmi == null:
		return
	var mm := _mmi.multimesh
	var hit: Array[Vector3i] = []
	for group: Dictionary in _groups:
		if group.get("crushed", false):
			continue
		var base: Vector3 = group["at"]
		if Vector2(base.x - at.x, base.z - at.z).length() <= radius:
			group["crushed"] = true
			var local: VoxelBuilder = group["local"]
			var offset: Vector3i = group["offset"]
			for cell: Vector3i in local.cells:
				hit.append(cell + offset)
	if hit.is_empty():
		return
	var flat: Dictionary = {}
	for cell: Vector3i in hit:
		flat[cell] = true
	for i: int in mm.instance_count:
		var t := mm.get_instance_transform(i)
		var cell := Vector3i(((t.origin - Vector3(0, voxel * 0.5, 0)) / voxel).round())
		if flat.has(cell):
			t.origin.y = t.origin.y * 0.2 + voxel * 0.1
			t.basis = Basis.from_scale(Vector3(1.15, 0.25, 1.15))
			mm.set_instance_transform(i, t)
