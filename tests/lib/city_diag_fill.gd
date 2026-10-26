extends RefCounted
## The diagonal's parked row fills by rule, not by chance (DiagonalParking.fill): in three Behemoth
## cities whose seeded draws leave a cell along the diagonal with nothing to smash (a block cut to
## a sliver inside the avenue), the fill parks a car there and the no-empty-ground measure finds
## no bare cell; with the fill off the same cities have one (so each seed still shows the need).

const Coverage := preload("res://tests/lib/city_coverage.gd")
const SEEDS: Array[int] = [43, 99, 79]
const TIER := 2
const Rings := preload("res://tests/lib/fixture_rings.gd")

var _check: Callable
var _root: Node


func _init(check_fn: Callable, root: Node) -> void:
	_check = check_fn
	_root = root


func run() -> void:
	# The riverside crates would fill some of these cells too; with them off the bank row is bare
	# (no alleys on the banks), so Coverage.off_bank leaves that row out of the count.
	RiverQuay.enabled = false
	for map_seed: int in SEEDS:
		var without := _empty(map_seed, false)
		var with_fill := _empty(map_seed, true)
		_check.call(
			without.size() > 0 and with_fill.is_empty(),
			(
				(
					"stage %d, map_seed %d: the diagonal's fill leaves no bare cell (%d without it"
					+ " at %s; %d with it at %s)"
				)
				% [TIER, map_seed, without.size(), without, with_fill.size(), with_fill]
			)
		)
	DiagonalParking.fill = true
	RiverQuay.enabled = true


## The bare cells (arena and band) of the city at map_seed, with the fill on or off.
func _empty(map_seed: int, fill: bool) -> Array:
	DiagonalParking.fill = fill
	var base: Dictionary = Content.tuning().duplicate(true)
	base["city"]["map_seed"] = map_seed
	Rings.apply(base)
	var sim := RampageSim.new(
		UpgradeTree.run_stats(
			Content.section("kaiju"),
			Content.species_def("reptilian"),
			UpgradeTree.new(Content.upgrades())
		),
		CityGrowth.tuning_for(base, TIER),
		CityGrowth.layout(base, TIER, Seeds.make("city", 0)),
		Seeds.make("army", 0)
	)
	var holder := Node3D.new()
	_root.add_child(holder)
	var decor := CityDecor.new(sim, Seeds.make("decor", 0))
	holder.add_child(decor)
	var fx := Fx.new()
	holder.add_child(fx)
	var street := StreetLife.new(sim, fx, Seeds.make("civilians", 0))
	holder.add_child(street)
	var ground := CityGround.new(sim.city)
	holder.add_child(ground)
	var skyline := CitySkyline.new(ground, Seeds.make("skyline", 0))
	holder.add_child(skyline)
	var got: Dictionary = Coverage.measure(sim, decor, street, skyline)
	holder.free()
	return Coverage.off_bank(got["empty"], sim)
