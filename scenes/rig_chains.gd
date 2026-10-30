class_name RigChains
extends RefCounted
## The spring chains of a rig.json: each run of physics bones from its first, one child at a time.


static func collect(defs: Array) -> Array[KaijuRig.SpringChain]:
	var chains: Array[KaijuRig.SpringChain] = []
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
			var chain := KaijuRig.SpringChain.new()
			chain.names.append(bone_name)
			var walk := bone_name
			while by_parent.has(walk):
				var children: Array = by_parent[walk]
				if children.size() != 1:
					break
				walk = str(children[0])
				if not _is_physics(defs, walk):
					break  # a physics run ends at a plain bone (the adult croc's clip-only tail tip)
				chain.names.append(walk)
			for _n: String in chain.names:
				chain.drive.append(Basis.IDENTITY)
			chains.append(chain)
	return chains


static func _is_physics(defs: Array, bone_name: String) -> bool:
	for d: Dictionary in defs:
		if str(d["name"]) == bone_name:
			var p: bool = d["physics"]
			return p
	return false
