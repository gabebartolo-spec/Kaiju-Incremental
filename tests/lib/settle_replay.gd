extends RefCounted
## The settle cache against the full flood (b2-3): seeded carves on real building grids, one copy
## settled with VoxelFrame.settle() (the cache's fast path when it can prove the cells lost leave
## the rest as it was) and one with settle_full() (the flood alone). Every step's events, and the
## cells after it, must be identical, and the fast path must actually have run.

## Buildings replayed (the largest of three seeded cities, window-heavy kinds among them) and
## carves per building.
const BUILDINGS := 5
const CARVES := 22

var _check: Callable


func _init(p_check: Callable) -> void:
	_check = p_check


func run() -> void:
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	var steps := 0
	var fast := 0
	var events := 0
	var same := true
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for k: int in 3:
		var layout := CityGrowth.layout(Content.tuning(), k + 1, Seeds.make("city", k))
		var sim := RampageSim.new(
			stats, CityGrowth.tuning_for(Content.tuning(), k + 1), layout, Seeds.make("army", 0)
		)
		var party := BuildingView.party_walls(sim.buildings)
		var picks: Array[int] = []
		for n: int in sim.buildings.size():
			if sim.buildings[n].landmark == "" and sim.buildings[n].style % 4 == k + 1:
				picks.append(n)
		picks = picks.slice(0, BUILDINGS - 3 * k if k < 2 else 1)
		for n: int in picks:
			var result := _replay(sim.buildings[n], party[n], rng)
			steps += result[0]
			fast += result[1]
			events += result[2]
			same = same and result[3] == 0
	_check.call(same, "the cached settle gives the flood's events and cells at every step")
	_check.call(
		fast * 2 >= steps and events > 0,
		"the fast path ran: %d of %d settles, %d fall events replayed" % [fast, steps, events]
	)


## Replays CARVES carves on building `b`: [settles, fast settles, events, mismatches].
func _replay(b: RampageSim.Building, party: Dictionary, rng: RandomNumberGenerator) -> Array:
	var grid := BuildingCells.new(b, party)
	var a := VoxelFrame.new(Vector3i(b.w, b.height, b.d), grid.res, Content.materials())
	var o := VoxelFrame.new(Vector3i(b.w, b.height, b.d), grid.res, Content.materials())
	a.adopt(grid.dims, grid.offset, grid.cells)
	o.adopt(grid.dims, grid.offset, grid.cells)
	a.settle()
	o.settle_full()
	var events := 0
	var bad := 0
	for _c: int in CARVES:
		var at := Vector3(
			rng.randf() * b.w, rng.randf() * b.height, rng.randf() * b.d
		)
		var radius := rng.randf_range(0.25, 1.1)
		if rng.randf() < 0.5:
			a.carve_sphere(at, radius)
			o.carve_sphere(at, radius)
		else:
			var to := at + Vector3(rng.randf_range(-2, 2), rng.randf_range(-1, 1), rng.randf_range(-2, 2))
			a.carve_capsule(at, to, radius)
			o.carve_capsule(at, to, radius)
		var got := a.settle()
		var want := o.settle_full()
		events += want.size()
		if var_to_str(got) != var_to_str(want) or a.cells != o.cells:
			bad += 1
	var cache: VoxelSettleCache = a.get("_cache")
	print("settle replay %dx%dx%d: %s" % [b.w, b.height, b.d, str(cache.why)])
	return [CARVES, cache.fast, events, bad]
