extends RefCounted
## The digests tools/unity/check_core.py compares the C++ port against: a fixed carve sequence run
## through KaijuCarve, KaijuSettle, VoxelTopple and KaijuMesher.

## Buildings the digests run on: the tallest of the block, so carves cut real load paths.
const DIGEST_BUILDINGS := 3
const RANDOM_CARVES := 12
const CUT_STEPS := 3
const DIGEST_SEED := 20261108
const CENTRE_SNAP := 0.125


## The fixed carve sequence on the block's tallest buildings. Every step records the sphere and what
## Godot's native code made of it, so the check needs nothing from this script but this file.
static func of(built: Array[Dictionary]) -> Dictionary:
	var order: Array[int] = []
	for i: int in built.size():
		order.append(i)
	order.sort_custom(
		func(a: int, b: int) -> bool:
			var ha: int = built[a]["meta"]["height"]
			var hb: int = built[b]["meta"]["height"]
			return ha > hb or (ha == hb and a < b)
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = DIGEST_SEED
	var out := []
	for k: int in mini(DIGEST_BUILDINGS, order.size()):
		out.append(_digest_building(order[k], built[order[k]], rng))
	return {"buildings": out}


static func _spheres(dims: Vector3i, rng: RandomNumberGenerator) -> Array[Array]:
	var out: Array[Array] = []
	for _i: int in RANDOM_CARVES:
		var c := Vector3(
			rng.randf_range(0.0, dims.x), rng.randf_range(0.0, dims.y), rng.randf_range(0.0, dims.z)
		)
		out.append([c.snappedf(CENTRE_SNAP), snappedf(rng.randf_range(4.0, 24.0), CENTRE_SNAP)])
	# A cut right through at a quarter height: what brings a building's top down.
	var r := float(maxi(dims.x, dims.z)) / float(CUT_STEPS) * 0.8
	for ix: int in CUT_STEPS:
		for iz: int in CUT_STEPS:
			var c := Vector3(
				(ix + 0.5) * dims.x / CUT_STEPS, dims.y * 0.25, (iz + 0.5) * dims.z / CUT_STEPS
			)
			out.append([c.snappedf(CENTRE_SNAP), snappedf(r, CENTRE_SNAP)])
	return out


static func _digest_building(n: int, one: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var mesher: CellMesher = one["mesher"]
	var frame: VoxelFrame = one["frame"]
	var grid: BuildingCells = one["grid"]
	var dims := mesher.dims
	var carve_cells: Object = ClassDB.instantiate("KaijuCarve")
	var carve_drawn: Object = ClassDB.instantiate("KaijuCarve")
	var settle: Object = ClassDB.instantiate("KaijuSettle")
	carve_cells.call("set_grid", grid.cells, dims)
	carve_drawn.call("set_grid", one["drawn"], dims)
	var steps := []
	for s: Array in _spheres(dims, rng):
		var centre: Vector3 = s[0]
		var radius: float = s[1]
		var removed: int = carve_cells.call("carve_sphere", centre, radius)
		carve_drawn.call("carve_sphere", centre, radius)
		var cells: PackedByteArray = carve_cells.call("get_grid")
		var drawn: PackedByteArray = carve_drawn.call("get_grid")
		var labelled: Array = settle.call("label", cells, frame.fixtures, dims, frame.has_fixtures)
		var labels: PackedInt32Array = labelled[0]
		var count: int = labelled[1]
		var parts: Array = settle.call(
			"islands", labels, cells, frame.fixtures, dims, frame.has_fixtures
		)
		var floors: Dictionary = settle.call("floors", labels, cells, frame.fixtures, dims, count)
		var mass: PackedInt64Array = floors["mass"]
		var sx: PackedInt64Array = floors["sx"]
		var sz: PackedInt64Array = floors["sz"]
		var box: PackedInt32Array = floors["box"]
		var tips := VoxelTopple.scan_levels(mass, sx, sz, box, count, dims.y, grid.offset, grid.res)
		var step := {
			"centre": [centre.x, centre.y, centre.z],
			"radius": radius,
			"removed": removed,
			"cells_sha": _sha([cells]),
			"labels_sha": _sha([labels.to_byte_array()]),
			"count": count,
		}
		_add_islands(step, parts)
		step["tips"] = _tip_rows(tips)
		_add_mesh(step, mesher, drawn)
		steps.append(step)
		# The islands leave the grid, as the game's settle takes them.
		for part: PackedInt32Array in parts:
			for i: int in part:
				cells[i] = 0
				drawn[i] = 0
		carve_cells.call("set_grid", cells, dims)
		carve_drawn.call("set_grid", drawn, dims)
	return {"index": n, "dims": [dims.x, dims.y, dims.z], "steps": steps}


static func _add_islands(step: Dictionary, parts: Array) -> void:
	var sizes := []
	var joined := PackedInt32Array()
	for part: PackedInt32Array in parts:
		sizes.append(part.size())
		joined.append_array(part)
	step["island_sizes"] = sizes
	step["islands_sha"] = _sha([joined.to_byte_array()])


static func _tip_rows(tips: Array[Dictionary]) -> Array:
	var rows := []
	for t: Dictionary in tips:
		var pivot: Vector3 = t["pivot"]
		var dir: Vector2i = t["dir"]
		(
			rows
			. append(
				{
					"part": t["label"],
					"level": t["level"],
					"dir": [dir.x, dir.y],
					"pivot": [pivot.x, pivot.y, pivot.z],
				}
			)
		)
	return rows


static func _add_mesh(step: Dictionary, mesher: CellMesher, drawn: PackedByteArray) -> void:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var nr := mesher.regions()
	var verts := 0
	var indices := 0
	for rx: int in nr.x:
		for ry: int in nr.y:
			for rz: int in nr.z:
				var arrays: Array = mesher.mesh_region(drawn, Vector3i(rx, ry, rz))
				var at: PackedVector3Array = arrays[0]
				if at.is_empty():
					continue
				verts += at.size()
				var normals: PackedVector3Array = arrays[1]
				var index: PackedInt32Array = arrays[3]
				var uv: PackedVector2Array = arrays[4]
				var colors: PackedColorArray = arrays[2]
				indices += index.size()
				ctx.update(at.to_byte_array())
				ctx.update(normals.to_byte_array())
				ctx.update(_colour_bytes(colors))
				ctx.update(uv.to_byte_array())
				ctx.update(index.to_byte_array())
	step["verts"] = verts
	step["indices"] = indices
	step["mesh_sha"] = ctx.finish().hex_encode()


static func _colour_bytes(colors: PackedColorArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(colors.size() * 4)
	for i: int in colors.size():
		var c := colors[i]
		out[i * 4] = c.r8
		out[i * 4 + 1] = c.g8
		out[i * 4 + 2] = c.b8
		out[i * 4 + 3] = c.a8
	return out


static func _sha(buffers: Array) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for b: PackedByteArray in buffers:
		if not b.is_empty():
			ctx.update(b)
	return ctx.finish().hex_encode()
