extends Node3D
## Look test (throwaway): a skinned mesh (tools/look_test/export_skin.py) driven by a KaijuRig.
## The rig keeps animating as in the game; this hides its voxels and copies every bone node's
## pose, relative to the rig, into a Skeleton3D, so the GPU skins the mesh with blended joints.
## Bone i of the mesh is bone i of the rig.json; its bind pose is the bone's rest head.
## Mode "rigid" skips the Skeleton3D: voxel_rigid.gdshader skins each cube as a rigid block from
## the same per-bone matrices, uploaded as a uniform.

## Render layer bits for the skinned meshes (A's voxels use KaijuModel.BODY_LAYER).
const SKIN_LAYER := 8
const VOXEL_LAYER := 16
const RIGID_SHADER := preload("res://tools/look_test/voxel_rigid.gdshader")

var skeleton: Skeleton3D
var _rig: KaijuRig
var _names: Array[String] = []
var _nodes: Array[Node3D] = []
var _binds: Array[Transform3D] = []
var _rigid: ShaderMaterial


## mode "skin" = B (Tripo texture), "voxel" = C round 1 (shared-corner lattice), "rigid" = C
## round 2 (rigid cubes, shader-skinned).
func setup(rig: KaijuRig, kmesh_path: String, albedo_path: String, mode: String) -> void:
	_rig = rig
	for mmi: Node in rig.find_children("*", "MultiMeshInstance3D", true, false):
		(mmi as MultiMeshInstance3D).visible = false
	_names = rig.bone_names()
	for i: int in _names.size():
		_nodes.append(rig.bone(_names[i]))
		_binds.append(Transform3D(Basis(), -rig.head_of(_names[i])))
	var mi := MeshInstance3D.new()
	mi.mesh = _load_kmesh(kmesh_path, rig.voxel_size())
	mi.layers = (SKIN_LAYER if mode == "skin" else VOXEL_LAYER) | KaijuModel.RIM_LAYER
	if mode == "rigid":
		_rigid = ShaderMaterial.new()
		_rigid.shader = RIGID_SHADER
		mi.material_override = _rigid
		# The shader moves vertices far from their rest place: never cull on the rest bounds.
		mi.custom_aabb = AABB(Vector3(-20, -5, -20), Vector3(40, 30, 40))
		add_child(mi)
		return
	skeleton = Skeleton3D.new()
	add_child(skeleton)
	var skin := Skin.new()
	for i: int in _names.size():
		skeleton.add_bone(_names[i])
		skin.add_bind(i, _binds[i])
	mi.skin = skin
	if mode == "skin":
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(albedo_path))
		mat.roughness = 0.9
		mi.material_override = mat
	else:
		mi.material_override = Look.voxel_material(0.0)
	skeleton.add_child(mi)
	mi.skeleton = NodePath("..")


## Copies the rig's current pose into the skeleton (or the rigid shader). Call after the rig
## animates, every frame.
func sync() -> void:
	var to_rig := _rig.global_transform.affine_inverse()
	if _rigid != null:
		var mats: Array[Projection] = []
		for i: int in _nodes.size():
			mats.append(Projection(to_rig * _nodes[i].global_transform * _binds[i]))
		_rigid.set_shader_parameter("bones", mats)
		return
	for i: int in _nodes.size():
		skeleton.set_bone_pose(i, to_rig * _nodes[i].global_transform)


static func _load_kmesh(path: String, voxel: float) -> ArrayMesh:
	var f := FileAccess.open(path, FileAccess.READ)
	var magic := f.get_buffer(4).get_string_from_ascii() if f != null else ""
	assert(magic == "KMSH" or magic == "KMS2", "bad kmesh " + path)
	var rigid := magic == "KMS2"
	var count := f.get_32()
	var tris := f.get_32()
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var centres := PackedFloat32Array()
	var bone_f := PackedFloat32Array()
	pos.resize(count)
	nrm.resize(count)
	uv.resize(count)
	col.resize(count)
	bones.resize(count * 4)
	weights.resize(count * 4)
	if rigid:
		centres.resize(count * 4)
		bone_f.resize(count * 4)
	for i: int in count:
		pos[i] = Vector3(f.get_float(), f.get_float(), f.get_float()) * voxel
		nrm[i] = Vector3(f.get_float(), f.get_float(), f.get_float())
		uv[i] = Vector2(f.get_float(), f.get_float())
		col[i] = Color8(f.get_8(), f.get_8(), f.get_8(), f.get_8())
		for k: int in 4:
			bones[i * 4 + k] = f.get_8()
		for k: int in 4:
			weights[i * 4 + k] = f.get_float()
		if rigid:
			for k: int in 3:
				centres[i * 4 + k] = f.get_float() * voxel
			centres[i * 4 + 3] = 1.0
			for k: int in 4:
				bone_f[i * 4 + k] = float(bones[i * 4 + k])
	var idx := PackedInt32Array()
	idx.resize(tris * 3)
	for i: int in tris * 3:
		idx[i] = f.get_32()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_INDEX] = idx
	var flags := 0
	if rigid:
		arrays[Mesh.ARRAY_CUSTOM0] = centres
		arrays[Mesh.ARRAY_CUSTOM1] = bone_f
		arrays[Mesh.ARRAY_CUSTOM2] = weights
		for slot: int in 3:
			flags |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << (Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT + slot * Mesh.ARRAY_FORMAT_CUSTOM_BITS)
	else:
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	return mesh
