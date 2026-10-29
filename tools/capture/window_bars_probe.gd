extends RefCounted
## Scene walkers for capture_window_bars.gd's diagnostic variants (window flicker, 2026-10-27):
## the facade materials of the stand-in boxes and skyline, and the baked buildings' shader.


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
