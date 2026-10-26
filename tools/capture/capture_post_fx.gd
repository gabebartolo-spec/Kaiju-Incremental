extends SceneTree
## The post effects (D-142) in a real autoplayed rampage at the game camera: the vignette in normal
## play, the red low-health pulse, and a colour fringe on a top-tier impact. One run, one fixed
## 60 fps clock, so the same seed gives the same frames every time.
##
##   --probe: headless, prints "FRINGE frame N" for every fringe a run of --frames=N shows (pick
##     --low_at from it), no pictures.
##   Clip (needs the off-screen no_focus override.cfg; render on the local GPU):
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 --write-movie <out>.avi \
##     --script tools/capture/capture_post_fx.gd -- --frames=N --low_at=M
## The run is the whole movie; cut the window with ffmpeg (-ss <start/60> -t 6). From --low_at the
## capture holds the kaiju's health at --low_share of its max, because the clip is about how it
## looks, not about the army: the one thing it sets by hand.
## --cost: after --frames ticks the run is paused on one frame and the GPU and render-CPU time is
## averaged over COST_FRAMES frames with the effects off, with the vignette only, and in the
## middle of a fringe burst, in COST_ROUNDS alternating rounds ("COST <mode> gpu .. cpu .. ms").
## --nofx: PostFx.enabled off, for the frame-cost comparison and the "off" frames.

const Kit := preload("res://tools/capture/capture_kit.gd")
const COST_FRAMES := 120
const COST_ROUNDS := 3
const COST_MODES: Array[String] = ["off", "vignette", "fringe"]

var _a: Dictionary


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	_a = (
		Kit
		. args(
			{
				"species": "reptilian",
				"stage": 2,  # STAGE_LEVELS index: the third body (a stomp wide enough for the fringe)
				"run": 1,  # picks the time of day (Content.time_for_run)
				"frames": 900,
				"low_at": 100000,
				"low_share": 0.08,
				"probe": false,
				"nofx": false,
				"cost": false,
				"preset": "high",
			}
		)
	)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	PostFx.enabled = _a["nofx"] != true
	PlayerSettings.graphics = str(_a["preset"])
	var stats := Kit.stats(str(_a["species"]), Kit.STAGE_LEVELS[Num.i(_a["stage"])])
	var layout := CityGrowth.layout(Content.tuning(), Num.i(stats["size"]), Seeds.make("city", 0))
	var rampage := Kit.autoplay(self, str(_a["species"]), stats, Num.i(_a["run"]), layout)
	var low_hp := rampage.sim.max_hp * Num.f(_a["low_share"])
	var fx: PostFx = rampage.find_children("*", "PostFx", true, false)[0]
	var was_on := false
	for frame: int in Num.i(_a["frames"]):
		await physics_frame
		if rampage.sim.over:
			break
		if frame >= Num.i(_a["low_at"]):
			rampage.sim.hp = low_hp
		var on: bool = fx.state.fringe_on()
		if on and not was_on and (_a["probe"] == true):
			print("FRINGE frame %d (%.2f s)" % [frame, frame / 60.0])
		was_on = on
	if _a["cost"] == true:
		await _cost(fx)
	print(
		(
			"done: %d s, hp %.0f of %.0f"
			% [Num.i(_a["frames"]) / 60, rampage.sim.hp, rampage.sim.max_hp]
		)
	)
	quit()


## Render cost on one paused frame: each mode in turn, alternating, so drift averages out.
func _cost(fx: PostFx) -> void:
	paused = true
	Kit.measure_on(self)
	await Kit.frames(self, 30)
	var sums := {}
	for _round: int in COST_ROUNDS:
		for mode: String in COST_MODES:
			PostFx.enabled = mode != "off"
			fx.state.update(5.0, 1.0, 1.0)  # past any cooldown, no burst running
			if mode == "fringe":
				fx.state.stomp(100.0)
			fx.update(0.05, 1.0, 1.0)  # a burst 0.05 s in is near its peak
			await Kit.frames(self, 10)
			var ms := await Kit.render_ms(self, COST_FRAMES)
			var sum: PackedFloat64Array = sums.get(mode, PackedFloat64Array([0.0, 0.0]))
			sum[0] += ms[0]
			sum[1] += ms[1]
			sums[mode] = sum
	for mode: String in COST_MODES:
		var sum: PackedFloat64Array = sums[mode]
		print("COST %s gpu %.3f cpu %.3f ms" % [mode, sum[0] / COST_ROUNDS, sum[1] / COST_ROUNDS])
