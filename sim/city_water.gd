class_name CityWater
extends RefCounted
## The water each demo city is built round and the kaiju rises from (D-435, director 2026-11-01:
## "the layouts should be completely different. we will have to craft unique 'emerge' scenes for
## each map / only one map should have the water layout like that"). City "layout" "kind":
## - bay: the fixed beachfront and the river (CityHarbour, CityRiver; Ostia Minor). Nothing here.
## - cothon: a round naval harbour mid-city (Carthago). The diagonals' open site (CityPlaza) holds
##   it: water "radius" m round diagonal_through, a ring avenue "ring" m out, and each diagonal
##   carried on from the site's kerb to the ring as a spoke. "canals": compass points ("n", "e",
##   "s", "w"), each a straight canal "canal_width" m wide from the harbour out to the map's edge
##   (director 2026-11-01: "has to somehow be connected to the edge of the map"); avenues and
##   diagonals bridge it, no other street comes within "quay" m, a block it reaches is "shore".
## - fjord: a narrow band of water, iced over, cutting the city north to south (Thule): centre x
##   + meander[0] sin(2 pi z / meander[1]), "width" m wide. No street comes within "quay" m of it
##   but the avenues and diagonals that bridge it; a block it reaches is bare "shore".
## Records plan["water"] (its shape) and the rise: plan["rise_spawn"] in the water's middle (the
## fjord's at "rise_z") and plan["rise_bank"] "bank_inset" m onto land. Part of CityGen.map. Pure.

const BAY := "bay"
const COTHON := "cothon"
const FJORD := "fjord"
const COMPASS := {
	"n": Vector2(0.0, -1.0), "e": Vector2(1.0, 0.0), "s": Vector2(0.0, 1.0), "w": Vector2(-1.0, 0.0)
}


## The city's layout kind (bay without one).
static func kind(cfg: Dictionary) -> String:
	var layout: Dictionary = cfg.get("layout", {})
	return str(layout.get("kind", BAY))


## Lays the harbour's ring avenue and the spokes from the open site's kerb to it (cothon only;
## after the diagonals, CityGen.map). index: CityGen's node index.
static func lay(plan: Dictionary, index: Dictionary, cfg: Dictionary) -> void:
	if kind(cfg) != COTHON:
		return
	var site := _site(plan)
	if site.is_empty():
		return
	var layout: Dictionary = cfg["layout"]
	var at: Vector2 = plan["diagonal"]["at"]
	var ring := Num.f(layout["ring"])
	var outer: Rect2 = site["outer"]
	var angles: Array[float] = []
	var n := Num.i(layout["ring_points"])
	for k: int in n:
		angles.append(TAU * k / n)
	for diag: Dictionary in plan["diagonals"]:
		var dir: Vector2 = diag["dir"]
		for way: Vector2 in [dir, -dir]:
			angles.append(fposmod(way.angle(), TAU))
			var kerb := _exit(diag, way, outer)
			CityGen.lay(plan, index, at + way * ring, kerb, CityGen.DIAGONAL, cfg)
	angles.sort()
	for k: int in angles.size():
		var a := at + Vector2.from_angle(angles[k]) * ring
		var b := at + Vector2.from_angle(angles[(k + 1) % angles.size()]) * ring
		CityGen.lay(plan, index, a, b, CityGen.AVENUE, cfg)
	plan["water"] = {"kind": COTHON, "at": at, "radius": Num.f(layout["radius"]), "ring": ring}
	var spoke: Vector2 = plan["diagonals"][0]["dir"]  # ashore along a spoke, never up a canal
	_rise(plan, at, spoke, Num.f(layout["radius"]), layout)


## True when the street from a to b would run into the fjord (within its quay): it is not laid,
## unless it is an avenue or diagonal crossing it, a bridge.
static func wet(plan: Dictionary, a: Vector2, b: Vector2, street_kind: String) -> bool:
	if _canal_wet(plan, a, b, street_kind):
		return true
	var water: Dictionary = plan.get("fjord", {})
	if water.is_empty():
		return false
	var across := absf(b.x - a.x) > absf(b.y - a.y)
	if across and street_kind in [CityGen.AVENUE, CityGen.DIAGONAL]:
		return false
	var reach := Num.f(water["width"]) * 0.5 + Num.f(water["quay"])
	var n := maxi(1, ceili(a.distance_to(b) / Num.f(water["step"])))
	for k: int in n + 1:
		if _off(water, a.lerp(b, float(k) / n)) < reach:
			return true
	return false


## Before the streets (CityGen.map): records the fjord, or the harbour's canals (plan["canals"]:
## each {rect, dir}), so wet() can keep streets off them.
static func dig(plan: Dictionary, cfg: Dictionary) -> void:
	if kind(cfg) == COTHON:
		_dig_canals(plan, cfg)
	if kind(cfg) != FJORD:
		return
	var layout: Dictionary = cfg["layout"]
	var water := layout.duplicate(true)
	plan["fjord"] = water
	plan["water"] = water


## After the blocks (CityGen.map): every block the fjord reaches turns bare "shore", and the rise
## goes in the ice at rise_z, wading east.
static func mark(plan: Dictionary, cfg: Dictionary) -> void:
	for block: Dictionary in plan["blocks"]:
		if not block.has("site") and _in_canal(plan, CityGen.pavement(block, cfg), 0.0):
			_shore(block)
	var water: Dictionary = plan.get("fjord", {})
	if water.is_empty():
		return
	var half := Num.f(water["width"]) * 0.5
	for block: Dictionary in plan["blocks"]:
		if block.has("site"):
			continue
		var rect := CityGen.pavement(block, cfg)
		if _reaches(water, rect, half):
			_shore(block)
	var z := Num.f(water["rise_z"])
	_rise(plan, Vector2(centre_x(water, z), z), Vector2(1.0, 0.0), half, water)


## True when the fjord (within its quay) reaches into rect: CitySites keeps landmarks off it.
static func reaches(plan: Dictionary, rect: Rect2) -> bool:
	if _in_canal(plan, rect, Num.f(plan.get("canal_quay", 0.0))):
		return true
	var water: Dictionary = plan.get("fjord", {})
	if water.is_empty():
		return false
	return _reaches(water, rect, Num.f(water["width"]) * 0.5 + Num.f(water["quay"]))


## True when p lies on open water: the fjord, the harbour or a canal (the kerb audit's bridge
## parapets, RoadGroundAudit).
static func over(plan: Dictionary, p: Vector2) -> bool:
	for canal: Dictionary in plan.get("canals", []):
		var rect: Rect2 = canal["rect"]
		if rect.has_point(p):
			return true
	var water: Dictionary = plan.get("water", {})
	match str(water.get("kind", "")):
		COTHON:
			var at: Vector2 = water["at"]
			return p.distance_to(at) < Num.f(water["radius"])
	var fjord: Dictionary = plan.get("fjord", {})
	return not fjord.is_empty() and _off(fjord, p) < Num.f(fjord["width"]) * 0.5


## The fjord's centre line at z.
static func centre_x(water: Dictionary, z: float) -> float:
	var meander: Array = water["meander"]
	return Num.f(water["x"]) + Num.f(meander[0]) * sin(TAU * z / Num.f(meander[1]))


static func _off(water: Dictionary, p: Vector2) -> float:
	return absf(p.x - centre_x(water, p.y))


## True when the fjord's water (half wide) reaches into rect.
static func _reaches(water: Dictionary, rect: Rect2, half: float) -> bool:
	var step := Num.f(water["step"])
	var z := rect.position.y
	while z <= rect.end.y:
		var c := centre_x(water, z)
		if c + half > rect.position.x and c - half < rect.end.x:
			return true
		z += step
	return false


## The diagonals' open site (CityPlaza), or {}.
static func _site(plan: Dictionary) -> Dictionary:
	for site: Dictionary in plan.get("sites", []):
		if site.get("plaza", false):
			return site
	return {}


## Where diag, from its point "at" heading `way`, leaves rect (the open site's kerb line).
static func _exit(diag: Dictionary, way: Vector2, rect: Rect2) -> Vector2:
	var at: Vector2 = diag["at"]
	var x := rect.end.x if way.x > 0.0 else rect.position.x
	var z := rect.end.y if way.y > 0.0 else rect.position.y
	var tx := (x - at.x) / way.x if absf(way.x) > 0.0001 else INF
	var tz := (z - at.y) / way.y if absf(way.y) > 0.0001 else INF
	if tx < tz:
		return Vector2(x, CityDiagonals.at_x(diag, x))
	return Vector2(CityDiagonals.at_z(diag, z), z)


## The rise: in the water at `at`, wading `way` to bank_inset past the water's edge (`edge` m out).
static func _rise(
	plan: Dictionary, at: Vector2, way: Vector2, edge: float, layout: Dictionary
) -> void:
	plan["rise_spawn"] = at
	plan["rise_bank"] = at + way * (edge + Num.f(layout["bank_inset"]))


## The harbour's canals: from its centre (diagonal_through) to the edge of the view (CityBand).
static func _dig_canals(plan: Dictionary, cfg: Dictionary) -> void:
	var layout: Dictionary = cfg["layout"]
	var through: Array = cfg["diagonal_through"]
	var at := Vector2(Num.f(through[0]), Num.f(through[1]))
	var half := Num.f(layout.get("canal_width", 0.0)) * 0.5
	var edge := CityBand.extent(cfg)
	var canals: Array[Dictionary] = []
	for point: String in layout.get("canals", []):
		var dir: Vector2 = COMPASS[point]
		var end := at + dir * (edge - at.dot(dir))
		var side := Vector2(dir.y, -dir.x) * half
		var rect := Rect2(at - side, Vector2.ZERO).expand(at + side).expand(end - side).expand(
			end + side
		)
		canals.append({"rect": rect, "dir": dir})
	plan["canals"] = canals
	plan["canal_quay"] = Num.f(layout.get("quay", 0.0))


## True when a street from a to b would run along a canal (within its quay); avenues crossing it
## and diagonals are bridges.
static func _canal_wet(plan: Dictionary, a: Vector2, b: Vector2, street_kind: String) -> bool:
	var quay := Num.f(plan.get("canal_quay", 0.0))
	for canal: Dictionary in plan.get("canals", []):
		var dir: Vector2 = canal["dir"]
		var across := absf((b - a).normalized().dot(dir)) < 0.5
		if street_kind == CityGen.DIAGONAL or (across and street_kind == CityGen.AVENUE):
			continue
		var rect: Rect2 = canal["rect"]
		if _segment_in(rect.grow(quay), a, b):
			return true
	return false


## True when any canal (grown by `grow` m) overlaps rect.
static func _in_canal(plan: Dictionary, rect: Rect2, grow: float) -> bool:
	for canal: Dictionary in plan.get("canals", []):
		var water: Rect2 = canal["rect"]
		if water.grow(grow).intersects(rect):
			return true
	return false


## True when the segment a-b passes through rect (sampled each metre).
static func _segment_in(rect: Rect2, a: Vector2, b: Vector2) -> bool:
	var n := maxi(1, ceili(a.distance_to(b)))
	for k: int in n + 1:
		if rect.has_point(a.lerp(b, float(k) / n)):
			return true
	return false


## A block the water reaches: bare ground (its old use kept in "was").
static func _shore(block: Dictionary) -> void:
	block["was"] = block["use"]
	block["use"] = "shore"
