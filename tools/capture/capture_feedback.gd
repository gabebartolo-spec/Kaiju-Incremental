extends SceneTree
## Captures the pause menu's bug / feedback report (D-145): an autoplayed rampage is paused, the
## report button is clicked with a real mouse event, a message is typed, and the panel is shot;
## then SEND is clicked and the confirmation is shot. The report folder's screenshot.png and
## report.txt are copied out beside the stills so the picture the player's report carries can be
## checked (it must show the rampage, not the menu or the panel). Needs a window (no --headless):
## run with the untracked off-screen no_focus override.cfg.
##
##   APPDATA=<scratch> godot --path . --resolution 3840x2160 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_feedback.gd -- --out=<dir> [--species=reptilian]

const Kit := preload("res://tools/capture/capture_kit.gd")
const GuiInput := preload("res://tests/lib/gui_input.gd")
const SETTLE := 20
const PLAY_FRAMES := 60 * 14
const MESSAGE := "The tank at the bridge shot straight through a tower and my kaiju froze."

var _args := {}


func _initialize() -> void:
	_args = Kit.args({"out": "user://feedback", "species": "reptilian"})
	_run.call_deferred()


func _run() -> void:
	await process_frame
	if not Kit.window_ok():
		quit(1)
		return
	var out := str(_args["out"])
	DirAccess.make_dir_recursive_absolute(out)
	var stats := Kit.stats(str(_args["species"]), Kit.STAGE_LEVELS[1])
	var layout := CityGrowth.layout(Content.tuning(), Num.i(stats["size"]), Seeds.make("city", 0))
	var rampage := Kit.autoplay(self, str(_args["species"]), stats, 1, layout)
	await rampage.wait_loaded()
	await Kit.frames(self, PLAY_FRAMES)
	var hud: RampageHud = rampage.find_children("*", "RampageHud", true, false)[0]
	hud.pause()
	await Kit.frames(self, SETTLE)
	var menu: PauseMenu = rampage.find_children("*", "PauseMenu", true, false)[0]
	await GuiInput.click(self, GuiInput.button(menu, str(Content.section("feedback")["label"])))
	await Kit.frames(self, SETTLE)
	var panel: FeedbackPanel = menu.find_children("*", "FeedbackPanel", true, false)[0]
	panel.box.text = MESSAGE
	panel.box.set_caret_column(MESSAGE.length())
	await Kit.frames(self, SETTLE)
	print("shot ", Kit.still(self, out, "feedback_panel"))
	await GuiInput.click(self, GuiInput.button(panel, "SEND"))
	await Kit.frames(self, SETTLE)
	print("shot ", Kit.still(self, out, "feedback_saved"))
	for file: String in ["screenshot.png", "report.txt"]:
		DirAccess.copy_absolute(panel.report_path.path_join(file), out.path_join("report_" + file))
	print("report ", panel.report_path)
	print(FileAccess.get_file_as_string(panel.report_path.path_join("report.txt")))
	quit()
