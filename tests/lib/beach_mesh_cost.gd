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
	_check_columns(plan, cfg, check_fn)
	_check_water(plan, cfg, check_fn)
	beach.material_override = null
	beach.free()
	sim.dispose()


## Height field on vs off (perf 2026-11): each column's shore line read once (HarbourView.by_column)
## gives the per-corner build's heights and wetness byte for byte.
static func _check_columns(plan: Dictionary, cfg: Dictionary, check_fn: Callable) -> void:
	var area := _area(plan, cfg)
	var wet := Num.f(Content.section("water")["lap"]["wet_width"])
	var was := HarbourView.by_column
	HarbourView.by_column = true
	var on := var_to_bytes(HarbourView._heights(plan, cfg, area, wet))
	HarbourView.by_column = false
	var off := var_to_bytes(HarbourView._heights(plan, cfg, area, wet))
	HarbourView.by_column = was
	check_fn.call(
		on == off and on.size() > 0,
		(
			"beach: column-cached heights are the per-corner ones (%d bytes on, %d off)"
			% [on.size(), off.size()]
		)
	)


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
	var area := _area(plan, cfg)
	var x0 := area.position.x
	var x1 := area.end.x
	var z0 := area.position.y
	var cell := HarbourView.CELL
	var nx := ceili((x1 - x0) / cell)
	var nz := ceili(area.size.y / cell)
	var lap: Dictionary = Content.section("water")["lap"]
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


## The bay's sheet on vs off (perf 2026-11): packed arrays (HarbourView.packed_water) give the
## SurfaceTool build's mesh byte for byte.
static func _check_water(plan: Dictionary, cfg: Dictionary, check_fn: Callable) -> void:
	var was := HarbourView.packed_water
	var sheets: Array[PackedByteArray] = []
	for packed: bool in [true, false]:
		HarbourView.packed_water = packed
		var mi := HarbourView.water(plan, cfg, Look.color("water"))
		var mesh: ArrayMesh = mi.mesh
		sheets.append(var_to_bytes(mesh.surface_get_arrays(0)))
		mi.free()
	HarbourView.packed_water = was
	check_fn.call(
		sheets[0] == sheets[1] and sheets[0].size() > 0,
		(
			"water: the packed bay sheet is the SurfaceTool one (%d bytes on, %d off)"
			% [sheets[0].size(), sheets[1].size()]
		)
	)


## The beach's grid area, as HarbourView.beach lays it.
static func _area(plan: Dictionary, cfg: Dictionary) -> Rect2:
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
	return Rect2(x0, z0, x1 - x0, z1 - z0)
