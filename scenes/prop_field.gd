class_name PropField
extends RefCounted
## Many small static props (cars, trees, streetlights) in one MultiMesh, each prop a group of
## instances that can be crushed when the kaiju stomps on it or walks over it. A car, bush or
## lamp flattens; a tree bursts: its trunk and crown go to voxel debris in their own colours
## (thrown like a building's) and a pale stump stays (critic on #55: a toppled tree never read).
## Presentation only: the sim never knows props exist.

const BUCKET := 8.0  # props are filed by ground cell of this size, so a crush looks nearby only
const STUMP := 2  # a crushed tree leaves its lowest cells this many high standing
const LEAF_EVERY := 3  # a crushed tree throws one piece per this many of its leaf cells
const BARK_EVERY := 1  # and every one of its bark cells above the stump

var vox := VoxelBuilder.new()
var voxel: float
var stump_color := Color(0.85, 0.77, 0.6)  # every crushed tree's stump: fresh-cut wood
var leaf_color := Color(0.42, 0.82, 0.24)  # a crushed tree's leaf debris (saturated: dusk light)
var bark_color := Color(0.55, 0.35, 0.17)  # and its bark debris
var throw_speed := 1.5  # how hard debris leaves a crushed tree, out and up
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
		var keys := PackedStringArray()  # and its palette key (bark or leaf, for debris)
		for cell: Vector3i in local.cells:
			if index_of.has(cell + offset):
				var idx: int = index_of[cell + offset]
				ids.append(idx)
				heights.append(cell.y)
				origins.append(Vector3(cell + offset) * voxel + Vector3(0, voxel * 0.5, 0))
				keys.append(str(vox.cells[cell + offset]))
		group["ids"] = ids
		group["heights"] = heights
		group["origins"] = origins
		group["keys"] = keys
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


## Takes the crushed-tree look from tuning's city section.
func configure(city: Dictionary) -> void:
	stump_color = Color(str(city["stump_color"]))
	leaf_color = Color(str(city["tree_debris_leaf"]))
	bark_color = Color(str(city["tree_debris_bark"]))
	throw_speed = Num.f(city["tree_debris_speed"])


## Sends what crushed trees left since the last call to `field` (null in tests) and an earth
## puff at each stump. Called before `field` processes this frame, so the burst shows on the
## frame the tree is crushed.
func throw(field: DebrisField, fx: Fx) -> void:
	for piece: Array in debris:
		var from: Vector3 = piece[0]
		var tint: Color = piece[1]
		var away: Vector3 = piece[2]
		if field != null:
			field.spawn(from, tint, away)
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
## stump colour, every cell above it is hidden, and one in LEAF_EVERY leaf cells and one in
## BARK_EVERY bark cells is thrown as leaf-green or bark-brown debris, away from the blow and
## up. Nothing rotates or slides.
func _burst(mm: MultiMesh, group: Dictionary, at: Vector3) -> void:
	var base: Vector3 = group["at"]
	var ids: PackedInt32Array = group["ids"]
	var heights: PackedInt32Array = group["heights"]
	var origins: PackedVector3Array = group["origins"]
	var keys: PackedStringArray = group["keys"]
	var out := Vector3(base.x - at.x, 0, base.z - at.z).normalized()
	var away := (out + Vector3.UP) * throw_speed
	var thrown := 0
	var gone := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	for k: int in ids.size():
		if heights[k] < STUMP:
			mm.set_instance_color(ids[k], stump_color)
			continue
		mm.set_instance_transform(ids[k], gone)
		var bark := keys[k] == "bark"
		if k % (BARK_EVERY if bark else LEAF_EVERY) == 0:
			debris.append([origins[k], bark_color if bark else leaf_color, away])
			thrown += 1
	group["stump_color"] = stump_color
	group["debris"] = thrown
	stumps.append(base)
