class_name HarbourView
extends RefCounted
## The fixed beachfront the kaiju rises from (CityHarbour; D-381), for CityGround, drawn inside the
## front's kerbs (plan["harbour"]["rect"], cut out of the city's own ground): its water at the
## sea's level, the long sand beach (a height field on the sim's own floor, CityHarbour.floor_at,
## so the feet and the sand agree), the promenade, the beach road, the pavement the hotel blocks
## stand on with the side streets between them, and past the seawall the port's quay deck, piers
## and yard. The curved bands are drawn as columns COLUMN wide. Presentation only.

const SAND := preload("res://scenes/sand.gdshader")
const GRAIN := 0.125  # a grain of sand is one city voxel (building voxels: 8 to the unit)
const GRAIN_SHADE := 0.065  # how far a grain's shade strays from the sand's (share of lightness)
const GRAIN_TILE := 64  # grains per side of the sand's texture, tiled over the beach
const CELL := 1.0  # metres: the beach's height-field cell
const COLUMN := 1.0  # metres: a column of the curved bands (promenade, road, pavement)

## The beach grid reads each column's shore line once, not at every corner three times (it is x's
## alone): the height field 339 -> 120 ms. Off: per corner, as before (fixture: same heights).
static var by_column := true
## Perf 2026-11: the bay's sheet from packed arrays (water 120 -> 40 ms). Off: SurfaceTool.
static var packed_water := true


## The port's decks (x, z): its quay from the beach's east end to the front's east edge (the beach
## road's near kerb seaward to the quay's edge), its finger piers, and the seawall with its
## breakwater.
static func quays(plan: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not plan.has("harbour"):
		return out
	var b: Dictionary = plan["harbour"]
	var rect: Rect2 = b["rect"]
	var east := Num.f(b["beach_east"])
	var quay := Num.f(b["quay_z"])
	var h: Dictionary = b["h"]
	var kerb := CityHarbour.bands(h, east)[2]
	out.append(Rect2(east, quay, rect.end.x - east, kerb - quay))
	var piers: Array[Rect2] = b["piers"]
	var walls: Array[Rect2] = b["walls"]
	out.append_array(piers)
	out.append_array(walls)
	return out


## The land bands as columns (x, z), by name: "promenade" (the sand's edge to the beach road, the
## beach only), "road" (the beach road, on straight along the port), "side" (the side streets,
## the road's far kerb to the back street's kerb), "pavement" (the same between them, where the
## hotel blocks stand) and "yard" (the same past the beach's east end: the port).
static func bands(plan: Dictionary, cfg: Dictionary) -> Dictionary:
	var b: Dictionary = plan["harbour"]
	var h: Dictionary = b["h"]
	var rect: Rect2 = b["rect"]
	var east := Num.f(b["beach_east"])
	var street := CityGen.width_of(CityGen.STREET, cfg) * 0.5
	var sides: Array[float] = b["sides"]
	var out := {"promenade": [], "road": [], "side": [], "pavement": [], "yard": []}
	var x := rect.position.x
	while x < rect.end.x - 0.001:
		var w := minf(COLUMN, rect.end.x - x)
		if x < east:
			w = minf(w, east - x)
		var mid := x + w * 0.5
		var at := CityHarbour.bands(h, mid)
		if x < east:
			_add(out, "promenade", Rect2(x, at[1], w, at[2] - at[1]))
		_add(out, "road", Rect2(x, at[2], w, at[3] - at[2]))
		var back := Rect2(x, at[3], w, rect.end.y - at[3])
		if sides.any(func(s: float) -> bool: return absf(mid - s) < street):
			_add(out, "side", back)
		else:
			_add(out, "yard" if x >= east else "pavement", back)
		x += w
	return out


static func _add(bands_out: Dictionary, band: String, rect: Rect2) -> void:
	var list: Array = bands_out[band]
	list.append(rect)


## The front's water: one sheet at the sea's level from the coast to the beach's furthest
## waterline and the port's quay (the sand, decks and pavement stand over its landward part),
## on the water surface (WaterSurface) like the open sea past the coast. It is cut into rows
## and columns (tuning water.lap) so the lapping wavelets lift it; their lift (vertex red) fades
## in over water.lap.fade from the coast, so it meets the open sea's flat sheet there.
static func water(plan: Dictionary, cfg: Dictionary, color: Color) -> MeshInstance3D:
	var b: Dictionary = plan["harbour"]
	var rect: Rect2 = b["rect"]
	var mouth := Num.f(b["mouth"])
	var reach := Num.f(b["quay_z"])
	for p: Vector2 in CityHarbour.arc(plan, cfg):
		reach = maxf(reach, p.y)
	var lap: Dictionary = Content.section("water")["lap"]
	var cols := ceili(rect.size.x / Num.f(lap["column"]))
	var rows := ceili((reach - mouth) / Num.f(lap["row"]))
	var fade := Num.f(lap["fade"])
	var y := CityHarbour.sea(cfg)
	var mi := MeshInstance3D.new()
	var span := [mouth, reach, fade, y]
	mi.mesh = _sheet(rect, span, cols, rows) if packed_water else _sheet_st(rect, span, cols, rows)
	if WaterSurface.on():
		var mat := WaterSurface.material(rect, color, true, Num.i(cfg["map_seed"]))
		WaterSurface.lap(mat)
		mi.material_override = mat
	else:
		mi.material_override = WaterSurface.gloss(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_to_group(WaterSurface.GROUP)
	return mi


## The bay's sheet, cols x rows cells over rect's x and span's z ([mouth, reach, fade, y]), its
## rows fading in from the mouth: packed arrays, one call (the per-vertex SurfaceTool build,
## _sheet_st, gives the same mesh).
static func _sheet(rect: Rect2, span: Array, cols: int, rows: int) -> ArrayMesh:
	var mouth: float = span[0]
	var reach: float = span[1]
	var fade: float = span[2]
	var y: float = span[3]
	var n := (rows + 1) * (cols + 1)
	var verts := PackedVector3Array()
	verts.resize(n)
	var normals := PackedVector3Array()
	normals.resize(n)
	normals.fill(Vector3.UP)
	var colors := PackedColorArray()
	colors.resize(n)
	var xs := PackedFloat32Array()
	for c: int in cols + 1:
		xs.append(lerpf(rect.position.x, rect.end.x, float(c) / cols))
	var k := 0
	for r: int in rows + 1:
		var z := lerpf(mouth, reach, float(r) / rows)
		var tint := Color(clampf((z - mouth) / fade, 0.0, 1.0), 0.0, 0.0)
		for c: int in cols + 1:
			verts[k] = Vector3(xs[c], y, z)
			colors[k] = tint
			k += 1
	var index := PackedInt32Array()
	index.resize(rows * cols * 6)
	k = 0
	for r: int in rows:
		for c: int in cols:
			var q := r * (cols + 1) + c
			index[k] = q
			index[k + 1] = q + 1
			index[k + 2] = q + cols + 2
			index[k + 3] = q
			index[k + 4] = q + cols + 2
			index[k + 5] = q + cols + 1
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## _sheet as built before 2026-11 (packed_water off): a SurfaceTool call per vertex and index.
static func _sheet_st(rect: Rect2, span: Array, cols: int, rows: int) -> ArrayMesh:
	var mouth: float = span[0]
	var reach: float = span[1]
	var fade: float = span[2]
	var y: float = span[3]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for r: int in rows + 1:
		var z := lerpf(mouth, reach, float(r) / rows)
		st.set_color(Color(clampf((z - mouth) / fade, 0.0, 1.0), 0.0, 0.0))
		for c: int in cols + 1:
			st.add_vertex(Vector3(lerpf(rect.position.x, rect.end.x, float(c) / cols), y, z))
	for r: int in rows:
		for c: int in cols:
			var q := r * (cols + 1) + c
			for k: int in [q, q + 1, q + cols + 2, q, q + cols + 2, q + cols + 1]:
				st.add_index(k)
	return st.commit()


## The beach: a height field over the beach (the front's west edge to its east end), the sim's
## floor (sea floor up the slope to the sand's top), from the foot of the slope to the
## promenade; sand grains a voxel each, every one a slightly different shade (nearest filtered,
## hard-edged like the city's cubes), wet along the waterline and lapped by the sea
## (scenes/sand.gdshader).
static func beach(plan: Dictionary, cfg: Dictionary, sand: Color) -> MeshInstance3D:
	var b: Dictionary = plan["harbour"]
	var h: Dictionary = cfg["harbour"]
	var rect: Rect2 = b["rect"]
	var x0 := rect.position.x
	var x1 := Num.f(b["beach_east"])
	var z0 := INF
	var z1 := -INF
	# Out over the whole shelf and the rise's hollow.
	var reach := maxf(
		Num.f(h["shelf"]), Num.f(h["beach"]) + 2.0 * Num.f(h["hollow"]) + Num.f(h["hollow_edge"])
	)
	for p: Vector2 in CityHarbour.arc(plan, cfg):
		z0 = minf(z0, p.y - reach)
		z1 = maxf(z1, CityHarbour.bands(h, p.x)[1])
	var nx := ceili((x1 - x0) / CELL)
	var nz := ceili((z1 - z0) / CELL)
	var lap: Dictionary = Content.section("water")["lap"]
	var grid := _heights(plan, cfg, Rect2(x0, z0, x1 - x0, z1 - z0), Num.f(lap["wet_width"]))
	var mi := MeshInstance3D.new()
	mi.mesh = _beach_mesh([x0, x1, z0], nx, nz, grid)
	mi.material_override = _sand(sand, lap)
	return mi


## The sand's look: its grains, wet along the waterline (tuning water.lap).
static func _sand(sand: Color, lap: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SAND
	mat.set_shader_parameter("grains", _grains(sand))
	for key: String in ["wet_width", "wet_dark", "wet_rough"]:
		mat.set_shader_parameter(key, Num.f(lap[key]))
	return mat


## The beach grid's corners over `area` (CELL apart, the last column clamped to its east end):
## [each corner's height, its metres up the sand from the waterline over wet_width (0..1)].
static func _heights(plan: Dictionary, cfg: Dictionary, area: Rect2, wet_width: float) -> Array:
	var rows := []
	rows.resize(ceili(area.size.y / CELL) + 1)
	var cols := []  # off: each corner reads its own shore
	if by_column:
		cols = _shores(plan, cfg, area)
	var row := func(j: int) -> void: rows[j] = _height_row(plan, cfg, area, wet_width, j, cols)
	var task := WorkerThreadPool.add_group_task(row, rows.size())
	WorkerThreadPool.wait_for_group_task_completion(task)
	var ys := PackedFloat32Array()
	var ups := PackedFloat32Array()
	for done: Array in rows:
		var row_ys: PackedFloat32Array = done[0]
		var row_ups: PackedFloat32Array = done[1]
		ys.append_array(row_ys)
		ups.append_array(row_ups)
	return [ys, ups]


## Each grid column's shore line (CityHarbour.shore_at of x alone): [cfg's harbour, the plan's],
## 64-bit like the corner-by-corner reads.
static func _shores(plan: Dictionary, cfg: Dictionary, area: Rect2) -> Array[PackedFloat64Array]:
	var h: Dictionary = cfg["harbour"]
	var plan_h: Dictionary = plan["harbour"]["h"] if plan.has("harbour") else h
	var own := PackedFloat64Array()
	var plans := PackedFloat64Array()
	for i: int in ceili(area.size.x / CELL) + 1:
		var x := minf(area.position.x + i * CELL, area.end.x)
		own.append(CityHarbour.shore_at(h, x))
		plans.append(CityHarbour.shore_at(plan_h, x))
	return [own, plans]


## One row (j) of _heights: reads only plan, cfg and `cols` (_shores; [] reads each corner's own),
## so the rows build on worker threads.
static func _height_row(
	plan: Dictionary, cfg: Dictionary, area: Rect2, wet_width: float, j: int, cols: Array
) -> Array:
	var h: Dictionary = cfg["harbour"]
	var top := Num.f(h["sand_top"])
	var waterline := CityHarbour.waterline(cfg)
	var ys := PackedFloat32Array()
	var ups := PackedFloat32Array()
	var shelf := CityHarbour.shelf_floor(cfg)
	var own: PackedFloat64Array = cols[0] if not cols.is_empty() else PackedFloat64Array()
	var plans: PackedFloat64Array = cols[1] if not cols.is_empty() else PackedFloat64Array()
	for i: int in ceili(area.size.x / CELL) + 1:
		var p := Vector2(minf(area.position.x + i * CELL, area.end.x), area.position.y + j * CELL)
		if cols.is_empty():
			var was := p.y - CityHarbour.shore_at(h, p.x) + waterline
			var dip := top if was >= 0.0 else CityHarbour.shelf_floor(cfg)
			ys.append(CityHarbour.floor_at(plan, cfg, p) if CityHarbour.holds(plan, p) else dip)
			ups.append(clampf(was / wet_width, 0.0, 1.0))
			continue
		var shore := own[i]
		var up := p.y - shore + waterline
		# Past the harbour's water the sand still dips under the sea (never a bar at the sand's
		# top a hand under the surface, bared by every trough: director 2026-10-31).
		var off := top if up >= 0.0 else shelf
		var wet := CityHarbour.holds_at(plan, p, plans[i])
		ys.append(CityHarbour.floor_held(plan, cfg, p, shore) if wet else off)
		ups.append(clampf(up / wet_width, 0.0, 1.0))
	return [ys, ups]


## The beach's height field (grid: _heights; span: [west x, east x, north z]) as one indexed
## mesh: a corner's place, grain uv and wetness are the same in all four cells round it, and its
## normal is the sum of their triangles' normals, summed in SurfaceTool.generate_normals' order
## (it built 390k vertices to the same mesh, ~0.5 s a city).
static func _beach_mesh(span: Array[float], nx: int, nz: int, grid: Array) -> ArrayMesh:
	var x0 := span[0]
	var x1 := span[1]
	var z0 := span[2]
	var ys: PackedFloat32Array = grid[0]
	var ups: PackedFloat32Array = grid[1]
	var count := (nx + 1) * (nz + 1)
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	for j: int in nz + 1:
		for i: int in nx + 1:
			var k := j * (nx + 1) + i
			var v := Vector3(minf(x0 + i * CELL, x1), ys[k], z0 + j * CELL)
			verts.append(v)
			uvs.append(Vector2(v.x, v.z) / (GRAIN * GRAIN_TILE))
			colors.append(Color(ups[k], 0.0, 0.0))
	var sums := PackedVector3Array()
	sums.resize(count)
	var index := PackedInt32Array()
	for j: int in nz:
		for i: int in nx:
			var q := j * (nx + 1) + i
			var r := q + nx + 1  # the cell's corners clockwise from (i, j): q, q + 1, r + 1, r
			_corner_sums(verts, sums, q, q + 1, r + 1)
			_corner_sums(verts, sums, q, r + 1, r)
			index.append_array([q, q + 1, r + 1, q, r + 1, r])
	var normals := PackedVector3Array()
	for s: Vector3 in sums:
		normals.append(s.normalized())
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Triangle a, b, c's normal added to each of its corners' sums (generate_normals' order).
static func _corner_sums(
	verts: PackedVector3Array, sums: PackedVector3Array, a: int, b: int, c: int
) -> void:
	var normal := Plane(verts[a], verts[b], verts[c]).normal
	sums[a] += normal
	sums[b] += normal
	sums[c] += normal


static func _grains(sand: Color) -> ImageTexture:
	var img := Image.create(GRAIN_TILE, GRAIN_TILE, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7301  # the same grains every run (presentation only)
	for y: int in GRAIN_TILE:
		for x: int in GRAIN_TILE:
			img.set_pixel(x, y, sand.lightened(rng.randf_range(-GRAIN_SHADE, GRAIN_SHADE)))
	return ImageTexture.create_from_image(img)
