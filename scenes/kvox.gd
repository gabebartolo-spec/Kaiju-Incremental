class_name Kvox
extends RefCounted
## Reads a .kvox voxel model (tools/blender/voxelize.py): the shell of a textured model on a
## grid, one colour per voxel, one or more poses (a walk-cycle flipbook). y up, facing -Z, feet
## on y = 0, centred in x and z. Version 1 files hold a single pose.

const MAGIC := "KVOX"

## Model height in voxels (0 if the file is missing or not a .kvox).
var height := 0
## One VoxelBuilder per pose, in playback order.
var frames: Array[VoxelBuilder] = []


static func read(path: String) -> Kvox:
	var out := Kvox.new()
	if not FileAccess.file_exists(path):
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_buffer(4).get_string_from_ascii() != MAGIC:
		return out
	var version := f.get_32()
	var count := 1 if version == 1 else f.get_32()
	var first := f.get_32() if version == 1 else 0
	out.height = f.get_16()
	for i: int in count:
		var voxels := first if version == 1 else f.get_32()
		var vox := VoxelBuilder.new()
		vox.height_hint = out.height
		var buf := f.get_buffer(voxels * 10)  # per voxel: x, y, z int16, r, g, b, face flags
		for v: int in buf.size() / 10:
			var o := v * 10
			var cell := Vector3i(buf.decode_s16(o), buf.decode_s16(o + 2), buf.decode_s16(o + 4))
			var color := Color8(buf[o + 6], buf[o + 7], buf[o + 8])
			var flag := buf[o + 9]
			vox.put_color(cell, color)
			if flag != 0:
				vox.flags[cell] = flag
		out.frames.append(vox)
	return out
