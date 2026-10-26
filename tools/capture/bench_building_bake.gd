extends SceneTree
## BuildingMesher's bake time on the adult city (render plan item 12: the baked AO tests 8 cells
## round every face): every `--every`th building of the stage-3 city (city seed 0, army seed 0,
## real party walls) is voxelized and baked on one thread, as BuildingView does on a worker.
## Prints voxel ms, bake ms, vertices and the mesh bytes of UV (AO, finish) and UV2.
## Seeded by design: the city seed is fixed.
##   godot --headless --path . --script tools/capture/bench_building_bake.gd -- [--every=10]

var _every := 10


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--every="):
			_every = maxi(1, arg.substr(8).to_int())
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	var tuning := CityGrowth.tuning_for(Content.tuning(), 3)
	var layout := CityGrowth.layout(Content.tuning(), 3, Seeds.make("city", 0))
	var sim := RampageSim.new(stats, tuning, layout, Seeds.make("army", 0))
	var party := BuildingView.party_walls(sim.buildings)
	var vox_us := 0
	var bake_us := 0
	var verts := 0
	var with_uv := 0
	var n := 0
	for i: int in range(0, sim.buildings.size(), _every):
		var b := sim.buildings[i]
		var t0 := Time.get_ticks_usec()
		var voxels := _voxels(b, party[i])
		var t1 := Time.get_ticks_usec()
		var mesher := BuildingMesher.new(voxels)
		bake_us += Time.get_ticks_usec() - t1
		vox_us += t1 - t0
		n += 1
		for mesh: ArrayMesh in [mesher.shell, mesher.slabs]:
			if mesh.get_surface_count() > 0:
				var count := mesh.surface_get_array_len(0)
				verts += count
				if mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_TEX_UV:
					with_uv += count
	print(
		(
			(
				"BAKE buildings=%d of %d voxels_ms=%.0f bake_ms=%.0f bake_ms_per_building=%.2f verts=%d"
				+ " uv_bytes=%d (UV on %d verts)"
			)
			% [
				n,
				sim.buildings.size(),
				vox_us / 1000.0,
				bake_us / 1000.0,
				bake_us / 1000.0 / maxi(1, n),
				verts,
				with_uv * 8,
				with_uv
			]
		)
	)
	quit()


## The voxels BuildingView would make for this building (BuildingView._make_voxels).
func _voxels(b: RampageSim.Building, party: Dictionary) -> BuildingVoxels:
	var base := Color("8a7f72")
	if b.is_rail():
		return RailVoxels.new(b, base)
	if b.landmark != "":
		return LandmarkVoxels.new(b, base)
	if b.hazard != "":
		return HazardVoxels.new(b, base)
	return BuildingVoxels.new(b, base, party)
