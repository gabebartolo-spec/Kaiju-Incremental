extends SceneTree
## Captures the game loop around the rampage through the real main scene: title, settings, the
## evolution tree, a rampage, the pause menu, the end beat, the results count-up, and the
## evolution reveal. Shots are PNGs; with --write-movie the same run is the flow clip. Render it
## on CI (tools/capture/ci_capture.sh), never windowed on the director's PC.
##
##   tools/capture/ci_capture.sh --resolution=1920x1080 capture_flow.gd -- --species=reptilian
##   tools/capture/ci_capture.sh --movie --resolution=1920x1080 capture_flow.gd -- --clip

const MAIN_SCENE := "res://scenes/main.tscn"
const SETTLE := 12
## Autoplayed frames before the pause shot (shorter for the clip).
const RAMPAGE_FRAMES := 420
const CLIP_RAMPAGE_FRAMES := 150

var _out := "user://flow"
var _species := "reptilian"
var _clip := false
var _main: Node


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--species="):
			_species = arg.substr(10)
		elif arg == "--clip":
			_clip = true
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
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
	await _frames(CLIP_RAMPAGE_FRAMES if _clip else RAMPAGE_FRAMES)
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
	while hud.beat_running():
		await process_frame
	await _frames(3)
	var results: ResultsScreen = rampage.find_children("*", "ResultsScreen", true, false)[0]
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
