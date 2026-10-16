class_name RigJoints
extends RefCounted
## A bent joint of a voxel rig opens a gap on the outside of the bend. Each side of a joint also
## carries a band of its neighbour's voxels next to the joint, so the pieces overlap, not part.

## Band length (share of the child bone's length) and how far from the bone's axis it reaches.
const BAND := 0.35
const WIDTH := 1.0


## The overlap band each bone carries: bone name -> VoxelBuilder of its neighbours' cells (only
## cells the bone does not own). Built as a separate, inset layer so it never z-fights the skin.
static func overlap(rig: KaijuRig) -> Dictionary:
	var extra: Dictionary = {}  # bone -> Dictionary cell -> Color
	for child: String in rig.bone_names():
		var parent := rig.parent_of(child)
		var mine := rig.voxels_of(child)
		var theirs := rig.voxels_of(parent) if parent != "" else null
		if mine == null or theirs == null:
			continue
		var axis := rig.dir_of(child)
		var length := axis.length()
		if length < 0.0001:
			continue
		var joint := {
			"head": rig.head_of(child),
			"axis": axis / length,
			"band": length * BAND,
			"width": length * WIDTH,
			"voxel": rig.voxel_size(),
		}
		_take(theirs, joint, -1.0, _bucket(extra, child))
		_take(mine, joint, 1.0, _bucket(extra, parent))
	var out: Dictionary = {}
	for bone_name: String in extra:
		var part := rig.voxels_of(bone_name)
		var band := VoxelBuilder.new()
		var cells: Dictionary = extra[bone_name]
		for cell: Vector3i in cells:
			if not part.cells.has(cell):
				var color: Color = cells[cell]
				band.put_color(cell, color)
		if band.cells.size() > 0:
			out[bone_name] = band
	return out


static func _bucket(extra: Dictionary, bone_name: String) -> Dictionary:
	if not extra.has(bone_name):
		extra[bone_name] = {}
	var out: Dictionary = extra[bone_name]
	return out


## Copies the cells of src within the band on one side of the joint (side -1 above, +1 below).
static func _take(src: VoxelBuilder, joint: Dictionary, side: float, out: Dictionary) -> void:
	var head: Vector3 = joint["head"]
	var axis: Vector3 = joint["axis"]
	var band: float = joint["band"]
	var width: float = joint["width"]
	var voxel: float = joint["voxel"]
	for cell: Vector3i in src.cells:
		var rel := (Vector3(cell) + Vector3(0.5, 0.5, 0.5)) * voxel - head
		var along := rel.dot(axis) * side
		if along < 0.0 or along > band:
			continue
		if (rel - axis * rel.dot(axis)).length() > width:
			continue
		out[cell] = src.colors[cell]
