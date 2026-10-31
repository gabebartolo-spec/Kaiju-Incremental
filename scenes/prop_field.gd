class_name PropField
extends RefCounted
## Many small static props (cars, trees, streetlights) in one MultiMesh, each prop a group of
## instances that can be crushed when the kaiju stomps on it or walks over it. A car, bush or
## lamp flattens; a tree bursts: its trunk and crown go to voxel debris in their own colours
## (thrown like a building's) and a pale stump stays (critic on #55: a toppled tree never read).
## Presentation only: the sim never knows props exist.

const TILE := 32.0  # props draw as one MultiMesh per ground square this size (culled apart)
const BUCKET := 8.0  # props are filed by ground cell of this size, so a crush looks nearby only
const STUMP := 2  # a crushed tree leaves its lowest cells this many high standing
const LEAF_EVERY := 4  # a crushed tree throws one piece per this many of its leaf cells
const BARK_EVERY := 1  # and every one of its bark cells above the stump

var vox := VoxelBuilder.new()
var voxel: float
var stump_color := Color(0.85, 0.77, 0.6)  # every crushed tree's stump: fresh-cut wood
var leaf_color := Color(0.42, 0.82, 0.24)  # a crushed tree's leaf debris (saturated: dusk light)
var bark_color := Color(0.55, 0.35, 0.17)  # and its bark debris
var throw_speed := 1.5  # how hard bark leaves a crushed tree, out and up
var leaf_speed := 1.0  # and leaves (slower: they land near the stump, not across the street)
var leaf_spread := 0.5  # how far each leaf's flight turns off the blow, at random
var puff_size := 1.0  # the dust puffs over a crushed tree's stump (m)
var puff_alpha := 0.3  # and how opaque each is at its peak
## Where crushed trees' debris flies, leaf and bark apart (bark bigger, to read); the owner adds
## both to the scene before it processes.
var leaf_field := DebrisField.new(Seeds.make("tree_leaf"), 160)
var bark_field := DebrisField.new(Seeds.make("tree_bark"), 60)
var stumps: Array[Vector3] = []  # trees crushed since the owner last drained this (earth puffs)
## Debris to throw since the owner last drained this: [position, colour, away] each.
var debris: Array[Array] = []
## Ground rects (x, z) where no prop is ever added (the river's bay, CityDecor).
var keep_out: Array[Rect2] = []
var _rng := Seeds.make("tree_burst")  # where in its crown each leaf starts, and its spread
var _groups: Array[Dictionary] = []
var _buckets: Dictionary = {}  # Vector2i cell -> Array of group indices
var _tiles: Array[MultiMeshInstance3D] = []  # build(): one per TILE square of ground


func _init(p_voxel: float) -> void:
	voxel = p_voxel


## Adds a prop: `shape` fills a VoxelBuilder in prop-local cells; `at` is its world base.
## Each prop is built into the shared builder offset by its own cell origin. fells: a tree,
## crushed to a stump and debris rather than flattened.
func add(at: Vector3, shape: Callable, fells := false) -> void:
	for r: Rect2 in keep_out:
		if r.has_point(Vector2(at.x, at.z)):
			return
	var local := VoxelBuilder.new()
	shape.call(local)
	var offset := Vector3i((at / voxel).round())
	offset.y = 0
	var before := vox.cells.size()
	for cell: Vector3i in local.cells:
		_copy(local, cell, vox, cell + offset)
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


## Where every tree (a prop added with fells) stands, on the ground plane.
func felled() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for group: Dictionary in _groups:
		if group.get("fells", false):
			var at: Vector3 = group["at"]
			out.append(Vector2(at.x, at.z))
	return out


## Builds the props into one MultiMesh per TILE m square of ground under one Node3D, so the camera
## culls the tiles it does not see (one city-wide MultiMesh was drawn whole whenever any prop
## showed; D-254's bigger city doubled that). Frustum culling only: what the camera shows is
## unchanged. glow: strength for palette colours with alpha 0 (lamps).
func build(palette: Dictionary, salt: int, glow: float) -> Node3D:
	var holder := Node3D.new()
	var by_tile := {}  # Vector2i -> group indices
	for n: int in _groups.size():
		var at: Vector3 = _groups[n]["at"]
		var key := Vector2i(floori(at.x / TILE), floori(at.z / TILE))
		if not by_tile.has(key):
			by_tile[key] = []
		var list: Array = by_tile[key]
		list.append(n)
	for key: Vector2i in by_tile:
		var tile := VoxelBuilder.new()
		tile.salt = salt
		tile.detail = true  # the city's surface family (flat surfaces P3)
		var members: Array = by_tile[key]
		for n: int in members:
			var local: VoxelBuilder = _groups[n]["local"]
			var offset: Vector3i = _groups[n]["offset"]
			for cell: Vector3i in local.cells:
				_copy(local, cell, tile, cell + offset)
		var mmi := tile.build(palette, voxel, glow, Vector3.ZERO)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mmi)
		_tiles.append(mmi)
		# Each prop remembers which instances of its tile are its voxels, so crushing touches
		# only those.
		var index_of := {}
		for i: int in tile.built_cells.size():
			index_of[tile.built_cells[i]] = i
		for n: int in members:
			_index(_groups[n], index_of, tile, _tiles.size() - 1)
	return holder


## One cell from `from` into `to` at `at`: its palette key, or its own colour (a baked model's).
static func _copy(from: VoxelBuilder, cell: Vector3i, to: VoxelBuilder, at: Vector3i) -> void:
	var key := from.key_at(cell)
	if key == VoxelBuilder.DIRECT:
		var color: Color = from.colors[cell]
		to.put_color(at, color)
	else:
		to.put(at, key)


func _index(group: Dictionary, index_of: Dictionary, tile: VoxelBuilder, at_tile: int) -> void:
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
			keys.append(str(tile.cells[cell + offset]))
	group["ids"] = ids
	group["heights"] = heights
	group["origins"] = origins
	group["keys"] = keys
	group["tile"] = at_tile
	group.erase("local")


## Flattens every prop whose base is within `radius` of `at` (ground plane); trees burst.
func crush(at: Vector3, radius: float) -> void:
	if _tiles.is_empty():
		return
	var lo := Vector2i(floori((at.x - radius) / BUCKET), floori((at.z - radius) / BUCKET))
	var hi := Vector2i(floori((at.x + radius) / BUCKET), floori((at.z + radius) / BUCKET))
	for bx: int in range(lo.x, hi.x + 1):
		for bz: int in range(lo.y, hi.y + 1):
			var bucket: Array = _buckets.get(Vector2i(bx, bz), [])
			for index: int in bucket:
				var group: Dictionary = _groups[index]
				var base: Vector3 = group["at"]
				if Vector2(base.x - at.x, base.z - at.z).length() <= radius:
					_crush_group(group, at)


## Flattens every prop whose base lies under a body: `foot` is its ground box (x across, y
## along) in the frame `body` (scale included), so the box turns and grows with it.
func crush_box(body: Transform3D, foot: Rect2) -> void:
	if _tiles.is_empty():
		return
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
					_crush_group(group, at)


## Takes the crushed-tree look from tuning's city section.
func configure(city: Dictionary) -> void:
	stump_color = Color(str(city["stump_color"]))
	leaf_color = Color(str(city["tree_debris_leaf"]))
	bark_color = Color(str(city["tree_debris_bark"]))
	throw_speed = Num.f(city["tree_debris_speed"])
	leaf_speed = Num.f(city["tree_leaf_speed"])
	leaf_spread = Num.f(city["tree_leaf_spread"])
	puff_size = Num.f(city["tree_puff_size"])
	puff_alpha = Num.f(city["tree_puff_alpha"])
	leaf_field.size_scale = Num.f(city["tree_debris_size"])
	bark_field.size_scale = Num.f(city["tree_bark_size"])
	leaf_field.lift = 0.0
	bark_field.lift = 0.0
	# A crushed tree's debris casts no shadow (lead, #55 r14: a grey smudge by the stump on the
	# contact frame, where the whole burst still sits together).
	leaf_field.shadows = false
	bark_field.shadows = false


## Throws what crushed trees left since the last call (before the fields process this frame,
## so the burst shows on the frame the tree goes), with two soft dust puffs over each stump.
func throw(fx: Fx) -> void:
	for piece: Array in debris:
		var from: Vector3 = piece[0]
		var tint: Color = piece[1]
		var away: Vector3 = piece[2]
		(bark_field if tint == bark_color else leaf_field).spawn(from, tint, away)
	debris.clear()
	for stump: Vector3 in stumps:
		for side: float in [-1.0, 1.0]:
			fx.tree_puff(stump + Vector3(side * puff_size * 0.25, 0, 0), puff_size, puff_alpha)
	stumps.clear()


func _crush_group(group: Dictionary, at: Vector3) -> void:
	if group.get("crushed", false):
		return
	var mm := _tiles[Num.i(group["tile"])].multimesh
	group["crushed"] = true
	if group.get("fells", false):
		_burst(mm, group, at)
		return
	# Origins come from the prop's own copy: reading them back from the MultiMesh stalled a
	# topple's landing up to 66 ms (bench 10-31, decor.crush).
	var ids: PackedInt32Array = group["ids"]
	var origins: PackedVector3Array = group["origins"]
	var flat := Basis.from_scale(Vector3(1.15, 0.25, 1.15))
	for k: int in ids.size():
		var o := origins[k]
		mm.set_instance_transform(
			ids[k], Transform3D(flat, Vector3(o.x, o.y * 0.2 + voxel * 0.1, o.z))
		)


## A tree is crushed in place, all on this frame: the stump (its lowest STUMP cells) turns the
## stump colour, every cell above it is hidden, and one in LEAF_EVERY leaf cells and one in
## BARK_EVERY bark cells is thrown as leaf-green or bark-brown debris, away from the blow and
## up. Leaves start anywhere inside the crown, centre included, each turned off the blow at
## random (lead, #55 r14: from the crown's shell they flew as a ring). Nothing rotates or slides.
func _burst(mm: MultiMesh, group: Dictionary, at: Vector3) -> void:
	var base: Vector3 = group["at"]
	var ids: PackedInt32Array = group["ids"]
	var heights: PackedInt32Array = group["heights"]
	var origins: PackedVector3Array = group["origins"]
	var keys: PackedStringArray = group["keys"]
	var out := Vector3(base.x - at.x, 0, base.z - at.z).normalized()
	var crown := _crown(origins, keys)
	var mid: Vector3 = crown[0]
	var reach: float = crown[1]
	# Bark comes out toward the game camera (south, +z), from under the falling leaves at once.
	var flung := (out + Vector3.BACK * 1.5 + Vector3.UP) * throw_speed
	var thrown := 0
	var gone := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	for k: int in ids.size():
		if heights[k] < STUMP:  # the cut top shows fresh wood; the stump's sides keep their bark
			if heights[k] == STUMP - 1:
				mm.set_instance_color(ids[k], stump_color)
			continue
		mm.set_instance_transform(ids[k], gone)
		var bark := keys[k] == "bark"
		if k % (BARK_EVERY if bark else LEAF_EVERY) == 0:
			var from := origins[k]
			if bark:  # scattered round the trunk, so the bark bursts instead of rising as a stack
				var turn := float(k) * 2.39996  # golden angle: evenly spread, the same every run
				from += Vector3(cos(turn), 0, sin(turn)) * voxel * 3.0
				debris.append([from, bark_color, flung])
			else:
				var aim := _rng.randf() * TAU
				var side := Vector3(cos(aim), 0, sin(aim))
				var lean := Vector3(cos(aim + 1.0), _rng.randf_range(-0.5, 0.5), sin(aim + 1.0))
				from = mid + lean * _rng.randf() * reach
				var away := (out + Vector3.UP + side * _rng.randf() * leaf_spread) * leaf_speed
				debris.append([from, leaf_color, away])
			thrown += 1
	group["stump_color"] = stump_color
	group["debris"] = thrown
	stumps.append(base)


## A tree's crown: the middle of its leaf cells and how far the farthest lies from it.
func _crown(origins: PackedVector3Array, keys: PackedStringArray) -> Array:
	var sum := Vector3.ZERO
	var count := 0
	for k: int in keys.size():
		if keys[k] != "bark":
			sum += origins[k]
			count += 1
	var mid := sum / maxf(count, 1)
	var reach := 0.0
	for k: int in keys.size():
		if keys[k] != "bark":
			reach = maxf(reach, mid.distance_to(origins[k]))
	return [mid, reach]
