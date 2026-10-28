extends "res://tests/lib/runner.gd"
## D-374 corrective helper joints (scenes/voxel_skin_helpers.gd): the Colossus's skin carries its
## hip, knee, web, ankle and belly helpers per leg by default, a helper's pose matches the
## reference maths (tools/kaiju_skin/skin_helpers.py pose(), numbers below from it), a helper sits
## still at rest, and a skin without a helper block has none.
##   godot --headless --path . --script tests/run_skin_helpers_tests.gd
## Seeded by design: fixed poses, no clock.

## The Colossus: five helpers a leg (tools/blender/croc_adult3_helpers.json).
const COLOSSUS := "res://assets/kaiju/reptilian_adult"
const COLOSSUS_HELPERS := 10
## A skin with no helpers.
const PLAIN := "res://assets/kaiju/insectoid_adult"
## Matrix entries agree to this (float32 file values against float64 reference).
const CLOSE := 1e-4


func suite_name() -> String:
	return "Skin helpers"


func run_checks() -> void:
	await _t("_check_colossus_has_helpers")
	await _t("_check_reference_maths")
	await _t("_check_still_at_rest")
	await _t("_check_plain_skin_has_none")


func _helpers_of(base: String) -> VoxelSkinHelpers:
	var raw := FileAccess.get_file_as_bytes(base + ".vskin").decompress_dynamic(
		-1, FileAccess.COMPRESSION_GZIP
	)
	return VoxelSkinHelpers.read(raw, VoxelSkin._filler_end(raw))


func _check_colossus_has_helpers() -> void:
	var helpers := _helpers_of(COLOSSUS)
	check(helpers.count == COLOSSUS_HELPERS, "the Colossus skin carries 10 helper joints")
	var def: Dictionary = Content.species_def("reptilian")
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, "adult")
	root.add_child(kaiju)
	for frame: int in 20:
		kaiju.position.z -= 0.05
		kaiju.animate(1.0 / 60.0, 1.0)
	var skins := kaiju.find_children("VoxelSkin", "VoxelSkin", true, false)
	check(skins.size() == 1, "the Colossus is drawn by its voxel skin, helpers and all")
	if skins.size() == 1:
		var skin: VoxelSkin = skins[0]
		var bone_names: Array = skin.get_parent().call("bone_names")
		var rig_bones: int = bone_names.size()
		var posed: int = skin.pose.size()
		check(posed == rig_bones + COLOSSUS_HELPERS, "every frame poses each rig bone and helper")
		var finite := true
		for m: Projection in skin.pose:
			finite = finite and m.x.is_finite() and m.y.is_finite() and m.z.is_finite() and m.w.is_finite()
		check(finite, "every helper pose is finite while the Colossus walks")
	kaiju.queue_free()


## One helper (frac 0.4, centre (1, 2, 3), push (0.5, -0.2, 0.1), push-per-turn rows
## (0.1 0.2 0) (0 0.3 0.1) (0.2 0 0.1)) between two turned, moved bones.
func _check_reference_maths() -> void:
	var a := Transform3D(Basis(Vector3(0.3, 0.9, 0.1).normalized(), 0.7), Vector3(1, 0, 2))
	var b := Transform3D(Basis(Vector3(1, 0.2, -0.4).normalized(), 1.9), Vector3(0, -1, 3))
	var want_basis := Basis(
		Vector3(0.82435, 0.03222, -0.565163),
		Vector3(0.408222, 0.657833, 0.632938),
		Vector3(0.392176, -0.752474, 0.529132)
	)
	var want := {1: Vector3(-0.134586, -0.856861, 1.362362), 0: Vector3(-0.053419, -0.9859, 1.381531)}
	for grow: int in want:
		var got := _one(grow).helper(a, b, 0)
		check(_near(got.basis, want_basis), "helper turn matches the reference (grow %d)" % grow)
		var target: Vector3 = want[grow]
		var moved: bool = got.origin.distance_to(target) < CLOSE
		check(moved, "helper move matches the reference (grow %d)" % grow)


func _check_still_at_rest() -> void:
	var got := _one(1).helper(Transform3D.IDENTITY, Transform3D.IDENTITY, 0)
	var still: bool = _near(got.basis, Basis.IDENTITY) and got.origin.length() < CLOSE
	check(still, "a helper sits still at rest")


func _check_plain_skin_has_none() -> void:
	check(_helpers_of(PLAIN).count == 0, "a skin with no helper block has no helpers")


func _one(grow: int) -> VoxelSkinHelpers:
	var raw := PackedByteArray()
	raw.resize(6 + VoxelSkinHelpers.HELPER_BYTES)
	raw.encode_u8(0, 72)  # H E L P
	raw.encode_u8(1, 69)
	raw.encode_u8(2, 76)
	raw.encode_u8(3, 80)
	raw.encode_u16(4, 1)
	raw.encode_u8(6, 0)
	raw.encode_u8(7, 1)
	raw.encode_u8(8, grow)
	var floats: PackedFloat32Array = [
		0.4, 1, 2, 3, 0.5, -0.2, 0.1, 0.1, 0, 0.2, 0.2, 0.3, 0, 0, 0.1, 0.1
	]
	for i: int in floats.size():
		raw.encode_float(10 + i * 4, floats[i])
	return VoxelSkinHelpers.read(raw, 0)


func _near(x: Basis, y: Basis) -> bool:
	for i: int in 3:
		if (x[i] - y[i]).length() > CLOSE:
			return false
	return true
