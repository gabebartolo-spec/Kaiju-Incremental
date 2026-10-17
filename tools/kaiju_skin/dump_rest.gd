extends SceneTree
## Writes every rigged kaiju's rest pose as the game builds it (KaijuRig.load_from, arms already
## lowered), for tools/kaiju_skin/bake.py. Run by tools/kaiju_skin/bake_all.sh:
##   godot --headless --path . --script tools/kaiju_skin/dump_rest.gd -- <out.json>
## Per kaiju: the voxel size and, per bone in rig.json order, its rest transform relative to the
## rig (rig units), as 12 numbers: basis columns x, y, z, then origin.

const SPECIES: Array[String] = ["reptilian", "insectoid", "cephalopod"]
const STAGES: Array[String] = ["baby", "adolescent", "adult"]


func _initialize() -> void:
	var out_path := OS.get_cmdline_user_args()[0]
	var dump := {}
	for species: String in SPECIES:
		for stage: String in STAGES:
			var name := "%s_%s" % [species, stage]
			var rig := KaijuRig.load_from(
				"res://assets/kaiju/" + name, KaijuModel.MODEL_HEIGHT, 1.0
			)
			if rig == null:
				continue
			var bones: Array = []
			for bone_name: String in rig.bone_names():
				var t := _to_rig(rig, rig.bone(bone_name))
				var head := rig.head_of(bone_name)
				var xform: Array = []
				for v: Vector3 in [t.basis.x, t.basis.y, t.basis.z, t.origin]:
					xform.append_array([v.x, v.y, v.z])
				bones.append({"name": bone_name, "xform": xform, "head": [head.x, head.y, head.z]})
			dump[name] = {"voxel": rig.voxel_size(), "bones": bones}
			rig.free()
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(dump))
	f.close()
	print("dumped %d rigs" % dump.size())
	quit()


## A bone's transform relative to the rig root, walking up its parents (the rig is not in a tree).
static func _to_rig(rig: KaijuRig, node: Node3D) -> Transform3D:
	var t := node.transform
	var parent := node.get_parent()
	while parent != rig and parent is Node3D:
		t = (parent as Node3D).transform * t
		parent = parent.get_parent()
	return t
