extends SceneTree
## Captures the results screen once per ending (D-259, D-263, D-265) through the real main
## scene and real input: Continue, slot 1, RAMPAGE, a stretch of autoplay, then the run ends
## (the city falls, time's up, the army wins, End rampage from the pause menu), Enter past the
## end beat, the count lands, a shot; EVOLVE and RAMPAGE start the next. The save starts played,
## with modest bests, so records and misses both show. Render it at 3840x2160 off screen
## (the no_focus override.cfg plus window/size/borderless=true, so the desktop does not clamp the
## window below 4K), never in a window that takes focus.
##
##   godot --path . --script tools/capture/capture_results.gd -- --out=<dir>

const GuiInput := preload("res://tests/lib/gui_input.gd")
const MAIN_SCENE := "res://scenes/main.tscn"
const ENDINGS: Array[String] = ["city_fallen", "time", "defeated", "ended"]
const SETTLE := 12
const SHOT_SIZE := Vector2i(3840, 2160)
## Autoplayed frames before each ending, so the report has a rampage to count.
const FIGHT_FRAMES := 900
## Capture only: at most this many 1/60 s steps to finish the rise, and frames for an ending.
const RISE_STEPS := 1200
const END_WAIT_FRAMES := 900
## The save's bests before the first capture: low enough that a played run beats some rows.
const BEST := {
	"rubble": 400.0, "destruction": 0.08, "toppled": 2.0, "civilians": 30.0, "tanks": 2.0
}

var _out := "user://results"
var _main: Node


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	Engine.max_physics_steps_per_frame = 1
	# A 4K shot even where the desktop clamps a framed window (the override is borderless).
	root.size = SHOT_SIZE
	await _frames(2)
	SaveFile.wipe()
	var save := SaveFile.new_save("reptilian")
	save["runs"] = 3
	save["rubble"] = 200
	save["levels"] = {"claws": 2, "hide": 1, "rage": 1}
	save["best"] = BEST
	SaveFile.save_game(save, 1)
	_main = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(_main)
	await _frames(SETTLE)
	await GuiInput.click(self, GuiInput.button(_screen(), "CONTINUE"))
	await _frames(2)
	await GuiInput.click(self, GuiInput.button(_screen(), "SLOT 1"))
	await _frames(SETTLE)
	for reason: String in ENDINGS:
		await GuiInput.click(self, GuiInput.button(_screen(), "RAMPAGE"))
		await _frames(2)
		while _screen() is SpecimenCard:  # after a death: the 2 s lab card, then the rise
			await process_frame
		var results := await _play_to(_screen() as Rampage, reason)
		if results == null:
			push_error("no report for " + reason)
			break
		while results.counting():
			await process_frame
		await _frames(SETTLE)
		_shot("results_" + reason)
		await GuiInput.click(self, GuiInput.button(results, "EVOLVE"))
		await _frames(SETTLE)
	SaveFile.wipe()
	quit()


## Plays `rampage` for a while, then ends it for `reason`; returns the report after the beat.
func _play_to(rampage: Rampage, reason: String) -> ResultsScreen:
	await rampage.wait_loaded()
	rampage.set_autoplay(true)
	var steps := 0
	while rampage.sim.emerge.active and steps < RISE_STEPS:
		rampage.sim.emerge.step(rampage.sim, 1.0 / 60.0)
		steps += 1
	await _frames(FIGHT_FRAMES)
	var sim := rampage.sim
	if reason == "ended":
		await GuiInput.key(self, KEY_ESCAPE)
		var menu := GuiInput.find_script(rampage, PauseMenu)
		await GuiInput.click(self, GuiInput.button(menu, "END RAMPAGE"))
		await GuiInput.click(self, GuiInput.button(menu, "YES"))
	for _i: int in END_WAIT_FRAMES:
		if sim.over:
			break
		match reason:
			"time":
				sim.time_left = 0.0
			"defeated":
				sim.hp = -sim.max_hp
			"city_fallen":
				sim.chunks_destroyed = sim.chunks_total
		await process_frame
	print("ended ", reason, " as ", sim.end_reason)
	await _frames(RampageHud.BEAT_MIN_FRAMES + 2)
	await GuiInput.key(self, KEY_ENTER)
	await _frames(3)
	return GuiInput.find_script(rampage, ResultsScreen) as ResultsScreen


func _screen() -> Node:
	return _main.call("screen")


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	image.save_png(path)
	print("saved ", path, " ", image.get_size())
	if image.get_size() != SHOT_SIZE:
		push_error("shot is %s, not %s" % [image.get_size(), SHOT_SIZE])
