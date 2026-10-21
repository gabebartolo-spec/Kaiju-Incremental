extends SceneTree
## Walk cadence per stage (research 11 R 11.1): the reptilian, driven by the real sim at 60 Hz the
## way the rampage scene drives it, walks straight at full stick for 10 s. Prints, per stage and
## upgrade set: sim speed (units/s and hip heights/s), walk cycles/s, footfalls/s, playback rate
## against the clip as authored, duty factor (share of frames a foot is down), catch steps/s and
## the worst foot drift. --off: the bare clips (ClipWeight.off). Headless.
##
##   godot --headless --path . --script tools/capture/probe_cadence.gd

const DT := 1.0 / 60.0
const FRAMES := 600
const TREES: Array[Dictionary] = [
	{},
	{"claws": 1, "stride": 4},
	{"evolve1": 1},
	{"evolve1": 1, "stride": 4},
	{"evolve1": 1, "evolve2": 1},
	{"evolve1": 1, "evolve2": 1, "stride": 4},
	{"evolve1": 1, "evolve2": 1, "evolve3": 1, "stride": 4},
]


func _initialize() -> void:
	ClipWeight.off = OS.get_cmdline_user_args().has("--off")  # the bare clips, the "before"
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for levels: Dictionary in TREES:
		_walk(levels)
		await process_frame
	quit()


func _walk(levels: Dictionary) -> void:
	var def := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), levels, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), def, tree)
	var layout: Array[Dictionary] = [
		{"x": 38.0, "z": 38.0, "w": 2, "d": 2, "h": 2, "tier": 1, "style": 0}
	]
	var sim := RampageSim.new(stats, Content.tuning(), layout, Seeds.make("army", 0))
	sim.body.use_species("reptilian")
	sim.kaiju_pos = Vector2(0, 40)
	var colors: Dictionary = def["colors"]
	var stage := KaijuModel.stage_for(sim.size_tier())
	var kaiju := KaijuModel.new("reptilian", colors, stage)
	kaiju.scale = Vector3.ONE * sim.body_scale()
	root.add_child(kaiju)
	var gait: ClipGait = kaiju._rig.gait
	var steps: Array[int] = [0]  # a lambda captures locals by value: count in an array
	kaiju._rig.foot_planted.connect(
		func(side: String, _k: float, _at: Vector3) -> void: steps[0] += 1 if side != "tail" else 0
	)
	var down := 0
	var catches := 0
	var was_catch := [false, false]
	var start_pos := sim.kaiju_pos
	var start_cycles := 0.0
	for f: int in FRAMES:
		if f == 120:
			steps[0] = 0
			catches = 0
			down = 0
			start_pos = sim.kaiju_pos
			start_cycles = gait.walk_cycles
		sim.step(DT, Vector2(0, -1), false, 0)
		if sim.over:
			print("  over at frame %d" % f)
			break
		kaiju.position = Vector3(sim.kaiju_pos.x, 0.0, sim.kaiju_pos.y)
		kaiju.rotation.y = atan2(-sim.body.heading.x, -sim.body.heading.y)
		kaiju.animate(DT, 1.0, -sim.body.turn_left)
		for i: int in 2:
			var c: bool = gait._catch[i] > 0.0
			if f >= 120:
				down += 1 if gait.legs[i].planted else 0
				catches += 1 if c and not was_catch[i] else 0
			was_catch[i] = c
	var secs := (FRAMES - 120) * DT
	var speed := (sim.kaiju_pos - start_pos).length() / secs
	var hip := kaiju.hip_height()
	var cps := (gait.walk_cycles - start_cycles) / secs
	var authored := (
		float(gait.clips.frames_of("walk")) / gait.clips.fps / gait.clips.cycles_of("walk")
	)
	print(
		(
			"cadence %s %s: scale %.2f speed %.2f u/s (%.2f hips/s) stride %.2f u (%.2f hips)"
			% [
				stage,
				levels,
				sim.body_scale(),
				speed,
				speed / hip,
				gait.stride(),
				gait.stride() / hip
			]
		)
	)
	print(
		(
			(
				"  cycles/s %.2f (cycle %.2f s, authored %.2f s, playback %.2fx) footfalls/s %.2f"
				% [cps, 1.0 / maxf(cps, 0.001), authored, cps * authored, steps[0] / secs]
			)
			+ (
				" duty %.2f catch/s %.2f drift %.3f hips"
				% [down / (2.0 * (FRAMES - 120)), catches / secs, kaiju.foot_drift() / hip]
			)
		)
	)
	kaiju.free()
