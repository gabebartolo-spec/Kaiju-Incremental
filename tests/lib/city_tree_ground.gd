extends RefCounted
## Trees stand on the ground (director 2026-10-27, D-345: "why are there so many trees on top of
## buildings is that a bug?"). Every tree base the decor planted lies outside every building
## footprint: the sim's lot buildings and the skyline's stand-in boxes past the playable edge.


static func check(
	tier: int, map_seed: int, sim: RampageSim, decor: CityDecor, skyline: CitySkyline, check: Callable
) -> void:
	var trees: Array[Vector2] = decor._props.felled()
	var on_roof := 0
	var at := Vector2.ZERO
	for t: Vector2 in trees:
		var under := _footprint_at(t, sim, skyline)
		if under:
			on_roof += 1
			at = t
	check.call(
		trees.size() > 0 and on_roof == 0,
		(
			"stage %d, map_seed %d: none of the city's %d trees stands inside a building footprint"
			% [tier, map_seed, trees.size()]
		)
		+ " (%d do, the last at %s)" % [on_roof, at]
	)


## True when `p` (x, z) is inside a lot building's footprint or a skyline stand-in's.
static func _footprint_at(p: Vector2, sim: RampageSim, skyline: CitySkyline) -> bool:
	for b: RampageSim.Building in sim.lot_buildings():
		if Rect2(b.x - b.w * 0.5, b.z - b.d * 0.5, b.w, b.d).has_point(p):
			return true
	for s: Dictionary in skyline.stand_ins():
		var size: Vector3 = s["size"]
		var at: Vector3 = s["at"]
		if Rect2(at.x - size.x * 0.5, at.z - size.z * 0.5, size.x, size.z).has_point(p):
			return true
	return false
