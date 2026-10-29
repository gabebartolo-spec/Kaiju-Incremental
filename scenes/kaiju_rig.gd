class_name KaijuRig
extends Node3D
## A rigged voxel kaiju (tools/blender/rig_voxel.py): one node per bone, each carrying its
## own voxels, so the body bends where the real one would. A gait per body plan (KaijuGait)
## moves it: planted feet solved by IK, a body that carries its weight, a head that hunts.
## Tails, antennae and tentacles ("physics" bones) are spring chains the gait can steer.
## Presentation only: the gait follows the node's motion and never moves the kaiju. Faces -Z.

## A foot (or a tentacle's grip) came down, on the frame it touches: which ("left"/"right",
## "fl"/"fr"/"bl"/"br", "t0".."t7"), how hard (0..1: walk speed x life stage, 1 = an adult's
## stomp) and where (world). For footfall sounds, dust and camera shake; presentation only.
signal foot_planted(side: String, strength: float, at: Vector3)

## Joint filler cubes are this much smaller, so they stay inside the skin until a bend opens it.
const JOINT_INSET := 0.82


## A run of physics bones (tail, antenna, tentacle) simulated as Verlet points.
class SpringChain:
	var names: Array[String] = []
	var stiffness := Num.f(Content.section("chain")["stiffness"])
	var gravity_scale := 1.0
	## Extra rotation per bone on top of its rest pose: how the gait steers the chain.
	var drive: Array[Basis] = []
	## Joint world positions this frame and last frame (index 0 is the root).
	var pos := PackedVector3Array()
	var prev := PackedVector3Array()
	## When set, the joint at that index is pinned to this world point (a tentacle tip gripping).
	var pins: Dictionary = {}
	## Joints never sink below this world height (a tentacle lying on the street).
	var ground := -INF
	## Whole-chain contraction (1 = rest length): a gripping tentacle shortens as it hauls.
	var contract := 1.0

	## Throws every joint (more towards the tip): a stomp whips the tail.
	func kick(velocity: Vector3, dt: float) -> void:
		for i: int in range(1, pos.size()):
			prev[i] -= velocity * dt * float(i) / (pos.size() - 1)


var height_units: float
## "biped", "hexapod" or "radial" (rig.json "type"); picks the gait.
var body_plan := "biped"
var gait: KaijuGait
var chains: Array[SpringChain] = []
## name -> how far that bone turns about x to shut (rig.json "close": an open sculpted jaw).
var bone_close: Dictionary = {}
## Bones that rest in a sculpted snarl (rig.json "snarl"): their mouth shows true colours.
var bone_snarl: Dictionary = {}
## name -> the MultiMeshInstance3D drawing that bone's own voxels (its skin).
var skins: Dictionary = {}
var _bones: Dictionary = {}  # name -> Node3D
var _rest: Dictionary = {}  # name -> Transform3D (local rest)
var _dir: Dictionary = {}  # name -> rest head->tail vector, in the bone's own space
var _head: Dictionary = {}  # name -> rest head, rig space
var _parent: Dictionary = {}  # name -> parent bone name ("" for the root)
var _voxels: Dictionary = {}  # name -> VoxelBuilder of that bone's cells (rig space, voxel units)
var _voxel := 1.0
var _glow := 1.5
## Time the chains have not stepped yet: they advance in fixed steps (tuning "chain" "step_hz").
var _owed := 0.0


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
	spec["clips"] = KaijuClips.read(base + ".kclip")  # D-047: null for a kaiju without clips
	var rig := KaijuRig.new()
	rig._build(spec, model.frames[0], model_height / model.height, glow)
	return rig


## A rig built in code (no files): spec as in rig.json, voxels tagged with bone index + 1.
static func from_spec(spec: Dictionary, vox: VoxelBuilder, voxel: float, glow: float) -> KaijuRig:
	var rig := KaijuRig.new()
	rig._build(spec, vox, voxel, glow)
	return rig


func _build(spec: Dictionary, vox: VoxelBuilder, voxel: float, glow: float) -> void:
	_voxel = voxel
	_glow = glow
	body_plan = str(spec.get("type", "biped"))
	var defs: Array = spec["bones"]
	var heads: Dictionary = {}
	for d: Dictionary in defs:
		heads[str(d["name"])] = _vec(d["head"]) * voxel
	# Split the voxels by bone (the flags byte).
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
		var parent_head: Vector3 = heads.get(parent_name, Vector3.ZERO)
		node.position = head - parent_head
		_bones[bone_name] = node
		_rest[bone_name] = node.transform
		_head[bone_name] = head
		_parent[bone_name] = parent_name
		bone_close[bone_name] = Num.f(d.get("close", 0.0))
		bone_snarl[bone_name] = d.get("snarl", false) == true
		_dir[bone_name] = _vec(d["tail"]) * voxel - head
		if per_bone.has(i):
			_voxels[bone_name] = per_bone[i]
	# Parented once every bone exists: a rig.json lists bones added later (the croc's collar
	# bones) after the bones they carry (rig_from_skin.py extra_order), so it is not parents first.
	for bone_name: String in _parent:
		var parent: Node3D = _bones.get(_parent[bone_name], self)
		var child: Node3D = _bones[bone_name]
		parent.add_child(child)
	var bands := RigJoints.overlap(self)
	for bone_name: String in _voxels:
		var part: VoxelBuilder = _voxels[bone_name]
		skins[bone_name] = attach_voxels(bone_name, part)
	for bone_name: String in bands:
		var band: VoxelBuilder = bands[bone_name]
		attach_voxels(bone_name, band, null, JOINT_INSET)
	height_units = vox.height_hint * voxel if vox.height_hint > 0 else 10.0
	_relax_arms()
	_collect_chains(defs)
	match body_plan:
		"hexapod":
			gait = HexapodGait.new(self)
		"radial":
			gait = RadialGait.new(self)
		_:
			gait = ClipGait.or_biped(self, spec.get("clips"))


## Shows a set of voxels (rig-space cells) on a bone, positioned relative to its rest head.
func attach_voxels(
	bone_name: String, part: VoxelBuilder, under: Node3D = null, inset: float = 1.0
) -> Node3D:
	part.salt = 7
	part.inset = inset
	var head: Vector3 = _head[bone_name]
	var mmi := part.build({}, _voxel, _glow, -head)
	mmi.layers = KaijuModel.BODY_LAYER | KaijuModel.RIM_LAYER
	var holder: Node3D = under if under != null else bone(bone_name)
	holder.add_child(mmi)
	return mmi


## Models arrive in a T-pose; a kaiju carries its arms lowered and reaching forward. A biped's
## rest pose is its standing arm pose (BipedSwing: hanging, elbow bent, hands at the belly), so a
## skin bound to the rest pose matches what is shown and the gait only adds small swings to it.
func _relax_arms() -> void:
	var bases := BipedSwing.rest_arm_bases(self) if body_plan == "biped" else {}
	for side: String in ["l", "r"] if bases.is_empty() else []:
		var root := "arm_%s0" % side
		if _bones.has(root):
			var outward: float = signf(dir_of(root).x)
			var lower := Basis(Vector3.BACK, -outward * 0.95)
			bases[root] = Basis(Vector3.UP, outward * 0.35) * lower * rest_of(root).basis
	for n: String in bases:
		var b: Basis = bases[n]
		_rest[n] = Transform3D(b, rest_of(n).origin)
		bone(n).transform = rest_of(n)


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
		if starts_chain:
			var chain := SpringChain.new()
			chain.names.append(bone_name)
			var walk := bone_name
			while by_parent.has(walk):
				var children: Array = by_parent[walk]
				if children.size() != 1:
					break
				walk = str(children[0])
				if not _is_physics(defs, walk):
					break  # a run of physics bones ends at a plain one (the adult croc's clip-only tail tip)
				chain.names.append(walk)
			for _n: String in chain.names:
				chain.drive.append(Basis.IDENTITY)
			chains.append(chain)


func _is_physics(defs: Array, bone_name: String) -> bool:
	for d: Dictionary in defs:
		if str(d["name"]) == bone_name:
			var p: bool = d["physics"]
			return p
	return false


static func _vec(v: Variant) -> Vector3:
	var a: Array = v
	return Vector3(Num.f(a[0]), Num.f(a[1]), Num.f(a[2]))


## The gait and the helpers it builds hold each other (HexapodUpper.gait, BipedHead.gait,
## LegReach.gait), and the engine frees a reference-counted object only once nothing counts it, so
## every rig that was freed kept its gait alive to the end of the run (the leaked instances at
## exit, debt row 2). Cut the rings as the rig is deleted (SimTeardown, as RampageSim.dispose
## does for the sim).
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and gait != null:
		SimTeardown.cut(gait)


func roar() -> void:
	gait.roar()


func stomp() -> void:
	gait.stomp()


## Call every frame. moving (0..1) is kept for callers; the gait reads the real motion itself.
func animate(delta: float, _moving: float) -> void:
	if not is_inside_tree():
		return
	gait.update(delta)


# --- bone access for gaits -----------------------------------------------------------------------


func has_bone(bone_name: String) -> bool:
	return _bones.has(bone_name)


func bone(bone_name: String) -> Node3D:
	var node: Node3D = _bones[bone_name]
	return node


func rest_of(bone_name: String) -> Transform3D:
	var t: Transform3D = _rest[bone_name]
	return t


func dir_of(bone_name: String) -> Vector3:
	var d: Vector3 = _dir[bone_name]
	return d


## Rest head of a bone in rig space (the rig's own units: model height ~10).
func head_of(bone_name: String) -> Vector3:
	var h: Vector3 = _head[bone_name]
	return h


func parent_of(bone_name: String) -> String:
	return str(_parent[bone_name])


func voxels_of(bone_name: String) -> VoxelBuilder:
	if not _voxels.has(bone_name):
		return null
	var part: VoxelBuilder = _voxels[bone_name]
	return part


## Voxel size in rig units.
func voxel_size() -> float:
	return _voxel


func bone_names() -> Array[String]:
	var out: Array[String] = []
	for n: String in _bones:
		out.append(n)
	return out


## Poses a bone by a rotation on top of its rest pose, and an offset in its parent's space.
func pose(bone_name: String, euler: Vector3, offset: Vector3 = Vector3.ZERO) -> void:
	if not _bones.has(bone_name):
		return
	var node: Node3D = _bones[bone_name]
	var rest: Transform3D = _rest[bone_name]
	node.transform = Transform3D(rest.basis * Basis.from_euler(euler), rest.origin + offset)


func pose_basis(bone_name: String, b: Basis, offset: Vector3 = Vector3.ZERO) -> void:
	var node: Node3D = _bones[bone_name]
	var rest: Transform3D = _rest[bone_name]
	node.transform = Transform3D(rest.basis * b, rest.origin + offset)


## Turns a bone (from its rest pose under its current parent) so its head->tail points from -> to
## (or, given `rest_dir`, so that rest vector does: a foot aimed by its toe tip past a toe bone).
func aim(bone_name: String, from: Vector3, to: Vector3, rest_dir := Vector3.ZERO) -> void:
	var node: Node3D = _bones[bone_name]
	var parent := node.get_parent() as Node3D
	var rest: Transform3D = _rest[bone_name]
	var rest_world := parent.global_transform * rest
	var want := to - from
	var have := rest_world.basis * (dir_of(bone_name) if rest_dir == Vector3.ZERO else rest_dir)
	if want.length() < 0.0001 or have.length() < 0.0001:
		return
	var turn := Quaternion(have.normalized(), want.normalized())
	var world_basis := Basis(turn) * rest_world.basis
	node.transform = Transform3D(parent.global_transform.basis.inverse() * world_basis, rest.origin)


## Sets a bone's world orientation (an orthonormal basis; the rig's scale is kept).
func set_world_basis(bone_name: String, world_basis: Basis) -> void:
	var node: Node3D = _bones[bone_name]
	var parent := node.get_parent() as Node3D
	var pb := parent.global_transform.basis
	var scaled := world_basis.scaled(pb.get_scale())
	node.transform = Transform3D(pb.inverse() * scaled, node.transform.origin)


## World position of a bone's tail as posed now.
func tail_world(bone_name: String) -> Vector3:
	return bone(bone_name).global_transform * dir_of(bone_name)


# --- spring chains -------------------------------------------------------------------------------


## Spring chains: joints follow where the (driven) rest pose would put them, with inertia and
## gravity, then each bone is turned to point at the simulated position of the next joint.
func simulate_chains(delta: float) -> void:
	var cfg := Content.section("chain")
	var h := 1.0 / Num.f(cfg["step_hz"])
	_owed += delta
	var steps := mini(int(_owed / h + 1e-6), Num.i(cfg["max_substeps"]))
	_owed = clampf(_owed - steps * h, 0.0, h)  # a long frame's excess time is dropped, not caught up
	for chain: SpringChain in chains:
		var target := _rest_points(chain)
		if chain.pos.is_empty():
			chain.pos = target.duplicate()
			chain.prev = target.duplicate()
		chain.pos[0] = target[0]
		for _step: int in steps:
			ChainStep.run(chain, target, h)
		for i: int in chain.names.size():
			aim(chain.names[i], chain.pos[i], chain.pos[i + 1])
		if chain.contract != 1.0:
			bone(chain.names[0]).scale = Vector3.ONE * chain.contract


## World positions of a chain's joints if every bone of it sat at its driven rest pose.
func _rest_points(chain: SpringChain) -> PackedVector3Array:
	var names := chain.names
	var parent := bone(names[0]).get_parent() as Node3D
	var first := rest_of(names[0])
	var shrink := Vector3.ONE * chain.contract
	var xform := (
		parent.global_transform
		* Transform3D((first.basis * chain.drive[0]).scaled(shrink), first.origin)
	)
	var points := PackedVector3Array([xform.origin])
	for i: int in names.size():
		points.append(xform * dir_of(names[i]))
		if i + 1 < names.size():
			var r := rest_of(names[i + 1])
			xform = xform * Transform3D(r.basis * chain.drive[i + 1], r.origin)
	return points


func chain_named(first_bone: String) -> SpringChain:
	for chain: SpringChain in chains:
		if chain.names[0] == first_bone:
			return chain
	return null
