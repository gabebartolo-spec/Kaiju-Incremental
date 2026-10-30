class_name VoxelSkinFiles
extends RefCounted
## Finds and loads a kaiju's voxel skin files (VoxelSkin).


## The skin for a rig built from <base>, or null when no .vskin was baked for it (the rig then
## keeps drawing its own voxels). Call right after KaijuRig.load_from, before it animates.
static func load_for(rig: KaijuRig, base: String) -> VoxelSkin:
	var path := base + ".vskin"
	if not FileAccess.file_exists(path):
		return null
	var raw := FileAccess.get_file_as_bytes(path).decompress_dynamic(
		-1, FileAccess.COMPRESSION_GZIP
	)
	if (
		raw.size() < 26
		or raw.slice(0, 4).get_string_from_ascii() != "VSKN"
		or raw.decode_u32(4) != VoxelSkin.VERSION
	):
		push_warning("VoxelSkin: unreadable " + path)
		return null
	var count_bones := raw.decode_u16(16)
	var helpers := VoxelSkinHelpers.read(raw, VoxelSkin._filler_end(raw))
	var rig_bones := count_bones - helpers.count
	if (
		rig_bones != rig.bone_names().size()
		or count_bones > VoxelSkin.MAX_BONES
		or not helpers.fits(rig_bones)
	):
		push_warning(
			"VoxelSkin: %s is stale (bones changed): rerun tools/kaiju_skin/bake_all.sh" % path
		)
		return null
	var skin := VoxelSkin.new()
	skin._helpers = helpers
	skin._setup(rig, raw)
	return skin


## The Blender skin files listed for <base> in its folder's skin_weights.json, or none.
static func skin_files(base: String) -> Array[String]:
	var out: Array[String] = []
	var listing := base.get_base_dir().path_join("skin_weights.json")
	if not FileAccess.file_exists(listing):
		return out
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(listing))
	if not parsed is Dictionary:
		return out
	var table: Dictionary = parsed
	var rel: Variant = table.get(base.get_file(), null)
	if not rel is String:
		return out
	var meta := base.get_base_dir().path_join(str(rel))
	var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta))
	if not info is Dictionary:
		return out
	var skin: Dictionary = info
	out.append(meta)
	var weights := meta.get_base_dir().path_join(str(skin.get("weights_file", "")))
	out.append(weights)
	# Its welded triangles, when exported (tools/kaiju_skin/skin_faces.py).
	var faces := weights.get_basename() + ".skinf"
	if FileAccess.file_exists(faces):
		out.append(faces)
	return out
