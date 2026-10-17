extends RefCounted
## The load suite's landmark check, split out to keep the runner small.

var _check: Callable


## check: the runner's check(condition, expectation).
func _init(p_check: Callable) -> void:
	_check = p_check


## A landmark draws its baked model (LandmarkVoxels) on the building grid: every voxel inside its
## footprint and in a chunk the sim builds, so each one breaks with its chunk; it meshes to real
## faces and leaves debris samples in its chunks; hiding a chunk switches its voxels off.
func run() -> void:
	var shape: Dictionary = Content.landmarks().get("stadium", {})
	var b := RampageSim.Building.new()
	b.w = Num.i(shape.get("w", 1))
	b.d = Num.i(shape.get("d", 1))
	b.height = Num.i(shape.get("h", 1))
	b.tier = 1
	b.landmark = "stadium"
	b.frame = Structure.new(b.w, b.d, b.height, 1.0)
	var layers: Array = shape.get("chunks", [])
	b.frame.keep(layers)
	var t0 := Time.get_ticks_msec()
	var view := BuildingView.new(b, Color.GRAY)
	var build_ms := Time.get_ticks_msec() - t0
	var cells: Dictionary = view.voxels.vox.cells
	var res := BuildingVoxels.RES
	var stray := 0
	for c: Vector3i in cells:
		if not b.frame.alive(Vector3i(c.x / res, c.y / res, c.z / res)):
			stray += 1
	_check.call(
		view.voxels is LandmarkVoxels and cells.size() > 10000 and stray == 0,
		(
			"the stadium's %d voxels all sit in chunks the sim builds (%d stray)"
			% [cells.size(), stray]
		)
	)
	var shell := view.mesher.shell
	var faces := shell.surface_get_array_len(0) / 4 if shell.get_surface_count() > 0 else 0
	_check.call(
		faces > cells.size() / 2 and faces < cells.size() * 4,
		"the stadium meshes to its open faces only: %d faces for %d voxels" % [faces, cells.size()]
	)
	var sampled := view.mesher.samples.size()
	_check.call(
		sampled * 2 > b.frame.alive_count,
		"most of its chunks throw debris when broken: %d of %d" % [sampled, b.frame.alive_count]
	)
	print("landmark view: stadium built in %d ms" % build_ms)
	view.free()
