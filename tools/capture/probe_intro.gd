extends SceneTree
## Probe for the run intro's shot (RunIntro.shot), headless and sim-only: per stage, where he
## rises, the water, bay and bank, and at key seconds the shot's eye and aim, how high the eye
## sits over the ground under it, whether the bay's ground and quays hide the head, neck and
## shoulders (BaySight), and how much of the frame's height the body above the water fills.
##   godot --headless --fixed-fps 60 --path . --script tools/capture/probe_intro.gd

const Kit := preload("res://tools/capture/capture_kit.gd")
const BaySight := preload("res://tests/lib/bay_sight.gd")
const DT := 1.0 / 60.0
const AT: Array[float] = [0.0, 0.5, 0.8, 1.0, 1.2, 1.4, 1.6, 2.0, 2.4, 2.7]


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for stage: int in range(1, CityGrowth.stage_count(Content.tuning()) + 1):
		_stage(stage)
	quit()


func _stage(stage: int) -> void:
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), Kit.STAGE_LEVELS[stage - 1], "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var tier := Num.i(stats["size"])
	var layout := CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", 0))
	var sim := RampageSim.new(stats, CityGrowth.for_stats(stats), layout, Seeds.make("army", 0))
	sim.body.use_species("reptilian")
	sim.emerge.start(sim)
	var plan := CityGen.map(sim.city)
	var water := sim.emerge.water_y()
	var s := sim.body_scale()
	print(
		(
			(
				"stage %d tier %d scale %.2f reach %.1f water %.1f rise %s facing %s bank %s bay %s"
				+ " break %.2f total %.2f"
			)
			% [
				stage,
				tier,
				s,
				sim.reach_height(),
				water,
				sim.kaiju_pos,
				sim.facing,
				plan.get("rise_bank"),
				plan.get("harbour"),
				sim.emerge.break_at(sim),
				sim.emerge.total()
			]
		)
	)
	var stone := BaySight.new(sim)
	var fov := CameraTuning.fov()
	var zoom := CameraTuning.zoom(s)
	var t := 0.0
	var next := 0
	while sim.emerge.active and next < AT.size():
		if t + 0.0001 >= AT[next]:
			var body := Vector3(sim.kaiju_pos.x, sim.stand_y, sim.kaiju_pos.y)
			var rest_eye := body + CameraTuning.offset() * zoom
			var rest_aim := body + Vector3(0, CameraFollow.LOOK_UP * s, 0)
			var cfg: Dictionary = Content.section("intro")
			var head := Vector2(
				Num.f(cfg["aim_ahead"]), Num.f(cfg["aim_head"]) * Num.f(sim.city["kaiju_height"])
			)
			var view := {
				"body": body, "eye": rest_eye, "aim": rest_aim, "fov": fov, "head": head * s
			}
			var shot := RunIntro.shot(sim, view, 0.0)
			var eye: Vector3 = shot["eye"]
			var aim: Vector3 = shot["aim"]
			var ground := CityHarbour.floor_at(plan, sim.city, Vector2(eye.x, eye.z))
			var hidden := 0
			var parts := BaySight.parts(sim)
			for p: Vector3 in parts:
				hidden += 1 if stone.hides(eye, p, true) else 0
			var top := sim.stand_y + sim.reach_height()
			var low := maxf(water, sim.stand_y)
			var dist := Vector2(eye.x - body.x, eye.z - body.z).length()
			var span := rad_to_deg(atan2(top - eye.y, dist) - atan2(low - eye.y, dist))
			print(
				(
					(
						"  t %.2f eye %s (%.1f over ground, %.1f from body) aim %s fov %.0f | body above"
						+ " water %.1f deg of %.0f | stone hides %d/%d parts | stand %.1f top %.1f"
					)
					% [
						t,
						eye.snappedf(0.1),
						eye.y - maxf(ground, water),
						dist,
						aim.snappedf(0.1),
						shot["fov"],
						span,
						shot["fov"],
						hidden,
						parts.size(),
						sim.stand_y,
						top
					]
				)
			)
			next += 1
		sim.step(DT, Vector2.ZERO, false, 0)
		t += DT
