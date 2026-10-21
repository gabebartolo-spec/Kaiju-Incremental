class_name CityShore
extends RefCounted
## The sand shore the kaiju climbs out of the river on (CityRiver.shore; director 2026-10-21 #17:
## "perhaps make a small shoreline that he can embark upon"): one sloped slab of sand from the
## river's floor up to the street across the bay's city-side edge, where the quay wall is open.
## Part of CityGround. Presentation only: the sim's Emergence climbs the same slope
## (CityRiver.floor_at).

const CELL := 0.125  # a grain of sand is one city voxel (building voxels: 8 to the unit)
const GRAIN := 0.1  # how far a grain's shade strays from the sand's (share of its lightness)


static func draw(ground: CityGround, plan: Dictionary, cfg: Dictionary, depth: float) -> void:
	var sand := CityRiver.shore(plan, cfg)
	if not sand.has_area():
		return
	# Voxel grains stepping down the slope (the same slope the sim's Emergence climbs), each a
	# column to the river's floor, shaded a little differently so the bank has a grain like the
	# city's cubes rather than one flat plane.
	var colour := Look.color("sand")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7301
	for ix: int in ceili(sand.size.x / CELL):
		for iz: int in ceili(sand.size.y / CELL):
			var at := Vector2(sand.position.x + (ix + 0.5) * CELL, sand.position.y + (iz + 0.5) * CELL)
			var low := CityRiver.floor_at(plan, cfg, at)
			var top := low + CityGround.PAVE_TOP * (1.0 + low / depth)  # meets the kerb at the top
			var shade := colour.lightened(rng.randf_range(-GRAIN, GRAIN))
			var cell := Rect2(at - Vector2.ONE * CELL * 0.5, Vector2.ONE * CELL)
			ground._slab(cell, Vector2(top, top + depth), shade)
