extends "res://tests/lib/runner.gd"
## Cells suite: the sim's fine destruction grid of a building (BuildingCells, D-094 WP3) is the
## grid the view draws (BuildingVoxels) cell for cell, the same every time, from data (materials
## and RES), with no clock or RNG; and a building gets its grid only on its first hit
## (CellPromoter). Nothing here is wired into the rampage yet (WP7).
## Seeded by design: the layout rolls hash the cell with the building's position; the city
## sample is CityGrowth's layout from Seeds "city" 0.
##   godot --headless --path . --script tests/run_cells_tests.gd

const CellsSupport := preload("res://tests/lib/cells_support.gd")

## Each fixture: [name, x, z, w, d, floors, tier, style, party].
const FIXTURES: Array = [
	["office", 10.5, 4.5, 3, 3, 6, 2, 0, {}],
	["brick", 20.5, 4.5, 3, 2, 5, 1, 1, {}],
	["glass", 30.0, 6.0, 4, 4, 12, 3, 2, {}],
	["stone", 40.5, 4.5, 3, 3, 8, 2, 3, {}],
	["party", 20.5, 14.0, 3, 2, 5, 1, 1, {Vector2i(1, 0): 3, Vector2i(0, -1): 5}],
	["tiny", 50.5, 0.5, 1, 1, 2, 1, 0, {}],
	["sign", 4.5, 2.5, 3, 3, 6, 1, 3, {}],
]
## Per fixture: [cells, digest] (first 16 hex digits of the grid's SHA-256 with its dims).
const PINNED := {
	"office": [9227, "494795997a4e992a"],
	"brick": [6674, "ac8dcb1ff799745a"],
	"glass": [27213, "2ea7122061040817"],
	"stone": [13385, "04da84b429e548bc"],
	"party": [6277, "6217a45fdf6352a2"],
	"tiny": [776, "8c0f4755ac5a6536"],
	"sign": [10911, "1c39938e3ebe6249"],
}
## City buildings compared with the view cell for cell.
const CITY_SAMPLE := 40
## Materials that hang on by an edge or a corner (data/materials.json "fixture").
const FIXTURES_EXPECTED: Array[String] = [
	"window", "mullion", "glass", "shop", "sign_frame", "neon0", "neon1", "neon2", "neon3"
]
## Text that must not appear in the module (comments stripped): RNG, clock, engine, view.
const FORBIDDEN: Array[String] = [
	"randi(",
	"randf(",
	"randomize(",
	"RandomNumberGenerator",
	"Seeds.",
	"Time.",
	"OS.",
	"Engine.",
	"Look.",
	"Node",
	"await ",
]
const MODULES: Array[String] = [
	"res://sim/building_cells.gd",
	"res://sim/cell_promoter.gd",
	"res://sim/glass_frame.gd",
]


func suite_name() -> String:
	return "Cells"


func run_checks() -> void:
	await _t("_check_materials_table")
	await _t("_check_res_matches_view")
	await _t("_check_grid_layout")
	await _t("_check_deterministic")
	await _t("_check_pinned")
	await _t("_check_fixtures_match_view")
	await _t("_check_city_matches_view")
	await _t("_check_no_clock_or_rng")
	await _t("_check_promotion_lazy")
	await _h("CellsSupport", func() -> void: CellsSupport.new(check, FIXTURES, _building).run())
	await _t("_check_lit_is_a_look")


## The view with no window lit: every voxel carries its material's palette key.
class UnlitVoxels:
	extends BuildingVoxels

	func _lit_or(key: String, _side: Vector2i, _p: int, _y: int) -> String:
		return key

	func _lit_cell(_p: int, _y: int) -> bool:
		return false


func _building(f: Array) -> RampageSim.Building:
	var b := RampageSim.Building.new()
	b.x = f[1]
	b.z = f[2]
	b.w = f[3]
	b.d = f[4]
	b.height = f[5]
	b.tier = f[6]
	b.style = f[7]
	b.frame = Structure.new(b.w, b.d, b.height, 1.0)
	return b


func _party(f: Array) -> Dictionary:
	var party: Dictionary = f[8]
	return party


func _digest(g: BuildingCells) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(var_to_bytes([g.dims, g.offset]))
	ctx.update(g.cells)
	return ctx.finish().hex_encode().substr(0, 16)


## Mismatched cells between the unlit view's voxels and the sim grid (0 = the same grid): each
## view voxel's palette key is exactly its sim cell's material name.
func _mismatches(b: RampageSim.Building, party: Dictionary) -> int:
	var g := BuildingCells.new(b, party)
	var vox := UnlitVoxels.new(b, Color.GRAY, party)
	var ids := BuildingCells.material_ids()
	var bad := absi(g.count() - vox.vox.cells.size())
	for cell: Vector3i in vox.vox.cells:
		if g.at(cell) != Num.i(ids.get(str(vox.vox.cells[cell]), -1)):
			bad += 1
	return bad


## [cells where the lit view is not the unlit one, of them not a lit pane over a window,
## mullion, glass or shop cell]; the two views must hold the same cells.
func _lit_changes(b: RampageSim.Building, party: Dictionary) -> Array[int]:
	var lit := BuildingVoxels.new(b, Color.GRAY, party).vox.cells
	var unlit := UnlitVoxels.new(b, Color.GRAY, party).vox.cells
	var changed := 0
	var bad := absi(lit.size() - unlit.size())
	for cell: Vector3i in unlit:
		var was := str(unlit[cell])
		var now := str(lit.get(cell, ""))
		if now == was:
			continue
		changed += 1
		var pane := now == "lit" and was in ["window", "mullion", "glass"]
		if not pane and not (now == "shop_lit" and was == "shop"):
			bad += 1
	return [changed, bad]


## The structural chunk (one sim unit, one floor) a building-local cell is in.
func _chunk(cell: Vector3i, r: int) -> Vector3i:
	return Vector3i(floori(float(cell.x) / r), floori(float(cell.y) / r), floori(float(cell.z) / r))


## Chunks (one sim unit, one floor) holding any cell in one grid and none in the other.
func _chunk_mismatches(b: RampageSim.Building, party: Dictionary) -> int:
	var g := BuildingCells.new(b, party)
	var vox := BuildingVoxels.new(b, Color.GRAY, party)
	var r := g.res
	var view := {}
	for cell: Vector3i in vox.vox.cells:
		view[_chunk(cell, r)] = 1
	var sim := {}
	for i: int in g.cells.size():
		if g.cells[i] != 0:
			var plan := g.dims.x * g.dims.z
			var c := Vector3i(i % g.dims.x, i / plan, (i / g.dims.x) % g.dims.z) + g.offset
			sim[_chunk(c, r)] = 1
	var bad := 0
	for c: Vector3i in view:
		bad += 0 if sim.has(c) else 1
	for c: Vector3i in sim:
		bad += 0 if view.has(c) else 1
	return bad


## data/materials.json: unique ids 1..255 (0 is empty), unique names, a strength above zero, a
## debris colour the view's palette has; every material the generator uses is listed.
func _check_materials_table() -> void:
	var palette := BuildingVoxels.new(_building(FIXTURES[0]), Color.GRAY).palette
	var ids := {}
	var names := {}
	var ok := not Content.materials().is_empty()
	for m: Dictionary in Content.materials():
		var id: Variant = m.get("id")
		var mname: Variant = m.get("name")
		var strength: Variant = m.get("strength")
		var debris: Variant = m.get("debris")
		var fixture: Variant = m.get("fixture")
		ok = ok and (id is float or id is int) and Num.i(id) >= 1 and Num.i(id) <= 255
		ok = ok and mname is String and str(mname) != "" and palette.has(str(mname))
		ok = ok and (strength is float or strength is int) and Num.f(strength) > 0.0
		ok = ok and debris is String and palette.has(str(debris))
		ok = ok and fixture is bool and fixture == (str(mname) in FIXTURES_EXPECTED)
		ok = ok and not ids.has(Num.i(id)) and not names.has(str(mname))
		ids[Num.i(id)] = true
		names[str(mname)] = true
	check(
		ok,
		(
			"every material has a unique id 1..255, a unique palette name, strength > 0, a palette"
			+ " debris key, a fixture flag (true for %s only)" % [FIXTURES_EXPECTED]
		)
	)
	var used := {}
	for f: Array in FIXTURES:
		var g := BuildingCells.new(_building(f), _party(f))
		for i: int in g.cells.size():
			used[g.cells[i]] = true
	used.erase(0)
	var listed: bool = used.keys().all(func(k: int) -> bool: return ids.has(k))
	check(
		listed and used.size() >= 20,
		"the fixtures use only listed materials (%d used)" % used.size()
	)


## The sim's RES (data/tuning.json) is the view's: the grids are the same size.
func _check_res_matches_view() -> void:
	check(
		BuildingCells.cell_res() == BuildingVoxels.RES,
		(
			"destruction.res %d == BuildingVoxels.RES %d"
			% [BuildingCells.cell_res(), BuildingVoxels.RES]
		)
	)


## One byte per cell, x fastest then z then y, ground at grid y 0, the footprint inside it.
func _check_grid_layout() -> void:
	var g := BuildingCells.new(_building(FIXTURES[0]), {})
	var dx := g.dims.x
	var dz := g.dims.z
	check(g.cells.size() == dx * g.dims.y * dz, "one byte per cell")
	check(
		(
			g.index(Vector3i(1, 0, 0)) == 1
			and g.index(Vector3i(0, 0, 1)) == dx
			and g.index(Vector3i(0, 1, 0)) == dx * dz
		),
		"index order x, then z, then y"
	)
	var corner := g.at(Vector3i.ZERO)
	check(
		g.offset.y == 0 and corner != 0 and g.cells[g.index(-g.offset)] == corner,
		"local cell (0, 0, 0) is the ground corner pier, at grid -offset"
	)
	check(
		g.at(Vector3i(-50, 0, 0)) == 0 and g.at(Vector3i(0, -1, 0)) == 0,
		"outside the grid is empty"
	)


## Built twice, the same grid, byte for byte.
func _check_deterministic() -> void:
	var same := true
	for f: Array in FIXTURES:
		var a := BuildingCells.new(_building(f), _party(f))
		var b := BuildingCells.new(_building(f), _party(f))
		same = same and a.cells == b.cells and a.dims == b.dims and a.offset == b.offset
	check(same, "every fixture builds the same grid twice")


## Cell counts and digests pinned per fixture: a layout change shows up here.
func _check_pinned() -> void:
	var got := {}
	for f: Array in FIXTURES:
		var g := BuildingCells.new(_building(f), _party(f))
		got[f[0]] = [g.count(), _digest(g)]
	for f: Array in FIXTURES:
		var want: Array = PINNED.get(f[0], [])
		var have: Array = got[f[0]]
		check(want == have, "%s pinned at %s (got %s)" % [f[0], want, have])


## The fixtures (each archetype, party walls, a one-unit lot, a neon sign) are the view's
## voxels cell for cell and chunk for chunk.
func _check_fixtures_match_view() -> void:
	for f: Array in FIXTURES:
		var b := _building(f)
		var cells := _mismatches(b, _party(f))
		var chunks := _chunk_mismatches(b, _party(f))
		check(
			cells == 0 and chunks == 0,
			"%s matches the view (%d cells, %d chunks off)" % [f[0], cells, chunks]
		)
	var signs := 0
	for i: int in BuildingCells.NEON_COUNT:
		signs += BuildingCells.new(_building(FIXTURES[6]), {}).cells.count(
			Num.i(BuildingCells.material_ids()["neon%d" % i])
		)
	check(signs > 0, "the sign fixture carries a neon sign (%d cells)" % signs)


## A seeded city's buildings, with their real party walls, are the view's voxels cell for cell.
func _check_city_matches_view() -> void:
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	var tuning := CityGrowth.tuning_for(Content.tuning(), 1)
	var layout := CityGrowth.layout(Content.tuning(), 1, Seeds.make("city", 0))
	var sim := RampageSim.new(stats, tuning, layout, Seeds.make("army", 0))
	var party := BuildingView.party_walls(sim.buildings)
	var compared := 0
	var bad := 0
	var styles := {}
	for n: int in sim.buildings.size():
		var b := sim.buildings[n]
		if b.landmark != "" or compared >= CITY_SAMPLE:
			continue
		compared += 1
		styles[b.style % 4] = true
		bad += _mismatches(b, party[n])
	check(
		compared == CITY_SAMPLE and styles.size() == 4,
		"the sample has %d buildings of all four archetypes" % compared
	)
	check(bad == 0, "the city sample matches the view cell for cell (%d cells off)" % bad)


## Lines of `text` holding a forbidden call, comments stripped.
func _forbidden(text: String) -> Array[String]:
	var hits: Array[String] = []
	for line: String in text.split("\n"):
		var code := line.get_slice("#", 0)
		for token: String in FORBIDDEN:
			if code.contains(token):
				hits.append("%s: %s" % [token, line.strip_edges()])
	return hits


## No clock, RNG, engine or view in the generator: the grep proves itself on a bad line first.
func _check_no_clock_or_rng() -> void:
	var bad := _forbidden("var t := Time.get_ticks_msec()\nvar r := randi() # Look.\n")
	check(bad.size() == 2, "the grep catches a clock read and an RNG call (%d hits)" % bad.size())
	for path: String in MODULES:
		var hits := _forbidden(FileAccess.get_file_as_string(path))
		check(
			FileAccess.file_exists(path) and hits.is_empty(),
			"%s reads no clock or RNG: %s" % [path, hits]
		)


## A building has no fine grid until its first hit; the first hit makes it, with the chunks the
## Structure already lost emptied; later hits get the same grid; landmarks are left alone.
func _check_promotion_lazy() -> void:
	var p := CellPromoter.new()
	var b := _building(FIXTURES[0])
	check(not p.promoted(0) and p.grid(0) == null, "no grid before the first hit")
	var whole := BuildingCells.new(_building(FIXTURES[0]), {})
	var lost := Vector3i(0, 2, 0)
	var in_chunk := 0
	var plan := whole.dims.x * whole.dims.z
	for i: int in whole.cells.size():
		var c := Vector3i(i % whole.dims.x, i / plan, (i / whole.dims.x) % whole.dims.z)
		var mine := CellsSupport.clamped_chunk(c + whole.offset, b, whole.res) == lost
		in_chunk += 1 if mine and whole.cells[i] != 0 else 0
	b.frame.remove(lost)
	var g := p.on_hit(0, b)
	check(p.promoted(0) and g != null and p.grid(0) == g, "the first hit makes the grid")
	check(
		in_chunk > 0 and g.count() == whole.count() - in_chunk,
		"the lost chunk's %d cells are empty (%d of %d left)" % [in_chunk, g.count(), whole.count()]
	)
	check(p.on_hit(0, b) == g and p.grids.size() == 1, "a second hit keeps the same grid")
	var mark := _building(FIXTURES[1])
	mark.landmark = "stadium"
	check(p.on_hit(1, mark) == null and not p.promoted(1), "a landmark stays on its chunks")


## A lit window is a look: the lit view holds the same cells as the unlit one and differs only
## where a window, mullion, curtain panel or shop pane is lit.
func _check_lit_is_a_look() -> void:
	var changed := 0
	var bad := 0
	for f: Array in FIXTURES:
		var got := _lit_changes(_building(f), _party(f))
		changed += got[0]
		bad += got[1]
	check(
		changed > 0 and bad == 0,
		"the lit view only lights panes (%d lit cells, %d other changes)" % [changed, bad]
	)
