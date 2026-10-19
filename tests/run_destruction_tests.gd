extends "res://tests/lib/runner.gd"
## Destruction suite: the carving sim grid (VoxelFrame, D-094 WP1). Carves, the ground flood,
## islands, the support rule on islands and on the grounded remainder, the Structure-shaped
## events, and replay determinism on the destruction spike's paths. Headless, no autoloads.
## Seeded by design: VoxelFrame has no randomness; every outcome is a function of the blows.
##   godot --headless --path . --script tests/run_destruction_tests.gd

const Paths := preload("res://tests/lib/destruction_paths.gd")
const MODULES: Array[String] = ["res://sim/voxel_frame.gd", "res://sim/voxel_support.gd"]
const BANNED: Array[String] = [
	"Time.",
	"OS.",
	"Engine.",
	"randi",
	"randf",
	"randomize",
	"RandomNumberGenerator",
	"Node",
	"await",
	"Input."
]
## Spike pins (DESTRUCTION_SPIKE.md section 4): the tower path's island at RES 4 and 8.
const ISLAND_RES4 := 8415
const ISLAND_RES8 := 35428
## Block of six at RES 8 replays this many ticks (the base cuts of the first buildings);
## the full 10 s runs at RES 4 and for the tower.
const BLOCK_RES8_TICKS := 200

var _replays: Dictionary = {}


func suite_name() -> String:
	return "Destruction"


func run_checks() -> void:
	await _t("_check_data")
	await _t("_check_pure")
	await _t("_check_api")
	await _t("_check_outside_noop")
	await _t("_check_capsule")
	await _t("_check_offset")
	await _t("_check_tunnel")
	await _t("_check_base_cut")
	await _t("_check_overhang")
	await _t("_check_island_support")
	await _t("_check_island_pin")
	await _t("_check_replay_tower")
	await _t("_check_replay_block")


## RES from data (8); `res` overrides it for the RES 4 fixtures.
func _res(res: int = 0) -> int:
	return res if res > 0 else Num.i(Content.section("destruction")["res"])


func _frame(units: Vector3i, res: int = 0) -> VoxelFrame:
	return VoxelFrame.new(units, _res(res), Paths.MATERIALS)


## One replay per (res, block, support, ticks), run twice; cached so several checks share it.
func _replay(res: int, block: bool, support: bool, ticks: int) -> Array[Dictionary]:
	var key := "%d/%s/%s/%d" % [res, block, support, ticks]
	if not _replays.has(key):
		var runs: Array[Dictionary] = []
		for run: int in 2:
			runs.append(Paths.replay(res, block, support, ticks))
		_replays[key] = runs
	var out: Array[Dictionary] = _replays[key]
	return out


func _full_ticks() -> int:
	return roundi(Paths.SECONDS / Paths.TICK)


## The destruction tuning: RES 8 cells per sim unit (the grid the view already draws).
func _check_data() -> void:
	var cfg := Content.section("destruction")
	check(cfg.get("res") is float and Num.i(cfg["res"]) == 8, "destruction.res is 8: %s" % cfg)
	var f := _frame(Vector3i(6, 16, 6))
	check(
		f.w == 48 and f.h == 128 and f.cells.size() == 48 * 48 * 128,
		"a 6x6x16 frame at data RES is 48x128x48 cells, one byte each (%d)" % f.cells.size()
	)


## No clock, RNG, Node or await in the module (sim rules 2 and 3); the scan itself catches a
## planted clock call.
func _check_pure() -> void:
	var found: Array[String] = []
	for path: String in MODULES:
		var source := FileAccess.get_file_as_string(path)
		check(not source.is_empty(), "%s exists and reads" % path)
		for word: String in _banned_in(source):
			found.append("%s: %s" % [path.get_file(), word])
	check(found.is_empty(), "no clock, RNG, Node or await in the carving sim: %s" % [found])
	check(
		_banned_in("var t := Time.get_ticks_usec()\nvar r := randi()") == ["Time.", "randi"],
		"the scan finds a planted Time. and randi"
	)


func _banned_in(source: String) -> Array[String]:
	var out: Array[String] = []
	for line: String in source.split("\n"):
		var code := line.split("#")[0]
		for word: String in BANNED:
			if code.contains(word) and not out.has(word):
				out.append(word)
	return out


## Structure's API at cell level: alive, alive_count, top_below, and damage against each
## material's strength from data (glass breaks under a blow a wall shrugs off).
func _check_api() -> void:
	var f := _frame(Vector3i(1, 2, 1))
	var glass := f.material_id("glass")
	var wall := f.material_id("wall")
	check(f.w == 8 and f.d == 8 and f.h == 16 and f.res == 8, "1x2x1 units at RES 8 is 8x16x8")
	check(f.alive_count == 0 and not f.alive(Vector3i(0, 0, 0)), "a new frame is empty")
	f.set_cell(Vector3i(2, 3, 4), glass)
	f.set_cell(Vector3i(2, 9, 4), wall)
	f.set_cell(Vector3i(2, 0, 4), wall)
	check(f.alive_count == 3 and f.alive(Vector3i(2, 3, 4)), "set_cell adds cells")
	check(
		f.top_below(2, 4, 9) == 3 and f.top_below(2, 4, 3) == 0 and f.top_below(2, 4, 0) == -1,
		(
			"top_below finds the highest cell under a height: %d %d %d"
			% [f.top_below(2, 4, 9), f.top_below(2, 4, 3), f.top_below(2, 4, 0)]
		)
	)
	var soft := 3.0
	check(
		f.damage(Vector3i(2, 3, 4), soft) and not f.damage(Vector3i(2, 9, 4), soft),
		"a blow of %.0f breaks glass but not a wall" % soft
	)
	check(f.alive_count == 2 and not f.alive(Vector3i(2, 3, 4)), "the broken cell is gone")
	check(
		f.damage(Vector3i(2, 9, 4), 100.0) and not f.damage(Vector3i(2, 9, 4), 100.0),
		"a hard blow breaks the wall, once"
	)
	var block := _frame(Vector3i(1, 1, 1))
	block.fill(Vector3i.ZERO, Vector3i(8, 8, 8), block.material_id("pillar"))
	var weak := block.carve_sphere(Vector3(0.5, 0.5, 0.5), 0.3, 7.0)
	var strong := block.carve_sphere(Vector3(0.5, 0.5, 0.5), 0.3, 14.0)
	check(
		weak.is_empty() and strong.size() > 0 and block.alive_count == 512 - strong.size(),
		(
			"a carve spares cells stronger than its force (pillars, %d then %d carved)"
			% [weak.size(), strong.size()]
		)
	)


## A carve wholly outside the grid changes nothing; damage and remove outside are refused.
func _check_outside_noop() -> void:
	var f := Paths.office(Vector3i(2, 2, 2), _res())
	var before := f.digest()
	var count := f.alive_count
	var removed := f.carve_sphere(Vector3(-5, 1, 1), 2.0)
	removed.append_array(f.carve_sphere(Vector3(1, 30, 1), 3.0))
	removed.append_array(f.carve_capsule(Vector3(-9, 1, -9), Vector3(-3, 1, 9), 1.5))
	check(
		removed.is_empty() and f.digest() == before and f.alive_count == count,
		"carves outside the grid are no-ops (%d carved)" % removed.size()
	)
	check(f.settle().is_empty(), "nothing settles after a no-op carve")
	check(not f.damage(Vector3i(-1, 0, 0), 100.0), "damage outside the grid is refused")
	f.remove(Vector3i(0, 99, 0))
	check(f.alive_count == count and f.digest() == before, "remove outside the grid is a no-op")


## A capsule (a swipe) carves the union of spheres along its segment, and nothing beyond.
func _check_capsule() -> void:
	var swept := _frame(Vector3i(4, 2, 2), 4)
	swept.fill(Vector3i.ZERO, Vector3i(swept.w, swept.h, swept.d), swept.material_id("wall"))
	var dotted := _frame(Vector3i(4, 2, 2), 4)
	dotted.fill(Vector3i.ZERO, Vector3i(dotted.w, dotted.h, dotted.d), dotted.material_id("wall"))
	var a := Vector3(0.5, 1.0, 1.0)
	var b := Vector3(3.5, 1.0, 1.0)
	var n := swept.carve_capsule(a, b, 0.6).size()
	for k: int in 61:
		dotted.carve_sphere(a.lerp(b, k / 60.0), 0.6)
	check(n > 0 and swept.digest() == dotted.digest(), "a capsule equals spheres along it (%d)" % n)
	var dot := _frame(Vector3i(4, 2, 2), 4)
	dot.fill(Vector3i.ZERO, Vector3i(dot.w, dot.h, dot.d), dot.material_id("wall"))
	var ball := _frame(Vector3i(4, 2, 2), 4)
	ball.fill(Vector3i.ZERO, Vector3i(ball.w, ball.h, ball.d), ball.material_id("wall"))
	var point := dot.carve_capsule(a, a, 0.6)
	check(
		point.size() > 0 and point == ball.carve_sphere(a, 0.6),
		"a zero-length capsule is a sphere (%d cells)" % point.size()
	)


## A grid adopted with an origin offset (WP3's BuildingCells: sills and signs stand proud of
## the footprint at x, z < 0): carves, cells, top_below and events are building-local, the
## same as the zero-offset grid shifted.
func _check_offset() -> void:
	var dims := Vector3i(12, 8, 12)
	var shift := Vector3i(-2, 0, -2)
	var plain := _frame(Vector3i(1, 1, 1), 4)
	var grid := PackedByteArray()
	grid.resize(dims.x * dims.y * dims.z)
	plain.adopt(dims, Vector3i.ZERO, grid)
	plain.fill(Vector3i(0, 0, 0), Vector3i(4, 8, 4), plain.material_id("wall"))
	plain.fill(Vector3i(0, 7, 0), Vector3i(12, 8, 4), plain.material_id("wall"))
	var moved := _frame(Vector3i(1, 1, 1), 4)
	moved.adopt(dims, shift, plain.cells)
	check(
		moved.alive_count == plain.alive_count and moved.w == 12 and moved.offset == shift,
		"adopt takes the grid, its size and offset (%d cells)" % moved.alive_count
	)
	var lit := moved.alive(Vector3i(-2, 0, -2)) and not moved.alive(Vector3i(2, 0, 2))
	check(lit and moved.top_below(-1, -1, 99) == 7, "cells and top_below are building-local")
	var at := Vector3(0.0, 0.25, 0.0)
	var a := plain.carve_sphere(at, 0.3)
	var b := moved.carve_sphere(at + Vector3(shift) / 4.0, 0.3)
	check(
		a.size() > 0 and a == b, "a carve at the shifted place takes the same cells (%d)" % a.size()
	)
	var pa := plain.settle()
	var pb := moved.settle()
	var same := pa.size() == 1 and pb.size() == 1
	if same:
		var ca: Array[Vector3i] = pa[0]["cells"]
		var cb: Array[Vector3i] = pb[0]["cells"]
		var va: Vector3 = pa[0]["pivot"]
		var vb: Vector3 = pb[0]["pivot"]
		same = cb[0] == ca[0] + shift and vb.is_equal_approx(va + Vector3(shift) / 4.0)
		same = same and str(pa[0]["kind"]) == "topple"
	check(same, "the topple's cells and pivot are building-local: %s %s" % [_kinds(pa), _kinds(pb)])


## A tunnel straight through floor 9 (the spike's first 3 s) leaves the tower standing: the
## side walls hold it, nothing drops or topples.
func _check_tunnel() -> void:
	var f := Paths.office(Paths.UNITS, 4)
	var origin := Vector3(-3, 0, -3)
	var start := f.alive_count
	var carved := 0
	var events := 0
	for tick: int in roundi(3.0 / Paths.TICK):
		carved += f.carve_sphere(Paths.path(Vector3.ZERO, tick * Paths.TICK) - origin, 2.4).size()
		events += f.settle().size()
	check(carved > 500, "the tunnel carves through the floor (%d cells)" % carved)
	check(events == 0, "the tower stands over its tunnel (%d events)" % events)
	check(f.alive_count == start - carved, "only the tunnel's cells are gone")
	var roof := f.top_below(1, 1, f.h)
	check(roof == f.h - 1 - (f.h - 1) % f.res, "the roof is still up (top %d)" % roof)


## Cutting clean through the base at once gives exactly one island: everything above the cut,
## dropping straight down.
func _check_base_cut() -> void:
	var f := Paths.office(Paths.UNITS, _res())
	var above := 0
	for y: int in range(3 * f.res, f.h):
		for z: int in f.d:
			for x: int in f.w:
				above += 1 if f.alive(Vector3i(x, y, z)) else 0
	for z: float in [0.5, 1.5, 2.5, 3.5, 4.5, 5.5]:
		f.carve_capsule(Vector3(-1, 2.0, z), Vector3(7, 2.0, z), 0.9)
	var parts := f.settle()
	var sizes: Array[int] = []
	for part: Dictionary in parts:
		var cells: Array[Vector3i] = part["cells"]
		sizes.append(cells.size())
	check(parts.size() == 1, "a clean base cut gives exactly one island: %s" % [sizes])
	if parts.size() == 1:
		check(str(parts[0]["kind"]) == "drop", "the island drops straight: %s" % parts[0]["kind"])
		check(sizes[0] >= above, "the island is the whole top (%d >= %d)" % [sizes[0], above])
		check(f.top_below(1, 1, f.h) < 3 * f.res, "nothing above the cut is left standing")


## Structure's topple rule at cell level on the grounded part: a slab hung out past the post
## holding it topples over the post's edge (RFG's fix for "held up by a chimney"); the same
## slab centred on the post stands.
func _check_overhang() -> void:
	var out: Array[Array] = []
	for shift: int in [0, -2]:
		var f := _frame(Vector3i(6, 4, 1), 4)
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
		var f := _frame(Vector3i(5, 5, 1), 4)
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


func _kinds(parts: Array) -> Array[String]:
	var out: Array[String] = []
	for part: Dictionary in parts:
		out.append(str(part["kind"]))
	return out


## The spike's island sizes, from the same rule (detach, no support rule) on the same path.
func _check_island_pin() -> void:
	var pins := {4: ISLAND_RES4, 8: ISLAND_RES8}
	for res: int in pins:
		var want: int = pins[res]
		var islands: PackedInt32Array = _replay(res, false, false, _full_ticks())[0]["islands"]
		check(
			islands == PackedInt32Array([want]),
			"the tower path at RES %d gives the spike's one island of %d: %s" % [res, want, islands]
		)


## Replaying the tower path twice gives identical digests every tick, at RES 4 and 8, with
## the spike's rule and with the support rule.
func _check_replay_tower() -> void:
	for res: int in [4, 8]:
		for support: bool in [false, true]:
			var runs := _replay(res, false, support, _full_ticks())
			var trace: PackedInt64Array = runs[0]["trace"]
			var again: PackedInt64Array = runs[1]["trace"]
			check(
				trace.size() > 600 and trace == again,
				(
					"tower RES %d support %s replays identically (%d entries)"
					% [res, support, trace.size()]
				)
			)
	var spike: PackedInt32Array = _replay(8, false, true, _full_ticks())[0]["islands"]
	print("  tower RES 8 with support rule, events: %s" % [spike])


## The block of six replays identically: the full 10 s at RES 4, the first base cuts at RES 8.
func _check_replay_block() -> void:
	var specs := {4: _full_ticks(), 8: BLOCK_RES8_TICKS}
	for res: int in specs:
		var ticks: int = specs[res]
		var runs := _replay(res, true, true, ticks)
		var trace: PackedInt64Array = runs[0]["trace"]
		var again: PackedInt64Array = runs[1]["trace"]
		var islands: PackedInt32Array = runs[0]["islands"]
		check(
			trace.size() > 600 and trace == again and islands.size() > 0,
			(
				"block RES %d replays identically (%d entries, events %s)"
				% [res, trace.size(), islands]
			)
		)
