class_name VoxelSkinFill
extends RefCounted
## The filler under a VoxelSkin's cubes (D-041), read from the .vskin's vertex block and built as
## one mesh instance drawn with the fill shader. Split out of VoxelSkin (D-159). Presentation only.

const FILL_SHADER := preload("res://scenes/voxel_skin_fill.gdshader")


## The filler as a mesh instance for `raw`'s vertex block (raw[start] is its vertex count), its
## ShaderMaterial as the material override; null when the block holds no triangles. `reach` takes
## the filler's vertices on the way (VoxelSkinReach.measure_fill), triangles or not.
static func node(raw: PackedByteArray, start: int, reach: VoxelSkinReach) -> MeshInstance3D:
	var at := start
	var verts := raw.decode_u32(at)
	at += 4
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
	reach.measure_fill(pos, custom0, custom1)
	var indices := raw.decode_u32(at)
	at += 4
	if verts == 0 or indices == 0:
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_CUSTOM0] = custom0
	arrays[Mesh.ARRAY_CUSTOM1] = custom1
	arrays[Mesh.ARRAY_INDEX] = raw.slice(at, at + indices * 4).to_int32_array()
	return _instance(arrays)


static func _instance(arrays: Array) -> MeshInstance3D:
	var flags := (
		(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	var material := ShaderMaterial.new()
	material.shader = FILL_SHADER
	material.set_shader_parameter("roughness_value", Look.value("kaiju_roughness"))
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.custom_aabb = VoxelSkin.BOUNDS
	node.layers = KaijuModel.BODY_LAYER | KaijuModel.RIM_LAYER
	return node
