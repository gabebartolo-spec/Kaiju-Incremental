class_name VehicleParts
extends RefCounted
## A vehicle voxelized per part (tools/blender/voxelize_parts.py): <base>.parts.json names each
## part's .kvox and its hinge, all on one grid, so a turret or a rotor turns about its real
## hinge. Presentation only.

## Parsed .kvox per path and built voxels per part, shared by every vehicle of a type, so a tank
## or helicopter spawning mid-rampage reuses them instead of re-reading and re-filling (35-45 ms a
## spawn before). Each vehicle still gets its own material (the governor's is recoloured alone).
static var _kvox_cache: Dictionary = {}
static var _mesh_cache: Dictionary = {}

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


## Empties the shared caches (tests that need the first build to run again).
static func clear_cache() -> void:
	_kvox_cache.clear()
	_mesh_cache.clear()


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
	var key := "%s|%s|%f|%d|%v" % [_dir, part, voxel, salt, origin]
	if not _mesh_cache.has(key):
		var vox: VoxelBuilder = _read(part).frames[0]
		vox.salt = salt
		var holder := vox.build({}, voxel, 0.0, origin)  # only its MultiMesh is shared
		_mesh_cache[key] = holder.multimesh
		holder.free()  # a node never added to the tree is not freed by anything else
	var mm: MultiMesh = _mesh_cache[key]
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = (mm.mesh as PrimitiveMesh).material.duplicate()
	return mmi


## A node on `parent` at the part's hinge (less `centre`), holding the part's voxels.
func hinge(part: String, parent: Node3D, centre: Vector3, salt: int) -> Node3D:
	var node := Node3D.new()
	node.position = pivot(part) - centre
	parent.add_child(node)
	node.add_child(build(part, -pivot(part), salt))
	return node


func _read(part: String) -> Kvox:
	var entry: Dictionary = _parts[part]
	var path := _dir.path_join(str(entry["kvox"]))
	if not _kvox_cache.has(path):
		_kvox_cache[path] = Kvox.read(path)
	return _kvox_cache[path]
