extends RefCounted
## Nothing a freed model or vehicle built stays alive (debt row 2, what the engine reports at exit):
##  - the vehicle parts' shared voxel meshes are built without leaving a node behind (the
##    MultiMeshInstance3D that held each part's MultiMesh was dropped unfreed, one per part);
##  - a freed kaiju lets go of its gait: the gait and the helpers it builds hold each other, and
##    without KaijuRig's cut every freed rig kept its gait alive to the end of the run.
## Seeded by design: nothing here is random.

const SPECIES: Array[String] = ["reptilian", "insectoid", "cephalopod"]


static func check(check: Callable, root: Node) -> void:
	_vehicle_parts(check)
	for species_id: String in SPECIES:
		await _rig_gait(check, root, species_id)


## Teeth: the cache is emptied first, so the build really runs.
static func _vehicle_parts(check: Callable) -> void:
	VehicleParts.clear_cache()
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	TankModel.new().free()
	HelicopterModel.new().free()
	var after := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	check.call(
		after == before,
		"building the tank and helicopter parts orphans no node (%d -> %d)" % [before, after]
	)


static func _rig_gait(check: Callable, root: Node, species_id: String) -> void:
	var def: Dictionary = Content.species_def(species_id)
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new(species_id, colors, "adult")
	root.add_child(kaiju)
	await root.get_tree().process_frame
	kaiju.animate(1.0 / 60.0, 1.0)
	var rigs := kaiju.find_children("*", "KaijuRig", true, false)
	check.call(rigs.size() == 1, "the %s has one rig" % species_id)
	if rigs.size() != 1:
		kaiju.free()
		return
	var gait: WeakRef = weakref((rigs[0] as KaijuRig).gait)
	kaiju.free()
	check.call(gait.get_ref() == null, "the %s's gait is freed with its rig" % species_id)
