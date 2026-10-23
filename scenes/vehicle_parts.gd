class_name VehicleParts
extends RefCounted
## A vehicle voxelized per part (tools/blender/voxelize_parts.py): <base>.parts.json names each
## part's .kvox and its hinge, all on one grid, so a turret or a rotor turns about its real
## hinge. Presentation only.

## Parsed .kvox per path and built voxels per part, shared by every vehicle of a type, so a tank
## or helicopter spawning mid-rampage reuses them instead of re-reading and re-filling (35-45 ms a
## spawn before). Each vehicle still gets its own material, so one fades without the others.
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
		_mesh_cache[key] = vox.build({}, voxel, 0.0, origin).multimesh
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


## A breaking part's heat on every voxel part under `root`: a white-hot flash of `gain` fading out
## over `flash_s`, while the part chars dark over `char_s` (the tween lives on `host`, so it
## outlasts the model being taken apart).
static func flash(root: Node, host: Node, gain: float, flash_s: float, char_s: float) -> void:
	var mats: Array[ShaderMaterial] = []
	for node: Node in root.find_children("*", "MultiMeshInstance3D", true, false):
		var mat := (node as MultiMeshInstance3D).material_override as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("flash", gain)
			mats.append(mat)
	host.create_tween().tween_method(
		func(v: float) -> void:
			var t := v * char_s
			for mat: ShaderMaterial in mats:
				mat.set_shader_parameter("flash", gain * maxf(0.0, 1.0 - t / flash_s))
				mat.set_shader_parameter("scorch", smoothstep(0.0, char_s, t)),
		0.0,
		1.0,
		char_s
	)


## Fades every voxel part under `root` (1 = solid, lower drops a share of its pixels).
static func set_opacity(root: Node, opacity: float) -> void:
	for node: Node in root.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := node as MultiMeshInstance3D
		var mat := mmi.material_override as ShaderMaterial
		if mat == null:
			mat = (mmi.multimesh.mesh as PrimitiveMesh).material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("opacity", opacity)


func _read(part: String) -> Kvox:
	var entry: Dictionary = _parts[part]
	var path := _dir.path_join(str(entry["kvox"]))
	if not _kvox_cache.has(path):
		_kvox_cache[path] = Kvox.read(path)
	return _kvox_cache[path]
