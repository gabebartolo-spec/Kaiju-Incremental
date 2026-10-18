class_name PropField
extends RefCounted
## Many small static props (cars, trees, streetlights) in one MultiMesh, each prop a group of
## instances that can be crushed when the kaiju stomps on it or walks over it. A car, bush or
## lamp flattens; a tree bursts: its trunk and crown go to voxel debris in their own colours
## (thrown like a building's) and a pale stump stays (critic on #55: a toppled tree never read).
## Presentation only: the sim never knows props exist.

const BUCKET := 8.0  # props are filed by ground cell of this size, so a crush looks nearby only
const STUMP := 2  # a crushed tree leaves its lowest cells this many high standing
const DEBRIS_EVERY := 4  # a crushed tree throws one piece of debris per this many of its cells

var vox := VoxelBuilder.new()
var voxel: float
var stump_color := Color(0.85, 0.77, 0.6)  # every crushed tree's stump: fresh-cut wood
var debris_lift := 0.0  # a tree's debris goes this much toward white, to read in the city's dusk
var stumps: Array[Vector3] = []  # trees crushed since the owner last drained this (earth puffs)
## Debris to throw since the owner last drained this: [position, colour, away] each.
var debris: Array[Array] = []
var _groups: Array[Dictionary] = []
var _buckets: Dictionary = {}  # Vector2i cell -> Array of group indices
var _mmi: MultiMeshInstance3D


func _init(p_voxel: float) -> void:
	voxel = p_voxel


## Adds a prop: `shape` fills a VoxelBuilder in prop-local cells; `at` is its world base.
## Each prop is built into the shared builder offset by its own cell origin. fells: a tree,
## crushed to a stump and debris rather than flattened.
func add(at: Vector3, shape: Callable, fells := false) -> void:
	var local := VoxelBuilder.new()
	shape.call(local)
	var offset := Vector3i((at / voxel).round())
	offset.y = 0
	var before := vox.cells.size()
	for cell: Vector3i in local.cells:
		vox.put(cell + offset, local.key_at(cell))
	_groups.append(
		{
			"at": at,
			"cells": vox.cells.size() - before,
			"offset": offset,
			"local": local,
			"fells": fells
		}
	)
	var key := Vector2i(floori(at.x / BUCKET), floori(at.z / BUCKET))
	if not _buckets.has(key):
		_buckets[key] = []
	var bucket: Array = _buckets[key]
	bucket.append(_groups.size() - 1)


## glow: strength for palette colours with alpha 0 (lamps).
## glow: strength for palette colours with alpha 0 (lamps).
func build(palette: Dictionary, salt: int, glow: float) -> MultiMeshInstance3D:
	vox.salt = salt
	_mmi = vox.build(palette, voxel, glow, Vector3.ZERO)
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Each prop remembers which instances are its voxels, so crushing touches only those.
	var index_of := {}
	for i: int in vox.built_cells.size():
		index_of[vox.built_cells[i]] = i
	for group: Dictionary in _groups:
		var local: VoxelBuilder = group["local"]
		var offset: Vector3i = group["offset"]
		var ids := PackedInt32Array()
		var heights := PackedInt32Array()  # each instance's prop-local cell height
		var origins := PackedVector3Array()  # where each is drawn (kept here: headless keeps none)
		var colors := PackedColorArray()  # and its colour, for debris
		for cell: Vector3i in local.cells:
			if index_of.has(cell + offset):
				var idx: int = index_of[cell + offset]
				ids.append(idx)
				heights.append(cell.y)
				origins.append(Vector3(cell + offset) * voxel + Vector3(0, voxel * 0.5, 0))
				var key: String = vox.cells[cell + offset]
				var tint: Color = (
					vox.colors[cell + offset]
					if key == VoxelBuilder.DIRECT
					else palette.get(key, Color.MAGENTA)
				)
				colors.append(Look.jitter(tint, cell + offset, salt))
		group["ids"] = ids
		group["heights"] = heights
		group["origins"] = origins
		group["colors"] = colors
		group.erase("local")
	return _mmi


## Flattens every prop whose base is within `radius` of `at` (ground plane); trees burst.
func crush(at: Vector3, radius: float) -> void:
	if _mmi == null:
		return
	var mm := _mmi.multimesh
	var lo := Vector2i(floori((at.x - radius) / BUCKET), floori((at.z - radius) / BUCKET))
	var hi := Vector2i(floori((at.x + radius) / BUCKET), floori((at.z + radius) / BUCKET))
	for bx: int in range(lo.x, hi.x + 1):
		for bz: int in range(lo.y, hi.y + 1):
			var bucket: Array = _buckets.get(Vector2i(bx, bz), [])
			for index: int in bucket:
				var group: Dictionary = _groups[index]
				var base: Vector3 = group["at"]
				if Vector2(base.x - at.x, base.z - at.z).length() <= radius:
					_crush_group(mm, group, at)


## Flattens every prop whose base lies under a body: `foot` is its ground box (x across, y
## along) in the frame `body` (scale included), so the box turns and grows with it.
func crush_box(body: Transform3D, foot: Rect2) -> void:
	if _mmi == null:
		return
	var mm := _mmi.multimesh
	var reach := maxf(foot.position.length(), foot.end.length()) * body.basis.get_scale().x
	var at := body.origin
	var into := body.affine_inverse()
	var lo := Vector2i(floori((at.x - reach) / BUCKET), floori((at.z - reach) / BUCKET))
	var hi := Vector2i(floori((at.x + reach) / BUCKET), floori((at.z + reach) / BUCKET))
	for bx: int in range(lo.x, hi.x + 1):
		for bz: int in range(lo.y, hi.y + 1):
			var bucket: Array = _buckets.get(Vector2i(bx, bz), [])
			for index: int in bucket:
				var group: Dictionary = _groups[index]
				var base: Vector3 = group["at"]
				var local := into * Vector3(base.x, at.y, base.z)
				if foot.has_point(Vector2(local.x, local.z)):
					_crush_group(mm, group, at)


## Sends what crushed trees left since the last call to the city's debris (none without a
## city, as in tests) and an earth puff at each stump.
func throw(city: CityView, fx: Fx) -> void:
	for piece: Array in debris:
		var from: Vector3 = piece[0]
		var tint: Color = piece[1]
		var away: Vector3 = piece[2]
		if city != null:
			city.debris(from, tint, away)
	debris.clear()
	for stump: Vector3 in stumps:
		fx.earth_puff(stump + Vector3(0, 0.2, 0))
	stumps.clear()


func _crush_group(mm: MultiMesh, group: Dictionary, at: Vector3) -> void:
	if group.get("crushed", false):
		return
	group["crushed"] = true
	if group.get("fells", false):
		_burst(mm, group, at)
		return
	var ids: PackedInt32Array = group["ids"]
	for i: int in ids:
		var t := mm.get_instance_transform(i)
		t.origin.y = t.origin.y * 0.2 + voxel * 0.1
		t.basis = Basis.from_scale(Vector3(1.15, 0.25, 1.15))
		mm.set_instance_transform(i, t)


## A tree is crushed in place, all on this frame: the stump (its lowest STUMP cells) turns the
## stump colour, every cell above it is hidden, and one in DEBRIS_EVERY of those is thrown as
## debris in its own leaf or bark colour, away from the blow and up. Nothing rotates or slides.
func _burst(mm: MultiMesh, group: Dictionary, at: Vector3) -> void:
	var base: Vector3 = group["at"]
	var ids: PackedInt32Array = group["ids"]
	var heights: PackedInt32Array = group["heights"]
	var origins: PackedVector3Array = group["origins"]
	var colors: PackedColorArray = group["colors"]
	var out := Vector3(base.x - at.x, 0, base.z - at.z).normalized()
	var thrown := 0
	var gone := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	for k: int in ids.size():
		if heights[k] < STUMP:
			mm.set_instance_color(ids[k], stump_color)
			continue
		mm.set_instance_transform(ids[k], gone)
		if k % DEBRIS_EVERY == 0:
			debris.append([origins[k], colors[k].lightened(debris_lift), out + Vector3(0, 1.0, 0)])
			thrown += 1
	group["stump_color"] = stump_color
	group["debris"] = thrown
	stumps.append(base)
