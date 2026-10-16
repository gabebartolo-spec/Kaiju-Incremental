class_name Kvox
extends RefCounted
## Reads a .kvox voxel model (tools/blender/voxelize.py): the shell of a textured model on a
## grid, one colour per voxel. y up, facing -Z, feet on y = 0, centred in x and z.

const MAGIC := "KVOX"


## Fills `vox` with the model's voxels (direct colours). Returns the model's height in voxels,
## or 0 if the file is missing or not a .kvox.
static func load_into(path: String, vox: VoxelBuilder) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_buffer(4).get_string_from_ascii() != MAGIC:
		return 0
	f.get_32()  # version
	var count := f.get_32()
	var height := f.get_16()
	for _i: int in count:
		var x := _signed16(f.get_16())
		var y := _signed16(f.get_16())
		var z := _signed16(f.get_16())
		var color := Color8(f.get_8(), f.get_8(), f.get_8())
		f.get_8()  # flags
		vox.put_color(Vector3i(x, y, z), color)
	return height


static func _signed16(v: int) -> int:
	return v - 65536 if v >= 32768 else v
