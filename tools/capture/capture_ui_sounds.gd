extends SceneTree
## The menu sounds by real input, for the listening clip: three clicks on the settings' UI-scale
## button (it wraps back to 100%), then on the evolution tree one Sharpened Claws bought
## (confirm) and one refused for want of rubble (deny). Pair with --write-movie (it records the
## audio). Needs a window and the no-focus override.cfg.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --write-movie <dir>/ui.avi --script tools/capture/capture_ui_sounds.gd

const GuiInput := preload("res://tests/lib/gui_input.gd")
const GAP := 40


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _wait(20)
	var menu := SettingsMenu.new()
	root.add_child(menu)
	await _wait(GAP)
	for _i: int in 3:
		await GuiInput.click(self, GuiInput.button(menu, "1"))
		await _wait(GAP)
	menu.close()
	var tree := UpgradeTree.new(Content.upgrades(), {}, "reptilian")
	var screen := UpgradeScreen.new()
	screen.setup(tree, 30, Content.species_def("reptilian"), Content.section("kaiju"))
	root.add_child(screen)
	await _wait(GAP)
	var claws := GuiInput.button(screen, "Sharpened Claws")
	for _i: int in 2:
		await GuiInput.click(self, claws)
		await _wait(GAP)
	print("UI SOUNDS %s" % [Sfx.ui_played])
	quit()


func _wait(frames: int) -> void:
	for _i: int in frames:
		await process_frame
