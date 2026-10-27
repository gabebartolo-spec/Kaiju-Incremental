class_name ThreeFaceCube
extends RefCounted
## Render plan item 14 (tuning render_opt.kaiju_three_faces): the kaiju's cube mesh as only its +X,
## +Y and +Z faces, 12 vertices and 6 triangles where the box has 24 and 12. The cube shader turns
## them to each pass's camera per cube (voxel_three_faces.gdshaderinc). Cut from the engine's own
## BoxMesh, so the faces keep its corners, normals and winding.


## The three faces of a box of `size`.
static func mesh(size: Vector3) -> ArrayMesh:
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.get_mesh_arrays()
	var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var nor: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var kept := {}
	var out_pos := PackedVector3Array()
	var out_nor := PackedVector3Array()
	var out_idx := PackedInt32Array()
	for t: int in range(0, idx.size(), 3):
		var n := nor[idx[t]]
		if n.x + n.y + n.z < 0.5:  # a -X, -Y or -Z face
			continue
		for k: int in 3:
			var v := idx[t + k]
			if not kept.has(v):
				kept[v] = out_pos.size()
				out_pos.append(pos[v])
				out_nor.append(nor[v])
			out_idx.append(Num.i(kept[v]))
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = out_pos
	out[Mesh.ARRAY_NORMAL] = out_nor
	out[Mesh.ARRAY_INDEX] = out_idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return mesh
