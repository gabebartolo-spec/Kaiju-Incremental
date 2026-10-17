extends SceneTree
## Captures the game loop around the rampage through the real main scene: title, settings, the
## evolution tree, a rampage, the pause menu, the end beat, the results count-up, and the
## evolution reveal. Shots are PNGs; with --write-movie the same run is the flow clip. Render it
## on CI (tools/capture/ci_capture.sh), never windowed on the director's PC.
##
##   tools/capture/ci_capture.sh --resolution=1920x1080 capture_flow.gd -- --species=reptilian
##   tools/capture/ci_capture.sh --resolution=3840x2160 capture_flow.gd -- --ui-scale=1.25 --ui-only
## --ui-only keeps the rampage short (a few seconds) and skips the waits: the city at 4K on a
## software GPU outlasts CI's time limit. Pause and the report are still over the live city.
##   tools/capture/ci_capture.sh --movie --resolution=1280x720 capture_flow.gd -- --clip
## The clip is about 20 s (CI's step limit, tools/capture/README.md).

const MAIN_SCENE := "res://scenes/main.tscn"
const SETTLE := 12
## Autoplayed frames before the pause shot (shorter for the clip).
const RAMPAGE_FRAMES := 420
const CLIP_RAMPAGE_FRAMES := 150
const UI_ONLY_RAMPAGE_FRAMES := 45
## Clip: how long the report counts, then how long it holds, before EVOLVE.
const CLIP_COUNT_FRAMES := 45
const CLIP_HOLD_FRAMES := 45

var _out := "user://flow"
var _species := "reptilian"
var _clip := false
## Settings UI scale for the run (PlayerSettings.UI_SCALES), e.g. 1.25 at 3840x2160 for the TV.
var _ui_scale := 1.0
var _ui_only := false
var _main: Node


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--species="):
			_species = arg.substr(10)
		elif arg == "--clip":
			_clip = true
		elif arg == "--ui-only":
			_ui_only = true
		elif arg.begins_with("--ui-scale="):
			_ui_scale = float(arg.substr(11))
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	# One sim step per rendered frame: a slow software render must not fast-forward the fight
	# (8 steps a frame killed the kaiju before the pause shot in run 38992440820).
	Engine.max_physics_steps_per_frame = 1
	if _ui_scale != 1.0:
		for _i: int in PlayerSettings.UI_SCALES.size():
			if not is_equal_approx(PlayerSettings.ui_scale, _ui_scale):
				PlayerSettings.next_ui_scale()
	# A played save one evolution away, with a best to beat.
	var save := SaveFile.new_save(_species)
	save["runs"] = 3
	save["rubble"] = UpgradeTree.new(Content.upgrades(), {}, _species).cost("evolve1") + 20
	save["levels"] = {"claws": 2, "hide": 1, "rage": 1}
	save["best"] = {"rubble": 60.0, "destruction": 0.05, "toppled": 1.0, "tanks": 1.0}
	SaveFile.save_game(save)
	_main = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(_main)
	await _frames(SETTLE)
	var title := _screen()
	_shot("01_title")
	if not _clip:
		_press(title, "SETTINGS")
		await _frames(SETTLE)
		_shot("02_settings")
		var settings: SettingsMenu = title.find_children("*", "SettingsMenu", true, false)[0]
		settings.close()
		await _frames(SETTLE)
		var select := SpeciesSelect.new()
		root.add_child(select)
		await _frames(SETTLE)
		_shot("02b_species_select")
		select.queue_free()
		await _frames(2)
	_press(_screen(), "CONTINUE")
	await _frames(SETTLE)
	var tree := _screen() as UpgradeScreen
	tree.node_button("evolve1").grab_focus()
	await _frames(SETTLE)
	_shot("03_evolution_tree")
	tree.start_pressed.emit()
	await _frames(2)
	var rampage := _screen() as Rampage
	rampage.set_autoplay(true)
	var fight := RAMPAGE_FRAMES
	if _clip:
		fight = CLIP_RAMPAGE_FRAMES
	elif _ui_only:
		fight = UI_ONLY_RAMPAGE_FRAMES
	await _frames(fight)
	_shot("04_rampage")
	var hud: RampageHud = rampage.find_children("*", "RampageHud", true, false)[0]
	if not _clip:
		hud.pause()
		await _frames(SETTLE)
		_shot("05_pause")
		paused = false
		for menu: Node in rampage.find_children("*", "PauseMenu", true, false):
			menu.queue_free()
		await _frames(2)
	rampage.sim.time_left = 0.05  # capture only: run the clock out now
	await _frames(18)
	_shot("06_end_beat")
	if _ui_only:
		hud.finish_beat()
	while hud.beat_running():
		await process_frame
	await _frames(3)
	var results: ResultsScreen = rampage.find_children("*", "ResultsScreen", true, false)[0]
	if _clip:
		await _frames(CLIP_COUNT_FRAMES)
		results.skip()
		await _frames(CLIP_HOLD_FRAMES)
	elif _ui_only:
		results.skip()
	else:
		await _frames(ResultsScreen.COUNT_FRAMES * 2)
		_shot("07_results_counting")
		while results.counting():
			await process_frame
	await _frames(SETTLE)
	_shot("08_results")
	results.continued.emit()
	await _frames(SETTLE)
	tree = _screen() as UpgradeScreen
	tree.node_button("evolve1").pressed.emit()
	await _frames(EvolutionReveal.SWAP_FRAME - 6)
	_shot("09_reveal_before")
	await _frames(EvolutionReveal.GROW_FRAMES + 30)
	_shot("10_reveal_after")
	await _frames(EvolutionReveal.END_FRAME - EvolutionReveal.SWAP_FRAME)
	await _frames(SETTLE)
	_shot("11_tree_after")
	SaveFile.delete_save()
	quit()


func _screen() -> Node:
	return _main.call("screen")


func _press(node: Node, prefix: String) -> void:
	for found: Node in node.find_children("*", "Button", true, false):
		var b: Button = found
		if b.is_visible_in_tree() and b.text.begins_with(prefix):
			b.pressed.emit()
			return
	push_error("capture_flow: no button %s" % prefix)


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _shot(name: String) -> void:
	if _clip:
		return
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	image.save_png(path)
	print("saved ", path, " ", image.get_size())
