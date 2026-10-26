extends SceneTree
## The play-area numbers per growth stage (D-254, the 1.5x play area): half-width, buildings per
## 1000 m2 of play area, the share of play-area street cells with nothing to smash
## (tests/lib/city_coverage.gd), the stadium's distance from the rise as a share of the
## half-width, and each landmark site. Headless:
##   godot --headless --path . --script tools/capture/play_area_stats.gd [-- --seed=7301]

const Coverage := preload("res://tests/lib/city_coverage.gd")
const Green := preload("res://tests/lib/city_green.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var map_seed := 7301
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			map_seed = int(arg.get_slice("=", 1))
	for tier: int in range(1, CityGrowth.stage_count(Content.tuning()) + 1):
		_stage(tier, map_seed)
	quit()


func _stage(tier: int, map_seed: int) -> void:
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), Content.species_def("reptilian"), UpgradeTree.new(Content.upgrades())
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
	# Street cells inside the play area, from the coverage map (' ' = no street or water).
	var size := Num.f(sim.city["coverage_cell"])
	var reach := sim.arena_half + Num.f(sim.city["view_beyond"])
	var n := ceili(reach * 2.0 / size)
	var origin := -n * size * 0.5
	var rows := str(got["map"]).split("\n")
	var arena_cells := 0
	for j: int in rows.size():
		for i: int in rows[j].length():
			var ch := rows[j][i]
			var c := Vector2(origin + (i + 0.5) * size, origin + (j + 0.5) * size)
			if ch != " " and maxf(absf(c.x), absf(c.y)) <= sim.arena_half:
				arena_cells += 1
	var inside := 0
	for b: RampageSim.Building in sim.buildings:
		inside += 1 if b.in_arena and absf(b.x) <= sim.arena_half and absf(b.z) <= sim.arena_half else 0
	var area := pow(sim.arena_half * 2.0, 2.0)
	var green: Dictionary = Green.measure(sim, decor)
	var plan := CityGen.map(sim.city)
	var spawn: Vector2 = plan.get("rise_spawn", Vector2.ZERO)
	var half := CityGen.half_extent(sim.city)
	# Density per built-block m2 (director 2026-10-26, "same feel per street"): the blocks left
	# for buildings, clipped to the play area; parks, plazas, river, roads and rail excluded.
	var play := Rect2(-sim.arena_half, -sim.arena_half, sim.arena_half * 2.0, sim.arena_half * 2.0)
	var built_m2 := 0.0
	for block: Dictionary in plan["blocks"]:
		var rect: Rect2 = block["rect"]
		if str(block["use"]) == "built" and play.intersects(rect):
			built_m2 += play.intersection(rect).get_area()
	var sites := []
	for site: Dictionary in plan.get("sites", []):
		var rect: Rect2 = site["rect"]
		var at := rect.get_center()
		sites.append(
			"%s (%.0f, %.0f) %.0f m from rise = %.2f x half" % [
				site["id"], at.x, at.y, at.distance_to(spawn), at.distance_to(spawn) / half
			]
		)
	print(
		(
			"stage %d map_seed %d half %.0f: %d buildings in play, %.2f per 1000 m2; empty %d of %d"
			+ " play cells (%.3f); %.2f per 1000 built-block m2 (%.0f m2); green %.1f%% (%d parks);"
			+ " rise %s; sites %s"
		)
		% [
			tier,
			map_seed,
			half,
			inside,
			inside / area * 1000.0,
			got["arena_empty"],
			arena_cells,
			Num.f(got["arena_empty"]) / maxf(1.0, arena_cells),
			inside / maxf(1.0, built_m2) * 1000.0,
			built_m2,
			green["green_pct"],
			green["parks"],
			spawn,
			sites,
		]
	)
	holder.free()
