class_name VoxelSkin
extends Node3D
## D-041: draws a rigged kaiju as voxel cubes on a smooth skin, from its baked <base>.vskin
## (tools/kaiju_skin/bake_all.sh). The KaijuRig keeps animating as before; this copies every
## bone's pose into the two shaders each frame, so joints bend without the per-bone voxels'
## tearing, gaps and speckle. The rig's own voxels stay built (gaits still toggle them) but are
## moved to render layer 0, where nothing draws them. Presentation only. Child of the rig.

const CUBE_SHADER := preload("res://scenes/voxel_skin.gdshader")
const FILL_SHADER := preload("res://scenes/voxel_skin_fill.gdshader")
## Bones the shaders take (the hydra has 79).
const MAX_BONES := 128
## Gzip'd .vskin layout version this reader understands (tools/kaiju_skin/bake.py).
const VERSION := 2
## Generous bounds: the shaders move every vertex away from where the engine thinks it is.
## A cell's centre sits half a voxel up from its corner (VoxelBuilder's lift).
const HALF_UP := Vector3(0, 0.5, 0)
## A cube of an eye, added to the mouth-inside flag (1) when both apply (EyeZones, the blink).
const EYE_FLAG := 2
const BOUNDS := AABB(Vector3(-12, -4, -12), Vector3(24, 24, 24))

## Debug: draw rigged kaiju the old way, rigid voxels per bone (pass "--kaiju-rigid" after "--").
static var show_rigid_voxels := "--kaiju-rigid" in OS.get_cmdline_user_args()

## The bone matrices sent to the shaders last frame, and whether the mouth's inside showed.
var pose: Array[Projection] = []
var mouth_open := false
## The breath (rig units, signed) and the lids (0 open .. 1 shut) the shaders show (ClipAlive).
var breath := 0.0
## The biggest push now (rig units), the breath's place in its cycle and its lag down the back
## (ClipAlive; the shaders draw the push from these, `breath` is the sum for tests).
var breath_peak := 0.0
var breath_phase := 0.0
var breath_lag := 0.0
var blink := 0.0
var _rig: KaijuRig
var _axis: Array[int] = [-1, -1]  # the bones the breath's spine axis runs between
var _nodes: Array[Node3D] = []
var _binds: Array[Transform3D] = []
var _cubes: ShaderMaterial
var _cube_node: MultiMeshInstance3D
var _fill: ShaderMaterial
var _hid_rig_voxels := 0


## Puts the skin on a rig built from <base> (KaijuModel does this); null when show_rigid_voxels is
## set or no skin was baked, and the rig then draws its own voxels.
static func attach(rig: KaijuRig, base: String) -> VoxelSkin:
	if show_rigid_voxels:
		return null
	var skin := load_for(rig, base)
	if skin != null:
		rig.add_child(skin)
	return skin


## Calls sync() on a skin that may be null (a kaiju without one).
static func sync_if(skin: VoxelSkin) -> void:
	if skin != null:
		skin.sync()


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
		or raw.decode_u32(4) != VERSION
	):
		push_warning("VoxelSkin: unreadable " + path)
		return null
	var count_bones := raw.decode_u16(16)
	if count_bones != rig.bone_names().size() or count_bones > MAX_BONES:
		push_warning(
			"VoxelSkin: %s is stale (bones changed): rerun tools/kaiju_skin/bake_all.sh" % path
		)
		return null
	var skin := VoxelSkin.new()
	skin._setup(rig, raw, base.get_file())
	return skin


## The first 8 bytes of SHA-256 over <base>.kvox, <base>.rig.json and, when skin_weights.json lists
## one for this kaiju, its Blender skin (.skin.json, then its weights file): what a fresh .vskin
## carries (tools/kaiju_skin/bake.py source_stamp()).
static func source_stamp(base: String) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(FileAccess.get_file_as_bytes(base + ".kvox"))
	ctx.update(FileAccess.get_file_as_bytes(base + ".rig.json"))
	for path: String in skin_files(base):
		ctx.update(FileAccess.get_file_as_bytes(path))
	return ctx.finish().slice(0, 8)


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


## The stamp a baked <base>.vskin was made from (empty if there is none).
static func baked_stamp(base: String) -> PackedByteArray:
	if not FileAccess.file_exists(base + ".vskin"):
		return PackedByteArray()
	var raw := FileAccess.get_file_as_bytes(base + ".vskin").decompress_dynamic(
		-1, FileAccess.COMPRESSION_GZIP
	)
	return raw.slice(8, 16) if raw.size() >= 26 else PackedByteArray()


func _setup(rig: KaijuRig, raw: PackedByteArray, base_name: String) -> void:
	_rig = rig
	var eyes := EyeZones.new(base_name)
	name = "VoxelSkin"
	for bone_name: String in rig.bone_names():
		var node := rig.bone(bone_name)
		_nodes.append(node)
		_binds.append(_to_rig(node).affine_inverse())
	var voxel := raw.decode_float(18)
	var cells := raw.decode_u32(22)
	var at := 26
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE * voxel * Look.value("voxel_inset")
	mm.mesh = box
	mm.instance_count = cells
	mm.custom_aabb = BOUNDS
	for i: int in cells:
		var cell := Vector3i(raw.decode_s16(at), raw.decode_s16(at + 2), raw.decode_s16(at + 4))
		var base := Color8(raw[at + 6], raw[at + 7], raw[at + 8])
		var tint := Look.jitter(base, cell, 7)
		tint.a = raw[at + 14] / 255.0  # the second bone's weight rides in the colour's alpha
		mm.set_instance_transform(i, Transform3D(Basis(), (Vector3(cell) + HALF_UP) * voxel))
		mm.set_instance_color(i, tint)
		var flag := raw[at + 9]
		if eyes.claim((Vector3(cell) + HALF_UP) * voxel, base):
			flag += EYE_FLAG  # 3: a dark pupil the mouth test caught keeps its dark seam
		mm.set_instance_custom_data(i, pack(flag, raw.slice(at + 10, at + 14)))
		at += 15
	_cubes = ShaderMaterial.new()
	_cubes.shader = CUBE_SHADER
	_cubes.set_shader_parameter("voxel", voxel)
	_cubes.set_shader_parameter("seam_dark", BipedHead.SEAM_DARK)
	_cubes.set_shader_parameter("lid_colour", eyes.lid_colour())
	# The kaiju's roughness doubles as its tag in the normal buffer: the crease pass skips it.
	_cubes.set_shader_parameter("roughness_value", Look.value("kaiju_roughness"))
	var cubes := MultiMeshInstance3D.new()
	_cube_node = cubes
	cubes.multimesh = mm
	cubes.material_override = _cubes
	cubes.custom_aabb = BOUNDS
	cubes.layers = KaijuModel.BODY_LAYER | KaijuModel.RIM_LAYER
	add_child(cubes)
	_setup_fill(raw, at)
	_setup_breath()
	_hide_rig_voxels()


## The filler under the cubes (watertight skin between them), from the file's mesh at byte `at`.
func _setup_fill(raw: PackedByteArray, start: int) -> void:
	var verts := raw.decode_u32(start)
	var arrays := _fill_vertices(raw, start + 4, verts)
	var at := start + 4 + verts * 20
	var indices := raw.decode_u32(at)
	if verts == 0 or indices == 0:
		return
	arrays[Mesh.ARRAY_INDEX] = raw.slice(at + 4, at + 4 + indices * 4).to_int32_array()
	var flags := (
		(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	_fill = ShaderMaterial.new()
	_fill.shader = FILL_SHADER
	_fill.set_shader_parameter("roughness_value", Look.value("kaiju_roughness"))
	var fill := MeshInstance3D.new()
	fill.mesh = mesh
	fill.material_override = _fill
	fill.custom_aabb = BOUNDS
	fill.layers = KaijuModel.BODY_LAYER | KaijuModel.RIM_LAYER
	add_child(fill)


## The filler's vertex arrays from `verts` vertices (20 bytes each) at byte `at`.
func _fill_vertices(raw: PackedByteArray, start: int, verts: int) -> Array:
	var at := start
	var pos := PackedVector3Array()
	var col := PackedColorArray()
	var custom0 := PackedFloat32Array()
	var custom1 := PackedFloat32Array()
	pos.resize(verts)
	col.resize(verts)
	custom0.resize(verts * 4)
	custom1.resize(verts * 4)
	for i: int in verts:
		pos[i] = Vector3(raw.decode_float(at), raw.decode_float(at + 4), raw.decode_float(at + 8))
		col[i] = Color8(raw[at + 12], raw[at + 13], raw[at + 14])
		var w0 := raw[at + 18] / 255.0
		var w1 := raw[at + 19] / 255.0
		custom0[i * 4] = raw[at + 15]
		custom0[i * 4 + 1] = raw[at + 16]
		custom0[i * 4 + 2] = raw[at + 17]
		custom0[i * 4 + 3] = w0
		custom1[i * 4] = w1
		custom1[i * 4 + 1] = maxf(0.0, 1.0 - w0 - w1)
		at += 20
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_CUSTOM0] = custom0
	arrays[Mesh.ARRAY_CUSTOM1] = custom1
	return arrays


## The breath's per-bone shares and look, from "croc_idle" tuning (a body without those bones
## never gets a push).
func _setup_breath() -> void:
	var cfg := Content.section("croc_idle")
	var shares: Dictionary = cfg["skin_bones"]
	var names := _rig.bone_names()
	var k := PackedFloat32Array()
	k.resize(MAX_BONES)
	for i: int in names.size():
		k[i] = Num.f(shares.get(names[i], 0.0))
	_axis = [names.find("spine0"), names.find("head0")]
	for mat: ShaderMaterial in [_cubes, _fill]:
		if mat != null:
			mat.set_shader_parameter("breath_k", k)
			mat.set_shader_parameter("breath_lift", Num.f(cfg["skin_lift"]))
			mat.set_shader_parameter("breath_belly", Num.f(cfg["skin_belly"]))
			mat.set_shader_parameter(
				"breath_shape", Vector2(Num.f(cfg["inhale"]), Num.f(cfg["pause"]))
			)


## A voxel's bones for INSTANCE_CUSTOM, as small whole numbers: the compatibility renderer keeps
## per-instance data at half precision (exact only up to 2048), where bigger packed numbers broke
## the mantis (PR #15 review). Bone 0 (+128 for a mouth-inside voxel), bone 1, bone 2, weight 0
## (0..255). The voxel's centre is its instance transform; weight 1 is the colour's alpha.
static func pack(flags: int, bones_weight: PackedByteArray) -> Color:
	return Color(
		float(bones_weight[0] + 128 * flags),
		float(bones_weight[1]),
		float(bones_weight[2]),
		float(bones_weight[3]),
	)


## Copies the rig's current pose into the shaders. Call after the rig animates, every frame.
func sync() -> void:
	if _hid_rig_voxels < 2:  # a gait may add voxels to a bone while it sets up
		_hide_rig_voxels()
	var to_rig := _rig.global_transform.affine_inverse()
	pose.resize(_nodes.size())
	for i: int in _nodes.size():
		pose[i] = Projection(to_rig * _skin_global(i) * _binds[i])
	_cubes.set_shader_parameter("bones", pose)
	_cubes.set_shader_parameter("to_skin", Projection(_cube_node.global_transform.affine_inverse()))
	if _fill != null:
		_fill.set_shader_parameter("bones", pose)
	mouth_open = _mouth_showing()
	_cubes.set_shader_parameter("mouth_open", 1.0 if mouth_open else 0.0)
	_cubes.set_shader_parameter("blink", blink)
	_sync_breath(to_rig)


## The breath and the spine axis it pushes out from, this frame.
func _sync_breath(to_rig: Transform3D) -> void:
	if _axis[0] < 0 or _axis[1] < 0:
		return
	var a := to_rig * _nodes[_axis[0]].global_position
	var b := to_rig * _nodes[_axis[1]].global_position
	for mat: ShaderMaterial in [_cubes, _fill]:
		if mat != null:
			mat.set_shader_parameter("breath", breath_peak)
			mat.set_shader_parameter("breath_phase", breath_phase)
			mat.set_shader_parameter("breath_lag", breath_lag)
			mat.set_shader_parameter("breath_a", a)
			mat.set_shader_parameter("breath_b", b)


## A bone's pose as its own voxels would show it: the bone, or the voxels' node when a gait scales
## it (the octopus mantle breathing).
func _skin_global(i: int) -> Transform3D:
	var bone_name := _nodes[i].name
	var held: Variant = _rig.skins.get(bone_name, null)
	if is_instance_valid(held):
		var node: Node3D = held
		return node.global_transform
	return _nodes[i].global_transform


## True when BipedHead would show the mouth's pink inside: a snarling rest, or a dropped jaw.
func _mouth_showing() -> bool:
	if not _rig.has_bone("jaw"):
		return false
	if _rig.bone_snarl.get("jaw", false):  # a resting snarl keeps its true colours (BipedHead)
		return true
	var turn := (_rig.rest_of("jaw").basis.inverse() * _rig.bone("jaw").transform.basis).get_euler()
	return Num.f(_rig.bone_close.get("jaw", 0.0)) - turn.x > BipedHead.MOUTH_SHOWS


func _hide_rig_voxels() -> void:
	_hid_rig_voxels += 1
	for node: Node in _rig.find_children("*", "MultiMeshInstance3D", true, false):
		if not is_ancestor_of(node):
			(node as MultiMeshInstance3D).layers = 0


## A node's transform relative to the rig (rest, before the rig is in the tree).
func _to_rig(node: Node3D) -> Transform3D:
	var t := node.transform
	var parent := node.get_parent()
	while parent != _rig and parent is Node3D:
		t = (parent as Node3D).transform * t
		parent = parent.get_parent()
	return t
