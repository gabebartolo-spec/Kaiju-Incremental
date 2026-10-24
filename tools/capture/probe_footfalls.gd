extends SceneTree
## Every footfall of an autoplaying croc against the sim's body: which foot, how far ahead of
## kaiju_pos and out to the left (units at body scale 1), the sim's step phase and step ratio.
## Headless.
##
##   godot --path . --headless --script tools/capture/probe_footfalls.gd -- <size 1..3>


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var size := int(args[0]) if args.size() > 0 else 1
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), {})
	)
	stats["size"] = float(size)
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 1
	)
	rampage.set_autoplay(true)
	rampage.autoplay_signature = false
	root.add_child(rampage)
	var kaiju: KaijuModel = rampage._kaiju
	var gait: ClipGait = kaiju._rig.gait
	print("STRIDE size %d stride %.3f scale %.3f" % [size, gait.stride(), rampage.sim.body_scale()])
	kaiju.foot_planted.connect(
		func(side: String, strength: float, at: Vector3) -> void:
			if side == "tail":
				return
			var sim := rampage.sim
			var rel := Vector2(at.x, at.z) - sim.kaiju_pos
			var h := sim.body.heading
			var s := sim.body_scale()
			print(
				(
					(
						"FOOT size %d %s ahead %.2f across %.2f phase %.2f ratio %.2f stride %.2f "
						+ "turn %.2f str %.2f"
					)
					% [
						size,
						side,
						rel.dot(h) / s,
						rel.dot(h.orthogonal()) / s,
						sim.body.phase,
						sim.body.step_ratio,
						sim.body.stride,
						sim.body.turn_left,
						strength
					]
				)
			)
	)
	for _i: int in 60 * 25:
		await process_frame
	quit()
