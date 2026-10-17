extends SceneTree
## Prints the D-062 coverage map (tests/lib/city_coverage.gd) for stage 1 and the Behemoth,
## three map_seed cities. Headless:
##   godot --headless --path . --script tools/coverage_probe.gd

const Coverage := preload("res://tests/lib/city_coverage.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for tier: int in [1, 2]:
		for map_seed: int in [7301, 1234, 98765]:
			var species := Content.species_def("reptilian")
			var stats := UpgradeTree.run_stats(
				Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
			)
			var base := Content.tuning().duplicate(true)
			base["city"]["map_seed"] = map_seed
			var tuning := CityGrowth.tuning_for(base, tier)
			var layout := CityGrowth.layout(base, tier, Seeds.make("city", 0))
			var sim := RampageSim.new(stats, tuning, layout, Seeds.make("army", 0))
			var holder := Node3D.new()
			root.add_child(holder)
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
			var empty: Array = got["empty"]
			print(
				"stage %d map_seed %d: %d cells, %d empty (arena %d, band %d)"
				% [tier, map_seed, got["cells"], empty.size(), got["arena_empty"], got["band_empty"]]
			)
			print("empty at ", empty)
			holder.free()
	quit()
