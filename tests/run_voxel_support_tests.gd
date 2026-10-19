extends "res://tests/lib/runner.gd"
## Voxel support suite: VoxelFrame's support rule on small hand-built grids (D-094 WP1, the
## review FIX on #97): the topple rule on a grounded part and on an island, adopt's guard,
## re-settling after a topple, and the fixture rule (panes and signs hang on their wall by a
## face, an edge or a corner and hold nothing up). Fast; the spike's replays and pins stay in
## the destruction suite. Headless, no autoloads.
## Seeded by design: VoxelFrame has no randomness; every outcome is a function of the cells.
##   godot --headless --path . --script tests/run_voxel_support_tests.gd

const Paths := preload("res://tests/lib/destruction_paths.gd")
## The fixtures here are built at RES 4 (small grids, same rules as RES 8).
const RES := 4


func suite_name() -> String:
	return "Voxel support"


func run_checks() -> void:
	await _t("_check_overhang")
	await _t("_check_island_support")
	await _t("_check_adopt_guard")
	await _t("_check_resettle")
	await _t("_check_fixture_edge")
	await _t("_check_fixture_cut_free")
	await _t("_check_fixture_holds_nothing")


func _frame(units: Vector3i, res: int = RES) -> VoxelFrame:
	return VoxelFrame.new(units, res, Paths.MATERIALS)


## Structure's topple rule at cell level on the grounded part: a slab hung out past the post
## holding it topples over the post's edge (RFG's fix for "held up by a chimney"); the same
## slab centred on the post stands.
func _check_overhang() -> void:
	var out: Array[Array] = []
	for shift: int in [0, -2]:
		var f := _frame(Vector3i(6, 4, 1))
		var wall := f.material_id("wall")
		var post := 2 * f.res if shift == -2 else 0
		f.fill(Vector3i(post, 0, 0), Vector3i(post + f.res, 3 * f.res, f.d), wall)
		f.fill(Vector3i(0, 3 * f.res, 0), Vector3i(f.w, 4 * f.res, f.d), wall)
		out.append(f.settle())
	var hung: Array = out[0]
	check(
		hung.size() == 1 and str(hung[0]["kind"]) == "topple",
		"the overhung slab topples: %s" % [_kinds(hung)]
	)
	if hung.size() == 1:
		var e: Dictionary = hung[0]
		check(
			e["dir"] is Vector2i and e["pivot"] is Vector3 and e["cells"] is Array, "settle shape"
		)
		var dir: Vector2i = e["dir"]
		var pivot: Vector3 = e["pivot"]
		check(
			dir == Vector2i(1, 0) and is_equal_approx(pivot.x, 1.0),
			"it tips +x over the post's edge at x 1: %s %s" % [dir, pivot]
		)
	var centred: Array = out[1]
	check(centred.is_empty(), "the slab centred on its post stands: %s" % [_kinds(centred)])


## The support rule on islands: a loose block lands on the cells nearest below it; hung past
## them it topples over their edge, centred on them it drops.
func _check_island_support() -> void:
	var kinds: Array[String] = []
	var dirs: Array[Vector2i] = []
	for post_x: int in [0, 2]:
		var f := _frame(Vector3i(5, 5, 1))
		var wall := f.material_id("wall")
		f.fill(Vector3i(post_x * f.res, 0, 0), Vector3i((post_x + 1) * f.res, 2 * f.res, f.d), wall)
		f.fill(Vector3i(0, 3 * f.res, 0), Vector3i(f.w, 4 * f.res, f.d), wall)
		var parts := f.settle()
		kinds.append(",".join(_kinds(parts)))
		dirs.append(parts[0]["dir"] if parts.size() == 1 else Vector2i(9, 9))
	check(
		kinds == ["topple", "drop"] and dirs[0] == Vector2i(1, 0),
		"a loose block off its post topples +x, centred it drops: %s %s" % [kinds, dirs]
	)


## adopt() refuses a grid whose ground is not grid layer 0 (the flood seeds from layer 0) or
## whose size does not match its bytes, and leaves the frame as it was.
func _check_adopt_guard() -> void:
	var dims := Vector3i(4, 8, 4)
	var grid := PackedByteArray()
	grid.resize(dims.x * dims.y * dims.z)
	grid.fill(1)
	var f := _frame(Vector3i(1, 1, 1))
	var low := f.adopt(dims, Vector3i(0, -1, 0), grid)
	var short := f.adopt(Vector3i(4, 9, 4), Vector3i.ZERO, grid)
	check(
		not low and not short and f.alive_count == 0 and f.h == 4,
		"adopt refuses offset.y -1 and a size that does not match its bytes (%s %s)" % [low, short]
	)
	var ok := f.adopt(dims, Vector3i(-2, 0, -2), grid)
	check(ok and f.alive_count == grid.size() and f.settle().is_empty(), "adopt takes a sound grid")


## Review FIX 1 on #97: after a topple, what hung from the toppled load below its level has
## nothing under it and drops in the same settle (the reviewer's repro: a post, a slab across it,
## a rod hung from the slab's far end; RES 4).
func _check_resettle() -> void:
	var f := _frame(Vector3i(8, 8, 1))
	var wall := f.material_id("wall")
	f.fill(Vector3i(8, 0, 0), Vector3i(12, 24, f.d), wall)
	f.fill(Vector3i(0, 24, 0), Vector3i(32, 28, f.d), wall)
	f.fill(Vector3i(0, 12, 0), Vector3i(4, 24, f.d), wall)
	var events := f.settle()
	var sizes: Array[int] = []
	for e: Dictionary in events:
		var cells: Array[Vector3i] = e["cells"]
		sizes.append(cells.size())
	check(
		_kinds(events) == ["topple", "drop"] and sizes == [832, 32],
		"the slab topples and the rod's foot drops with it: %s %s" % [_kinds(events), sizes]
	)
	var left := f.detach()
	check(left.is_empty(), "nothing is left floating after settle (%d parts)" % left.size())


## Lead rule on #97: a fixture (a recessed window pane) touching its wall only by an edge is
## attached; the same cells as a structural material would be an island.
func _check_fixture_edge() -> void:
	var counts: Array[int] = []
	for name: String in ["window", "wall"]:
		var f := _frame(Vector3i(2, 2, 1))
		f.fill(Vector3i(0, 0, 0), Vector3i(4, 8, 1), f.material_id("wall"))
		f.fill(Vector3i(4, 2, 1), Vector3i(8, 6, 2), f.material_id(name))
		counts.append(f.settle().size())
	check(
		counts == [0, 1],
		"an edge-only pane stays put; an edge-only wall block drops: %s" % [counts]
	)


## A pane whose wall is carved away drops, as one part, all of it.
func _check_fixture_cut_free() -> void:
	var f := _frame(Vector3i(2, 2, 1))
	var window := f.material_id("window")
	f.fill(Vector3i(0, 0, 0), Vector3i(4, 8, 1), f.material_id("wall"))
	f.fill(Vector3i(4, 2, 1), Vector3i(8, 6, 2), window)
	f.fill(Vector3i(3, 0, 0), Vector3i(4, 8, 1), VoxelFrame.EMPTY)
	var events := f.settle()
	var whole := events.size() == 1 and str(events[0]["kind"]) == "drop"
	if whole:
		var mats: PackedByteArray = events[0]["mats"]
		whole = mats.size() == 16 and mats.count(window) == 16
	check(whole, "the pane cut free drops whole: %s" % [_kinds(events)])
	check(f.detach().is_empty() and f.alive_count == 24, "the rest of the wall stands")


## Fixtures never hold up structural cells: a wall cell touching only a pane drops, the pane
## stays.
func _check_fixture_holds_nothing() -> void:
	var f := _frame(Vector3i(2, 2, 1))
	f.fill(Vector3i(0, 0, 0), Vector3i(4, 8, 1), f.material_id("wall"))
	f.set_cell(Vector3i(4, 4, 1), f.material_id("window"))
	f.set_cell(Vector3i(5, 4, 1), f.material_id("wall"))
	var events := f.settle()
	var lone := events.size() == 1
	if lone:
		var cells: Array[Vector3i] = events[0]["cells"]
		lone = cells == [Vector3i(5, 4, 1)]
	check(lone, "a wall cell held only by a pane drops: %s" % [_kinds(events)])
	check(f.alive(Vector3i(4, 4, 1)), "the pane itself stays")


func _kinds(parts: Array) -> Array[String]:
	var out: Array[String] = []
	for part: Dictionary in parts:
		out.append(str(part["kind"]))
	return out
