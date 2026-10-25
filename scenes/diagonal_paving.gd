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


## Adds a flat-topped prism over polygon `poly` (x, z) to `st`: top at y.x, y.y thick. Drawn
## with both faces (the material culls nothing), each face lit by its own outward normal.
static func prism(st: SurfaceTool, poly: PackedVector2Array, y: Vector2, color: Color) -> void:
	st.set_color(color)
	var top := y.x
	var low := y.x - y.y
	var mid := Vector2.ZERO
	for p: Vector2 in poly:
		mid += p / poly.size()
	st.set_normal(Vector3.UP)
	for k: int in Geometry2D.triangulate_polygon(poly):
		st.add_vertex(Vector3(poly[k].x, top, poly[k].y))
	for k: int in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		var out := Vector2(b.y - a.y, a.x - b.x).normalized()
		if out.dot((a + b) * 0.5 - mid) < 0.0:
			out = -out
		st.set_normal(Vector3(out.x, 0.0, out.y))
		for v: Vector3 in [
			Vector3(a.x, top, a.y),
			Vector3(b.x, top, b.y),
			Vector3(b.x, low, b.y),
			Vector3(a.x, top, a.y),
			Vector3(b.x, low, b.y),
			Vector3(a.x, low, a.y)
		]:
			st.add_vertex(v)
