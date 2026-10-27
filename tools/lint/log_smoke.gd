extends SceneTree
## The engine-log smoke run (debt list row 1-2, D-295): plays a seeded rampage of every species
## (the title's skyline beast, the autoplayed kaiju, a death) and frees it all, so the run's log
## shows every engine error, warning and leak a real run makes. tools/lint/log_smoke.sh runs this
## and fails on any ERROR / WARNING / leak line in the log.
##
##   godot --headless --fixed-fps 60 --path . --script tools/lint/log_smoke.gd -- [--species=x]
##     [--seconds=N] [--stage=N] [--windowed]
## --seconds is sim seconds of rampage per species, --stage the growth stage's city (0: the flow
## test's). Seeded by design: Seeds.make streams, the autoplay kaiju and a fixed frame clock.

const Kit := preload("res://tools/capture/capture_kit.gd")
## Frames the death is watched for at most: his overload (stagger, stone, shatter, the shards
## landing) plays out before the run ends, about ten seconds with settle (D-294).
const DEATH_FRAMES := 1800
## Frames after everything is freed, so deferred frees run before the engine exits.
const DRAIN_FRAMES := 30

var _seconds := 24.0
var _stage := 2
var _only := ""


func _initialize() -> void:
	var a := Kit.args({"species": _only, "seconds": _seconds, "stage": _stage})
	_only = str(a["species"])
	_seconds = Num.f(a["seconds"])
	_stage = Num.i(a["stage"])
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	PlayerSettings.controls_seen = true  # no first-run controls card
	for def: Dictionary in Content.species():
		var id := str(def["id"])
		if _only == "" or _only == id:
			await _rampage(id)
	await Kit.frames(self, DRAIN_FRAMES)
	await QuitGame.settle_audio(self)  # a sound alive at exit leaks its stream and playbacks
	print("LOG_SMOKE done")
	quit()


## One seeded rampage: autoplayed for `_seconds` of sim time, then the kaiju is felled.
func _rampage(species_id: String) -> void:
	var levels: Dictionary = Kit.STAGE_LEVELS[clampi(_stage - 1, 0, 2)]
	var layout: Array[Dictionary] = []
	if _stage > 0:
		layout = CityGrowth.layout(Content.tuning(), _stage, Seeds.make("city", 0))
	var rampage := Kit.autoplay(
		self, species_id, Kit.stats(species_id, levels, species_id), 2, layout
	)
	await rampage.wait_loaded()
	print(
		(
			"log_smoke: %s skyline beasts %d"
			% [species_id, rampage.find_children("*", "FarBeast", true, false).size()]
		)
	)
	var start := Time.get_ticks_msec()
	while rampage.sim.elapsed < _seconds and not rampage.sim.over:
		await process_frame
	print(
		(
			"log_smoke: %s played %.1f s of sim in %d ms"
			% [species_id, rampage.sim.elapsed, Time.get_ticks_msec() - start]
		)
	)
	rampage.sim.hp = 0.0  # a death: the overload plays, then the sim ends the run "defeated"
	var waited := 0
	while not rampage.sim.over and waited < DEATH_FRAMES:
		waited += 1
		await process_frame
	print("log_smoke: %s ended %s after %d frames" % [species_id, rampage.sim.end_reason, waited])
	rampage.queue_free()
	await Kit.frames(self, DRAIN_FRAMES)
