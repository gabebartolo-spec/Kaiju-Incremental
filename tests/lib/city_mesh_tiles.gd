extends RefCounted
## The city's props and skyline are drawn as ground tiles (MeshTiles: each culled on its own,
## perf study 2026-10-21) and the tiles hold exactly the instances the one city-wide MultiMesh
## held: every instance once, in the tile under it, in the source's order inside its tile, the
## same mesh in every tile; the props' voxels are built in the same order as an untiled build.
## Headless Godot keeps no instance transforms (its renderer drops them), so the drawn values are
## proved by the 4K pixel diff on every preset (to-kaiju/015).


static func check(root: Window, check_fn: Callable) -> void:
	var base: Dictionary = Content.tuning()
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	var sim := RampageSim.new(
		stats,
		CityGrowth.tuning_for(base, 1),
		CityGrowth.layout(base, 1, Seeds.make("city", 0)),
		Seeds.make("army", 0)
	)
	var holder := Node3D.new()
	root.add_child(holder)
	var decor := CityDecor.new(sim, Seeds.make("decor", 0))
	holder.add_child(decor)
	var ground := CityGround.new(sim.city)
	holder.add_child(ground)
	var skyline := CitySkyline.new(ground, Seeds.make("skyline", 0))
	holder.add_child(skyline)
	var props := decor._props
	var cells := props.vox.built_cells
	var lift := Vector3(0, props.voxel * 0.5, 0)
	var at := PackedVector3Array()
	for cell: Vector3i in cells:
		at.append(Vector3(cell) * props.voxel + lift)
	var why := _misplaced(props._tiles, at, Num.f(sim.city["prop_tile"]))
	var again := VoxelBuilder.new()
	again.cells = props.vox.cells
	again.build({}, props.voxel, 0.0, Vector3.ZERO).free()
	check_fn.call(
		why == "" and again.built_cells == cells,
		(
			"the props' %d voxels sit in %d tiles, each once, in order, as an untiled build (%s)"
			% [cells.size(), props._tiles.multimeshes.size(), why]
		)
	)
	var tiles: Array[MeshTiles] = []
	_collect(skyline, tiles)
	var hazy := 0
	for box: Dictionary in skyline._plain:
		hazy += 1 if box["hazy"] else 0
	var want: Array[int] = [
		skyline._near.size(), skyline._far.size(), skyline._plain.size() - hazy, hazy
	]
	want.append(skyline._lamps.size())
	var got: Array[int] = []
	var bad := ""
	for t: MeshTiles in tiles:
		got.append(t.instance_count())
		var sum := 0
		for mm: MultiMesh in t.multimeshes:
			sum += mm.instance_count
			bad = "a tile with its own mesh" if mm.mesh != t.mesh else bad
		if sum != t.instance_count():
			bad = "tiles hold %d of %d" % [sum, t.instance_count()]
	check_fn.call(
		got == want and bad == "",
		(
			"the skyline's stand-ins, boxes and lamps are tiled whole: %s instances for %s (%s)"
			% [got, want, bad]
		)
	)
	holder.free()


## Why `tiles` does not hold instance i of `at` in the tile under at[i], at the next slot in that
## tile (source order), each slot once, with one mesh; "" when it does.
static func _misplaced(tiles: MeshTiles, at: PackedVector3Array, size: float) -> String:
	if tiles.instance_count() != at.size():
		return "%d tiled of %d" % [tiles.instance_count(), at.size()]
	var tile_at := {}  # Vector2i ground tile -> tile index
	var ground_of := {}  # tile index -> its ground tile
	var next := PackedInt32Array()
	next.resize(tiles.multimeshes.size())
	for i: int in at.size():
		var key := Vector2i(floori(at[i].x / size), floori(at[i].z / size))
		var tile := tiles.tile_of[i]
		if tile_at.get(key, tile) != tile or ground_of.get(tile, key) != key:
			return "instance %d in tile %d, not the one under it" % [i, tile]
		tile_at[key] = tile
		ground_of[tile] = key
		if tiles.slot_of[i] != next[tile]:
			return "instance %d at slot %d of tile %d" % [i, tiles.slot_of[i], tile]
		next[tile] += 1
	for t: int in next.size():
		var mm := tiles.multimeshes[t]
		if mm.instance_count != next[t] or mm.mesh != tiles.mesh:
			return "tile %d holds %d of %d" % [t, mm.instance_count, next[t]]
	return ""


static func _collect(node: Node, into: Array[MeshTiles]) -> void:
	for child: Node in node.get_children():
		if child is MeshTiles:
			into.append(child as MeshTiles)
		else:
			_collect(child, into)
