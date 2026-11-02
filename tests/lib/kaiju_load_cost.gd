extends RefCounted
## The kaiju's load cost (KaijuModel.new took 3.5 s for the Colossus, 2026-11-02): the rig packs its
## bones' and joint bands' voxels on worker threads, the skin writes its cubes straight into the
## MultiMesh buffer, and both read the tint's noise amount once (Look.jitter_by). Each draws what
## the one-thread, call-per-cube build drew (on vs off: the buffers, float for float). Seeded: the
## Colossus's files, no clock.

const COLOSSUS := "res://assets/kaiju/reptilian_adult"


static func check(check_fn: Callable) -> void:
	var model := Kvox.read(COLOSSUS + ".kvox")
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(COLOSSUS + ".rig.json"))
	var voxel := KaijuModel.MODEL_HEIGHT / model.height
	var rig := KaijuRig.from_spec(spec, model.frames[0], voxel, 0.0)
	_rig(rig, voxel, check_fn)
	var skin := VoxelSkin.load_for(rig, COLOSSUS)
	_skin(skin, check_fn)
	skin.free()
	rig.free()


## Every bone's and band's node holds the buffer a one-thread pack of its voxels gives.
static func _rig(rig: KaijuRig, voxel: float, check_fn: Callable) -> void:
	var bands := RigJoints.overlap(rig)
	var parts := 0
	var bad := 0
	for bone_name: String in rig.bone_names():
		var shown: Array[MultiMeshInstance3D] = []
		for child: Node in rig.bone(bone_name).get_children():
			if child is MultiMeshInstance3D:
				shown.append(child)
		var want: Array[PackedFloat32Array] = []
		var head := rig.head_of(bone_name)
		var parts_of: Array = [rig.voxels_of(bone_name), bands.get(bone_name)]
		for k: int in parts_of.size():
			if parts_of[k] != null:
				var part: VoxelBuilder = parts_of[k]
				part.salt = 7
				part.inset = 1.0 if k == 0 else KaijuRig.JOINT_INSET
				want.append(_old_pack(part, voxel, -head))
		for i: int in want.size():
			parts += 1
			if i >= shown.size() or shown[i].multimesh.buffer != want[i]:
				bad += 1
	check_fn.call(
		parts > 40 and bad == 0,
		(
			"kaiju load: the rig's %d threaded parts draw as packed on one thread (%d differ)"
			% [parts, bad]
		)
	)


## VoxelBuilder.pack as it was before the noise amount was read once: Look.jitter per cell.
static func _old_pack(part: VoxelBuilder, voxel: float, origin: Vector3) -> PackedFloat32Array:
	var buf := part.pack({}, voxel, origin)
	if not part.noise:
		return buf
	var stride := VoxelBuilder.DETAIL_STRIDE if part.detail else VoxelBuilder.STRIDE
	for i: int in part.built_cells.size():
		var cell := part.built_cells[i]
		var base: Color = part.colors[cell]
		var c := Look.jitter(base, cell, part.salt)
		for n: int in 4:
			buf[i * stride + 12 + n] = c[n]
	return buf


## The skin's cubes equal the old build: Look.jitter per cube and VoxelSkin.pack(), laid out as
## MultiMesh stores an instance (the transform row by row, the colour, the custom data; a headless
## run keeps no set_instance_* call, so the old calls are written out here).
static func _skin(skin: VoxelSkin, check_fn: Callable) -> void:
	var raw := FileAccess.get_file_as_bytes(COLOSSUS + ".vskin").decompress_dynamic(
		-1, FileAccess.COMPRESSION_GZIP
	)
	var cells := raw.decode_u32(22)
	var voxel := raw.decode_float(18)
	var want := PackedFloat32Array()
	var at := VoxelSkin.HEADER_BYTES
	for i: int in cells:
		var cell := Vector3i(raw.decode_s16(at), raw.decode_s16(at + 2), raw.decode_s16(at + 4))
		var tint := Look.jitter(Color8(raw[at + 6], raw[at + 7], raw[at + 8]), cell, 7)
		tint.a = raw[at + 14] / 255.0
		var c := (Vector3(cell) + VoxelSkin.HALF_UP) * voxel
		var custom := VoxelSkin.pack(raw[at + 9], raw.slice(at + 10, at + 14))
		want.append_array([1, 0, 0, c.x, 0, 1, 0, c.y, 0, 0, 1, c.z])
		want.append_array([tint.r, tint.g, tint.b, tint.a, custom.r, custom.g, custom.b, custom.a])
		at += VoxelSkin.CELL_BYTES
	var cubes: MultiMeshInstance3D = skin.get("_cube_node")
	var got := cubes.multimesh.buffer
	var bad := 0
	for k: int in mini(got.size(), want.size()):
		if got[k] != want[k]:
			bad += 1
	check_fn.call(
		got.size() == cells * VoxelSkin.INSTANCE_FLOATS and got.size() == want.size() and bad == 0,
		(
			"kaiju load: the skin's %d cubes equal the call-per-cube build (%d floats differ)"
			% [cells, bad]
		)
	)
