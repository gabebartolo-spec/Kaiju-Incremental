class_name DiagonalPaving
extends RefCounted
## The pavements of the blocks the diagonal avenue cuts across (CityGround, split out to keep
## files small). The diagonal is a road like the others, at street level with a kerb either side
## (director 2026-10-26: roads meet "other roads and pavements in a natural, realistic way", and
## "a seam between them rather than a seamless join"; it used to be laid over the blocks, a step
## above the streets it crossed and with no kerb). So a block it crosses is paved as the block's
## pavement with the avenue's carriageway cut out of it: one or two flat-topped prisms whose
## sides along the cut are the avenue's kerbs; a park's lawn keeps a pavement's width back from
## them. Presentation only.

const REACH := 4.0  # the cut band runs this many times the plan's outer half past its centre
## The prisms' x and z are stored divided by this and scaled back by the instance transform, so
## ground_slab.gdshader's pavement (which reads its kerb distance from the instance's size) sees
## one huge slab and lays no gutter grime across the cut.
const SPREAD := 1000.0


## The pavements, lawns, car parks and bank walls `ground` (CityGround) set aside as cut by the
## diagonal (its cut_blocks and cut_walls), the carriageway cut out of them, in the ground's
## material `mat`: one MultiMesh of one instance per surface kind (GroundKit), so they wear the
## same look as the slabs round them. colors: "pavement", "asphalt", "stone".
static func meshes(ground: CityGround, colors: Dictionary, mat: ShaderMaterial) -> Array:
	var plan := ground.plan
	var cfg := ground.cfg
	var road := band(plan, cfg, 0.0)
	var kerbed := band(plan, cfg, Num.f(cfg["sidewalk"]))
	var depth := Num.f(cfg.get("river_depth", 0.0))
	var top := CityGround.PAVE_TOP
	var tools := {}  # kind data -> SurfaceTool
	var stone: Color = colors["stone"]
	var pavement: Color = colors["pavement"]
	var asphalt: Color = colors["asphalt"]
	var wall := GroundKit.kind(GroundKit.K_CONCRETE, -depth)
	for side: Rect2 in ground.cut_walls:
		for piece: PackedVector2Array in pieces(side, road):
			prism(_tool(tools, wall), piece, Vector2(top, depth + 0.5), stone)
	var walk := GroundKit.kind(GroundKit.K_PAVEMENT)
	var inner := {
		"park": [0.5, 0.02, GroundKit.K_LAWN, Look.color("outskirts")],
		"parking": [0.6, 0.01, GroundKit.K_ASPHALT, asphalt.lightened(0.06)]
	}
	for block: Dictionary in ground.cut_blocks:
		for piece: PackedVector2Array in pieces(CityGen.pavement(block, cfg), road):
			prism(_tool(tools, walk), piece, Vector2(top, 0.3), pavement)
		if not inner.has(str(block["use"])):
			continue
		var spec: Array = inner[str(block["use"])]
		var rect: Rect2 = block["rect"]
		var st := _tool(tools, GroundKit.kind(Num.i(spec[2])))
		var tint: Color = spec[3]
		for piece: PackedVector2Array in pieces(rect.grow(-Num.f(spec[0])), kerbed):
			prism(st, piece, Vector2(top + Num.f(spec[1]), 0.3), tint)
	var out := []
	for data: Color in tools:
		var st: SurfaceTool = tools[data]
		out.append(_instance(st, data, mat))
	return out


static func _tool(tools: Dictionary, data: Color) -> SurfaceTool:
	if not tools.has(data):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[data] = st
	return tools[data]


## One instance of the prisms in st, custom data `data`, spread back to world size (SPREAD).
static func _instance(st: SurfaceTool, data: Color, mat: ShaderMaterial) -> MultiMeshInstance3D:
	var arrays := st.commit_to_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for k: int in verts.size():
		verts[k] = Vector3(verts[k].x / SPREAD, verts[k].y, verts[k].z / SPREAD)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D(Basis.from_scale(Vector3(SPREAD, 1.0, SPREAD))))
	mm.set_instance_custom_data(0, data)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


## True when the diagonal's carriageway reaches into the block's pavement.
static func cuts(plan: Dictionary, block: Dictionary, cfg: Dictionary) -> bool:
	var walk := CityGen.pavement(block, cfg)
	var half := CityGen.width_of(CityGen.DIAGONAL, cfg) * 0.5
	return CityGen.diagonal_distance(plan, walk.get_center()) < walk.size.length() * 0.5 + half


## The diagonal's carriageway grown by `grow` either side, as a polygon (x, z).
static func band(plan: Dictionary, cfg: Dictionary, grow: float) -> PackedVector2Array:
	var diag: Dictionary = plan["diagonal"]
	var at: Vector2 = diag["at"]
	var dir: Vector2 = diag["dir"]
	var across := Vector2(-dir.y, dir.x) * (CityGen.width_of(CityGen.DIAGONAL, cfg) * 0.5 + grow)
	var along := dir * Num.f(cfg["outer_half"]) * REACH
	return PackedVector2Array(
		[at - along - across, at + along - across, at + along + across, at - along + across]
	)


## What is left of rect once the band is cut out of it.
static func pieces(rect: Rect2, cut: PackedVector2Array) -> Array[PackedVector2Array]:
	var poly := PackedVector2Array(
		[rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	)
	var out: Array[PackedVector2Array] = []
	out.assign(Geometry2D.clip_polygons(poly, cut))
	return out


## Adds a flat-topped prism over convex polygon `poly` (x, z) to `st`: top at y.x, y.y thick,
## each face wound to face out (the ground material culls back faces) and lit by its own normal.
static func prism(st: SurfaceTool, poly: PackedVector2Array, y: Vector2, color: Color) -> void:
	st.set_color(color)
	var top := y.x
	var low := y.x - y.y
	var mid := Vector2.ZERO
	for p: Vector2 in poly:
		mid += p / poly.size()
	var ids := Geometry2D.triangulate_polygon(poly)
	for k: int in range(0, ids.size(), 3):
		var tri: Array[Vector3] = []
		for j: int in 3:
			tri.append(Vector3(poly[ids[k + j]].x, top, poly[ids[k + j]].y))
		_tri(st, tri, Vector3.UP)
	for k: int in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		var out := Vector2(b.y - a.y, a.x - b.x).normalized()
		if out.dot((a + b) * 0.5 - mid) < 0.0:
			out = -out
		var n := Vector3(out.x, 0.0, out.y)
		var at := Vector3(a.x, top, a.y)
		var bt := Vector3(b.x, top, b.y)
		var bl := Vector3(b.x, low, b.y)
		_tri(st, [at, bt, bl], n)
		_tri(st, [at, bl, Vector3(a.x, low, a.y)], n)


## One triangle facing `normal`: Godot's front faces wind clockwise seen from the front.
static func _tri(st: SurfaceTool, tri: Array[Vector3], normal: Vector3) -> void:
	if (tri[1] - tri[0]).cross(tri[2] - tri[0]).dot(normal) > 0.0:
		tri = [tri[0], tri[2], tri[1]]
	st.set_normal(normal)
	for v: Vector3 in tri:
		st.add_vertex(v)
