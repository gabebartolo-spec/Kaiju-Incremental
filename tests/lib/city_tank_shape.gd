extends RefCounted
## The rooftop water tower is a barrel with a cone roof, not a ball (director 2026-10-27, D-345,
## D-348: the old brown ball on legs read as a tree crown from the far city; "Wooden water towers":
## same spots and count, a classic barrel tower with a cone roof). Measured on the voxels
## BuildingLayout lays for BRICK lots (the archetype that carries one): the smallest two and the
## largest footprint at each stage and map seed, so the tower is not clipped on a narrow roof.

const MIN_STRAIGHT := 8  # layers whose width is within one cell of the widest: straight staves
const MIN_ROOF := 5  # layers of cone roof narrower than the barrel, never widening upward
const MIN_ASPECT := 1.5  # the whole tower (barrel and roof) is this many times taller than wide
const TIP_MAX := 2  # the roof ends in a point at most this many cells wide


static func check(tier: int, map_seed: int, sim: RampageSim, check: Callable) -> void:
	var brick: Array[RampageSim.Building] = []
	for b: RampageSim.Building in sim.lot_buildings():
		if b.style % 4 == BuildingLayout.BRICK:
			brick.append(b)
	brick.sort_custom(_smaller)
	var sample: Array[RampageSim.Building] = []
	for b: RampageSim.Building in brick.slice(0, 2) + brick.slice(-1):
		if not sample.has(b):
			sample.append(b)
	var bad: Array[String] = []
	var worst := {"straight": 999, "roof": 999, "aspect": 999.0, "tip": 0}
	for b: RampageSim.Building in sample:
		var got := measure(BuildingLayout.new(b, BuildingVoxels.RES).cells)
		worst["straight"] = mini(Num.i(worst["straight"]), Num.i(got["straight"]))
		worst["roof"] = mini(Num.i(worst["roof"]), Num.i(got["roof"]))
		worst["aspect"] = minf(Num.f(worst["aspect"]), Num.f(got["aspect"]))
		worst["tip"] = maxi(Num.i(worst["tip"]), Num.i(got["tip"]))
		if not is_barrel_tower(got):
			bad.append("%dx%d" % [b.w, b.d])
	check.call(
		not sample.is_empty() and bad.is_empty(),
		(
			(
				"stage %d, map_seed %d: the rooftop water tower of %d BRICK lots is a barrel with a cone"
				+ " roof (worst: %d straight layers of >= %d, %d roof layers of >= %d, %.2f tall"
				+ " for its width of >= %.1f, tip %d cells of <= %d wide)"
			)
			% [
				tier,
				map_seed,
				sample.size(),
				Num.i(worst["straight"]),
				MIN_STRAIGHT,
				Num.i(worst["roof"]),
				MIN_ROOF,
				Num.f(worst["aspect"]),
				MIN_ASPECT,
				Num.i(worst["tip"]),
				TIP_MAX
			]
		)
		+ (" (not one on %s)" % [bad] if not bad.is_empty() else "")
	)


static func _smaller(p: RampageSim.Building, q: RampageSim.Building) -> bool:
	return p.w * p.d < q.w * q.d


## The "tank" cells of one building, layer by layer from the roof up: how many layers, how wide
## the widest is, the longest run of layers within one cell of that (the staves), the cone roof
## above the staves (layers narrower than the barrel, none wider than the one below), the tip.
static func measure(cells: Dictionary) -> Dictionary:
	var box: Dictionary = {}  # y -> Vector4i(x min, x max, z min, z max)
	for cell: Vector3i in cells:
		if str(cells[cell]) != "tank":
			continue
		var at: Vector4i = box.get(cell.y, Vector4i(cell.x, cell.x, cell.z, cell.z))
		box[cell.y] = Vector4i(
			mini(at.x, cell.x), maxi(at.y, cell.x), mini(at.z, cell.z), maxi(at.w, cell.z)
		)
	var layers: Array = box.keys()
	layers.sort()
	var widths: Array[int] = []
	var widest := 0
	for y: int in layers:
		var at: Vector4i = box[y]
		widths.append(maxi(at.y - at.x, at.w - at.z) + 1)
		widest = maxi(widest, widths[-1])
	var straight := 0
	var run := 0
	for w: int in widths:
		run = run + 1 if w >= widest - 1 else 0
		straight = maxi(straight, run)
	var roof := 0  # from the top layer down, while narrower than the barrel
	var tidy := true
	for i: int in range(widths.size() - 1, -1, -1):
		if widths[i] >= widest - 1:
			break
		roof += 1
		if i + 1 < widths.size() and widths[i] < widths[i + 1]:
			tidy = false  # a layer narrower than the one above it: a bulge, not a cone
	return {
		"layers": widths.size(),
		"contiguous": widths.size() == 0 or Num.i(layers[-1]) - Num.i(layers[0]) + 1 == widths.size(),
		"widest": widest,
		"straight": straight,
		"roof": roof if tidy else 0,
		"aspect": float(widths.size()) / maxf(1.0, float(widest)),
		"tip": widths[-1] if not widths.is_empty() else 0
	}


static func is_barrel_tower(got: Dictionary) -> bool:
	return (
		Num.i(got["layers"]) > 0
		and got["contiguous"] == true
		and Num.i(got["straight"]) >= MIN_STRAIGHT
		and Num.i(got["roof"]) >= MIN_ROOF
		and Num.f(got["aspect"]) >= MIN_ASPECT
		and Num.i(got["tip"]) <= TIP_MAX
	)
