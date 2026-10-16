class_name VehicleParts
extends RefCounted
## A vehicle voxelized per part (tools/blender/voxelize_parts.py): <base>.parts.json names each
## part's .kvox and its hinge, all on one grid, so a turret or a rotor turns about its real
## hinge. Presentation only.

## World size of one voxel.
var voxel := 0.0
var _dir := ""
var _parts: Dictionary = {}


## `height` is the drawn height of the whole model in world units.
func _init(base: String, height: float) -> void:
	var meta := Content.load_json(base + ".parts.json")
	_dir = base.get_base_dir()
	_parts = meta.get("parts", {})
	voxel = height / maxf(1.0, Num.f(meta.get("height", 2)) - 1.0)


## A part's hinge in the model's space (world units).
func pivot(part: String) -> Vector3:
	var entry: Dictionary = _parts[part]
	var p: Array = entry["pivot"]
	return Vector3(Num.f(p[0]), Num.f(p[1]), Num.f(p[2])) * voxel


## The z of a part's most forward (-Z) voxel, in the model's space: where a gun's muzzle is.
func front(part: String) -> float:
	var out := INF
	for cell: Vector3i in _read(part).frames[0].cells:
		out = minf(out, cell.z * voxel)
	return out


## A part's voxels with every cell offset by `origin` (minus the hinge puts the hinge at 0).
func build(part: String, origin: Vector3, salt: int) -> MultiMeshInstance3D:
	var vox: VoxelBuilder = _read(part).frames[0]
	vox.salt = salt
	return vox.build({}, voxel, 0.0, origin)


## A node on `parent` at the part's hinge (less `centre`), holding the part's voxels.
func hinge(part: String, parent: Node3D, centre: Vector3, salt: int) -> Node3D:
	var node := Node3D.new()
	node.position = pivot(part) - centre
	parent.add_child(node)
	node.add_child(build(part, -pivot(part), salt))
	return node


func _read(part: String) -> Kvox:
	var entry: Dictionary = _parts[part]
	return Kvox.read(_dir.path_join(str(entry["kvox"])))
