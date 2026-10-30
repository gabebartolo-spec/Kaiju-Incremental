extends RefCounted
## Scene walkers for capture_window_bars.gd's diagnostic variants (window flicker, 2026-10-27):
## the facade materials of the stand-in boxes and skyline, the baked buildings' shader, and a
## shell mesh as baked before the balcony fix.


## Every facade.gdshaderinc material in the world (stand-in boxes, skyline), once each.
static func facade_mats(root: Node) -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		var mesh: Mesh = null
		if node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
			mesh = (node as MultiMeshInstance3D).multimesh.mesh
		elif node is MeshInstance3D:
			mesh = (node as MeshInstance3D).mesh
		if mesh == null:
			continue
		for k: int in mesh.get_surface_count():
			var mat := mesh.surface_get_material(k) as ShaderMaterial
			if mat == null and mesh is PrimitiveMesh:
				mat = (mesh as PrimitiveMesh).material as ShaderMaterial
			if (
				mat != null
				and mat.shader != null
				and mat.shader.resource_path.contains("facade")
				and not out.has(mat)
			):
				out.append(mat)
	return out


## Every building_baked.gdshader material in the scene switched to a copy of the shader with `from`
## replaced by `to`; returns what puts the shader back.
static func patch_baked(root: Node, from: String, to: String) -> Callable:
	var src: Shader = load("res://scenes/building_baked.gdshader")
	assert(src.code.contains(from), "building_baked.gdshader has no '%s'" % from)
	var patched := Shader.new()
	patched.code = src.code.replace(from, to)
	var mats: Array[ShaderMaterial] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is GeometryInstance3D:
			var mat := (node as GeometryInstance3D).material_override as ShaderMaterial
			if mat != null and mat.shader == src:
				mat.shader = patched
				mats.append(mat)
	print("  patched %d building materials" % mats.size())
	return func() -> void:
		for mat: ShaderMaterial in mats:
			mat.shader = src


## The view's shell mesh without the wall faces that look at a balcony slab (a slab outside the
## hollow): what BuildingMesher baked before the fix, face for face.
static func without_balcony_walls(view: BuildingView) -> ArrayMesh:
	var voxels := view.voxels
	var cells: Dictionary = voxels.vox.cells
	var res := BuildingVoxels.RES
	var w := view.b.w * res
	var d := view.b.d * res
	var h := view.b.height * res
	var half := BuildingVoxels.VOXEL * 0.5
	var skip := {}
	for cell: Vector3i in cells:
		if cells[cell] == "slab":
			continue
		for dir: Vector3i in BuildingMesher.NEIGHBOURS:
			var o := cell + dir
			var inside := o.x >= 1 and o.x <= w - 2 and o.z >= 1 and o.z <= d - 2
			inside = inside and o.y >= 0 and o.y < h - 1
			if cells.get(o, "") == "slab" and not inside:
				var at := (
					voxels.origin() + Vector3(0, half, 0) + Vector3(cell) * BuildingVoxels.VOXEL
				)
				skip[Vector3i(((at + Vector3(dir) * half) * 1024.0).round())] = true
	var src := view.mesher.shell.surface_get_arrays(0)
	var verts: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = src[Mesh.ARRAY_COLOR]
	var uv2: PackedVector2Array = src[Mesh.ARRAY_TEX_UV2]
	var nv := PackedVector3Array()
	var nn := PackedVector3Array()
	var nc := PackedColorArray()
	var nu := PackedVector2Array()
	var index := PackedInt32Array()
	var dropped := 0
	for q: int in range(0, verts.size(), 4):
		var centre := (verts[q] + verts[q + 1] + verts[q + 2] + verts[q + 3]) * 0.25
		if skip.has(Vector3i((centre * 1024.0).round())):
			dropped += 1
			continue
		var at := nv.size()
		for k: int in 4:
			nv.append(verts[q + k])
			nn.append(normals[q + k])
			nc.append(colors[q + k])
			nu.append(uv2[q + k])
		index.append_array([at, at + 2, at + 1, at, at + 3, at + 2])
	print("  main shell: dropped %d wall faces behind balcony slabs" % dropped)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = nv
	arrays[Mesh.ARRAY_NORMAL] = nn
	arrays[Mesh.ARRAY_COLOR] = nc
	arrays[Mesh.ARRAY_TEX_UV2] = nu
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
