class_name BuildingNative
extends RefCounted
## BuildingMesher's bake in native code (KaijuBuilding, native/src/kaiju_building.cpp): the same
## arrays and debris samples as the GDScript bake, byte for byte, about 20x faster (director
## 2026-11-02: the title waited ~4 s on the GDScript bake of its 122 buildings). Plain
## BuildingVoxels only: the kinds with their own face_mask (rails, bridges, landmarks, hazards) bake
## in the GDScript.

## Off, every building bakes in the GDScript (the oracle the tests compare with).
static var use_native := true
## Per BuildingMesher.NEIGHBOURS direction its face corner vectors u and v, the axes of its normal,
## u and v, and its AO ring (VoxelAO.ring_of), then VoxelAO.table: built once, on the loading
## thread, as BuildingMesher._begin builds them.
static var _tables: Array = _make_tables()


## [shell arrays, slab arrays, samples] as BuildingMesher keeps them, or null: native off, no
## library, not a plain BuildingVoxels, or cells spanning too big a box for the native grid.
static func bake(v: BuildingVoxels, finish: Dictionary, noise: float) -> Variant:
	if not use_native or v.get_script() != BuildingVoxels:
		return null
	if not ClassDB.class_exists("KaijuBuilding"):
		return null
	var b := v.b
	var res := BuildingVoxels.RES
	var dims := PackedInt32Array(
		[b.w * res, b.height * res, b.d * res, b.w, b.height, b.d, res, b.style]
	)
	var origin := v.origin() + Vector3(0, BuildingVoxels.VOXEL * 0.5, 0)
	var native: Object = ClassDB.instantiate("KaijuBuilding")
	var t := _tables
	return native.call(
		"bake",
		v.vox.cells,
		v.vox.colors,
		v.palette,
		finish,
		dims,
		origin,
		noise,
		t[0],
		t[1],
		t[2],
		t[3],
		t[4]
	)


static func _make_tables() -> Array:
	var face_u := PackedVector3Array()
	var face_v := PackedVector3Array()
	var axes := PackedInt32Array()
	var rings := PackedInt32Array()
	var half := BuildingVoxels.VOXEL * 0.5
	for d: Vector3i in BuildingMesher.NEIGHBOURS:
		var nf := Vector3(d)
		var a := Vector3.UP if d.y == 0 else Vector3.RIGHT
		var u := a.cross(nf) * half
		var v := nf.cross(u.normalized()) * half
		face_u.append(u)
		face_v.append(v)
		axes.append_array([_axis(nf), _axis(u), _axis(v)])
		for s: Vector3i in VoxelAO.ring_of(d):
			rings.append_array([s.x, s.y, s.z])
	var ao := PackedInt32Array()
	for bits: int in 256:
		ao.append(VoxelAO.table(bits))
	return [face_u, face_v, axes, rings, ao]


static func _axis(v: Vector3) -> int:
	return 0 if v.x != 0.0 else (1 if v.y != 0.0 else 2)
