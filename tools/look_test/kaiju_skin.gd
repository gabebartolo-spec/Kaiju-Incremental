extends Node3D
## Look test (throwaway): a skinned mesh (tools/look_test/export_skin.py) driven by a KaijuRig.
## The rig keeps animating as in the game; this hides its voxels and copies every bone node's
## pose, relative to the rig, into a Skeleton3D, so the GPU skins the mesh with blended joints.
## Bone i of the mesh is bone i of the rig.json; its bind pose is the bone's rest head.

## Render layer bits for the skinned meshes (A's voxels use KaijuModel.BODY_LAYER).
const SKIN_LAYER := 8
const VOXEL_LAYER := 16

var skeleton: Skeleton3D
var _rig: KaijuRig
var _names: Array[String] = []
var _nodes: Array[Node3D] = []


## mode "skin" = B (Tripo texture), "voxel" = C (A's voxels as one skinned lattice surface).
func setup(rig: KaijuRig, kmesh_path: String, albedo_path: String, mode: String) -> void:
	_rig = rig
	for mmi: Node in rig.find_children("*", "MultiMeshInstance3D", true, false):
		(mmi as MultiMeshInstance3D).visible = false
	skeleton = Skeleton3D.new()
	add_child(skeleton)
	_names = rig.bone_names()
	var voxel := rig.voxel_size()
	var skin := Skin.new()
	for i: int in _names.size():
		skeleton.add_bone(_names[i])
		_nodes.append(rig.bone(_names[i]))
		skin.add_bind(i, Transform3D(Basis(), -rig.head_of(_names[i])))
	var mi := MeshInstance3D.new()
	mi.mesh = _load_kmesh(kmesh_path, voxel)
	mi.skin = skin
	mi.layers = (SKIN_LAYER if mode == "skin" else VOXEL_LAYER) | KaijuModel.RIM_LAYER
	if mode == "skin":
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(albedo_path))
		mat.roughness = 0.9
		mi.material_override = mat
	else:
		mi.material_override = Look.voxel_material(0.0)
	skeleton.add_child(mi)
	mi.skeleton = NodePath("..")


## Copies the rig's current pose into the skeleton. Call after the rig animates, every frame.
func sync() -> void:
	var to_rig := _rig.global_transform.affine_inverse()
	for i: int in _nodes.size():
		skeleton.set_bone_pose(i, to_rig * _nodes[i].global_transform)


static func _load_kmesh(path: String, voxel: float) -> ArrayMesh:
	var f := FileAccess.open(path, FileAccess.READ)
	assert(f != null and f.get_buffer(4).get_string_from_ascii() == "KMSH", "bad kmesh " + path)
	var count := f.get_32()
	var tris := f.get_32()
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	pos.resize(count)
	nrm.resize(count)
	uv.resize(count)
	col.resize(count)
	bones.resize(count * 4)
	weights.resize(count * 4)
	for i: int in count:
		pos[i] = Vector3(f.get_float(), f.get_float(), f.get_float()) * voxel
		nrm[i] = Vector3(f.get_float(), f.get_float(), f.get_float())
		uv[i] = Vector2(f.get_float(), f.get_float())
		col[i] = Color8(f.get_8(), f.get_8(), f.get_8(), f.get_8())
		for k: int in 4:
			bones[i * 4 + k] = f.get_8()
		for k: int in 4:
			weights[i * 4 + k] = f.get_float()
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
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
