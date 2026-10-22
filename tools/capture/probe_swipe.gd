extends SceneTree
## Swipe on vs off, the sim suite's fixture set-up, traced: every 2 s the kaiju's position,
## destruction, whether it is moving, its facing vs the way to the target, swipes and cuts.
## --city=N city seed (default 0), --run=N army seed.

const DT := 1.0 / 30.0
const MAX_STEPS := 30 * 400


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var city := 0
	var run := 0
	var trace := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--city="):
			city = arg.substr(7).to_int()
		elif arg.begins_with("--run="):
			run = arg.substr(6).to_int()
		elif arg == "--trace":
			trace = true
	for swipe_on: bool in [true, false]:
		var sim := _sim(city, run)
		if not swipe_on:
			sim.stats["swipe_damage"] = 0.0
		var steps := 0
		var target := Vector2(INF, INF)
		var still := 0
		var held := 0
		while not sim.over and steps < MAX_STEPS:
			if steps % 15 == 0:
				target = sim.nearest_standing(sim.kaiju_pos)
			var move := Vector2.ZERO
			if target.x < INF and sim.kaiju_pos.distance_to(target) > sim.stomp_radius() * 0.5:
				move = (target - sim.kaiju_pos).normalized()
			var was := sim.kaiju_pos
			sim.step(DT, move, sim.ability_ready_in <= 0.0)
			if move != Vector2.ZERO and sim.kaiju_pos.distance_to(was) < 0.001:
				still += 1
			if sim.body.held:
				held += 1
			if trace and steps % 60 == 0:
				print(
					(
						"  t %.0f pos %v dest %.3f move %s face-err %.0f deg swipes %d cut %d"
						% [
							steps * DT,
							sim.kaiju_pos.snapped(Vector2(0.1, 0.1)),
							Num.f(sim.result()["destruction"]),
							move != Vector2.ZERO,
							rad_to_deg(absf(sim.facing.angle_to(move))) if move != Vector2.ZERO else 0.0,
							sim.powers.swipe.swipes,
							sim.powers.swipe.cut
						]
					)
				)
			steps += 1
		print(
			(
				"city %d run %d swipe %s: dest %.4f, t %.1f s, swipes %d cut %d carved %d, stuck steps %d, held %d"
				% [
					city,
					run,
					swipe_on,
					Num.f(sim.result()["destruction"]),
					steps * DT,
					sim.powers.swipe.swipes,
					sim.powers.swipe.cut,
					sim.powers.swipe.carved,
					still,
					held
				]
			)
		)
	quit(0)


func _sim(city: int, run: int) -> RampageSim:
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), {})
	)
	var tune := Content.tuning()
	var city_cfg: Dictionary = tune["city"]
	var layout := CityGen.generate(Seeds.make("city", city), city_cfg)
	var sim := RampageSim.new(stats, tune, layout, Seeds.make("army", run))
	sim.ability_type = str(species["ability"]["type"])
	sim.body.use_species("reptilian")
	return sim
