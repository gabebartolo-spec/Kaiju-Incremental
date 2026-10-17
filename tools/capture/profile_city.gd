extends SceneTree
## Where a rampage's load time goes, per growth stage (D-039): the sim (layout + RampageSim),
## the party-wall pass, the building meshes (worker threads), and each part of the city view
## entering the tree (ground, skyline, buildings, decor, street life). Runs headless (the dummy
## renderer still builds every mesh, so the CPU side is real; GPU upload is not included).
##   godot --headless --path . --script tools/capture/profile_city.gd [-- --stage=N]

var _only := 0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):
			_only = arg.substr(8).to_int()
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for tier: int in range(1, CityGrowth.stage_count(Content.tuning()) + 1):
		if _only == 0 or _only == tier:
			await _profile(tier)
	quit()


func _profile(tier: int) -> void:
	var t := Time.get_ticks_usec()
	var tuning := CityGrowth.tuning_for(Content.tuning(), tier)
	var layout := CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", 0))
	var t_layout := _lap(t)
	t = Time.get_ticks_usec()
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), Content.species_def("reptilian"), UpgradeTree.new(Content.upgrades())
	)
	var sim := RampageSim.new(stats, tuning, layout, Seeds.make("army", 0))
	var t_sim := _lap(t)
	t = Time.get_ticks_usec()
	var party := BuildingView.party_walls(sim.buildings)
	var t_party := _lap(t)
	t = Time.get_ticks_usec()
	var colors: Array[Color] = []
	for b: RampageSim.Building in sim.buildings:
		colors.append(Color.GRAY)
	var views := BuildingView.build_all(sim.buildings, colors)
	var t_views := _lap(t)  # includes a second party-wall pass inside build_all
	t = Time.get_ticks_usec()
	var holder := Node3D.new()
	root.add_child(holder)
	for view: BuildingView in views:
		holder.add_child(view)
	var t_add := _lap(t)
	t = Time.get_ticks_usec()
	var streets := CityGround.new(sim.city)
	holder.add_child(streets)
	var t_ground := _lap(t)
	t = Time.get_ticks_usec()
	holder.add_child(CitySkyline.new(streets, Seeds.make("skyline", 0)))
	var t_skyline := _lap(t)
	t = Time.get_ticks_usec()
	holder.add_child(CityDecor.new(sim, Seeds.make("decor", 0)))
	var t_decor := _lap(t)
	t = Time.get_ticks_usec()
	var fx := Fx.new()
	holder.add_child(fx)
	holder.add_child(StreetLife.new(sim, fx, Seeds.make("civilians", 0)))
	var t_street := _lap(t)
	print(
		(
			(
				"stage %d (%d buildings, %d party pairs): layout %d ms, sim %d, party_walls %d,"
				+ " meshes %d, add %d, ground %d, skyline %d, decor %d, street %d ms"
			)
			% [
				tier,
				sim.buildings.size(),
				BuildingView.pair_checks,
				t_layout,
				t_sim,
				t_party,
				t_views,
				t_add,
				t_ground,
				t_skyline,
				t_decor,
				t_street
			]
		)
	)
	party.clear()
	holder.queue_free()
	await process_frame


func _lap(since: int) -> int:
	return (Time.get_ticks_usec() - since) / 1000
