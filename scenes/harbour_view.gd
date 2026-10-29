class_name HarbourView
extends RefCounted
## The sea bay the kaiju rises from (CityHarbour; D-270), for CityGround, drawn inside the bay's
## fixed rectangle (its kerbs, plan["harbour"]["rect"]): its water at the sea's level, one
## continuous sand beach round its crescent (a height field on the sim's own floor,
## CityHarbour.floor_at, so the feet and the sand agree), a straight quay deck down each side
## from the coast to the promenade, and the promenade's pavement along the coast road. The street
## plan never sees the curve. Presentation only.

const GRAIN := 0.125  # a grain of sand is one city voxel (building voxels: 8 to the unit)
const GRAIN_SHADE := 0.065  # how far a grain's shade strays from the sand's (share of lightness)
const GRAIN_TILE := 64  # grains per side of the sand's texture, tiled over the beach
const CELLS := 160  # the beach's height field: at most this many cells across the bay
const CELL_MIN := 0.5  # metres: its finest cell


## The two quay decks (x, z): between the water and the side streets' kerbs, from the coast to
## the promenade.
static func quays(plan: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not plan.has("harbour"):
		return out
	var b: Dictionary = plan["harbour"]
	var rect: Rect2 = b["rect"]
	var cx := Num.f(b["cx"])
	var half := Num.f(b["half"])
	var mouth := Num.f(b["mouth"])
	var length := rect.end.y - mouth
	out.append(Rect2(rect.position.x, mouth, cx - half - rect.position.x, length))
	out.append(Rect2(cx + half, mouth, rect.end.x - cx - half, length))
	return out


## The promenade's pavement (x, z): between the quays, from the sand to the coast road's kerb.
static func promenade(plan: Dictionary, cfg: Dictionary) -> Rect2:
	var b: Dictionary = plan["harbour"]
	var cx := Num.f(b["cx"])
	var half := Num.f(b["half"])
	var shore := Num.f(b["apex"]) + Num.f(cfg["harbour"]["sand"])
	var rect: Rect2 = b["rect"]
	return Rect2(cx - half, shore, half * 2.0, rect.end.y - shore)


## The bay's water: one sheet at the sea's level over its whole outline (straight reach and
## crescent), on the water surface (WaterSurface) like the open sea past the coast.
static func water(plan: Dictionary, cfg: Dictionary, color: Color) -> MeshInstance3D:
	var b: Dictionary = plan["harbour"]
	var cx := Num.f(b["cx"])
	var half := Num.f(b["half"])
	var mouth := Num.f(b["mouth"])
	var from := Num.f(b["curve_from"])
	var outline := PackedVector2Array([Vector2(cx - half, mouth), Vector2(cx + half, mouth)])
	var curve := CityHarbour.arc(plan, cfg)
	curve.reverse()  # east end first, round to the west
	outline.append_array(curve)
	outline.append(Vector2(cx - half, from))
	var tris := Geometry2D.triangulate_polygon(outline)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var y := CityHarbour.sea(cfg)
	for k: int in range(tris.size() - 1, -1, -1):  # wound to face up
		var p := outline[tris[k]]
		st.add_vertex(Vector3(p.x, y, p.y))
	var rect: Rect2 = b["rect"]
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = (
		WaterSurface.material(rect, color, true, Num.i(cfg["map_seed"]))
		if WaterSurface.on()
		else WaterSurface.gloss(color)
	)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_to_group(WaterSurface.GROUP)
	return mi


## The beach: a height field over the crescent's end of the bay, the sim's floor (sea floor up the
## slope to the sand's top), from the foot of the slope to the promenade; sand grains a voxel
## each, every one a slightly different shade (nearest filtered, hard-edged like the city's cubes).
static func beach(plan: Dictionary, cfg: Dictionary, sand: Color) -> MeshInstance3D:
	var b: Dictionary = plan["harbour"]
	var h: Dictionary = cfg["harbour"]
	var cx := Num.f(b["cx"])
	var half := Num.f(b["half"])
	var z0 := Num.f(b["curve_from"]) - Num.f(h["beach"])
	var z1 := Num.f(b["apex"]) + Num.f(h["sand"])
	var cell := maxf(CELL_MIN, half * 2.0 / CELLS)
	var nx := ceili(half * 2.0 / cell)
	var nz := ceili((z1 - z0) / cell)
	var top := Num.f(h["sand_top"])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var at := func(i: int, j: int) -> Vector3:
		var p := Vector2(cx - half + i * cell, z0 + j * cell)
		var y := CityHarbour.floor_at(plan, cfg, p) if CityHarbour.holds(plan, p) else top
		return Vector3(p.x, y, p.y)
	for j: int in nz:
		for i: int in nx:
			var q: Array[Vector3] = [at.call(i, j), at.call(i + 1, j)]
			q.append_array([at.call(i + 1, j + 1), at.call(i, j + 1)])
			for n: int in [0, 2, 1, 0, 3, 2]:  # two triangles, wound to face up
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
