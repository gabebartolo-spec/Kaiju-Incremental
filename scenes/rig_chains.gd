class_name RigChains
extends RefCounted
## A rig's spring chains (SpringChain: its runs of rig.json "physics" bones, tail, antennae,
## tentacles): joints follow where the (driven) rest pose would put them, with inertia and gravity,
## then each bone is turned to point at the simulated position of the next joint. Part of KaijuRig;
## presentation only.

var chains: Array[SpringChain] = []
var _rig: KaijuRig
## Time the chains have not stepped yet: they advance in fixed steps (tuning "chain" "step_hz").
var _owed := 0.0


## The chains of a rig built from bone defs (rig.json "bones").
func _init(rig: KaijuRig, defs: Array) -> void:
	_rig = rig
	var by_parent: Dictionary = {}
	for d: Dictionary in defs:
		var parent := str(d["parent"]) if d["parent"] != null else ""
		by_parent[parent] = by_parent.get(parent, []) + [str(d["name"])]
	for d: Dictionary in defs:
		var bone_name := str(d["name"])
		var parent := str(d["parent"]) if d["parent"] != null else ""
		var is_physics: bool = d["physics"]
		if is_physics and not _is_physics(defs, parent):
			chains.append(_chain_from(bone_name, by_parent))


## The chain that starts at `first_bone`, or null.
func named(first_bone: String) -> SpringChain:
	for chain: SpringChain in chains:
		if chain.names[0] == first_bone:
			return chain
	return null


## Steps every chain by delta (in fixed steps) and turns its bones onto it.
func simulate(delta: float) -> void:
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
			_rig.aim(chain.names[i], chain.pos[i], chain.pos[i + 1])
		if chain.contract != 1.0:
			_rig.bone(chain.names[0]).scale = Vector3.ONE * chain.contract


## The chain from `first` down its single children (by_parent: bone -> its children).
static func _chain_from(first: String, by_parent: Dictionary) -> SpringChain:
	var chain := SpringChain.new()
	chain.names.append(first)
	var walk := first
	while by_parent.has(walk):
		var children: Array = by_parent[walk]
		if children.size() != 1:
			break
		walk = str(children[0])
		chain.names.append(walk)
	for _n: String in chain.names:
		chain.drive.append(Basis.IDENTITY)
	return chain


## World positions of a chain's joints if every bone of it sat at its driven rest pose.
func _rest_points(chain: SpringChain) -> PackedVector3Array:
	var names := chain.names
	var parent := _rig.bone(names[0]).get_parent() as Node3D
	var first := _rig.rest_of(names[0])
	var shrink := Vector3.ONE * chain.contract
	var xform := (
		parent.global_transform
		* Transform3D((first.basis * chain.drive[0]).scaled(shrink), first.origin)
	)
	var points := PackedVector3Array([xform.origin])
	for i: int in names.size():
		points.append(xform * _rig.dir_of(names[i]))
		if i + 1 < names.size():
			var r := _rig.rest_of(names[i + 1])
			xform = xform * Transform3D(r.basis * chain.drive[i + 1], r.origin)
	return points


static func _is_physics(defs: Array, bone_name: String) -> bool:
	for d: Dictionary in defs:
		if str(d["name"]) == bone_name:
			var p: bool = d["physics"]
			return p
	return false
