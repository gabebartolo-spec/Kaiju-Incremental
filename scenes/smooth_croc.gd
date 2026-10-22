class_name SmoothCroc
extends Node3D
## Look-boards mock C (capture-only branch, not for merge, "--smooth-croc"): the croc titan drawn as
## its own smooth textured Tripo mesh, skinned to the same bones as the voxel skin (baked by
## tools/kaiju_skin/smooth_bake.py), in place of the cubes. Presentation only.

const SHADER := preload("res://scenes/smooth_croc.gdshader")

static var on := "--smooth-croc" in OS.get_cmdline_user_args()

var _skin: VoxelSkin
var _mat: ShaderMaterial


## Hides `skin`'s cubes and draws the smooth croc of `stage` on its pose; null when not baked.
static func attach(rig: Node3D, skin: VoxelSkin, stage: String) -> SmoothCroc:
	var base := "res://assets/kaiju/test/smooth/reptilian_%s" % stage
	if not FileAccess.file_exists(base + ".smesh"):
		return null
	var croc := SmoothCroc.new()
	croc._skin = skin
	croc._build(base)
	rig.add_child(croc)
	skin.visible = false  # it still syncs the pose every frame
	return croc


func _build(base: String) -> void:
	var raw := FileAccess.get_file_as_bytes(base + ".smesh")
	var verts := raw.decode_u32(8)
	var count := raw.decode_u32(12)
	var at := 16
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var uv := PackedVector2Array()
	var f := raw.slice(at, at + verts * 4 * 16).to_float32_array()
	at += verts * 4 * 16
	pos.resize(verts)
	nrm.resize(verts)
	uv.resize(verts)
	var bones := PackedFloat32Array()
	var weights := PackedFloat32Array()
	bones.resize(verts * 4)
	weights.resize(verts * 4)
	# f is laid out as separate blocks: position[3n], normal[3n], uv[2n], bone[4n], weight[4n].
	var n3 := verts * 3
	var n2 := verts * 2
	for i: int in verts:
		pos[i] = Vector3(f[i * 3], f[i * 3 + 1], f[i * 3 + 2])
		nrm[i] = Vector3(f[n3 + i * 3], f[n3 + i * 3 + 1], f[n3 + i * 3 + 2])
		uv[i] = Vector2(f[n3 * 2 + i * 2], f[n3 * 2 + i * 2 + 1])
		for k: int in 4:
			bones[i * 4 + k] = f[n3 * 2 + n2 + i * 4 + k]
			weights[i * 4 + k] = f[n3 * 2 + n2 + verts * 4 + i * 4 + k]
	var idx := raw.slice(at, at + count * 4).to_int32_array()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_CUSTOM0] = bones
	arrays[Mesh.ARRAY_CUSTOM1] = weights
	arrays[Mesh.ARRAY_INDEX] = idx
	var flags := (
		(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	var image := Image.load_from_file(base + ".jpg")
	image.generate_mipmaps()
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("albedo", ImageTexture.create_from_image(image))
	_mat.set_shader_parameter("roughness_value", Look.value("kaiju_roughness"))
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _mat
	node.custom_aabb = VoxelSkin.BOUNDS
	node.layers = KaijuModel.BODY_LAYER | KaijuModel.RIM_LAYER
	add_child(node)
	RenderingServer.frame_pre_draw.connect(_push)


func _push() -> void:
	if is_instance_valid(_skin) and not _skin.pose.is_empty():
		_mat.set_shader_parameter("bones", _skin.pose)
