class_name HarbourView
extends RefCounted
## The fixed beachfront the kaiju rises from (CityHarbour; D-381), for CityGround, drawn inside the
## front's kerbs (plan["harbour"]["rect"], cut out of the city's own ground): its water at the
## sea's level, the long sand beach (a height field on the sim's own floor, CityHarbour.floor_at,
## so the feet and the sand agree), the promenade, the beach road, the pavement the hotel blocks
## stand on with the side streets between them, and past the seawall the port's quay deck, piers
## and yard. The curved bands are drawn as columns COLUMN wide. Presentation only.

const GRAIN := 0.125  # a grain of sand is one city voxel (building voxels: 8 to the unit)
const GRAIN_SHADE := 0.065  # how far a grain's shade strays from the sand's (share of lightness)
const GRAIN_TILE := 64  # grains per side of the sand's texture, tiled over the beach
const CELL := 1.0  # metres: the beach's height-field cell
const COLUMN := 1.0  # metres: a column of the curved bands (promenade, road, pavement)


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
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	if WaterSurface.on():
		var mat := WaterSurface.material(rect, color, true, Num.i(cfg["map_seed"]))
		WaterSurface.lap(mat)
		mi.material_override = mat
	else:
		mi.material_override = WaterSurface.gloss(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_to_group(WaterSurface.GROUP)
	return mi


## The beach: a height field over the beach (the front's west edge to its east end), the sim's
## floor (sea floor up the slope to the sand's top), from the foot of the slope to the
## promenade; sand grains a voxel each, every one a slightly different shade (nearest filtered,
## hard-edged like the city's cubes).
static func beach(plan: Dictionary, cfg: Dictionary, sand: Color) -> MeshInstance3D:
	var b: Dictionary = plan["harbour"]
	var h: Dictionary = cfg["harbour"]
	var rect: Rect2 = b["rect"]
	var x0 := rect.position.x
	var x1 := Num.f(b["beach_east"])
	var z0 := INF
	var z1 := -INF
	for p: Vector2 in CityHarbour.arc(plan, cfg):
		z0 = minf(z0, p.y - Num.f(h["beach"]))
		z1 = maxf(z1, CityHarbour.bands(h, p.x)[1])
	var nx := ceili((x1 - x0) / CELL)
	var nz := ceili((z1 - z0) / CELL)
	var top := Num.f(h["sand_top"])
	var ys := PackedFloat32Array()
	for j: int in nz + 1:
		for i: int in nx + 1:
			var p := Vector2(minf(x0 + i * CELL, x1), z0 + j * CELL)
			ys.append(CityHarbour.floor_at(plan, cfg, p) if CityHarbour.holds(plan, p) else top)
	var at := func(i: int, j: int) -> Vector3:
		return Vector3(minf(x0 + i * CELL, x1), ys[j * (nx + 1) + i], z0 + j * CELL)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j: int in nz:
		for i: int in nx:
			var q: Array[Vector3] = [at.call(i, j), at.call(i + 1, j)]
			q.append_array([at.call(i + 1, j + 1), at.call(i, j + 1)])
			for n: int in [0, 1, 2, 0, 2, 3]:  # two triangles, clockwise from above (Godot front faces)
				st.set_uv(Vector2(q[n].x, q[n].z) / (GRAIN * GRAIN_TILE))
				st.add_vertex(q[n])
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _grains(sand)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	return mi


static func _grains(sand: Color) -> ImageTexture:
	var img := Image.create(GRAIN_TILE, GRAIN_TILE, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7301  # the same grains every run (presentation only)
	for y: int in GRAIN_TILE:
		for x: int in GRAIN_TILE:
			img.set_pixel(x, y, sand.lightened(rng.randf_range(-GRAIN_SHADE, GRAIN_SHADE)))
	return ImageTexture.create_from_image(img)
