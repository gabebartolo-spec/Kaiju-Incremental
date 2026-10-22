extends RefCounted
## Model loading and voxelizing for the UI icon renders (render_icon.gd). A GLB (Tripo's, with
## its texture) or one of our .kvox models is read; an optional crop box keeps just a part of it
## (the head); the part is shown either smooth, as it is, or voxelized into the game's own cubes
## (VoxelBuilder, Look's voxel material and colour jitter), coloured from the model's texture.
## Tools only: nothing here ships in the game.

## Surface samples are taken this fraction of a voxel apart, so no cell of the shell is missed.
const SAMPLE_STEP := 0.45


## One mesh surface in the model's space.
class Part:
	extends RefCounted
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var index := PackedInt32Array()
	var material: Material


## One triangle: three corners with their normals, texture coordinates and vertex colours.
class Tri:
	extends RefCounted
	var p: Array[Vector3] = []
	var n: Array[Vector3] = []
	var uv: Array[Vector2] = []
	var c: Array[Color] = []
	var has_color := false


## Reads a material's base colour at a texture coordinate (its albedo texture times its colour).
class Sampler:
	extends RefCounted
	var _image: Image
	var _tint := Color.WHITE

	func _init(material: Material) -> void:
		if material is BaseMaterial3D:
			var m := material as BaseMaterial3D
			_tint = m.albedo_color
			if m.albedo_texture != null:
				_image = m.albedo_texture.get_image()
				if _image != null and _image.is_compressed():
					_image.decompress()

	func at(uv: Vector2) -> Color:
		if _image == null:
			return _tint
		var x := clampi(floori(fposmod(uv.x, 1.0) * _image.get_width()), 0, _image.get_width() - 1)
		var y := clampi(
			floori(fposmod(uv.y, 1.0) * _image.get_height()), 0, _image.get_height() - 1
		)
		return _image.get_pixel(x, y) * _tint


## The GLB at `path` as a scene (null if it cannot be read).
static func load_glb(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return null
	return doc.generate_scene(state) as Node3D


## Every triangle surface of `root` (not in a tree), vertices moved into root space.
static func surfaces(root: Node3D) -> Array[Part]:
	var out: Array[Part] = []
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var xform := _chain(mi, root)
		var mesh: Mesh = mi.mesh
		for s: int in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(s)
			var part := Part.new()
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			part.verts.resize(verts.size())
			for i: int in verts.size():
				part.verts[i] = xform * verts[i]
			if arrays[Mesh.ARRAY_NORMAL] != null:
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				part.normals.resize(normals.size())
				for i: int in normals.size():
					part.normals[i] = (xform.basis * normals[i]).normalized()
			if arrays[Mesh.ARRAY_TEX_UV] != null:
				part.uvs = arrays[Mesh.ARRAY_TEX_UV]
			if arrays[Mesh.ARRAY_COLOR] != null:
				part.colors = arrays[Mesh.ARRAY_COLOR]
			if arrays[Mesh.ARRAY_INDEX] != null:
				part.index = arrays[Mesh.ARRAY_INDEX]
			else:
				part.index.resize(verts.size())
				for i: int in verts.size():
					part.index[i] = i
			part.material = mi.get_active_material(s)
			out.append(part)
	return out


## The transform of `node` relative to `root` for a scene that is not in the tree.
static func _chain(node: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D()
	var at: Node = node
	while at != null and at != root:
		if at is Node3D:
			t = (at as Node3D).transform * t
		at = at.get_parent()
	return t


## The bounds of every vertex of `parts`.
static func bounds(parts: Array[Part]) -> AABB:
	var box := AABB()
	var first := true
	for part: Part in parts:
		for p: Vector3 in part.verts:
			if first:
				box = AABB(p, Vector3.ZERO)
				first = false
			else:
				box = box.expand(p)
	return box


## The part of `box` that `frac` (min x, y, z then max x, y, z, as shares of the box) names.
static func crop_box(box: AABB, frac: PackedFloat32Array) -> AABB:
	var lo := box.position + box.size * Vector3(frac[0], frac[1], frac[2])
	var hi := box.position + box.size * Vector3(frac[3], frac[4], frac[5])
	return AABB(lo, hi - lo)


## The surfaces' triangles whose centre lies in `crop`, as one smooth MeshInstance3D per surface
## with its own material, double sided so a cut stays closed to the eye.
static func smooth(parts: Array[Part], crop: AABB) -> Node3D:
	var holder := Node3D.new()
	for part: Part in parts:
		var tris := _tris_in(part, crop)
		if tris.is_empty():
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for t: Tri in tris:
			for k: int in 3:
				st.set_normal(t.n[k])
				st.set_uv(t.uv[k])
				if t.has_color:
					st.set_color(t.c[k])
				st.add_vertex(t.p[k])
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		var mat: Material = part.material
		if mat is BaseMaterial3D:
			var copy := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
			copy.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat = copy
		mi.material_override = mat
		holder.add_child(mi)
	return holder


## The surfaces voxelized (cells `voxel` wide, from crop.position): the shell's cells coloured by
## the texture under each sample.
static func voxelize(parts: Array[Part], crop: AABB, voxel: float) -> VoxelBuilder:
	var sums: Dictionary[Vector3i, Color] = {}
	var counts: Dictionary[Vector3i, int] = {}
	for part: Part in parts:
		var sampler := Sampler.new(part.material)
		for t: Tri in _tris_in(part, crop):
			_sample_triangle(t, sampler, crop, voxel, sums, counts)
	var vb := VoxelBuilder.new()
	for cell: Vector3i in sums:
		var c := sums[cell] / float(counts[cell])
		vb.put_color(cell, Color(c.r, c.g, c.b, 1.0))
	return vb


static func _sample_triangle(
	t: Tri,
	sampler: Sampler,
	crop: AABB,
	voxel: float,
	sums: Dictionary[Vector3i, Color],
	counts: Dictionary[Vector3i, int]
) -> void:
	var a := t.p[0]
	var b := t.p[1]
	var c := t.p[2]
	var longest := maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a)))
	var n := maxi(1, ceili(longest / (voxel * SAMPLE_STEP)))
	for i: int in n + 1:
		for j: int in n + 1 - i:
			var u := float(i) / n
			var v := float(j) / n
			var w := 1.0 - u - v
			var at := a * w + b * u + c * v
			if not crop.has_point(at):
				continue
			var uv := t.uv[0] * w + t.uv[1] * u + t.uv[2] * v
			var shade := Color.WHITE
			if t.has_color:
				shade = t.c[0] * w + t.c[1] * u + t.c[2] * v
			var cell := Vector3i(((at - crop.position) / voxel).floor())
			sums[cell] = sums.get(cell, Color(0, 0, 0, 0)) + sampler.at(uv) * shade
			counts[cell] = counts.get(cell, 0) + 1


## Triangles of `part` whose centre is in `crop`.
static func _tris_in(part: Part, crop: AABB) -> Array[Tri]:
	var out: Array[Tri] = []
	for k: int in range(0, part.index.size() - 2, 3):
		var ids: Array[int] = [part.index[k], part.index[k + 1], part.index[k + 2]]
		var centre := (part.verts[ids[0]] + part.verts[ids[1]] + part.verts[ids[2]]) / 3.0
		if not crop.has_point(centre):
			continue
		var t := Tri.new()
		t.has_color = not part.colors.is_empty()
		for id: int in ids:
			t.p.append(part.verts[id])
			t.n.append(part.normals[id] if not part.normals.is_empty() else Vector3.UP)
			t.uv.append(part.uvs[id] if not part.uvs.is_empty() else Vector2.ZERO)
			t.c.append(part.colors[id] if t.has_color else Color.WHITE)
		out.append(t)
	return out
