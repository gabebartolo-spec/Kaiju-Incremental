extends RefCounted
## The beach's load cost (the rampage took ~19 s to load, 2026-11-02): HarbourView builds the
## beach's height field as one indexed mesh, its rows on worker threads, where it built every
## cell's six vertices through SurfaceTool and generate_normals. On vs off: the old build, kept
## here, gives the same triangles (place, normal, grain uv, wetness) bit for bit from 6x the
## vertices. Seeded: the stage-2 city of the harbour fixtures.

const Harbour := preload("res://tests/lib/city_harbour.gd")


static func check(_root: Node, check_fn: Callable) -> void:
	var sim := Harbour._fresh(2, Num.i(Content.section("city")["map_seed"]))
	var cfg := sim.city
	var plan := CityGen.map(cfg)
	var beach := HarbourView.beach(plan, cfg, Look.color("sand"))
	var on: ArrayMesh = beach.mesh
	var off := _old(plan, cfg)
	var a := _triangles(on)
	var b := _triangles(off)
	var bad := 0
	for n: int in a.size():
		if a[n] != b[n]:
			bad += 1
	check_fn.call(
		a.size() == b.size() and a.size() > 0 and bad == 0,
		(
			"beach: the indexed mesh is the old build's %d triangle corners (%d differ)"
			% [b.size(), bad]
		)
	)
	var verts_on := on.surface_get_array_len(0)
	var verts_off := off.surface_get_array_len(0)
	check_fn.call(
		verts_on * 5 < verts_off,
		"beach: %d vertices where the old build made %d" % [verts_on, verts_off]
	)
	beach.material_override = null
	beach.free()
	sim.dispose()


## Each triangle corner, in draw order: [place, normal, uv, colour].
static func _triangles(mesh: ArrayMesh) -> Array:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var index := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:  # SurfaceTool's unindexed build has none
		index = arrays[Mesh.ARRAY_INDEX]
	var out := []
	var corners := index.size() if not index.is_empty() else verts.size()
	for n: int in corners:
		var k := index[n] if not index.is_empty() else n
		out.append([verts[k], normals[k], uvs[k], colors[k]])
	return out


## The beach as HarbourView built it before 2026-11-02: six vertices a cell, SurfaceTool's
## smooth normals.
static func _old(plan: Dictionary, cfg: Dictionary) -> ArrayMesh:
	var b: Dictionary = plan["harbour"]
	var h: Dictionary = cfg["harbour"]
	var rect: Rect2 = b["rect"]
	var x0 := rect.position.x
	var x1 := Num.f(b["beach_east"])
	var z0 := INF
	var z1 := -INF
	var reach := maxf(
		Num.f(h["shelf"]), Num.f(h["beach"]) + 2.0 * Num.f(h["hollow"]) + Num.f(h["hollow_edge"])
	)
	for p: Vector2 in CityHarbour.arc(plan, cfg):
		z0 = minf(z0, p.y - reach)
		z1 = maxf(z1, CityHarbour.bands(h, p.x)[1])
	var cell := HarbourView.CELL
	var nx := ceili((x1 - x0) / cell)
	var nz := ceili((z1 - z0) / cell)
	var lap: Dictionary = Content.section("water")["lap"]
	var area := Rect2(x0, z0, x1 - x0, z1 - z0)
	var grid := HarbourView._heights(plan, cfg, area, Num.f(lap["wet_width"]))
	var ys: PackedFloat32Array = grid[0]
	var ups: PackedFloat32Array = grid[1]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j: int in nz:
		for i: int in nx:
			var corners: Array[Vector2i] = [
				Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)
			]
			for n: int in [0, 1, 2, 0, 2, 3]:
				var at := corners[n]
				var k := at.y * (nx + 1) + at.x
				var q := Vector3(minf(x0 + at.x * cell, x1), ys[k], z0 + at.y * cell)
				st.set_uv(Vector2(q.x, q.z) / (HarbourView.GRAIN * HarbourView.GRAIN_TILE))
				st.set_color(Color(ups[k], 0.0, 0.0))
				st.add_vertex(q)
	st.generate_normals()
	return st.commit()
