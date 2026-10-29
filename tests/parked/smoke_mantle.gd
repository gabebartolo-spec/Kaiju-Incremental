extends RefCounted
## PARKED (director 2026-10-29): the smoke suite's octopus mantle probe; the cephalopod is not in
## the demo. Move back to tests/lib/ when work on it starts.


## The mantle voxels' node (which gait_radial scales to breathe) sizes the skin's mantle0 bone.
static func follows(kaiju: KaijuModel, skin: VoxelSkin) -> bool:
	var rig: KaijuRig = kaiju.find_children("*", "KaijuRig", true, false)[0]
	var held: Variant = rig.skins.get("mantle0", null)
	if not is_instance_valid(held):
		return false
	var mantle: Node3D = held
	mantle.scale = Vector3.ONE * 1.2  # a roar puff
	skin.sync()
	var m := skin.pose[rig.bone_names().find("mantle0")]
	return absf(Vector3(m.x.x, m.x.y, m.x.z).length() - 1.2) < 0.001
