extends RefCounted
## The cells suite's support checks, split out to keep the runner small (D-094 WP3 review FIX):
## a promoted grid holds nothing in a chunk the view already took away, and a fresh grid is one
## part joined to the ground before any carve (no pane, sign or roof tank falls off on a
## building's first hit).

const SettleReplay := preload("res://tests/lib/settle_replay.gd")

## City buildings checked for islands: this many from each of three seeded cities (tiers 1-3).
const ISLAND_SAMPLE := 40

var _check: Callable
var _fixtures: Array
var _make: Callable


## check: the runner's check; fixtures: the runner's FIXTURES ([name, x, z, w, d, floors, tier,
## style, party]); make(fixture) -> RampageSim.Building.
func _init(p_check: Callable, fixtures: Array, make: Callable) -> void:
	_check = p_check
	_fixtures = fixtures
	_make = make


func run() -> void:
	_promotion_clears_edge_chunks()
	_pane_under_wall_is_cut_off()
	_no_islands_before_carving()
	_glass_towers_stand()
	SettleReplay.new(_check).run()
	_party_sides_carry_facade()


## The structural chunk the view gives building-local cell `c` (BuildingMesher.chunk_index):
## proud cells clamp into the edge chunks, roof gear into the top floor.
static func clamped_chunk(c: Vector3i, b: RampageSim.Building, r: int) -> Vector3i:
	return Vector3i(
		clampi(floori(float(c.x) / r), 0, b.w - 1),
		clampi(floori(float(c.y) / r), 0, b.height - 1),
		clampi(floori(float(c.z) / r), 0, b.d - 1)
	)


## A building that lost its whole top floor and a ground corner chunk before its first hit: no
## cell survives promotion in a chunk the view already took away (the parapet, roof gear, a
## sign or an awning would come back), and every cell of a standing chunk is kept.
func _promotion_clears_edge_chunks() -> void:
	for f: Array in _fixtures.slice(0, 4):
		var b := _building(f)
		var whole := BuildingCells.new(_building(f), {})
		for z: int in b.d:
			for x: int in b.w:
				b.frame.remove(Vector3i(x, b.height - 1, z))
		b.frame.remove(Vector3i.ZERO)
		var g := CellPromoter.new().on_hit(0, b)
		var plan := g.dims.x * g.dims.z
		var back := 0
		var kept := 0
		var should := 0
		for i: int in g.cells.size():
			var c := Vector3i(i % g.dims.x, i / plan, (i / g.dims.x) % g.dims.z) + g.offset
			var alive := b.frame.alive(clamped_chunk(c, b, g.res))
			should += 1 if alive and whole.cells[i] != 0 else 0
			back += 1 if g.cells[i] != 0 and not alive else 0
			kept += 1 if g.cells[i] != 0 and alive else 0
		_check.call(
			back == 0 and kept == should and kept > 0,
			(
				"%s: no cell left in a lost top-floor or edge chunk (%d left, %d of %d kept)"
				% [f[0], back, kept, should]
			)
		)


## Cells of a grid VoxelSupport (WP1's rule) finds in islands: no ground-joined structure.
func _cut(dims: Vector3i, offset: Vector3i, cells: PackedByteArray) -> int:
	var frame := VoxelFrame.new(Vector3i.ONE, BuildingCells.cell_res(), Content.materials())
	if not frame.adopt(dims, offset, cells):
		return -1
	var n := 0
	for part: PackedInt32Array in VoxelSupport.new(frame).islands():
		n += part.size()
	return n


## VoxelSupport's rule: a shop pane on the ground with two wall cells on it leaves those two
## cells cut off (a fixture never carries a structural cell), the pane alone rests on the street,
## and a wall column on the street carries the cells above it.
func _pane_under_wall_is_cut_off() -> void:
	var ids := BuildingCells.material_ids()
	var shop: int = ids["shop"]
	var wall: int = ids["wall"]
	var dims := Vector3i(1, 3, 1)
	var on_pane := _cut(dims, Vector3i.ZERO, PackedByteArray([shop, wall, wall]))
	_check.call(on_pane == 2, "wall on a pane is cut off (%d cells)" % on_pane)
	var pane := _cut(dims, Vector3i.ZERO, PackedByteArray([shop, 0, 0]))
	_check.call(pane == 0, "a pane on layer 0 is grounded")
	var column := _cut(dims, Vector3i.ZERO, PackedByteArray([wall, wall, shop]))
	_check.call(column == 0, "wall carries the pane above it")


## Every glass-style building of three seeded cities, party walls in, stands under WP1's rule:
## the curtain wall is all fixtures, so the columns inside it have to carry the slabs and roof.
func _glass_towers_stand() -> void:
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	var glass := 0
	var bad := 0
	for k: int in 3:
		var tuning := CityGrowth.tuning_for(Content.tuning(), k + 1)
		var layout := CityGrowth.layout(Content.tuning(), k + 1, Seeds.make("city", k))
		var sim := RampageSim.new(stats, tuning, layout, Seeds.make("army", 0))
		var party := BuildingView.party_walls(sim.buildings)
		for n: int in sim.buildings.size():
			var b := sim.buildings[n]
			if b.landmark != "" or b.style % 4 != BuildingCells.GLASS:
				continue
			glass += 1
			var g := BuildingCells.new(b, party[n])
			bad += 0 if _cut(g.dims, g.offset, g.cells) == 0 else 1
	_check.call(
		glass > 0 and bad == 0, "%d of %d glass-style buildings have an island" % [bad, glass]
	)


## Before any carve, every fixture and every building of three seeded cities (tiers 1-3, real
## party walls) is one part joined to the ground under VoxelSupport's rule.
func _no_islands_before_carving() -> void:
	for f: Array in _fixtures:
		var party: Dictionary = f[8]
		var g := BuildingCells.new(_building(f), party)
		var cells := _cut(g.dims, g.offset, g.cells)
		_check.call(
			cells == 0, "%s has no island before any carve (%d cells cut off)" % [f[0], cells]
		)
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	var checked := 0
	var bad := 0
	var cut := 0
	for k: int in 3:
		var tuning := CityGrowth.tuning_for(Content.tuning(), k + 1)
		var layout := CityGrowth.layout(Content.tuning(), k + 1, Seeds.make("city", k))
		var sim := RampageSim.new(stats, tuning, layout, Seeds.make("army", 0))
		var party := BuildingView.party_walls(sim.buildings)
		var taken := 0
		for n: int in sim.buildings.size():
			var b := sim.buildings[n]
			if b.landmark != "" or taken >= ISLAND_SAMPLE:
				continue
			taken += 1
			checked += 1
			var g := BuildingCells.new(b, party[n])
			var off := _cut(g.dims, g.offset, g.cells)
			cut += off
			bad += 1 if off > 0 else 0
	_check.call(
		checked == ISLAND_SAMPLE * 3 and bad == 0,
		"%d of %d city buildings have an island before any carve (%d cells)" % [bad, checked, cut]
	)


func _building(f: Array) -> RampageSim.Building:
	var b: RampageSim.Building = _make.call(f)
	return b


## A side touching a neighbour carries the same facade as a free side (build 2 note 22: no blank
## party walls): the "party" fixture built with its neighbours and without them differs only in
## its sign cells (signs hang only off faces with no neighbour), and no cell is "party".
func _party_sides_carry_facade() -> void:
	var ids := CellGrid.material_ids()
	var signs := {}
	for name: String in ["sign_frame", "neon0", "neon1", "neon2", "neon3"]:
		signs[Num.i(ids[name])] = true
	for f: Array in _fixtures:
		var party: Dictionary = f[8]
		if party.is_empty():
			continue
		var touching := BuildingCells.new(_building(f), party)
		var free := BuildingCells.new(_building(f), {})
		var other := 0
		var blank := 0
		for i: int in touching.cells.size():
			var a := touching.cells[i]
			var b := free.cells[i]
			if a == Num.i(ids["party"]):
				blank += 1
			if a != b and not signs.has(a) and not signs.has(b):
				other += 1
		_check.call(
			touching.dims == free.dims and other == 0 and blank == 0,
			(
				"%s: touching sides carry the facade (%d differ beyond signs, %d blank)"
				% [f[0], other, blank]
			)
		)
