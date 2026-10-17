class_name LandmarkVoxels
extends BuildingVoxels
## A landmark's voxels: its baked shell (tools/landmarks/bake.py, from a Blender model) in place of
## a generated facade, on the same grid (RES cells per sim unit, cells local to the footprint), so
## BuildingMesher and BuildingView draw and break it chunk by chunk like any building. Each voxel's
## .kvox flags hold the faces it shows (open to the air outside the model); nothing else is drawn.

## Parsed .kvox per path: every view of a landmark shares one read.
static var _cache: Dictionary = {}
static var _lock := Mutex.new()


func _init(p_building: RampageSim.Building, base: Color) -> void:
	super(p_building, base, {}, false)
	var shape: Dictionary = Content.landmarks().get(b.landmark, {})
	var model := _read(str(shape.get("kvox", "")))
	if not model.frames.is_empty():
		vox = model.frames[0]


func face_mask(cell: Vector3i) -> int:
	return Num.i(vox.flags.get(cell, 0))


static func _read(path: String) -> Kvox:
	_lock.lock()
	if not _cache.has(path):
		_cache[path] = Kvox.read(path)
	var out: Kvox = _cache[path]
	_lock.unlock()
	return out
