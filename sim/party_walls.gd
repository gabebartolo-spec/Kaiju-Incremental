class_name PartyWalls
extends RefCounted
## Which sides of each building a touching neighbour covers, and how many floors up (no sign
## hangs off a covered side): the same answer for BuildingCells (sim) and BuildingVoxels (view),
## so the sim's fine grid and the drawn building agree. Moved out of BuildingView for the
## gameplay port (WP7): the sim promotes a building to its fine grid on its first hit and needs
## the same answer. Pure.

## The bucket grid's cell size (sim units): a little over a typical lot.
const CELL := 8.0
## Building pairs the last of() call compared (tests check it grows about linearly).
static var pair_checks := 0


## For each building, side (BuildingCells.SIDES) -> how many floors of it a touching
## neighbour covers (the tallest one, where several share the side). Buildings are bucketed in
## a coarse grid first, so each is compared only with those in its own cells: about linear in
## the building count (the adult city is thousands of buildings; all pairs would be millions).
static func of(buildings: Array[RampageSim.Building]) -> Array[Dictionary]:
	var grid := _grid(buildings)
	var out: Array[Dictionary] = []
	pair_checks = 0
	for n: int in buildings.size():
		out.append(_sides(buildings, n, grid))
	return out


## The bucket grid: cell -> the indices of the buildings whose footprint touches it.
static func _grid(buildings: Array[RampageSim.Building]) -> Dictionary:
	var grid := {}
	for n: int in buildings.size():
		for cell: Vector2i in _cells(buildings[n]):
			if not grid.has(cell):
				grid[cell] = [] as Array[int]
			var bucket: Array[int] = grid[cell]
			bucket.append(n)
	return grid


## Building n's covered sides: side -> floors of it the tallest touching neighbour covers.
static func _sides(buildings: Array[RampageSim.Building], n: int, grid: Dictionary) -> Dictionary:
	var a := buildings[n]
	var sides := {}
	var seen := {}
	for cell: Vector2i in _cells(a):
		var bucket: Array[int] = grid[cell]
		for m: int in bucket:
			if m == n or seen.has(m):
				continue
			seen[m] = true
			pair_checks += 1
			var other := buildings[m]
			var side := _side_toward(a, other)
			if side != Vector2i.ZERO:
				sides[side] = maxi(Num.i(sides.get(side, 0)), other.height)
	return sides


## The side of `a` along which `other` shares a wall (touching, and overlapping along it), or zero.
static func _side_toward(a: RampageSim.Building, other: RampageSim.Building) -> Vector2i:
	var gap_x := absf(a.x - other.x) - (a.w + other.w) * 0.5
	var gap_z := absf(a.z - other.z) - (a.d + other.d) * 0.5
	if absf(gap_x) < 0.01 and gap_z < -0.01:
		return Vector2i(1 if other.x > a.x else -1, 0)
	if absf(gap_z) < 0.01 and gap_x < -0.01:
		return Vector2i(0, 1 if other.z > a.z else -1)
	return Vector2i.ZERO


## The grid cells a building's footprint touches, grown a little so touching walls share one.
static func _cells(b: RampageSim.Building) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if b.is_rail():  # a viaduct shares no wall: it is in no bucket
		return out
	var lo := Vector2i(
		floori((b.x - b.w * 0.5 - 0.1) / CELL), floori((b.z - b.d * 0.5 - 0.1) / CELL)
	)
	var hi := Vector2i(
		floori((b.x + b.w * 0.5 + 0.1) / CELL), floori((b.z + b.d * 0.5 + 0.1) / CELL)
	)
	for cx: int in range(lo.x, hi.x + 1):
		for cz: int in range(lo.y, hi.y + 1):
			out.append(Vector2i(cx, cz))
	return out
