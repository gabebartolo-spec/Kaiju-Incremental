class_name VoxelSkin
extends Node3D
## D-041: draws a rigged kaiju as voxel cubes on a smooth skin, from its baked <base>.vskin
## (tools/kaiju_skin/bake_all.sh). The KaijuRig keeps animating as before; this copies every
## bone's pose into the two shaders each frame, so joints bend without the per-bone voxels'
## tearing, gaps and speckle. The rig's own voxels stay built (gaits still toggle them) but are
## moved to render layer 0, where nothing draws them. Presentation only. Child of the rig.

const CUBE_SHADER := preload("res://scenes/voxel_skin.gdshader")
## Bones the shaders take (the hydra has 79).
const MAX_BONES := 128
## Gzip'd .vskin layout version this reader understands (tools/kaiju_skin/bake.py).
const VERSION := 2
## Bytes before the first cube in a .vskin (bake.py): magic, version, stamp, bones, voxel, cells.
const HEADER_BYTES := 26
## Bytes a cube takes in a .vskin: cell x y z (s16 each), colour, bone flags, three bones, weight.
const CELL_BYTES := 15
## Bytes a filler vertex takes (position, colour, three bones, weight): VoxelSkinFill.
const FILL_VERTEX_BYTES := 20
## Generous bounds: the shaders move every vertex away from where the engine thinks it is.
## A cell's centre sits half a voxel up from its corner (VoxelBuilder's lift).
const HALF_UP := Vector3(0, 0.5, 0)
const BOUNDS := AABB(Vector3(-12, -4, -12), Vector3(24, 24, 24))
## The cube shader's max_grow, set on the material so the bounds below and the shader agree.
const MAX_GROW := 0.0
## A cube's corner lies this many voxels from its centre (half the diagonal of a unit cube).
const HALF_DIAGONAL := 0.8660254

## Debug: draw rigged kaiju the old way, rigid voxels per bone (pass "--kaiju-rigid" after "--").
static var show_rigid_voxels := "--kaiju-rigid" in OS.get_cmdline_user_args()

## The bone matrices sent to the shaders last frame, and whether the mouth's inside showed.
var pose: Array[Projection] = []
var mouth_open := false
## Where shots meet this skin, and the wounds they leave (SkinHits).
var hits := SkinHits.new()
## Render plan item 2 (tuning render_opt.kaiju_tight_bounds): the box the cubes and the filler fit
## in this frame, set on all three draw nodes so the engine culls and shadow-casts by it (BOUNDS
## when the flag is off). VoxelSkinReach works it out from the pose.
var bounds := BOUNDS
var _rig: KaijuRig
var _nodes: Array[Node3D] = []
var _binds: Array[Transform3D] = []
var _cubes: ShaderMaterial
var _cube_node: MultiMeshInstance3D
var _fill: ShaderMaterial
var _fill_node: MeshInstance3D
var _hid_rig_voxels := 0
var _top := 0.0  # the highest cube centre at rest (skin units): where the stone creep ends
var _overload_set := false
var _tight := false
var _slack := 1.0
var _reach: VoxelSkinReach
## D-374 corrective joints after the rig's bones (none for most kaiju): VoxelSkinHelpers.
var _helpers: VoxelSkinHelpers


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
	var helpers := VoxelSkinHelpers.read(raw, _filler_end(raw))
	var rig_bones := count_bones - helpers.count
	if (
		rig_bones != rig.bone_names().size()
		or count_bones > MAX_BONES
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


## Byte offset just past raw's filler block (where an optional helper block starts).
static func _filler_end(raw: PackedByteArray) -> int:
	var at := HEADER_BYTES + raw.decode_u32(22) * CELL_BYTES
	if at + 4 > raw.size():
		return raw.size()
	at += 4 + raw.decode_u32(at) * FILL_VERTEX_BYTES
	if at + 4 > raw.size():
		return raw.size()
	return at + 4 + raw.decode_u32(at) * 4


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


func _cube_material(voxel: float, tune: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = CUBE_SHADER
	mat.set_shader_parameter("voxel", voxel)
	mat.set_shader_parameter("max_grow", MAX_GROW)
	mat.set_shader_parameter("seam_dark", BipedHead.SEAM_DARK)
	mat.set_shader_parameter("wound_radius", voxel * Num.f(tune["wound_radius_voxels"]))
	mat.set_shader_parameter("wound_tint", Color(str(tune["wound_tint"])).srgb_to_linear())
	# The kaiju's roughness doubles as its tag in the normal buffer: the crease pass skips it.
	mat.set_shader_parameter("roughness_value", Look.value("kaiju_roughness"))
	return mat


func _setup(rig: KaijuRig, raw: PackedByteArray) -> void:
	_rig = rig
	name = "VoxelSkin"
	for bone_name: String in rig.bone_names():
		var node := rig.bone(bone_name)
		_nodes.append(node)
		_binds.append(_to_rig(node).affine_inverse())
	if _helpers == null:
		_helpers = VoxelSkinHelpers.new()
	_reach = VoxelSkinReach.new(_nodes.size() + _helpers.count)
	var cfg: Dictionary = Content.section("render_opt")
	_tight = Num.i(cfg["kaiju_tight_bounds"]) != 0
	_slack = maxf(1.0, Num.f(cfg["kaiju_bounds_slack"]))
	var three := Num.i(cfg["kaiju_three_faces"]) != 0
	var voxel := raw.decode_float(18)
	var cells := raw.decode_u32(22)
	var tune: Dictionary = Content.section("fx")["hide_hit"]
	hits.setup(_nodes.size() + _helpers.count, voxel, Num.i(tune["max_wounds"]))
	var mm := _cube_multimesh(raw, cells, voxel, three)
	var corner := HALF_DIAGONAL * voxel * Look.value("voxel_inset") * (1.0 + MAX_GROW)
	_reach.measure_cubes(raw, cells, voxel, corner)
	_cubes = _cube_material(voxel, tune)
	_cubes.set_shader_parameter("three_faces", three)
	_cube_node = _cube_instance(mm)
	add_child(_cube_node)
	_fill_node = VoxelSkinFill.node(raw, HEADER_BYTES + cells * CELL_BYTES, _reach)
	if _fill_node != null:
		_fill = _fill_node.material_override as ShaderMaterial
		add_child(_fill_node)
	_hide_rig_voxels()


## The cubes as one MultiMesh from raw's cell block: a transform, a tint and the bones' packing
## (pack) per cell; every cell is also handed to `hits`.
func _cube_multimesh(raw: PackedByteArray, cells: int, voxel: float, three: bool) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE * voxel * Look.value("voxel_inset")
	mm.mesh = box
	if three:  # render plan item 14: three faces a cube, turned to each camera
		mm.mesh = ThreeFaceCube.mesh(box.size)
	mm.instance_count = cells
	mm.custom_aabb = BOUNDS
	var at := HEADER_BYTES
	for i: int in cells:
		var cell := Vector3i(raw.decode_s16(at), raw.decode_s16(at + 2), raw.decode_s16(at + 4))
		var base := Color8(raw[at + 6], raw[at + 7], raw[at + 8])
		var tint := Look.jitter(base, cell, 7)
		tint.a = raw[at + 14] / 255.0  # the second bone's weight rides in the colour's alpha
		mm.set_instance_transform(i, Transform3D(Basis(), (Vector3(cell) + HALF_UP) * voxel))
		mm.set_instance_color(i, tint)
		mm.set_instance_custom_data(i, pack(raw[at + 9], raw.slice(at + 10, at + 14)))
		hits.add_cell(raw[at + 10], cell, base)
		at += CELL_BYTES
	return mm


## The node that draws the cubes, with the cube material.
func _cube_instance(mm: MultiMesh) -> MultiMeshInstance3D:
	var cubes := MultiMeshInstance3D.new()
	cubes.multimesh = mm
	cubes.material_override = _cubes
	cubes.custom_aabb = BOUNDS
	cubes.layers = KaijuModel.BODY_LAYER | KaijuModel.RIM_LAYER
	return cubes


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


## Sets the box the engine culls and shadow-casts by on the cubes (MultiMesh and instance) and the
## filler (the box is VoxelSkinReach's, grown by tuning render_opt.kaiju_bounds_slack).
func _set_bounds(box: AABB) -> void:
	bounds = box
	_cube_node.custom_aabb = bounds
	_cube_node.multimesh.custom_aabb = bounds
	if _fill_node != null:
		_fill_node.custom_aabb = bounds


## Copies the rig's current pose into the shaders. Call after the rig animates, every frame.
func sync() -> void:
	if _hid_rig_voxels < 2:  # a gait may add voxels to a bone while it sets up
		_hide_rig_voxels()
	var to_rig := _rig.global_transform.affine_inverse()
	pose.resize(_nodes.size())
	_reach.begin()
	for i: int in _nodes.size():
		var t := to_rig * _skin_global(i) * _binds[i]
		pose[i] = Projection(t)
		if _tight:
			_reach.add(i, t)
	_helpers.add_poses(pose, _nodes.size())
	if _tight:
		for k: int in _helpers.count:
			_reach.add(_nodes.size() + k, Transform3D(pose[_nodes.size() + k]))
	if _tight and _reach.has_box():
		_set_bounds(_reach.box(_slack))
	_cubes.set_shader_parameter("bones", pose)
	_cubes.set_shader_parameter("to_skin", Projection(_cube_node.global_transform.affine_inverse()))
	if _fill != null:
		_fill.set_shader_parameter("bones", pose)
	_cubes.set_shader_parameter("wounds", hits.wounds())
	mouth_open = _mouth_showing()
	_cubes.set_shader_parameter("mouth_open", 1.0 if mouth_open else 0.0)


## The Special K overload (DeathOverload; tuning death.look): charge 0..1 lights a crackle of
## violet cubes, stone 0..1 turns him to stone from the feet up (cubes and the filler between).
func overload(charge: float, stone: float) -> void:
	if not _overload_set:
		_overload_set = true
		for i: int in _cube_node.multimesh.instance_count:
			_top = maxf(_top, _cube_node.multimesh.get_instance_transform(i).origin.y)
		var look: Dictionary = Content.section("death")["look"]
		var violet := Color(str(Content.section("creation")["lab"]["colors"]["special_k"]))
		for m: ShaderMaterial in [_cubes, _fill]:
			if m == null:
				continue
			m.set_shader_parameter("overload_color", violet)
			DeathStone.look(m)  # the stone the flying pieces are drawn with too
			m.set_shader_parameter("body_top", maxf(0.001, _top))
		_cubes.set_shader_parameter("crackle_share", Num.f(look["crackle_share"]))
		_cubes.set_shader_parameter("crackle_hz", Num.f(look["crackle_hz"]))
		_cubes.set_shader_parameter("crackle_energy", Num.f(look["crackle"]))
	_cubes.set_shader_parameter("overload", charge)
	_cubes.set_shader_parameter("stone", stone)
	if _fill != null:
		_fill.set_shader_parameter("stone", stone)


## Up to `most` cubes, evenly picked, where they are drawn now (world): {"pos", "color"} each.
## Each follows its main bone only (close enough for a burst); call after sync().
func world_points(most: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var mm := _cube_node.multimesh
	if pose.is_empty() or most <= 0:
		return out
	var g := _cube_node.global_transform
	var every := maxi(1, ceili(float(mm.instance_count) / most))
	for i: int in range(0, mm.instance_count, every):
		var bone := int(mm.get_instance_custom_data(i).r + 0.5) % MAX_BONES
		var at := mm.get_instance_transform(i).origin
		var moved := Transform3D(pose[mini(bone, pose.size() - 1)]) * at
		out.append({"pos": g * moved, "color": mm.get_instance_color(i)})
	return out


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
