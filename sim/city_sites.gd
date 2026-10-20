class_name CitySites
extends RefCounted
## Landmark sites (part of CityGen.map, split out to keep files small). Each landmark in
## city.landmarks takes the street-grid cells round its anchor, as many as its baked footprint
## (city.landmark_shapes: data/landmarks.json, merged in by Content) plus a margin needs, as one
## plaza: the streets inside it are never laid, so traffic and the ground go round it. A site
## stays inside one district (it never swallows a ring avenue), clear of the diagonal avenue and
## out of the river's row (CityRiver.river_row); a landmark that cannot get one is left out.
## Pure: the same city config always gives the same sites.


## One site per landmark that fits: {"id", "spec", "shape", "i": Vector2i (first and last x cell),
## "j": Vector2i (z cells), "outer": Rect2 between the street centre lines, "rect": Rect2 inside
## the kerbs}.
static func find(
	plan: Dictionary, rings: Array[float], avenues: Array, cfg: Dictionary
) -> Array[Dictionary]:
	var xs: Array[float] = plan["xs"]
	var zs: Array[float] = plan["zs"]
	var av_x: Dictionary = avenues[0]
	var av_z: Dictionary = avenues[1]
	var out: Array[Dictionary] = []
	var raw: Array = cfg.get("landmarks", [])
	var shapes: Dictionary = cfg.get("landmark_shapes", {})
	for spec: Dictionary in raw:
		var shape: Dictionary = shapes.get(str(spec["id"]), {})
		if shape.is_empty():
			continue
		var pad := 2.0 * Num.f(spec["margin"])
		var at: Array = spec["anchor"]
		var along_x := {"lines": xs, "rings": rings, "avenues": av_x, "cfg": cfg}
		var along_z := {"lines": zs, "rings": rings, "avenues": av_z, "cfg": cfg}
		var i := _span(along_x, Num.f(at[0]), Num.f(shape["w"]) + pad)
		var j := _span(along_z, Num.f(at[1]), Num.f(shape["d"]) + pad)
		if i.x < 0 or j.x < 0:
			continue
		var river := CityRiver.river_row(zs, cfg)
		if river >= 0 and j.x <= river and j.y >= river:
			continue  # never in the river's row (CityRiver): it would stand in the water
		var outer := Rect2(xs[i.x], zs[j.x], xs[i.y + 1] - xs[i.x], zs[j.y + 1] - zs[j.x])
		if _crosses_diagonal(plan, outer, cfg):
			continue
		var x0 := xs[i.x] + _inset(av_x, i.x, cfg)
		var z0 := zs[j.x] + _inset(av_z, j.x, cfg)
		var x1 := xs[i.y + 1] - _inset(av_x, i.y + 1, cfg)
		var z1 := zs[j.y + 1] - _inset(av_z, j.y + 1, cfg)
		(
			out
			. append(
				{
					"id": str(spec["id"]),
					"spec": spec,
					"shape": shape,
					"i": i,
					"j": j,
					"outer": outer,
					"rect": Rect2(x0, z0, x1 - x0, z1 - z0),
				}
			)
		)
	return out


## True when the street from a to b would run through a site (its middle lies inside one).
static func cuts(plan: Dictionary, a: Vector2, b: Vector2) -> bool:
	for site: Dictionary in plan.get("sites", []):
		var outer: Rect2 = site["outer"]
		if outer.grow(-0.01).has_point((a + b) * 0.5):
			return true
	return false


## True when grid cell (i, j) is part of a site (it becomes the site's one block).
static func covers(plan: Dictionary, i: int, j: int) -> bool:
	for site: Dictionary in plan.get("sites", []):
		var si: Vector2i = site["i"]
		var sj: Vector2i = site["j"]
		if i >= si.x and i <= si.y and j >= sj.x and j <= sj.y:
			return true
	return false


## Each site's block: "landmark" while it lies in the playable city or the real band the camera
## shows past its edge (CityBand), else "outer" (a stand-in until an evolution
## brings it near).
static func add_blocks(plan: Dictionary, cfg: Dictionary) -> void:
	var blocks: Array[Dictionary] = plan["blocks"]
	var half := CityGen.half_extent(cfg)
	var sites: Array[Dictionary] = plan.get("sites", [] as Array[Dictionary])
	for n: int in sites.size():
		var rect: Rect2 = sites[n]["rect"]
		var reach := maxf(
			maxf(absf(rect.position.x), absf(rect.end.x)),
			maxf(absf(rect.position.y), absf(rect.end.y))
		)
		(
			blocks
			. append(
				{
					"rect": rect,
					"use": "landmark" if reach < half or CityBand.real(rect, cfg) else "outer",
					"district": CityGen.district_of(rect, cfg),
					"site": n,
				}
			)
		)


## The landmarks standing in district `ring` of the playable city, as layout entries
## (Landmarks.building): centred on their site, with their baked chunks, tier, bonus and arcs.
static func entries(plan: Dictionary, ring: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var sites: Array[Dictionary] = plan.get("sites", [] as Array[Dictionary])
	for block: Dictionary in plan["blocks"]:
		if str(block["use"]) != "landmark" or Num.i(block["district"]) != ring:
			continue
		var site: Dictionary = sites[Num.i(block["site"])]
		var shape: Dictionary = site["shape"]
		var spec: Dictionary = site["spec"]
		var rect: Rect2 = site["rect"]
		(
			out
			. append(
				{
					"x": rect.get_center().x,
					"z": rect.get_center().y,
					"w": Num.i(shape["w"]),
					"d": Num.i(shape["d"]),
					"h": Num.i(shape["h"]),
					"tier": Num.i(spec["tier"]),
					"style": 0,
					"landmark": str(site["id"]),
					"chunks": shape["chunks"],
					"rubble_bonus": Num.f(spec["rubble_bonus"]),
				}
			)
		)
		if spec.has("arcs"):
			out[-1]["arcs"] = spec["arcs"]
	return out


## The run of grid cells (first, last) round v whose inside, kerb to kerb, is at least `need`
## wide: grown one cell at a time, toward whichever side keeps v nearer the middle, never past a
## ring avenue. (-1, -1) if it cannot. axis: {lines, rings, avenues, cfg}.
static func _span(axis: Dictionary, v: float, need: float) -> Vector2i:
	var lines: Array[float] = axis["lines"]
	var rings: Array[float] = axis["rings"]
	var avenues: Dictionary = axis["avenues"]
	var cfg: Dictionary = axis["cfg"]
	var a := -1
	for k: int in lines.size() - 1:
		if v >= lines[k] and v < lines[k + 1]:
			a = k
	if a < 0:
		return Vector2i(-1, -1)
	var b := a
	while lines[b + 1] - lines[a] - _inset(avenues, a, cfg) - _inset(avenues, b + 1, cfg) < need:
		var low_ok := a > 0 and not _is_ring(lines[a], rings)
		var high_ok := b + 2 < lines.size() and not _is_ring(lines[b + 1], rings)
		if not low_ok and not high_ok:
			return Vector2i(-1, -1)
		if low_ok and (not high_ok or v - lines[a] < lines[b + 1] - v):
			a -= 1
		else:
			b += 1
	return Vector2i(a, b)


static func _is_ring(line: float, rings: Array[float]) -> bool:
	for h: float in rings:
		if is_equal_approx(absf(line), h):
			return true
	return false


## How far a plaza's edge sits in from street line k: half the street's width. A landmark's plaza
## runs out to the kerb, taking the sidewalk in (so the stadium fits between district 1's ring
## avenues, past the baby's play area: build 2 note 21).
static func _inset(avenues: Dictionary, k: int, cfg: Dictionary) -> float:
	var kind := CityGen.AVENUE if avenues.has(k) else CityGen.STREET
	return CityGen.width_of(kind, cfg) * 0.5


## True when the diagonal avenue (with its half width) passes through the rect.
static func _crosses_diagonal(plan: Dictionary, outer: Rect2, cfg: Dictionary) -> bool:
	var diag: Dictionary = plan["diagonal"]
	var at: Vector2 = diag["at"]
	var dir: Vector2 = diag["dir"]
	var clear := CityGen.width_of(CityGen.DIAGONAL, cfg) * 0.5 + Num.f(cfg["sidewalk"])
	var za := at.y + (outer.position.x - at.x) * dir.y / dir.x
	var zb := at.y + (outer.end.x - at.x) * dir.y / dir.x
	return maxf(za, zb) + clear >= outer.position.y and minf(za, zb) - clear <= outer.end.y
