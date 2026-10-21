extends SceneTree
## Stills of the city at each growth stage (D-039): for every size tier, the stage's city with
## its kaiju (young, Behemoth, Colossus, Apex Titan) seen from high over the south edge (the
## whole playable city, its ring avenue and the districts still to come past it), and a closer
## view of the kaiju among the buildings it is the size of, and the in-game camera's view.
## Prints build time, building counts and frame timings per stage. Needs a window: run it on CI
## (tools/capture/ci_capture.sh capture_growth.gd), or off-screen with the no_focus override.
##
##   godot --path . --resolution 1280x720 --windowed \
##     --script tools/capture/capture_growth.gd -- --out=<dir> [--stage=N] [--quick]
## --quick: a few settle frames and no frame timings (a software-rendered CI frame of the
## Colossus city takes tens of seconds, and its timings mean nothing anyway).

const Kit := preload("res://tools/capture/capture_kit.gd")
const SETTLE := 12
const SPECIES := "reptilian"

var _out := "user://growth"
var _only := 0
var _settle := SETTLE
var _timed := true


func _initialize() -> void:
	var a := Kit.args({"out": _out, "stage": _only, "quick": false})
	_out = str(a["out"])
	_only = Num.i(a["stage"])
	if a["quick"]:
		_settle = 3
		_timed = false
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for tier: int in range(1, CityGrowth.stage_count(Content.tuning()) + 1):
		if _only == 0 or _only == tier:
			await _stage(tier)
	quit()


func _stage(tier: int) -> void:
	var species := Content.species_def(SPECIES)
	var stats := Kit.stats(SPECIES, Kit.STAGE_LEVELS[tier - 1], SPECIES)
	var sim := Kit.stage_sim(stats, tier, CityGrowth.tuning_for(Content.tuning(), tier))
	var half := CityGen.half_extent(sim.city)
	var started := Time.get_ticks_msec()
	var stage := Node3D.new()
	var city := CityView.new(sim, Seeds.make("fx", 0))
	stage.add_child(city)
	var colors: Dictionary = species["colors"]
	var kaiju := KaijuModel.new(SPECIES, colors, KaijuModel.stage_for(sim.size_tier()))
	# On the south ring avenue, where every rampage starts, facing into the city.
	var at := Vector3(sim.kaiju_pos.x, 0, sim.kaiju_pos.y)
	kaiju.position = at
	kaiju.scale = Vector3.ONE * sim.body_scale()
	stage.add_child(kaiju)
	var cam := Kit.camera(stage)
	root.add_child(stage)
	var built := Time.get_ticks_msec() - started
	cam.position = Vector3(half * 0.15, half * 1.05, half * 1.75)
	cam.look_at(Vector3(0, 0, -half * 0.15))
	cam.current = true
	await _frames(_settle)
	var id := "growth_%d" % tier
	_shot(id + "_aerial")
	print(
		(
			"stage %d half %.0f: %d buildings, %d chunks, built in %d ms, body %.2f, aerial %s"
			% [
				tier,
				half,
				sim.buildings.size(),
				sim.chunks_total,
				built,
				sim.body_scale(),
				await _measure()
			]
		)
	)
	var scale := sim.body_scale()
	# From over the edge behind it, high enough that no tower stands between camera and kaiju.
	cam.position = at + Vector3(10.0, 13.0, 15.0) * (0.75 + 0.6 * scale)
	cam.look_at(at + Vector3(0, 4.0 * scale, -6.0 * scale))
	await _frames(_settle)
	_shot(id + "_kaiju")
	print("stage %d kaiju view %s" % [tier, await _measure()])
	# The rampage's own camera (Rampage._place_camera at rest): what the player sees.
	cam.position = at + Kit.GAME_CAMERA * (0.75 + 0.4 * scale)
	cam.look_at(at + Vector3(0, 3.5 * scale, 0))
	await _frames(_settle)
	_shot(id + "_game")
	stage.queue_free()
	await process_frame


## Average GPU and CPU frame time (ms) over 30 frames, from the engine's own timers.
func _measure() -> String:
	if not _timed:
		return "(not timed)"
	Kit.measure_on(self)
	await _frames(10)
	var ms := await Kit.render_ms(self, 30)
	var tris := RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME
	)
	return "gpu %.1fms cpu %.1fms tris %dk" % [ms[0], ms[1], tris / 1000]


func _frames(n: int) -> void:
	await Kit.frames(self, n)


func _shot(shot_name: String) -> void:
	print("saved ", Kit.still(self, _out, shot_name))
