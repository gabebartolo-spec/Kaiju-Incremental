class_name KaijuRig
extends Node3D
## A rigged voxel kaiju (tools/blender/rig_voxel.py): one node per bone, each carrying its
## own voxels, so the body bends where the real one would. A procedural walk drives the
## legs, arms, spine and head; tails, antennae and tentacles ("physics" bones) are spring
## chains: they lag behind the body, swing with every step and settle under gravity. Presentation only. Faces -Z.

## Chain feel: how hard a joint is pulled back to its rest pose, how much motion it keeps, gravity.
const STIFFNESS := 9.0
const DAMPING := 0.9
const GRAVITY := Vector3(0, -6.0, 0)
const LIMB_STIFFNESS := 26.0
const CONSTRAINT_PASSES := 3

var height_units: float
var _bones: Dictionary = {}  # name -> Node3D
var _rest: Dictionary = {}  # name -> Transform3D (local rest)
var _dir: Dictionary = {}  # name -> rest head->tail vector, in the bone's own space
var _chains: Array[Dictionary] = []
var _phase := 0.0
var _roar := 0.0


## Builds the rig from <base>.rig.json and <base>.kvox; returns null if either is missing.
static func load_from(base: String, model_height: float, glow: float) -> KaijuRig:
	var rig_path := base + ".rig.json"
	if not FileAccess.file_exists(rig_path):
		return null
	var model := Kvox.read(base + ".kvox")
	if model.height <= 0 or model.frames.is_empty():
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(rig_path))
	if not parsed is Dictionary:
		return null
	var spec: Dictionary = parsed
	var rig := KaijuRig.new()
	rig._build(spec, model.frames[0], model_height / model.height, glow)
	return rig


func _build(spec: Dictionary, vox: VoxelBuilder, voxel: float, glow: float) -> void:
	var defs: Array = spec["bones"]
	var heads: Dictionary = {}
	for d: Dictionary in defs:
		heads[str(d["name"])] = _vec(d["head"]) * voxel
	# Split the voxels by bone (the flags byte), each relative to its bone's head.
	var per_bone: Dictionary = {}
	for cell: Vector3i in vox.cells:
		var index: int = vox.flags.get(cell, 0)
		if not per_bone.has(index):
			per_bone[index] = VoxelBuilder.new()
		var part: VoxelBuilder = per_bone[index]
		var color: Color = vox.colors[cell]
		part.put_color(cell, color)
	for i: int in defs.size():
		var d: Dictionary = defs[i]
		var bone_name := str(d["name"])
		var parent_name := str(d["parent"]) if d["parent"] != null else ""
		var node := Node3D.new()
		node.name = bone_name
		var head: Vector3 = heads[bone_name]
		var parent: Node3D = _bones.get(parent_name, self)
		var parent_head: Vector3 = heads.get(parent_name, Vector3.ZERO)
		node.position = head - parent_head
		parent.add_child(node)
		_bones[bone_name] = node
		_rest[bone_name] = node.transform
		_dir[bone_name] = _vec(d["tail"]) * voxel - head
		if per_bone.has(i):
			var part: VoxelBuilder = per_bone[i]
			part.salt = 7
			var mmi := part.build({}, voxel, glow, -head)
			mmi.layers = 1 | KaijuModel.RIM_LAYER
			node.add_child(mmi)
	height_units = vox.height_hint * voxel if vox.height_hint > 0 else 10.0
	_relax_arms()
	_collect_chains(defs)


## Models arrive in a T-pose; a kaiju carries its arms lowered and reaching forward.
func _relax_arms() -> void:
	for side: String in ["l", "r"]:
		var root := "arm_%s0" % side
		if not _bones.has(root):
			continue
		var outward: float = signf(_dir_of(root).x)
		var lower := Basis(Vector3.BACK, -outward * 0.95)
		var reach := Basis(Vector3.UP, outward * 0.35)
		var rest: Transform3D = _rest[root]
		_rest[root] = Transform3D(reach * lower * rest.basis, rest.origin)
		_bone(root).transform = _rest_of(root)


func _collect_chains(defs: Array) -> void:
	var by_parent: Dictionary = {}
	for d: Dictionary in defs:
		var parent := str(d["parent"]) if d["parent"] != null else ""
		by_parent[parent] = by_parent.get(parent, []) + [str(d["name"])]
	for d: Dictionary in defs:
		var bone_name := str(d["name"])
		var parent := str(d["parent"]) if d["parent"] != null else ""
		var is_physics: bool = d["physics"]
		var starts_chain := is_physics and not _is_physics(defs, parent)
		var is_arm := bone_name.begins_with("arm_") and not parent.begins_with("arm_")
		if starts_chain or is_arm:
			var names: Array[String] = [bone_name]
			var walk := bone_name
			while by_parent.has(walk):
				var children: Array = by_parent[walk]
				if children.size() != 1:
					break
				walk = str(children[0])
				names.append(walk)
			_chains.append({"names": names, "stiffness": LIMB_STIFFNESS if is_arm else STIFFNESS})


func _is_physics(defs: Array, bone_name: String) -> bool:
	for d: Dictionary in defs:
		if str(d["name"]) == bone_name:
			var p: bool = d["physics"]
			return p
	return false


static func _vec(v: Variant) -> Vector3:
	var a: Array = v
	return Vector3(Num.f(a[0]), Num.f(a[1]), Num.f(a[2]))


func roar() -> void:
	_roar = 1.0


## moving 0..1. Call every frame.
func animate(delta: float, moving: float) -> void:
	_phase += delta * (1.5 + 5.5 * moving)
	_roar = maxf(0.0, _roar - delta * 1.5)
	var s := sin(_phase)
	var c := cos(_phase)
	for side: String in ["l", "r"]:
		var sign := 1.0 if side == "l" else -1.0
		_pose("leg_%s0" % side, Vector3(s * sign * 0.45 * moving, 0, 0))
		_pose("leg_%s1" % side, Vector3(maxf(0.0, -c * sign) * 0.6 * moving, 0, 0))
		_pose("leg_%s2" % side, Vector3(-s * sign * 0.25 * moving, 0, 0))
	_pose("spine0", Vector3(0.05 * moving, 0, sin(_phase * 2.0) * 0.04 * moving))
	_pose("spine1", Vector3(sin(_phase * 0.5) * 0.02, 0, 0))
	_pose("spine2", Vector3(0, s * 0.08 * moving, 0))
	_pose("head0", Vector3(-0.35 * _roar + sin(_phase * 2.0) * 0.03, 0, 0))
	_pose("head1", Vector3(-0.25 * _roar, 0, 0))
	_simulate(delta)


func _pose(bone_name: String, euler: Vector3) -> void:
	if not _bones.has(bone_name):
		return
	var node: Node3D = _bones[bone_name]
	var rest: Transform3D = _rest[bone_name]
	node.transform = Transform3D(rest.basis * Basis.from_euler(euler), rest.origin)


## Spring chains: joints follow where the rest pose would put them, but with inertia and gravity,
## then each bone is turned to point at the simulated position of the next joint.
func _simulate(delta: float) -> void:
	var dt := minf(delta, 1.0 / 30.0)
	for chain: Dictionary in _chains:
		var names: Array[String] = chain["names"]
		var k: float = chain["stiffness"]
		var target := _rest_points(names)
		if not chain.has("pos"):
			chain["pos"] = target.duplicate()
			chain["prev"] = target.duplicate()
		var pos: PackedVector3Array = chain["pos"]
		var prev: PackedVector3Array = chain["prev"]
		pos[0] = target[0]
		for i: int in range(1, pos.size()):
			var p := pos[i]
			var vel := (p - prev[i]) * DAMPING
			prev[i] = p
			pos[i] = p + vel + ((target[i] - p) * k + GRAVITY) * dt * dt
		for _pass: int in CONSTRAINT_PASSES:
			for i: int in range(1, pos.size()):
				var length := (target[i] - target[i - 1]).length()
				var d := pos[i] - pos[i - 1]
				if d.length() > 0.0001:
					pos[i] = pos[i - 1] + d.normalized() * length
		chain["pos"] = pos
		chain["prev"] = prev
		for i: int in names.size():
			_aim(names[i], pos[i], pos[i + 1])


## World positions of a chain's joints if every bone of it sat at rest under its moving parent.
func _rest_points(names: Array[String]) -> PackedVector3Array:
	var parent := _bone(names[0]).get_parent() as Node3D
	var xform := parent.global_transform * _rest_of(names[0])
	var points := PackedVector3Array([xform.origin])
	for i: int in names.size():
		points.append(xform * _dir_of(names[i]))
		if i + 1 < names.size():
			xform = xform * _rest_of(names[i + 1])
	return points


func _bone(bone_name: String) -> Node3D:
	var node: Node3D = _bones[bone_name]
	return node


func _rest_of(bone_name: String) -> Transform3D:
	var t: Transform3D = _rest[bone_name]
	return t


func _dir_of(bone_name: String) -> Vector3:
	var d: Vector3 = _dir[bone_name]
	return d


func _aim(bone_name: String, from: Vector3, to: Vector3) -> void:
	var node: Node3D = _bones[bone_name]
	var parent := node.get_parent() as Node3D
	var rest: Transform3D = _rest[bone_name]
	var rest_world := parent.global_transform * rest
	var want := to - from
	var have := rest_world.basis * _dir_of(bone_name)
	if want.length() < 0.0001 or have.length() < 0.0001:
		return
	var turn := Quaternion(have.normalized(), want.normalized())
	var world_basis := Basis(turn) * rest_world.basis
	node.transform = Transform3D(parent.global_transform.basis.inverse() * world_basis, rest.origin)
