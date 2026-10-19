extends RefCounted
## The destruction spike's fixtures (claude/destruction-proto spike/carve_spike.gd and
## carve_grid.gd, d49d241), ported so the suite pins the same outcomes: a hollow office block
## (shell walls with window bands, a slab per floor, interior columns) and the blow's path (a
## tunnel through floor 9, then two low passes that cut the base through). Used by
## tests/run_destruction_tests.gd and tools/destruction_bench.gd.

const TICK := 1.0 / 30.0
const RADIUS := 2.4
const UNITS := Vector3i(6, 16, 6)
const SECONDS := 10.0
## A fixture material list in data/materials.json's shape ({id, name, strength, debris}; id 0
## is empty). Strengths differ so the suite proves the strength rule while the data's are
## all 1.0; the names are BuildingVoxels palette keys (the spike's column is a pillar).
const MATERIALS: Array[Dictionary] = [
	{"id": 1, "name": "wall", "strength": 7.0, "debris": "wall"},
	{"id": 2, "name": "slab", "strength": 7.0, "debris": "slab"},
	{"id": 3, "name": "glass", "strength": 2.0, "debris": "glass"},
	{"id": 4, "name": "pillar", "strength": 14.0, "debris": "pillar"},
]


## The spike's office block on a fresh frame (material ids looked up by name).
static func office(units: Vector3i, res: int) -> VoxelFrame:
	var f := VoxelFrame.new(units, res, MATERIALS)
	var wall := f.material_id("wall")
	var slab := f.material_id("slab")
	var glass := f.material_id("glass")
	var column := f.material_id("pillar")
	for y: int in f.h:
		for z: int in f.d:
			for x: int in f.w:
				var edge := x == 0 or z == 0 or x == f.w - 1 or z == f.d - 1
				var m := VoxelFrame.EMPTY
				if y % res == 0:
					m = slab
				elif edge:
					var bay := (x + z) % res
					m = glass if (y % res >= 2 and bay != 0 and y >= res) else wall
				elif x % (2 * res) == res and z % (2 * res) == res:
					m = column
				if m != VoxelFrame.EMPTY:
					f.set_cell(Vector3i(x, y, z), m)
	return f


## The sphere's centre for a building at `c`, `t` seconds after it starts (world units).
static func path(c: Vector3, t: float) -> Vector3:
	if t < 3.0:
		return c + Vector3(lerpf(-6.0, 6.0, t / 3.0), 9.0, 0.0)
	if t < 5.5:
		return c + Vector3(lerpf(6.0, -6.0, (t - 3.0) / 2.5), 1.6, -1.6)
	if t < 8.0:
		return c + Vector3(lerpf(-6.0, 6.0, (t - 5.5) / 2.5), 1.6, 1.6)
	return c + Vector3(6.0 + (t - 8.0) * 4.0, 1.6 + (t - 8.0) * 6.0, 1.6)


## Building centres: one tower, or a block of six (2 rows of 3).
static func layout(block: bool) -> Array[Vector3]:
	if not block:
		return [Vector3.ZERO]
	var out: Array[Vector3] = []
	for row: int in 2:
		for col: int in 3:
			out.append(Vector3((col - 1) * 9.0, 0.0, (row - 0.5) * 10.0))
	return out


static func units(block: bool, n: int) -> Vector3i:
	return UNITS if not block else Vector3i(6, 12 + (n * 5) % 9, 6)


## The spike's replay at `res`: every tick, each building's blow carves, then the frame splits
## (support false: detach(), the spike's rule) or settles (support true: settle(), with the
## support rule). Returns {"trace": PackedInt64Array (digest, carved count, then each event's
## size and kind per building per tick), "islands": PackedInt32Array (every event's size)}.
static func replay(res: int, block: bool, support: bool, ticks: int) -> Dictionary:
	var trace := PackedInt64Array()
	var sizes := PackedInt32Array()
	var frames: Array[VoxelFrame] = []
	var origins: Array[Vector3] = []
	var centres := layout(block)
	for n: int in centres.size():
		frames.append(office(units(block, n), res))
		origins.append(centres[n] - Vector3(3, 0, 3))
	for tick: int in ticks:
		for n: int in frames.size():
			var t := tick * TICK - n * 0.25
			if t < 0.0:
				continue
			var removed := frames[n].carve_sphere(path(centres[n], t) - origins[n], RADIUS)
			var parts: Array[Dictionary] = []
			if not removed.is_empty():
				parts = frames[n].settle() if support else frames[n].detach()
			trace.append(frames[n].digest())
			trace.append(removed.size())
			for part: Dictionary in parts:
				var cells: Array[Vector3i] = part["cells"]
				trace.append(cells.size())
				trace.append(1 if str(part["kind"]) == "topple" else 0)
				sizes.append(cells.size())
	return {"trace": trace, "islands": sizes}
