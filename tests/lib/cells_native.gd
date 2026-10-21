extends RefCounted
## The native BuildingCells generator (KaijuSettle.cells, native/src/kaiju_cells.cpp) against the
## GDScript (b2-3 part 4): every fixture and every building of three seeded cities, with their
## real party walls, built both ways (VoxelSupport.use_native off is the GDScript alone) must give
## the same offset, dims and bytes. Seeded by design: CityGrowth's layouts from Seeds "city" 0-2.
## (All 2382 buildings of the three cities matched when the port landed; the suite keeps a sample.)

const CITIES := 3
## Buildings compared per archetype x tier kind per city (the GDScript costs up to 270 ms each).
const PER_KIND := 4

var _check: Callable
var _fixtures: Array
var _make: Callable
var _party: Callable


## check: the runner's check; fixtures and make(fixture) as CellsSupport's; party(fixture) the
## fixture's party walls.
func _init(p_check: Callable, fixtures: Array, make: Callable, party: Callable) -> void:
	_check = p_check
	_fixtures = fixtures
	_make = make
	_party = party


func run() -> void:
	var loaded := ClassDB.class_exists("KaijuSettle")
	var nat := VoxelSupport.native()
	var has := nat != null and nat.has_method("cells")
	_check.call(
		has or not loaded,
		"a loaded extension has the native cells generator (stale dll: rebuild native/)"
	)
	var first: RampageSim.Building = _make.call(_fixtures[0])
	var a := BuildingCells.new(first, {})
	var planted := a.cells.duplicate()
	planted[planted.size() / 2] = 255 - planted[planted.size() / 2]
	_check.call(
		_diff(a, a.offset, a.dims, planted) == 1 and _diff(a, a.offset, a.dims, a.cells) == 0,
		"the byte comparison catches one planted cell"
	)
	if not has:
		return
	var compared := 0
	var bad := 0
	var kinds := {}
	for f: Array in _fixtures:
		var fb: RampageSim.Building = _make.call(f)
		var fp: Dictionary = _party.call(f)
		bad += _both(fb, fp)
		compared += 1
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	for k: int in CITIES:
		var layout := CityGrowth.layout(Content.tuning(), k + 1, Seeds.make("city", k))
		var sim := RampageSim.new(
			stats, CityGrowth.tuning_for(Content.tuning(), k + 1), layout, Seeds.make("army", 0)
		)
		var party := BuildingView.party_walls(sim.buildings)
		for n: int in sim.buildings.size():
			var b := sim.buildings[n]
			if b.landmark != "":
				continue
			var kind := [b.style % 4, b.tier]
			if kinds.get(kind, 0) >= PER_KIND * (k + 1):
				continue
			kinds[kind] = kinds.get(kind, 0) + 1
			bad += _both(b, party[n])
			compared += 1
	_check.call(
		bad == 0 and compared > 60 and kinds.size() >= 8,
		(
			"native cells = GDScript cells for %d buildings (%d archetype x tier kinds, %d off)"
			% [compared, kinds.size(), bad]
		)
	)


## 1 when building b's native grid differs from its GDScript one, else 0.
func _both(b: RampageSim.Building, party: Dictionary) -> int:
	var fast := BuildingCells.new(b, party)
	VoxelSupport.use_native = false
	var ref := BuildingCells.new(b, party)
	VoxelSupport.use_native = true
	return 1 if _diff(ref, fast.offset, fast.dims, fast.cells) != 0 else 0


## Cells of `ref` that differ from (offset, dims, cells); the whole grid when the boxes differ.
func _diff(ref: BuildingCells, offset: Vector3i, dims: Vector3i, cells: PackedByteArray) -> int:
	if ref.offset != offset or ref.dims != dims or ref.cells.size() != cells.size():
		return maxi(1, ref.cells.size())
	if cells == ref.cells:
		return 0
	var off := 0
	for i: int in cells.size():
		off += 1 if cells[i] != ref.cells[i] else 0
	return off
