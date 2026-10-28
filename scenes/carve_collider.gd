class_name CarveCollider
extends Node3D
## What still stands of a carved building, as static colliders for its debris and its falling
## islands: one static body per region (REGION bricks a side) so a carve rebuilds only the
## regions it touched, and a box per brick round its cells; a brick its cells fill thinly (a
## corner of wall, a slab with a hole) gets a box per half-brick instead, so pieces do not land
## on air inside the building. Reads the sim's grid; never writes it.
## Render plan item 10 (D-311, tuning render_opt.native_colliders): the boxes come from the native
## core (KaijuCarve.region_boxes) where the extension is loaded; script_boxes() below is the oracle
## it is held to (tests/run_native_tests.gd). A region keeps its one static body: a rebuild swaps
## its shapes through the physics server, one box shape per size in cells shared by every body.
## A building's first build can be spread (build(grid, true)): its regions are built bottom up,
## render_opt.collider_boxes_per_tick boxes a physics tick (a count, never a clock, so a replay
## builds the same regions on the same tick), and a carve builds the regions it touches at once.

const REGION := 2  # bricks per region side
const SPARSE := 0.35  # a brick whose cells fill less of its box than this is split in eight
const BOX := 6  # ints a box in region_boxes(): lower cell x, y, z, size in cells x, y, z

static var _native: Object = null  # a KaijuCarve, for region_boxes (it keeps no grid)

var site: CarveSite
var use_native := true
## The longest refresh() so far, in microseconds (the speed check reads it).
var worst_usec := 0
var _regions: Dictionary = {}  # region -> StaticBody3D
var _shapes: Dictionary = {}  # box size in cells (Vector3i) -> BoxShape3D
var _pending: Array[Vector3i] = []  # regions a spread build has still to make, in build order
var _waiting: Dictionary = {}  # the same regions, for lookup
var _grid := PackedByteArray()  # the latest grid, for the spread build
var _per_tick := 0


func _init(p_site: CarveSite) -> void:
	site = p_site
	var opt := Content.section("render_opt")
	use_native = opt.get("native_colliders", true) == true
	_per_tick = Num.i(opt["collider_boxes_per_tick"])


## Builds every region from the whole grid: now, or with `spread` over the next physics ticks.
func build(grid: PackedByteArray, spread := false) -> void:
	var units := Vector3i(
		ceili(float(site.size.x) / site.res),
		ceili(float(site.size.y) / site.res),
		ceili(float(site.size.z) / site.res)
	)
	var regions := {}
	for y: int in units.y:
		for z: int in units.z:
			for x: int in units.x:
				regions[Vector3i(x, y, z) / REGION] = true
	if not spread:
		refresh(grid, regions)
		return
	_grid = grid
	for key: Vector3i in regions:
		if not _waiting.has(key):
			_waiting[key] = true
			_pending.append(key)


## Regions a spread build has still to make.
func pending() -> int:
	return _pending.size()


func _physics_process(_delta: float) -> void:
	if not _pending.is_empty():
		var start := Time.get_ticks_usec()
		build_step()
		worst_usec = maxi(worst_usec, Time.get_ticks_usec() - start)


## One tick of a spread build: regions until collider_boxes_per_tick boxes are made; returns the
## box count.
func build_step() -> int:
	var made := 0
	while not _pending.is_empty() and made < _per_tick:
		var key: Vector3i = _pending.pop_front()
		_waiting.erase(key)
		made += _rebuild(_grid, key)
	return made


## Rebuilds the regions that hold any of `cells` (indices).
func touched(grid: PackedByteArray, cells: PackedInt32Array) -> void:
	var regions := {}
	for i: int in cells:
		regions[site.cell(i) / site.res / REGION] = true
	_grid = grid
	for key: Vector3i in regions:
		if _waiting.erase(key):
			_pending.erase(key)
	refresh(grid, regions)


func refresh(grid: PackedByteArray, regions: Dictionary) -> void:
	var start := Time.get_ticks_usec()
	for key: Vector3i in regions:
		_rebuild(grid, key)
	worst_usec = maxi(worst_usec, Time.get_ticks_usec() - start)


## Region `region`'s boxes, BOX ints each: the native core's, else script_boxes().
func region_boxes(grid: PackedByteArray, region: Vector3i) -> PackedInt32Array:
	var nat: Object = native() if use_native else null
	if nat == null:
		return script_boxes(grid, region)
	var got: PackedInt32Array = nat.call(
		"region_boxes", grid, site.size, region, REGION, site.res, SPARSE
	)
	return got


## The native core, or null where the extension (or a DLL with region_boxes) is not loaded.
static func native() -> Object:
	if _native == null and ClassDB.class_exists("KaijuCarve"):
		_native = ClassDB.instantiate("KaijuCarve")
	return _native if _native != null and _native.has_method("region_boxes") else null


## The GDScript boxes (the oracle): the region's bricks in y, z, x order.
func script_boxes(grid: PackedByteArray, region: Vector3i) -> PackedInt32Array:
	var out := PackedInt32Array()
	for y: int in REGION:
		for z: int in REGION:
			for x: int in REGION:
				_brick_boxes(grid, (region * REGION + Vector3i(x, y, z)) * site.res, out)
	return out


## Region `region`'s static body, or null when nothing of it stands.
func body(region: Vector3i) -> StaticBody3D:
	var out: StaticBody3D = _regions.get(region)
	return out


## The world box of a box at `k` in `boxes` (region_boxes()' layout).
func world_box(boxes: PackedInt32Array, k: int) -> AABB:
	var s := 1.0 / site.res
	var lo := Vector3(boxes[k], boxes[k + 1], boxes[k + 2])
	var n := Vector3(boxes[k + 3], boxes[k + 4], boxes[k + 5])
	return AABB(site.origin + lo * s, n * s)


## Rebuilds region `region`; returns its box count.
func _rebuild(grid: PackedByteArray, region: Vector3i) -> int:
	var boxes := region_boxes(grid, region)
	var body: StaticBody3D = _regions.get(region)
	if boxes.is_empty():
		if body != null:
			_regions.erase(region)
			body.queue_free()
		return 0
	if body == null:
		body = StaticBody3D.new()
		add_child(body)
		_regions[region] = body
	var rid := body.get_rid()
	# Out of its space while its shapes change: in a space Jolt rebuilds the body's compound shape
	# on every add (a 72-region tower's build took 10-27 ms in space, item 10's speed bar is 2 ms).
	var space := PhysicsServer3D.body_get_space(rid)
	if space.is_valid():
		PhysicsServer3D.body_set_space(rid, RID())
	PhysicsServer3D.body_clear_shapes(rid)
	for k: int in range(0, boxes.size(), BOX):
		var box := world_box(boxes, k)
		var shape := _shape(Vector3i(boxes[k + 3], boxes[k + 4], boxes[k + 5]), box.size)
		PhysicsServer3D.body_add_shape(rid, shape.get_rid(), Transform3D(Basis(), box.get_center()))
	if space.is_valid():
		PhysicsServer3D.body_set_space(rid, space)
	return boxes.size() / BOX


## The shared box shape of a box `cells` cells a side (`size` in the world).
func _shape(cells: Vector3i, size: Vector3) -> BoxShape3D:
	var shape: BoxShape3D = _shapes.get(cells)
	if shape == null:
		shape = BoxShape3D.new()
		shape.size = size
		_shapes[cells] = shape
	return shape


## The boxes of the brick whose lower cell is `lo`: the box round its solid cells, or the boxes
## of its non-empty half-bricks when the cells fill less than SPARSE of that box.
func _brick_boxes(grid: PackedByteArray, lo: Vector3i, out: PackedInt32Array) -> void:
	var whole := _span(grid, lo, site.res)
	if whole.is_empty():
		return
	var volume := whole[3] * whole[4] * whole[5]
	if float(whole[BOX]) / float(volume) >= SPARSE or site.res < 2:
		out.append_array(whole.slice(0, BOX))
		return
	var half := site.res >> 1
	for y: int in 2:
		for z: int in 2:
			for x: int in 2:
				var sub := _span(grid, lo + Vector3i(x, y, z) * half, half)
				if not sub.is_empty():
					out.append_array(sub.slice(0, BOX))


## The cell box round the solid cells of the block at `lo`, `n` cells a side (clamped to the
## grid): lower cell x, y, z, size x, y, z, then the solid count; empty when none.
func _span(grid: PackedByteArray, lo: Vector3i, n: int) -> PackedInt32Array:
	var a := site.size
	var b := -Vector3i.ONE
	var count := 0
	for y: int in range(maxi(0, lo.y), mini(site.size.y, lo.y + n)):
		for z: int in range(maxi(0, lo.z), mini(site.size.z, lo.z + n)):
			var row := site.index(Vector3i(0, y, z))
			for x: int in range(maxi(0, lo.x), mini(site.size.x, lo.x + n)):
				if grid[row + x] != 0:
					a = a.min(Vector3i(x, y, z))
					b = b.max(Vector3i(x, y, z))
					count += 1
	if count == 0:
		return PackedInt32Array()
	var size := b - a + Vector3i.ONE
	return PackedInt32Array([a.x, a.y, a.z, size.x, size.y, size.z, count])
