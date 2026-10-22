extends SceneTree
## The options menu's time-of-day row (D-145) for the screen critic, as the game draws it at 4K:
## <out>/settings_<setting>.png (the whole menu) and settings_<setting>_row.png (the row, cropped at
## its own pixels), for the default Random and for a fixed Night. Needs the off-screen no_focus
## override.cfg (a window).
##   godot --path . --resolution 3840x2160 --windowed
##     --script tools/capture/capture_time_setting.gd -- --out=<dir>

const Kit := preload("res://tools/capture/capture_kit.gd")
const SETTLE := 6
const ROW_PAD := Vector2(40, 24)

var _out := "user://time_setting"


func _initialize() -> void:
	_out = str(Kit.args({"out": _out})["out"])
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for setting: String in [TimeOfDay.RANDOM, "night"]:
		PlayerSettings.time_of_day = setting
		var menu := SettingsMenu.new()
		root.add_child(menu)
		await Kit.frames(self, SETTLE)
		var name := "random" if setting == TimeOfDay.RANDOM else setting
		var shot := root.get_texture().get_image()
		shot.save_png(_out.path_join("settings_%s.png" % name))
		var button: Button = menu.get("_time")
		var area := button.get_parent().get_global_rect()
		var factor := Vector2(shot.get_size()) / Vector2(root.get_visible_rect().size)
		var rect := Rect2i(
			((area.position - ROW_PAD) * factor).floor(),
			((area.size + ROW_PAD * 2.0) * factor).ceil()
		)
		rect = rect.intersection(Rect2i(Vector2i.ZERO, shot.get_size()))
		shot.get_region(rect).save_png(_out.path_join("settings_%s_row.png" % name))
		print(
			(
				"TIMEROW %s %s button %s text '%s'"
				% [name, rect, button.get_global_rect(), button.text]
			)
		)
		menu.queue_free()
		await process_frame
	PlayerSettings.time_of_day = TimeOfDay.RANDOM
	quit()
