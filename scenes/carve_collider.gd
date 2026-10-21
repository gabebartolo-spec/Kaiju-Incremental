class_name CarveCollider
extends Node3D
## What still stands of a carved building, as static colliders for its debris and its falling
## islands: one static body per region (REGION bricks a side) so a carve rebuilds only the
## regions it touched, and a box per brick round its cells; a brick its cells fill thinly (a
## corner of wall, a slab with a hole) gets a box per half-brick instead, so pieces do not land
## on air inside the building. Reads the sim's grid; never writes it.

const REGION := 2  # bricks per region side
const SPARSE := 0.35  # a brick whose cells fill less of its box than this is split in eight

var site: CarveSite
var _regions: Dictionary = {}  # region -> StaticBody3D


func _init(p_site: CarveSite) -> void:
	site = p_site


## Builds every region from the whole grid.
func build(grid: PackedByteArray) -> void:
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
	refresh(grid, regions)


## Rebuilds the regions that hold any of `cells` (indices).
func touched(grid: PackedByteArray, cells: PackedInt32Array) -> void:
	var regions := {}
	for i: int in cells:
		regions[site.cell(i) / site.res / REGION] = true
	refresh(grid, regions)


func refresh(grid: PackedByteArray, regions: Dictionary) -> void:
	for key: Vector3i in regions:
		_rebuild(grid, key)


func _rebuild(grid: PackedByteArray, region: Vector3i) -> void:
	var boxes: Array[AABB] = []
	for y: int in REGION:
		for z: int in REGION:
			for x: int in REGION:
				_brick_boxes(grid, region * REGION + Vector3i(x, y, z), boxes)
	var body: StaticBody3D = _regions.get(region)
	if body != null:
		_regions.erase(region)
		body.queue_free()
	if boxes.is_empty():
		return
	body = StaticBody3D.new()
	for box: AABB in boxes:
		var shape := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = box.size
		shape.shape = b
		shape.position = box.get_center()
		body.add_child(shape)
	add_child(body)
	_regions[region] = body


func _brick_boxes(grid: PackedByteArray, brick: Vector3i, out: Array[AABB]) -> void:
	var lo := brick * site.res
	var whole := _span(grid, lo, Vector3i.ONE * site.res)
	if whole.size == Vector3.ZERO:
		return
	var cells_in_box := whole.get_volume() * pow(site.res, 3)
	var filled := _count(grid, lo, Vector3i.ONE * site.res) / cells_in_box
	if filled >= SPARSE or site.res < 2:
		out.append(whole)
		return
	var half := site.res >> 1
	for y: int in 2:
		for z: int in 2:
			for x: int in 2:
				var sub := _span(grid, lo + Vector3i(x, y, z) * half, Vector3i.ONE * half)
				if sub.size != Vector3.ZERO:
					out.append(sub)


## The world box round the solid cells of the block at `lo` of `n` cells a side (zero if none).
func _span(grid: PackedByteArray, lo: Vector3i, n: Vector3i) -> AABB:
	var a := site.size
	var b := -Vector3i.ONE
	for y: int in range(lo.y, mini(site.size.y, lo.y + n.y)):
		for z: int in range(lo.z, mini(site.size.z, lo.z + n.z)):
			var row := site.index(Vector3i(0, y, z))
			for x: int in range(lo.x, mini(site.size.x, lo.x + n.x)):
				if grid[row + x] != 0:
					a = a.min(Vector3i(x, y, z))
					b = b.max(Vector3i(x, y, z))
	if b.x < 0:
		return AABB()
	var s := 1.0 / site.res
	return AABB(site.origin + Vector3(a) * s, Vector3(b - a + Vector3i.ONE) * s)


func _count(grid: PackedByteArray, lo: Vector3i, n: Vector3i) -> float:
	var total := 0
	for y: int in range(lo.y, mini(site.size.y, lo.y + n.y)):
		for z: int in range(lo.z, mini(site.size.z, lo.z + n.z)):
			var row := site.index(Vector3i(0, y, z))
			for x: int in range(lo.x, mini(site.size.x, lo.x + n.x)):
				if grid[row + x] != 0:
					total += 1
	return float(total)
