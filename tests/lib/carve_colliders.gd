extends RefCounted
## Render plan item 10 (D-311) for tests/run_native_tests.gd: CarveCollider's native boxes
## (KaijuCarve.region_boxes) equal its GDScript oracle (script_boxes) box for box over 200 seeded
## carved regions, and a rebuild keeps its region's one static body, its shapes swapped through
## the physics server exactly as the boxes say. Seeded by design (SEED); no clock.

const REGIONS := 200
const GRIDS := 20
const PER_GRID := 10  # REGIONS / GRIDS
## Brick sizes in cells: the game's 8 (tuning destruction.res), a smaller power of two, an odd
## one (its half-bricks leave the last cell row out, as the GDScript does) and the smallest split.
const RES_CYCLE: Array[int] = [8, 4, 5, 2]
const SEED := 311

var _check: Callable


func _init(p_check: Callable) -> void:
	_check = p_check


func run() -> void:
	var loaded := ClassDB.class_exists("KaijuCarve")
	var nat := CarveCollider.native()
	_check.call(
		nat != null or not loaded,
		"a loaded extension has KaijuCarve.region_boxes (stale dll: rebuild native/)"
	)
	_server_shapes()
	_spread_build()
	if nat != null:
		_digest(nat)


## Native == GDScript boxes, int for int, over REGIONS seeded regions of GRIDS carved grids.
func _digest(nat: Object) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var compared := 0
	var boxes := 0
	var off := 0
	for g: int in GRIDS:
		var res: int = RES_CYCLE[g % RES_CYCLE.size()]
		var dims := Vector3i(
			rng.randi_range(9, 24), rng.randi_range(12, 40), rng.randi_range(9, 24)
		)
		var grid := _grid(rng, dims)
		var col := CarveCollider.new(CarveSite.new(g, Vector3.ZERO, dims, res))
		var span := res * CarveCollider.REGION
		var most := Vector3i(
			ceili(float(dims.x) / span), ceili(float(dims.y) / span), ceili(float(dims.z) / span)
		)
		for _r: int in PER_GRID:
			var region := Vector3i(
				rng.randi_range(0, most.x - 1),
				rng.randi_range(0, most.y - 1),
				rng.randi_range(0, most.z - 1)
			)
			var want := col.script_boxes(grid, region)
			var got: PackedInt32Array = nat.call(
				"region_boxes", grid, dims, region, CarveCollider.REGION, res, CarveCollider.SPARSE
			)
			compared += 1
			boxes += want.size()
			off += 0 if got == want else 1
		col.free()
	_check.call(
		compared == REGIONS and off == 0 and boxes > REGIONS * CarveCollider.BOX,
		(
			"native region_boxes = GDScript boxes for %d carved regions (%d ints of boxes, %d off)"
			% [compared, boxes, off]
		)
	)


## A region's body holds one server shape per box, placed and sized as the box; a carve rebuilds
## the region on the same body; a region carved empty loses its body.
func _server_shapes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 1
	var dims := Vector3i(20, 32, 16)
	var site := CarveSite.new(0, Vector3(10.0, 0.0, -5.0), dims, 8)
	var grid := _grid(rng, dims)
	var col := CarveCollider.new(site)
	col.build(grid)
	var bad := _bodies_off(col, grid)
	_check.call(bad.is_empty(), "every region body's server shapes are its boxes (off: %s)" % [bad])
	var region := Vector3i.ZERO
	var before := col.body(region)
	var cut := _carve(grid, dims, Vector3(4.0, 5.0, 4.0), 3.5)
	col.touched(grid, cut)
	var after := col.body(region)
	bad = _bodies_off(col, grid)
	_check.call(
		before != null and after == before and not cut.is_empty() and bad.is_empty(),
		(
			"a carve of %d cells rebuilds region 0 on its own body, shapes as its boxes (off: %s)"
			% [cut.size(), bad]
		)
	)
	var gone := _carve(grid, dims, Vector3(8.0, 8.0, 8.0), 15.0)
	col.touched(grid, gone)
	_check.call(
		col.body(region) == null and col.region_boxes(grid, region).is_empty(),
		"a region carved empty has no body"
	)
	col.free()


## A spread build (a building's first hit) makes at most collider_boxes_per_tick boxes a tick
## (plus the region that crosses it, 64 boxes at most), a carve builds a waiting region at once,
## and the finished build is the immediate build's bodies, shape for shape.
func _spread_build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 2
	var dims := Vector3i(48, 96, 48)
	var site := CarveSite.new(0, Vector3.ZERO, dims, 8)
	var grid := _grid(rng, dims)
	var col := CarveCollider.new(site)
	col.build(grid, true)
	var waiting := col.pending()
	var top := Vector3i(0, dims.y - 1, 0) / site.res / CarveCollider.REGION
	var cut := _carve(grid, dims, Vector3(2.0, dims.y - 3.0, 2.0), 2.5)
	col.touched(grid, cut)
	var carved_now := col.body(top) != null and _body_matches(col, grid, top)
	var per_tick := Num.i(Content.section("render_opt")["collider_boxes_per_tick"])
	var most := 0
	var ticks := 0
	while col.pending() > 0 and ticks < 10000:
		most = maxi(most, col.build_step())
		ticks += 1
	var bad := _bodies_off(col, grid)
	(
		_check
		. call(
			waiting > 1 and ticks > 1 and most < per_tick + 64 and carved_now and bad.is_empty(),
			(
				(
					"a spread build of %d regions takes %d ticks, at most %d boxes a tick (budget %d); a carve"
					+ " builds its waiting region at once; the bodies end as the boxes (off: %s)"
				)
				% [waiting, ticks, most, per_tick, bad]
			)
		)
	)
	col.free()


## Regions whose body disagrees with their boxes (count, centre or size of a shape).
func _bodies_off(col: CarveCollider, grid: PackedByteArray) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var span := col.site.res * CarveCollider.REGION
	for y: int in ceili(float(col.site.size.y) / span):
		for z: int in ceili(float(col.site.size.z) / span):
			for x: int in ceili(float(col.site.size.x) / span):
				var region := Vector3i(x, y, z)
				if not _body_matches(col, grid, region):
					out.append(region)
	return out


func _body_matches(col: CarveCollider, grid: PackedByteArray, region: Vector3i) -> bool:
	var boxes := col.region_boxes(grid, region)
	var b := col.body(region)
	if b == null:
		return boxes.is_empty()
	var rid := b.get_rid()
	if PhysicsServer3D.body_get_shape_count(rid) * CarveCollider.BOX != boxes.size():
		return false
	for k: int in range(0, boxes.size(), CarveCollider.BOX):
		@warning_ignore("integer_division")
		var i := k / CarveCollider.BOX
		var box := col.world_box(boxes, k)
		var xf := PhysicsServer3D.body_get_shape_transform(rid, i)
		var half: Vector3 = PhysicsServer3D.shape_get_data(PhysicsServer3D.body_get_shape(rid, i))
		if not xf.origin.is_equal_approx(box.get_center()):
			return false
		if not (half * 2.0).is_equal_approx(box.size):
			return false
	return true


## A building-like grid: slabs, a shell and columns, some cells knocked out (thin bricks), then
## carved by a few spheres.
func _grid(rng: RandomNumberGenerator, dims: Vector3i) -> PackedByteArray:
	var cells := PackedByteArray()
	cells.resize(dims.x * dims.y * dims.z)
	var storey := rng.randi_range(3, 6)
	var holes := rng.randf_range(0.0, 0.6)
	for y: int in dims.y:
		for z: int in dims.z:
			for x: int in dims.x:
				var edge := x == 0 or z == 0 or x == dims.x - 1 or z == dims.z - 1
				var solid := y % storey == 0 or edge or (x % 7 == 3 and z % 7 == 3)
				if solid and rng.randf() >= holes:
					cells[x + z * dims.x + y * dims.x * dims.z] = rng.randi_range(1, 6)
	for _s: int in rng.randi_range(1, 4):
		var c := Vector3(
			rng.randf_range(0.0, dims.x), rng.randf_range(0.0, dims.y), rng.randf_range(0.0, dims.z)
		)
		_carve(cells, dims, c, rng.randf_range(2.0, 9.0))
	return cells


## Empties the cells whose centres are in the sphere; returns their indices.
func _carve(cells: PackedByteArray, dims: Vector3i, c: Vector3, r: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	for y: int in dims.y:
		for z: int in dims.z:
			for x: int in dims.x:
				var i := x + z * dims.x + y * dims.x * dims.z
				if cells[i] != 0 and Vector3(x + 0.5, y + 0.5, z + 0.5).distance_to(c) <= r:
					cells[i] = 0
					out.append(i)
	return out
